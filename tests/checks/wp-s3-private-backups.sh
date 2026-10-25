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
file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null; }

setup=skills/wp-s3/scripts/s3-setup.sh
revert=skills/wp-s3/scripts/s3-revert.sh
cmd=commands/wp-s3.md

tmp="$(mktemp -d -t wp-s3-backups-XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
root="$tmp/site"; home="$tmp/home"
mkdir -p "$root/wp-content/plugins" "$root/wp-content/uploads" "$home"
cat > "$root/wp-config.php" <<'PHP'
<?php
define( 'DB_PASSWORD', 'fixture-db-password' );
require_once ABSPATH . 'wp-settings.php';
PHP
chmod 640 "$root/wp-config.php"
orig_og="$(stat -c %U:%G "$root/wp-config.php")"
printf '%s\n' 'fixture-secret' > "$tmp/secret"; chmod 644 "$tmp/secret"

run() { HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= env -u S3_UPLOADS_SECRET_VALUE bash "$setup" \
  --wp-root "$root" --bucket b --region r --bucket-url https://m.example.test --auth key --key K \
  --skip-plugin-install "$@"; }

# An operator override cannot put credential backups under the web root, even via symlink.
mkdir -p "$root/private"
HOME="$home" WP_S3_BACKUP_DIR="$root/private" XDG_STATE_HOME= S3_UPLOADS_SECRET_VALUE=fixture-secret \
  bash "$setup" --wp-root "$root" --bucket b --region r --bucket-url https://m.example.test \
  --auth key --key K --skip-plugin-install >"$tmp/inside.out" 2>&1 \
  && fail "a backup directory inside the document root was accepted"
grep -Fq 'backup directory must be outside' "$tmp/inside.out" || fail "inside-docroot rejection was unclear"
ln -s "$root" "$tmp/symlink-into-root"
HOME="$home" WP_S3_BACKUP_DIR="$tmp/symlink-into-root/private" XDG_STATE_HOME= S3_UPLOADS_SECRET_VALUE=fixture-secret \
  bash "$setup" --wp-root "$root" --bucket b --region r --bucket-url https://m.example.test \
  --auth key --key K --skip-plugin-install >"$tmp/symlink.out" 2>&1 \
  && fail "a symlink into the document root was accepted"
grep -Fq 'backup directory must be outside' "$tmp/symlink.out" || fail "symlink rejection was unclear"
[ ! -e "$root/s3-config.php" ] || fail "setup wrote credential config before rejecting the backup location"

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
case "$(file_mode "$bdir")" in 700|0700) ;; *) false ;; esac || fail "backup directory is not 0700"
shopt -s nullglob
wp_backups=("$bdir"/wp-config.php.bak-*)
[ "${#wp_backups[@]}" -gt 0 ] || fail "no wp-config.php backup was created"
for b in "${wp_backups[@]}"; do
  case "$(file_mode "$b")" in 600|0600) ;; *) fail "$b is not 0600" ;; esac
done
shopt -u nullglob

# The rewrite keeps the original mode.
case "$(file_mode "$root/wp-config.php")" in 640|0640) ;; *) false ;; esac || fail "wp-config.php lost its 0640 mode"

# ...and the original owner:group (the rename must not hand the file to another group).
[ "$(stat -c %U:%G "$root/wp-config.php")" = "$orig_og" ] || fail "wp-config.php lost its owner:group"

