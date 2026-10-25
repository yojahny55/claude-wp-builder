#!/usr/bin/env bash
# s3-revert.sh used to park the config as s3-config.php.disabled beside wp-config.php. That
# name no longer ends in .php, so a web server serves it as plain text, bucket key and
# secret included. It must now land in a 0600 file inside a 0700 directory outside the
# docroot, leave nothing credential-shaped behind, and stay restorable with one mv.
# Runs the real script against a fixture root with a private HOME.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
revert="$PWD/skills/wp-s3/scripts/s3-revert.sh"

tmp="$(mktemp -d -t wp-s3-revert-XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
root="$tmp/site"; home="$tmp/home"
mkdir -p "$root/wp-content/uploads" "$root/wp-content/mu-plugins" "$home"
echo '<?php // wp-config' > "$root/wp-config.php"
printf "<?php\ndefine('S3_UPLOADS_SECRET', 'canary-secret');\n" > "$root/s3-config.php"
echo '<?php' > "$root/wp-content/mu-plugins/s3-uploads-endpoint.php"

out="$(HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= PATH="$(dirname "$(command -v bash)"):/usr/bin:/bin" \
  bash "$revert" "$root" --keep-remote-media 2>&1)" || { echo "$out"; fail "revert did not finish"; }

[ ! -e "$root/s3-config.php" ] || fail "s3-config.php is still in the docroot"
[ -z "$(find "$root" -name 's3-config*' -not -path '*/mu-plugins/*')" ] \
  || fail "something s3-config-shaped is still inside the docroot"
parked="$(find "$home/.local/state/wp-s3-backups" -name s3-config.php.disabled | head -1)"
[ -n "$parked" ] || fail "no parked config under the private state dir"
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ "$(mode "$parked")" = 600 ] || fail "parked config is not 0600"
[ "$(mode "$(dirname "$parked")")" = 700 ] || fail "parked directory is not 0700"
grep -Fq canary-secret "$parked" || fail "the parked copy lost its content, so it cannot be re-enabled"
grep -Fq "mv '$parked'" <<<"$out" || fail "the output does not print the mv that restores it"

# Legacy leftover: only a docroot s3-config.php.disabled from the previous version.
root2="$tmp/site2"; home2="$tmp/home2"
mkdir -p "$root2/wp-content/uploads" "$home2"
echo '<?php // wp-config' > "$root2/wp-config.php"
printf "<?php\ndefine('S3_UPLOADS_SECRET', 'legacy-canary');\n" > "$root2/s3-config.php.disabled"
out="$(HOME="$home2" WP_S3_BACKUP_DIR= XDG_STATE_HOME= PATH="$(dirname "$(command -v bash)"):/usr/bin:/bin" \
  bash "$revert" "$root2" --keep-remote-media 2>&1)" || { echo "$out"; fail "legacy revert did not finish"; }
[ ! -e "$root2/s3-config.php.disabled" ] || fail "legacy .disabled is still in the docroot"
parked2="$(find "$home2/.local/state/wp-s3-backups" -name 's3-config.php.disabled*' | head -1)"
[ -n "$parked2" ] || fail "legacy .disabled was not parked"
[ "$(mode "$parked2")" = 600 ] || fail "parked legacy file is not 0600"
grep -Fq legacy-canary "$parked2" || fail "parked legacy file lost its content"

# No sha256sum on PATH (macOS): the shasum fallback has to run instead of errexit ending the script.
if command -v shasum >/dev/null 2>&1; then
  bin="$tmp/bin"; mkdir -p "$bin"
  for tool in bash env date cut printf grep sed php python3 dirname mkdir chmod cp rm mv cat head find perl; do
    p="$(command -v "$tool" 2>/dev/null || true)"; [ -n "$p" ] && ln -sf "$p" "$bin/$tool"
  done
  ln -sf "$(command -v shasum)" "$bin/shasum"
  [ ! -e "$bin/sha256sum" ] || fail "fixture bin unexpectedly has sha256sum"
  root3="$tmp/site3"; home3="$tmp/home3"
  mkdir -p "$root3/wp-content/uploads" "$home3"
  echo '<?php // wp-config' > "$root3/wp-config.php"
  printf "<?php\n" > "$root3/s3-config.php"
  out="$(HOME="$home3" WP_S3_BACKUP_DIR= XDG_STATE_HOME= PATH="$bin" \
    bash "$revert" "$root3" --keep-remote-media 2>&1)" || { echo "$out"; fail "revert aborted without sha256sum"; }
  [ -n "$(find "$home3/.local/state/wp-s3-backups" -name s3-config.php.disabled)" ] \
    || fail "no parked config when sha256sum is absent"
else
  echo "SKIP: no shasum on this machine, the sha256sum-less case was not exercised"
fi

echo PASS
