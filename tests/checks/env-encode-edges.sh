#!/usr/bin/env bash
# Edge cases of bin/wp-env-setup.sh, bin/wp-cinematic-encode.sh, the lando template and
# store-kit-sync: detect never lets npx download, is_running reports the real state, the
# encoder refuses a non-scrubbable video and contradictory flags, the lando template points
# at no file nothing creates.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# --- SH-11: detect must not let npx install anything
grep >/dev/null -c 'npx --no-install wp-env' bin/wp-env-setup.sh || fail "detect calls npx without --no-install"
mkdir "$work/bin"
printf '#!/bin/sh\necho "$@" >> "%s/npx.log"\nexit 1\n' "$work" > "$work/bin/npx"; chmod +x "$work/bin/npx"
PATH="$work/bin:$PATH" bash bin/wp-env-setup.sh detect >/dev/null 2>&1 || true
[ -f "$work/npx.log" ] || fail "detect never called npx"
grep >/dev/null -c -- '--no-install' "$work/npx.log" || fail "npx ran without --no-install: $(sed -n 1p "$work/npx.log")"

# --- SH-13: is_running returns the real state; a || b reaches the second service
cat > "$work/bin/systemctl" <<'SH'
#!/bin/sh
[ "$2" = "mysql" ]
SH
chmod +x "$work/bin/systemctl"
out=$(PATH="$work/bin:$PATH" bash -c '
  OS=linux
  eval "$(sed -n "/^is_running()/,/^}/p;/^any_running()/,/^}/p" bin/wp-env-setup.sh)"
  a=$(is_running mariadb || true); b=$(is_running mysql || true); c=$(any_running mariadb mysql)
  if is_running mariadb >/dev/null; then r1=up; else r1=down; fi
  echo "$a $b $c $r1"')
[ "$out" = "false true true down" ] || fail "is_running/any_running gave: $out"

# --- SH-21 / SH-15: encoder usage errors, tilde, relative theme
enc=bin/wp-cinematic-encode.sh
touch "$work/in.mp4"; mkdir -p "$work/theme"
set +e
bash $enc "$work/in.mp4" --theme="$work/theme" --desktop-only --mobile-only >/dev/null 2>&1; rc=$?
set -e
[ "$rc" = 2 ] || fail "--desktop-only --mobile-only exited $rc, want 2"
grep >/dev/null -c 'pids\[@\]+' $enc || fail "(static grep) empty pids array unguarded under set -u"

# --- SH-09: failed keyframe check exits non-zero before any import
fakebin="$work/fb"; mkdir -p "$fakebin" "$work/kit/scripts"
printf '#!/bin/sh\nexit 0\n' > "$fakebin/ffmpeg"
printf '#!/bin/sh\necho "0,0,P"\n' > "$fakebin/ffprobe"
printf '#!/bin/sh\necho "$@" >> "%s/wp.log"\nexit 0\n' "$work" > "$fakebin/wp"
chmod +x "$fakebin"/*
printf '#!/bin/sh\n: > "$2"\n' > "$work/kit/scripts/encode-keyframe.sh"
printf '#!/bin/sh\n: > "$2"\n' > "$work/kit/scripts/encode-mobile-portrait.sh"
set +e
PATH="$fakebin:$PATH" bash $enc "$work/in.mp4" --theme="$work/theme" --kit="$work/kit" --scene=2 >/dev/null 2>&1; rc=$?
set -e
[ "$rc" = 1 ] || fail "failed keyframe verification exited $rc, want 1"
[ ! -f "$work/wp.log" ] || fail "video imported despite failed keyframe verification"

# --- SH-21 behaviour: tilde kit and relative theme, through the same fakes
mkdir -p "$work/home/kit/scripts" "$work/root/wp-content/themes/t"
cp "$work/kit/scripts/"* "$work/home/kit/scripts/"
printf '#!/bin/sh\nfor i in 1 2 3 4 5 6 7 8 9 10; do echo "0,0,I,x"; done\n' > "$fakebin/ffprobe"
printf '#!/bin/sh\necho "$@" >> "%s/wp2.log"\ncase "$1$2" in *media*import*) echo 7;; esac\nexit 0\n' "$work" > "$fakebin/wp"
set +e
out=$(HOME="$work/home" PATH="$fakebin:$PATH" bash $enc "$work/in.mp4" --theme="$work/theme" --kit='~/kit' --desktop-only 2>&1); rc=$?
set -e
[ "$rc" = 0 ] || fail "--kit='~/kit' not resolved (rc=$rc): $out"
rm -f "$work/wp2.log"
root=$(cd "$work/root" && pwd -P)
cp "$work/in.mp4" "$work/root/in.mp4"
(cd "$work/root/wp-content/themes/t" && PATH="$fakebin:$PATH" bash "$OLDPWD/$enc" ../../../in.mp4 --theme=. --kit="$work/kit" --scene=1 >/dev/null 2>&1) || fail "--theme=. run failed"
grep >/dev/null -c -- "--path=$root " "$work/wp2.log" || fail "--theme=. did not import against $root: $(cat "$work/wp2.log" 2>/dev/null)"

# --- SH-22: the template references no php.ini nobody creates
! grep >/dev/null -c 'lando/php.ini' templates/docker/.lando.yml.tpl || fail ".lando.yml.tpl references .lando/php.ini"

# --- SH-25: comment states the gap
! grep -E 'would be absent, and' bin/store-kit-sync.sh >/dev/null || fail "store-kit-sync comment still claims the swap has no gap"

echo PASS