# When chown cannot restore the group (not root, group the operator is not primary in),
# the rewrite must go in place instead of renaming a file with the wrong group over it.
# Reproduced without root: chgrp the fixture to a supplementary group, and make os.chown
# fail through a sitecustomize, which is what EPERM on a foreign group looks like.
alt_gid=""
for g in $(id -G); do [ "$g" != "$(id -g)" ] && { alt_gid=$g; break; }; done
if [ -n "$alt_gid" ]; then
  mkdir -p "$tmp/eperm"
  printf '%s\n' 'import os' 'def _deny(*a, **k): raise PermissionError(1, "Operation not permitted")' 'os.chown = _deny' > "$tmp/eperm/sitecustomize.py"
  root2="$tmp/site2"; mkdir -p "$root2/wp-content/plugins" "$root2/wp-content/uploads"
  cp "$root/wp-config.php" "$root2/wp-config.php"
  # Fresh config without the s3 require, mode 0640, group = a supplementary group.
  printf '%s\n' '<?php' "define( 'DB_PASSWORD', 'fixture-db-password' );" "require_once ABSPATH . 'wp-settings.php';" > "$root2/wp-config.php"
  chmod 640 "$root2/wp-config.php"; chgrp "$alt_gid" "$root2/wp-config.php"
  before_og="$(stat -c %U:%G "$root2/wp-config.php")"; before_ino="$(stat -c %i "$root2/wp-config.php")"
  HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= PYTHONPATH="$tmp/eperm" S3_UPLOADS_SECRET_VALUE=fixture-secret \
    bash "$setup" --wp-root "$root2" --bucket b --region r --bucket-url https://m.example.test \
    --auth key --key K --skip-plugin-install >"$tmp/eperm.out" 2>&1 || { cat "$tmp/eperm.out"; fail "setup failed when chown was refused"; }
  grep -Fq "s3-config.php" "$root2/wp-config.php" || fail "the require was not written when chown was refused"
  [ "$(stat -c %U:%G "$root2/wp-config.php")" = "$before_og" ] || fail "setup changed wp-config.php's group when chown was refused"
  [ "$(stat -c %i "$root2/wp-config.php")" = "$before_ino" ] || fail "setup replaced the wp-config.php inode when chown was refused"
  case "$(file_mode "$root2/wp-config.php")" in 640|0640) ;; *) fail "setup changed wp-config.php's mode when chown was refused" ;; esac
  HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= PYTHONPATH="$tmp/eperm" bash "$revert" "$root2" --keep-remote-media >"$tmp/eperm-revert.out" 2>&1 \
    || { cat "$tmp/eperm-revert.out"; fail "revert failed when chown was refused"; }
  ! grep -Fq "s3-config.php" "$root2/wp-config.php" || fail "revert did not remove the require when chown was refused"
  [ "$(stat -c %U:%G "$root2/wp-config.php")" = "$before_og" ] || fail "revert changed wp-config.php's group when chown was refused"
  [ "$(stat -c %i "$root2/wp-config.php")" = "$before_ino" ] || fail "revert replaced the wp-config.php inode when chown was refused"
else
  echo "NOTE: no supplementary group; the refused-chown case was not exercised"
fi

# A second run backs up the existing s3-config.php, also privately.
run --secret-file "$tmp/secret" >/dev/null 2>&1 || fail "second run failed"
shopt -s nullglob
s3_backups=("$bdir"/s3-config.php.bak-*)
[ "${#s3_backups[@]}" -gt 0 ] || fail "s3-config.php was not backed up to the private dir"
for b in "${s3_backups[@]}"; do case "$(file_mode "$b")" in 600|0600) ;; *) fail "$b is not 0600" ;; esac; done
shopt -u nullglob

# Revert must never leave the credential-bearing config as plain text in the docroot.
HOME="$home" WP_S3_BACKUP_DIR= XDG_STATE_HOME= bash "$revert" "$root" --keep-remote-media >"$tmp/revert.out" 2>&1 \
  || { cat "$tmp/revert.out"; fail "revert failed against the fixture root"; }
[ ! -e "$root/s3-config.php" ] && [ ! -e "$root/s3-config.php.disabled" ] \
  || fail "revert left the S3 config in the docroot"
parked=$(find "$home/.local/state/wp-s3-backups" -type f -name 's3-config.php.disabled*' | head -1)
[ -n "$parked" ] || fail "revert did not park s3-config.php outside the docroot"
[ "$(file_mode "$parked")" = 600 ] || [ "$(file_mode "$parked")" = 0600 ] || fail "parked s3-config.php is not 0600"

# Setup and revert derive the directory from the same root: revert parks beside setup's backups.
pdir="$(dirname "$parked")"
ls "$pdir"/wp-config.php.bak-* >/dev/null 2>&1 \
  || fail "revert parked in $pdir, which holds none of setup's wp-config.php backups"

# The revert must also preserve wp-config.php's mode.
grep -Fq 'shutil.copymode' "$revert" || fail "$revert's rewrite does not keep wp-config.php's mode"

# The documented flow must be one that works.
! grep -Fq 'export S3_UPLOADS_SECRET_VALUE' "$cmd" || fail "$cmd still tells the user to export the secret from a ! line"
grep -Fq -- '--secret-file' "$cmd" || fail "$cmd does not document --secret-file"

echo PASS
