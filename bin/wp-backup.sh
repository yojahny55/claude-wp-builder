#!/usr/bin/env bash
# wp-backup.sh <project-path> [--out <dir>] [--label <word>] [--uploads] [--json] [--wrapper "<cmd>"]
#
# One verified backup of a WordPress site, shared by /wp-backup, /wp-update, /wp-clone and
# /wp-anonymize so the export is not re-implemented (and re-weakened) in each of them.
#
#   <out>/<slug>-<UTC %Y%m%dT%H%M%SZ>[-<label>]/
#     db.sql          wp db export, written to a temp name and renamed only once it is complete
#     uploads.tar.gz  wp-content/uploads, only with --uploads (gzip -t verified)
#     backup.json     created, slug, siteurl, db_name, table and post counts, sha256 + size of every file
#
# wp-config.php is NOT copied: it holds credentials, and a backup is the file people forget
# to protect. Restoring the database does not need it.
#
# --out is the PARENT of the dated folder (default ~/.wp-backups) and must lie outside
# the WordPress root: a backup under the site shares the fate of what it protects. Directories
# are 700 and files 600 (umask 077). Without --uploads the report says uploads are not in the copy.
#
# --wrapper "<cmd>" supplies the WP-CLI wrapper and skips reading it from the manifest (a command
# whose manifest policy is a bare-wp fallback has already resolved it). The slug still comes from
# the manifest when there is one, else from the directory name; either way it is reduced to
# [A-Za-z0-9._-] so it cannot steer the folder out of --out.
#
# stdout: the folder path on the last line (a caller captures it). --json also prints backup.json.
# Exit: 0 verified copy; 1 copy made but it does not verify (the folder is deleted);
#       2 could not measure (no manifest, WP-CLI wrapper does not answer); 64 usage.
set -euo pipefail
umask 077

here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: wp-backup.sh <project-path> [--out <dir>] [--label <word>] [--uploads] [--json] [--wrapper \"<cmd>\"]" >&2; exit 64; }

[ $# -ge 1 ] || usage
project=$1; shift
out="" label="" uploads=0 json=0 wrapper=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || usage; out=$2; shift 2 ;;
    --label) [ $# -ge 2 ] || usage; label=$2; shift 2 ;;
    --uploads) uploads=1; shift ;;
    --json) json=1; shift ;;
    --wrapper) [ $# -ge 2 ] || usage; wrapper=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$label" in *[!A-Za-z0-9._-]*) echo "wp-backup: --label takes letters, digits, '.', '_' and '-' only" >&2; exit 64 ;; esac
[ -d "$project" ] || { echo "wp-backup: $project is not a directory" >&2; exit 64; }
root=$(cd "$project" && pwd -P)

if [ -z "$wrapper" ]; then
  wrapper=$(node "$here/wp-config.mjs" get "$root" wp_cli.wrapper 2>/dev/null) || {
    echo "wp-backup: cannot read wp_cli.wrapper from $root/.wp-create.json (pass --wrapper)" >&2; exit 2; }
fi
slug=$(node "$here/wp-config.mjs" get "$root" project.slug 2>/dev/null) || slug=""
case "$slug" in ''|.*|*[!A-Za-z0-9._-]*)
  slug=$(basename "$root" | tr -c 'A-Za-z0-9._\n-' '-')
  case "$slug" in ''|.*) slug="site$slug" ;; esac ;;
esac
WP=$wrapper
cd "$root"

siteurl=$(bash -c "$WP option get siteurl" 2>/dev/null) || siteurl=""
[ -n "$siteurl" ] || { echo "wp-backup: the WP-CLI wrapper ($WP) did not answer 'option get siteurl'" >&2; exit 2; }
db_name=$(bash -c "$WP config get DB_NAME" 2>/dev/null) || db_name=""
[ -n "$db_name" ] || { echo "wp-backup: could not read DB_NAME through the wrapper" >&2; exit 2; }

