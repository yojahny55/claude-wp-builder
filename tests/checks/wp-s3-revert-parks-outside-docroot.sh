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
[ "$(stat -c %a "$parked")" = 600 ] || fail "parked config is not 0600"
[ "$(stat -c %a "$(dirname "$parked")")" = 700 ] || fail "parked directory is not 0700"
grep -Fq canary-secret "$parked" || fail "the parked copy lost its content, so it cannot be re-enabled"
grep -Fq "mv '$parked'" <<<"$out" || fail "the output does not print the mv that restores it"

echo PASS
