#!/usr/bin/env bash
# wp-restore.sh <project-path> <backup-dir> [--dry-run] [--yes]
#
# Restores a folder written by wp-backup.sh, and proves it did.
#   1. every file in backup.json is checked against its sha256 BEFORE anything is touched;
#   2. the site's DB_NAME must equal the backup's (--yes overrides, the command asks first);
#   3. a pre-restore copy of the current state is taken with wp-backup.sh (uploads included
#      when the backup carries them); if it fails nothing is touched;
#   4. db import, then uploads swapped in with mv (the old directory stays as
#      uploads.pre-restore-<ts> until siteurl verifies, then it is removed);
#   5. `option get siteurl` must equal the backup's.
# --dry-run prints the plan and exits 0 without changing anything.
#
# Exit: 0 restored and verified; 1 refused or verification failed (the message gives the
#       pre-restore copy to go back to); 2 could not measure; 64 usage.
set -euo pipefail
umask 077

here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: wp-restore.sh <project-path> <backup-dir> [--dry-run] [--yes]" >&2; exit 64; }

[ $# -ge 2 ] || usage
project=$1; backup=$2; shift 2
dry=0 yes=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --yes) yes=1; shift ;;
    *) usage ;;
  esac
done
[ -d "$project" ] || { echo "wp-restore: $project is not a directory" >&2; exit 64; }
[ -d "$backup" ] || { echo "wp-restore: $backup is not a directory" >&2; exit 64; }
root=$(cd "$project" && pwd -P)
backup=$(cd "$backup" && pwd -P)
refuse() { echo "wp-restore: $*" >&2; exit 1; }

[ -f "$backup/backup.json" ] || refuse "$backup has no backup.json: not a wp-backup folder"
meta=$(META="$backup/backup.json" node -e '
  const m = JSON.parse(require("fs").readFileSync(process.env.META, "utf8"));
  if (!m.siteurl || !m.db_name || !Array.isArray(m.files) || !m.files.some((f) => f.name === "db.sql")) process.exit(3);
  for (const f of m.files) {
    if (!/^[A-Za-z0-9._-]+$/.test(f.name) || !/^[0-9a-f]{64}$/.test(f.sha256)) process.exit(3);
    console.log(["F", f.name, f.sha256].join("\t"));
  }
  console.log(["S", m.siteurl].join("\t"));
  console.log(["D", m.db_name].join("\t"));
') || refuse "backup.json is malformed or lists no db.sql"

# --- 1. checksums, before anything else ---
has_uploads=0 want_url="" want_db=""
while IFS=$'\t' read -r kind a b; do
  case "$kind" in
    F)
      [ -f "$backup/$a" ] || refuse "$a is listed in backup.json but missing; nothing was touched"
      got=$(sha256sum -- "$backup/$a"); got=${got%% *}
      [ "$got" = "$b" ] || refuse "sha256 of $a does not match backup.json; nothing was touched"
      [ "$a" != uploads.tar.gz ] || has_uploads=1 ;;
    S) want_url=$a ;;
    D) want_db=$a ;;
  esac
done <<< "$meta"

wrapper=$(node "$here/wp-config.mjs" get "$root" wp_cli.wrapper 2>/dev/null) || {
  echo "wp-restore: cannot read wp_cli.wrapper from $root/.wp-create.json" >&2; exit 2; }
WP=$wrapper
cd "$root"
cur_db=$(bash -c "$WP config get DB_NAME" 2>/dev/null) || cur_db=""
[ -n "$cur_db" ] || { echo "wp-restore: the WP-CLI wrapper ($WP) did not answer; cannot read DB_NAME" >&2; exit 2; }

db_match=1; [ "$cur_db" = "$want_db" ] || db_match=0

echo "wp-restore plan:" >&2
echo "  backup        $backup" >&2
echo "  checksums     verified" >&2
echo "  database      $cur_db <- db.sql (backup was taken from $want_db)" >&2
echo "  uploads       $([ "$has_uploads" = 1 ] && echo 'replaced from uploads.tar.gz (old one kept until siteurl verifies)' || echo 'untouched (not in this backup)')" >&2
echo "  pre-restore   a copy of the current state is taken first" >&2
echo "  verification  option get siteurl must equal $want_url" >&2
[ "$db_match" = 1 ] || echo "  WARNING       DB_NAME differs: without --yes this is refused" >&2

[ "$dry" = 0 ] || { echo "wp-restore: --dry-run, nothing changed" >&2; exit 0; }
[ "$db_match" = 1 ] || [ "$yes" = 1 ] || refuse "the site's DB_NAME ($cur_db) is not the backup's ($want_db); pass --yes to restore anyway"

# --- 3. pre-restore copy ---
pre_args=(--label pre-restore)
[ "$has_uploads" = 0 ] || pre_args+=(--uploads)
pre_out=$(bash "$here/wp-backup.sh" "$root" "${pre_args[@]}") || refuse "the pre-restore copy failed; nothing was touched"
pre=$(tail -n 1 <<< "$pre_out")
echo "wp-restore: pre-restore copy at $pre" >&2

# --- 4. import ---
q=$(printf '%q' "$backup/db.sql")
bash -c "$WP db import $q" || refuse "db import failed; go back with the pre-restore copy at $pre"

old=""
if [ "$has_uploads" = 1 ]; then
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  stage="$root/wp-content/.uploads-restore-$ts"
  # The site's files, not the backup's: extract with the archive's own modes (-p) under a
  # normal umask, or the umask 077 above would leave uploads 700/600 and unreadable to the
  # web server user.
  ( umask 022; mkdir -p -- "$stage" ) || refuse "cannot create $stage; database was imported, pre-restore copy at $pre"
  ( umask 022; tar -xzpf "$backup/uploads.tar.gz" -C "$stage" ) || { rm -rf -- "$stage"; refuse "uploads.tar.gz did not extract; database was imported, pre-restore copy at $pre"; }
  [ -d "$stage/uploads" ] || { rm -rf -- "$stage"; refuse "uploads.tar.gz has no uploads/ directory; pre-restore copy at $pre"; }
  if [ -d "$root/wp-content/uploads" ]; then
    old="$root/wp-content/uploads.pre-restore-$ts"
    mv -- "$root/wp-content/uploads" "$old"
  fi
  mv -- "$stage/uploads" "$root/wp-content/uploads"
  rmdir -- "$stage"
fi

# --- 5. verify ---
now_url=$(bash -c "$WP option get siteurl" 2>/dev/null) || now_url=""
if [ "$now_url" != "$want_url" ]; then
  refuse "after the import siteurl is '$now_url', the backup says '$want_url'; go back with the pre-restore copy at $pre${old:+ (previous uploads kept at $old)}"
fi
[ -z "$old" ] || rm -rf -- "$old"
echo "wp-restore: restored and verified (siteurl $now_url); pre-restore copy kept at $pre" >&2
printf '%s\n' "$pre"
