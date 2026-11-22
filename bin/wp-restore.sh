#!/usr/bin/env bash
# wp-restore.sh <project-path> <backup-dir> [--dry-run] [--yes] [--wrapper "<cmd>"]
#
# Restores a folder written by wp-backup.sh, and proves it did.
#   1. every file in backup.json is checked against its sha256 BEFORE anything is touched;
#   2. the site's DB_NAME must equal the backup's (--yes overrides, the command asks first);
#   3. a pre-restore copy of the current state is taken with wp-backup.sh (uploads included
#      when the backup carries them); if it fails nothing is touched;
#   4. db import, then uploads swapped in with mv (the old directory stays as
#      uploads.pre-restore-<ts> until siteurl verifies, then it is removed);
#   5. `option get siteurl` must equal the backup's, the post count must be equal and the table
#      count at least the backup's (see the comment at the check).
# --wrapper "<cmd>" supplies the WP-CLI wrapper instead of reading it from the manifest (same
# meaning as in wp-backup.sh), and is handed on to the pre-restore copy.
# --dry-run prints the plan and exits 0 without changing anything.
#
# Exit: 0 restored and verified; 1 refused or verification failed (the message gives the
#       pre-restore copy to go back to); 2 could not measure; 64 usage.
set -euo pipefail
umask 077

here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: wp-restore.sh <project-path> <backup-dir> [--dry-run] [--yes] [--wrapper \"<cmd>\"]" >&2; exit 64; }

[ $# -ge 2 ] || usage
project=$1; backup=$2; shift 2
dry=0 yes=0 wrapper=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --yes) yes=1; shift ;;
    --wrapper) [ $# -ge 2 ] || usage; wrapper=$2; shift 2 ;;
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
  console.log(["T", m.tables ?? ""].join("\t"));
  console.log(["P", m.posts ?? ""].join("\t"));
  console.log(["U", Number.isInteger(m.uploads_files) ? m.uploads_files : ""].join("\t"));
') || refuse "backup.json is malformed or lists no db.sql"

# --- 1. checksums, before anything else ---
has_uploads=0 want_url="" want_db="" want_tables="" want_posts="" want_files=""
while IFS=$'\t' read -r kind a b; do
  case "$kind" in
    F)
      [ -f "$backup/$a" ] || refuse "$a is listed in backup.json but missing; nothing was touched"
      got=$(sha256sum -- "$backup/$a"); got=${got%% *}
      [ "$got" = "$b" ] || refuse "sha256 of $a does not match backup.json; nothing was touched"
      [ "$a" != uploads.tar.gz ] || has_uploads=1 ;;
    S) want_url=$a ;;
    D) want_db=$a ;;
    T) want_tables=$a ;;
    P) want_posts=$a ;;
    U) want_files=$a ;;
  esac
done <<< "$meta"

if [ -z "$wrapper" ]; then
  wrapper=$(node "$here/wp-config.mjs" get "$root" wp_cli.wrapper 2>/dev/null) || {
    echo "wp-restore: cannot read wp_cli.wrapper from $root/.wp-create.json (pass --wrapper)" >&2; exit 2; }
fi
WP=$wrapper
cd "$root"
cur_db=$(bash -c "$WP config get DB_NAME" 2>/dev/null) || cur_db=""
[ -n "$cur_db" ] || { echo "wp-restore: the WP-CLI wrapper ($WP) did not answer; cannot read DB_NAME" >&2; exit 2; }

db_match=1; [ "$cur_db" = "$want_db" ] || db_match=0
cur_url=$(bash -c "$WP option get siteurl" 2>/dev/null) || cur_url=""
[ -n "$cur_url" ] || { echo "wp-restore: the WP-CLI wrapper did not answer 'option get siteurl'" >&2; exit 2; }
url_match=1; [ "$cur_url" = "$want_url" ] || url_match=0

echo "wp-restore plan:" >&2
echo "  backup        $backup" >&2
echo "  checksums     verified" >&2
echo "  database      $cur_db <- db.sql (backup was taken from $want_db)" >&2
echo "  uploads       $([ "$has_uploads" = 1 ] && echo 'replaced from uploads.tar.gz (old one kept until siteurl verifies)' || echo 'untouched (not in this backup)')" >&2
echo "  pre-restore   a copy of the current state is taken first" >&2
echo "  verification  option get siteurl must equal $want_url" >&2
echo "  counts        $([ -n "$want_tables$want_posts" ] && echo "after the import: tables >= ${want_tables:-?} (the dump replaces only its own), posts = ${want_posts:-?}" || echo 'not recorded in this backup: not verified')" >&2
[ "$db_match" = 1 ] || echo "  WARNING       DB_NAME differs: without --yes this is refused" >&2
[ "$url_match" = 1 ] || echo "  WARNING       the site's siteurl ($cur_url) is not the backup's ($want_url): without --yes this is refused" >&2

