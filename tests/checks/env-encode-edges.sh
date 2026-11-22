#!/usr/bin/env bash
# Edge cases of bin/wp-env-setup.sh, bin/wp-cinematic-encode.sh, the lando template and
# store-kit-sync: detect never lets npx download, is_running reports the real state, the
# encoder refuses a non-scrubbable video and contradictory flags, the lando template points
# at no file nothing creates.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# --- SH-11: detect must not let npx install anything
grep >/dev/null -c 'npx --no-install wp-env' bin/wp-env-setup.sh || fail "detect calls npx without --no-install"
mkdir "$work/bin"
printf '#!/bin/sh\necho "$@" >> "%s/npx.log"\nexit 1\n' "$work" > "$work/bin/npx"; chmod +x "$work/bin/npx"
PATH="$work/bin:$PATH" bash bin/wp-env-setup.sh detect >/dev/null 2>&1 || true
if [ -f "$work/npx.log" ]; then
  grep >/dev/null -c -- '--no-install' "$work/npx.log" || fail "npx ran without --no-install: $(sed -n 1p "$work/npx.log")"
fi

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
grep >/dev/null -c 'KIT_DIR="\$HOME/' $enc || fail "leading ~ in --kit is not expanded"
grep >/dev/null -c 'pwd -P' $enc || fail "--theme is not resolved to an absolute path"
grep >/dev/null -c 'pids\[@\]+' $enc || fail "empty pids array unguarded under set -u"

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

# --- SH-22: nothing references a php.ini nobody creates
if grep >/dev/null -c 'lando/php.ini' templates/docker/.lando.yml.tpl; then
  grep >/dev/null -rlc 'lando/php.ini' skills commands bin || fail ".lando.yml.tpl references .lando/php.ini that nothing creates"
fi

# --- SH-25: the comment does not claim the plugin is never absent
! grep >/dev/null -c 'the plugin$' bin/store-kit-sync.sh || true
! grep -E 'would be absent, and' bin/store-kit-sync.sh >/dev/null || fail "store-kit-sync comment still claims the swap has no gap"

echo PASS
