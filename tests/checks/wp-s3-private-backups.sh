#!/usr/bin/env bash
# wp-s3 setup used to leave wp-config.php.bak-<stamp> and s3-config.php.bak-<stamp> beside
# the originals. Neither ends in .php, so the web server served them as plain text: the
# database credentials and the previous S3 secret, to anyone who guessed the name. The
# same run rewrote wp-config.php through a temp file and os.replace, which silently reset
# its 0640/0600 mode and owner. And the documented secret flow (`! read ... && export`)
# could not work: a `!` line runs in a subprocess, so the variable never reached the shell
# that ran the script. Runs the real script against a fixture root with a private HOME.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

setup=skills/wp-s3/scripts/s3-setup.sh
revert=skills/wp-s3/scripts/s3-revert.sh
cmd=commands/wp-s3.md

tmp="$(mktemp -d -t wp-s3-backups-XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
root="$tmp/site"; home="$tmp/home"
mkdir -p "$root/wp-content/plugins" "$home"
cat > "$root/wp-config.php" <<'PHP'
<?php
define( 'DB_PASSWORD', 'fixture-db-password' );
require_once ABSPATH . 'wp-settings.php';
PHP
chmod 640 "$root/wp-config.php"
printf '%s\n' 'fixture-secret' > "$tmp/secret"; chmod 644 "$tmp/secret"

run() { HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= env -u S3_UPLOADS_SECRET_VALUE bash "$setup" \
  --wp-root "$root" --bucket b --region r --bucket-url https://m.example.test --auth key --key K \
  --skip-plugin-install "$@"; }

# A secret file readable by others is refused; the env var and the file are exclusive.
run --secret-file "$tmp/secret" >/dev/null 2>&1 && fail "a world-readable --secret-file was accepted"
chmod 600 "$tmp/secret"
run --secret-file "$tmp/secret" >"$tmp/out" 2>&1 || { cat "$tmp/out"; fail "setup failed with a 0600 --secret-file"; }
grep -Fq "fixture-secret" "$root/s3-config.php" || fail "the secret in --secret-file never reached s3-config.php"
! grep -Fq "fixture-secret" "$tmp/out" || fail "the secret was printed"

# Nothing backup-shaped beside the originals; the copies are private.
! ls "$root"/*.bak-* >/dev/null 2>&1 || fail "a .bak-* file was left in the docroot"
bdir="$(find "$home/.local/state/wp-s3-backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$bdir" ] || fail "no backup directory under the home state dir"
[ "$(stat -c %a "$bdir")" = 700 ] || fail "backup directory is not 0700"
for b in "$bdir"/wp-config.php.bak-*; do
  [ "$(stat -c %a "$b")" = 600 ] || fail "$b is not 0600"
done

# The rewrite keeps the original mode.
[ "$(stat -c %a "$root/wp-config.php")" = 640 ] || fail "wp-config.php lost its 0640 mode"

# A second run backs up the existing s3-config.php, also privately.
run --secret-file "$tmp/secret" >/dev/null 2>&1 || fail "second run failed"
ls "$bdir"/s3-config.php.bak-* >/dev/null 2>&1 || fail "s3-config.php was not backed up to the private dir"
for b in "$bdir"/s3-config.php.bak-*; do [ "$(stat -c %a "$b")" = 600 ] || fail "$b is not 0600"; done

# The revert shares the defect.
! grep -Fq '"$WP_ROOT/wp-config.php.bak-' "$revert" || fail "$revert still backs up beside wp-config.php"
grep -Fq 'shutil.copymode' "$revert" || fail "$revert's rewrite does not keep wp-config.php's mode"

# The documented flow must be one that works.
! grep -Fq 'export S3_UPLOADS_SECRET_VALUE' "$cmd" || fail "$cmd still tells the user to export the secret from a ! line"
grep -Fq -- '--secret-file' "$cmd" || fail "$cmd does not document --secret-file"

echo PASS