[ "$dry" = 0 ] || { echo "wp-restore: --dry-run, nothing changed" >&2; exit 0; }
[ "$db_match" = 1 ] || [ "$yes" = 1 ] || refuse "the site's DB_NAME ($cur_db) is not the backup's ($want_db); pass --yes to restore anyway"
[ "$url_match" = 1 ] || [ "$yes" = 1 ] || refuse "the site's siteurl ($cur_url) is not the backup's ($want_url): this looks like another site; pass --yes to restore anyway"

# --- 3. pre-restore copy ---
pre_args=(--label pre-restore)
[ "$has_uploads" = 0 ] || pre_args+=(--uploads)
pre_out=$(bash "$here/wp-backup.sh" "$root" --wrapper "$WP" "${pre_args[@]}") || refuse "the pre-restore copy failed; nothing was touched"
pre=$(tail -n 1 <<< "$pre_out")
echo "wp-restore: pre-restore copy at $pre" >&2

# --- 4. import ---
# Every failure from here on names the pre-restore copy and the exact command to go back.
# printf %q: the wrapper often carries its own quotes (--path='...'), and this is the line a
# user pastes at the worst moment, so it must survive the shell exactly.
back="bash \"\${CLAUDE_PLUGIN_ROOT}/bin/wp-restore.sh\" $(printf '%q' "$root") $(printf '%q' "$pre") --yes --wrapper $(printf '%q' "$WP")"
fail_after() { refuse "$1; the pre-restore copy is at $pre; to go back: $back${old:+ (the previous uploads are at $old)}"; }
old=""
q=$(printf '%q' "$backup/db.sql")
bash -c "$WP db import $q" || fail_after "db import failed"

if [ "$has_uploads" = 1 ]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  stage="$root/wp-content/.uploads-restore-$ts"
  # The site's files, not the backup's: extract with the archive's own modes (-p) under a
  # normal umask, or the umask 077 above would leave uploads 700/600 and unreadable to the
  # web server user.
  ( umask 022; mkdir -p -- "$stage" ) || fail_after "cannot create $stage; the database was imported"
  ( umask 022; tar -xzpf "$backup/uploads.tar.gz" -C "$stage" ) || { rm -rf -- "$stage"; fail_after "uploads.tar.gz did not extract; the database was imported"; }
  [ -d "$stage/uploads" ] || { rm -rf -- "$stage"; fail_after "uploads.tar.gz has no uploads/ directory; the database was imported"; }
  # transfer-verified: the extracted files are counted against backup.json before they replace
  # anything (a backup older than the count has none, and is trusted on its sha256 alone).
  if [ -n "$want_files" ]; then
    got_files=$(find "$stage/uploads" -type f | wc -l)
    [ "$got_files" = "$want_files" ] || { rm -rf -- "$stage"; fail_after "uploads.tar.gz extracted $got_files files, backup.json says $want_files; the current uploads were not touched, the database was imported"; }
  fi
  if [ -d "$root/wp-content/uploads" ]; then
    old="$root/wp-content/uploads.pre-restore-$ts"
    mv -- "$root/wp-content/uploads" "$old" || { old=""; rm -rf -- "$stage"; fail_after "could not move the current uploads aside; the database was imported"; }
  fi
  if ! mv -- "$stage/uploads" "$root/wp-content/uploads"; then
    rm -rf -- "$stage"
    if [ -z "$old" ]; then
      fail_after "could not move the restored uploads into place; the database was imported"
    elif mv -- "$old" "$root/wp-content/uploads"; then
      old=""
      fail_after "could not move the restored uploads into place (the previous uploads were put back); the database was imported"
    else
      # old stays set: fail_after must say where the previous uploads are, not claim they are back.
      fail_after "could not move the restored uploads into place and could not put the previous uploads back: the previous uploads are at $old; the database was imported"
    fi
  fi
  rmdir -- "$stage" || true
fi

# --- 5. verify: identity and content ---
now_url=$(bash -c "$WP option get siteurl" 2>/dev/null) || now_url=""
[ "$now_url" = "$want_url" ] || fail_after "after the import siteurl is '$now_url', the backup says '$want_url'"
verified="siteurl $now_url"
if [ -n "$want_tables" ]; then
  now_tables=$(bash -c "$WP db tables --all-tables-with-prefix" 2>/dev/null | wc -l) || now_tables=""
  # At least, not equal: the dump only drops and recreates its own tables, so a table the site
  # gained since the backup (a plugin installed later) survives the import. Fewer tables than
  # the backup means the import did not complete. Posts are exact: wp_posts is replaced whole.
  [ "${now_tables:-0}" -ge "$want_tables" ] || fail_after "after the import there are $now_tables tables, the backup has $want_tables"
  verified="$verified, $now_tables tables"
fi
if [ -n "$want_posts" ]; then
  now_posts=$(bash -c "$WP post list --post_type=any --post_status=any --format=count" 2>/dev/null) || now_posts=""
  [ "$now_posts" = "$want_posts" ] || fail_after "after the import there are '$now_posts' posts, the backup has $want_posts"
  verified="$verified, $now_posts posts"
fi
[ -z "$old" ] || rm -rf -- "$old"
echo "wp-restore: restored and verified ($verified); pre-restore copy kept at $pre" >&2
printf '%s\n' "$pre"