[ -n "$out" ] || out="$HOME/.wp-backups"
out=$(realpath -m -- "$out")
case "$out/" in
  "$root"/*) echo "wp-backup: --out ($out) is inside the WordPress root ($root); a backup there shares the fate of the site" >&2; exit 64 ;;
esac

stamp=$(date -u +%Y%m%dT%H%M%SZ)
dir="$out/$slug-$stamp${label:+-$label}"
[ ! -e "$dir" ] || dir="$dir-$$"
mkdir -p -- "$out"
mkdir -- "$dir"
chmod 700 "$dir"

ok=0
cleanup() { [ "$ok" = 1 ] || rm -rf -- "$dir"; }
trap cleanup EXIT
bad() { echo "wp-backup: $*" >&2; exit 1; }

# --- database: a half-written dump never carries the final name ---
tmp="$dir/.db.sql.partial"
bash -c "$WP db export -" > "$tmp" || bad "wp db export failed"
[ -s "$tmp" ] || bad "the database dump is empty"
first=$(grep -v '^[[:space:]]*$' "$tmp" | sed -n 1p || true)
case "$first" in
  --*|"/*"*) ;;
  *) bad "the dump does not start with a SQL header (first line: ${first:0:60}): the wrapper printed something before it" ;;
esac
last=$(grep -v '^[[:space:]]*$' "$tmp" | tail -n 1 || true)
case "$last" in
  *"Dump completed"*) ;;
  *) bad "the database dump has no 'Dump completed' footer: it was cut short" ;;
esac
mv -- "$tmp" "$dir/db.sql"
files=(db.sql)

# --- uploads ---
uploads_state="not in this copy"
if [ "$uploads" = 1 ]; then
  if [ -d "$root/wp-content/uploads" ]; then
    tar -czf "$dir/uploads.tar.gz" -C "$root/wp-content" uploads || bad "tar of wp-content/uploads failed"
    gzip -t "$dir/uploads.tar.gz" || bad "uploads.tar.gz does not read back"
    [ -s "$dir/uploads.tar.gz" ] || bad "uploads.tar.gz is empty"
    files+=(uploads.tar.gz); uploads_state="uploads.tar.gz"
  else
    echo "wp-backup: --uploads given but $root/wp-content/uploads does not exist; nothing to archive" >&2
    uploads_state="no uploads directory on the site"
  fi
fi

# --- content counts, so a restore can prove the content came back ---
tables=$(bash -c "$WP db tables --all-tables-with-prefix" 2>/dev/null | wc -l) || tables=""
[ -n "$tables" ] && [ "$tables" -gt 0 ] || tables=null
posts=$(bash -c "$WP post list --post_type=any --post_status=any --format=count" 2>/dev/null) || posts=""
case "$posts" in ''|*[!0-9]*) posts=null ;; esac
[ "$posts" != null ] && [ "$tables" != null ] || echo "wp-backup: could not count tables/posts through the wrapper; the restore will not verify content counts" >&2

# --- backup.json ---
sums=""
for f in "${files[@]}"; do
  sha=$(sha256sum -- "$dir/$f"); sha=${sha%% *}
  size=$(stat -c %s -- "$dir/$f")
  sums+="$f"$'\t'"$sha"$'\t'"$size"$'\n'
done
SUMS=$sums SLUG=$slug SITEURL=$siteurl DBNAME=$db_name TABLES=$tables POSTS=$posts UPLOADS=$uploads_state CREATED=$stamp \
  node -e '
    const files = process.env.SUMS.trim().split("\n").map((l) => { const [name, sha256, size] = l.split("\t"); return { name, sha256, size: Number(size) }; });
    const e = process.env;
    process.stdout.write(JSON.stringify({ created: e.CREATED, slug: e.SLUG, siteurl: e.SITEURL, db_name: e.DBNAME, tables: e.TABLES === "null" ? null : Number(e.TABLES), posts: e.POSTS === "null" ? null : Number(e.POSTS), uploads: e.UPLOADS, files }, null, 2) + "\n");
  ' > "$dir/backup.json"
chmod 600 "$dir"/*
chmod 700 "$dir"

echo "wp-backup: database dump verified ($db_name); uploads: $uploads_state; wp-config.php is not copied" >&2
ok=1
[ "$json" = 0 ] || cat "$dir/backup.json"
printf '%s\n' "$dir"
