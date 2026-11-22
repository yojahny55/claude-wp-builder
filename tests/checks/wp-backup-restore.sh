#!/usr/bin/env bash
# bin/wp-backup.sh and bin/wp-restore.sh against a FAKE `wp` on PATH, so no WordPress is
# needed. The fake simulates `db export -`, `db import`, `option get siteurl` and
# `config get DB_NAME`, and logs every call so the check can prove an import did NOT happen.
#
# What it pins: permissions, sha256 sums in backup.json, a backup outside the project root,
# a truncated dump leaving no folder, a damaged backup refused before any import, a foreign
# DB_NAME refused, --dry-run importing nothing, a pre-restore copy before every import, and a
# wrong siteurl after the import failing the restore.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node sha256sum tar gzip

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
SITE="$T/site"; mkdir -p "$SITE/wp-content/uploads/2026"
echo "img" > "$SITE/wp-content/uploads/2026/a.txt"
chmod 755 "$SITE/wp-content/uploads" "$SITE/wp-content/uploads/2026"; chmod 644 "$SITE/wp-content/uploads/2026/a.txt"
cat > "$SITE/.wp-create.json" <<'JSON'
{"manifest_version":3,"project":{"source":"blank","name":"x","slug":"demo-site"},"theme":{"slug":"ghost","initialized":false},"plugins":{"installed":[]},"wp_cli":{"wrapper":"wp"}}
JSON

mkdir -p "$T/bin"
cat > "$T/bin/wp" <<'FAKE'
#!/usr/bin/env bash
echo "wp $*" >> "$FAKE_LOG"
case "$1 $2" in
  "db export")
    [ "${FAKE_NOTICE:-0}" != 1 ] || echo "Notice: Undefined index in /x/plugin.php on line 3"
    echo "-- MariaDB dump"; echo "CREATE TABLE t (a int);"
    [ "${FAKE_TRUNCATE:-0}" = 1 ] || echo "-- Dump completed on 2026-01-01  0:00:00" ;;
  "db import") [ "${FAKE_IMPORT_FAIL:-0}" != 1 ] || { echo "ERROR 1064" >&2; exit 1; }
    echo "import $3" >> "$FAKE_LOG.import" ;;
  "db tables") n=${FAKE_TABLES:-3}; [ ! -f "$FAKE_LOG.import" ] || n=${FAKE_TABLES_AFTER:-$n}; seq 1 "$n" | sed 's/^/wp_t/' ;;
  "post list") n=${FAKE_POSTS:-7}; [ ! -f "$FAKE_LOG.import" ] || n=${FAKE_POSTS_AFTER:-$n}; echo "$n" ;;
  "option get") if [ -f "$FAKE_LOG.import" ]; then echo "${FAKE_URL_AFTER:-https://site.test}"; else echo "${FAKE_URL_BEFORE:-https://site.test}"; fi ;;
  "config get") echo "${FAKE_DB:-wpdb}" ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$T/bin/wp"
export PATH="$T/bin:$PATH" FAKE_LOG="$T/calls.log"
: > "$FAKE_LOG"
reset_imports() { rm -f "$FAKE_LOG.import"; }
imports() { if [ -f "$FAKE_LOG.import" ]; then wc -l < "$FAKE_LOG.import"; else echo 0; fi; }
code() { local rc=0; "$@" >"$T/out" 2>"$T/err" || rc=$?; echo "$rc"; }

# --- backup ok ---
rc=$(code bash bin/wp-backup.sh "$SITE" --uploads --label t1)
[ "$rc" = 0 ] || fail "backup exited $rc: $(cat "$T/err")"
B=$(tail -n 1 "$T/out")
case "$B" in "$SITE"/*) fail "backup landed inside the project root: $B" ;; esac
case "$B" in "$HOME/.wp-backups/demo-site-"*-t1) ;; *) fail "unexpected default destination: $B" ;; esac
[ "$(stat -c %a "$B")" = 700 ] || fail "backup dir is not 700"
for f in db.sql uploads.tar.gz backup.json; do
  [ "$(stat -c %a "$B/$f")" = 600 ] || fail "$f is not 600"
done
[ ! -e "$B/wp-config.php" ] || fail "wp-config.php was copied"
want=$(sha256sum "$B/db.sql"); want=${want%% *}
node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1]));const f=m.files.find(x=>x.name==="db.sql");if(f.sha256!==process.argv[2]||m.siteurl!=="https://site.test"||m.db_name!=="wpdb"||m.slug!=="demo-site"||m.tables!==3||m.posts!==7)process.exit(1)' "$B/backup.json" "$want" || fail "backup.json does not carry sha256/siteurl/db_name/slug/tables/posts"
tar -tzf "$B/uploads.tar.gz" | grep >/dev/null -c 'uploads/2026/a.txt' || fail "uploads archive lacks the file"

# --- no --uploads: said so ---
rc=$(code bash bin/wp-backup.sh "$SITE" --label t2)
[ "$rc" = 0 ] && [ ! -e "$(tail -n 1 "$T/out")/uploads.tar.gz" ] || fail "backup without --uploads should have no archive"
grep >/dev/null -c 'not in this copy' "$(tail -n 1 "$T/out")/backup.json" || fail "backup.json does not say uploads are absent"

# --- truncated dump: exit 1 and no folder ---
before=$(find "$HOME/.wp-backups" -mindepth 1 -maxdepth 1 | wc -l)
rc=$(FAKE_TRUNCATE=1 code bash bin/wp-backup.sh "$SITE" --label trunc)
[ "$rc" = 1 ] || fail "truncated dump exited $rc, expected 1"
[ "$(find "$HOME/.wp-backups" -mindepth 1 -maxdepth 1 | wc -l)" = "$before" ] || fail "a failed backup left a folder behind"

# --- a PHP notice printed before the SQL: exit 1 and no folder ---
rc=$(FAKE_NOTICE=1 code bash bin/wp-backup.sh "$SITE" --label notice)
[ "$rc" = 1 ] || fail "dump preceded by a notice exited $rc, expected 1"
grep >/dev/null -c 'SQL header' "$T/err" || fail "the notice failure does not say the dump lacks a SQL header"
[ "$(find "$HOME/.wp-backups" -mindepth 1 -maxdepth 1 | wc -l)" = "$before" ] || fail "a notice-polluted dump left a folder behind"

# --- a malicious project.slug cannot steer the folder out of --out ---
EVIL="$T/evil"; mkdir -p "$EVIL"
sed 's|"slug":"demo-site"|"slug":"../../x"|' "$SITE/.wp-create.json" > "$EVIL/.wp-create.json"
rc=$(code bash bin/wp-backup.sh "$EVIL" --out "$T/evil-out" --label e)
[ "$rc" = 0 ] || fail "evil-slug backup exited $rc: $(cat "$T/err")"
case "$(tail -n 1 "$T/out")" in "$T/evil-out/"*) ;; *) fail "a slug of ../../x escaped --out: $(tail -n 1 "$T/out")" ;; esac
[ -z "$(find "$T" -maxdepth 1 -name 'x-*')" ] || fail "a slug of ../../x wrote next to the test root"

# --- --out inside the root: 64 ---
rc=$(code bash bin/wp-backup.sh "$SITE" --out "$SITE/wp-content/bk")
[ "$rc" = 64 ] || fail "--out inside the root exited $rc, expected 64"
# --- no manifest: 2 ---
mkdir "$T/bare"; rc=$(code bash bin/wp-backup.sh "$T/bare")
[ "$rc" = 2 ] || fail "no manifest exited $rc, expected 2"
# --- no manifest but --wrapper (the bare-wp fallback of /wp-update): works, slug from the directory ---
rc=$(code bash bin/wp-backup.sh "$T/bare" --wrapper wp --out "$T/bare-out")
[ "$rc" = 0 ] || fail "--wrapper without a manifest exited $rc: $(cat "$T/err")"
case "$(tail -n 1 "$T/out")" in "$T/bare-out/bare-"*) ;; *) fail "no-manifest backup is not named after the directory: $(tail -n 1 "$T/out")" ;; esac

# --- restore: altered file refused before any import ---
\cp -rf "$B" "$T/damaged"; echo "tamper" >> "$T/damaged/db.sql"
rc=$(code bash bin/wp-restore.sh "$SITE" "$T/damaged" --yes)
[ "$rc" = 1 ] && [ "$(imports)" = 0 ] || fail "damaged backup: exit $rc, imports $(imports)"

# --- restore: foreign DB_NAME refused ---
rc=$(FAKE_DB=other code bash bin/wp-restore.sh "$SITE" "$B")
[ "$rc" = 1 ] && [ "$(imports)" = 0 ] || fail "DB_NAME mismatch: exit $rc, imports $(imports)"

# --- restore: same DB_NAME but another siteurl refused ---
rc=$(FAKE_URL_BEFORE=https://other.test code bash bin/wp-restore.sh "$SITE" "$B")
[ "$rc" = 1 ] && [ "$(imports)" = 0 ] || fail "siteurl mismatch before the import: exit $rc, imports $(imports)"

# --- restore: dry-run imports nothing ---
rc=$(code bash bin/wp-restore.sh "$SITE" "$B" --dry-run)
[ "$rc" = 0 ] && [ "$(imports)" = 0 ] || fail "--dry-run: exit $rc, imports $(imports)"

# --- restore: db import fails -> 1, names the pre-restore copy and the way back ---
rc=$(FAKE_IMPORT_FAIL=1 code bash bin/wp-restore.sh "$SITE" "$B" --yes)
[ "$rc" = 1 ] || fail "failed import exited $rc, expected 1"
grep >/dev/null -c 'pre-restore' "$T/err" || fail "a failed import does not name the pre-restore copy"
grep >/dev/null -c 'wp-restore.sh' "$T/err" || fail "a failed import does not give the command to go back"

# --- restore: corrupt uploads archive with a matching sha -> 1, database already imported ---
\cp -rf "$B" "$T/badtar"; echo "not a tar" > "$T/badtar/uploads.tar.gz"
node -e 'const fs=require("fs"),c=require("crypto"),f=process.argv[1]+"/backup.json",m=JSON.parse(fs.readFileSync(f));const u=m.files.find(x=>x.name==="uploads.tar.gz");u.sha256=c.createHash("sha256").update(fs.readFileSync(process.argv[1]+"/uploads.tar.gz")).digest("hex");fs.writeFileSync(f,JSON.stringify(m))' "$T/badtar"
reset_imports; echo "keep" > "$SITE/wp-content/uploads/2026/a.txt"
rc=$(code bash bin/wp-restore.sh "$SITE" "$T/badtar" --yes)
[ "$rc" = 1 ] && [ "$(imports)" = 1 ] || fail "corrupt uploads: exit $rc, imports $(imports)"
grep >/dev/null -c 'to go back' "$T/err" || fail "corrupt uploads: no way back in the message"
[ "$(cat "$SITE/wp-content/uploads/2026/a.txt")" = keep ] || fail "corrupt uploads archive disturbed the current uploads"

# --- restore: table or post counts differ after the import -> 1 ---
reset_imports
rc=$(FAKE_TABLES_AFTER=2 code bash bin/wp-restore.sh "$SITE" "$B" --yes)
[ "$rc" = 1 ] || fail "table count mismatch exited $rc, expected 1"
grep >/dev/null -c 'tables' "$T/err" || fail "table count failure not reported"
reset_imports
rc=$(FAKE_POSTS_AFTER=0 code bash bin/wp-restore.sh "$SITE" "$B" --yes)
[ "$rc" = 1 ] || fail "post count mismatch exited $rc, expected 1"
grep >/dev/null -c 'posts' "$T/err" || fail "post count failure not reported"

# --- restore ok: pre-restore copy, import, uploads swapped ---
reset_imports
# earlier failed restores keep their old uploads on purpose; only this run must clean up
\rm -rf "$SITE"/wp-content/uploads.pre-restore-*
echo "changed" > "$SITE/wp-content/uploads/2026/a.txt"
n_before=$(find "$HOME/.wp-backups" -maxdepth 1 -name '*-pre-restore*' | wc -l)
rc=$(code bash bin/wp-restore.sh "$SITE" "$B" --yes)
[ "$rc" = 0 ] || fail "restore exited $rc: $(cat "$T/err")"
[ "$(imports)" = 1 ] || fail "restore did not import exactly once"
[ "$(find "$HOME/.wp-backups" -maxdepth 1 -name '*-pre-restore*' | wc -l)" -gt "$n_before" ] || fail "no pre-restore copy"
[ "$(cat "$SITE/wp-content/uploads/2026/a.txt")" = img ] || fail "uploads were not restored"
# Restored uploads keep the site's modes, not the backup's private 700/600: the web server
# user has to read them.
[ "$(stat -c %a "$SITE/wp-content/uploads/2026/a.txt")" = 644 ] || fail "restored upload is $(stat -c %a "$SITE/wp-content/uploads/2026/a.txt"), not 644"
[ "$(stat -c %a "$SITE/wp-content/uploads")" = 755 ] || fail "restored uploads dir is $(stat -c %a "$SITE/wp-content/uploads"), not 755"
[ -z "$(find "$SITE/wp-content" -maxdepth 1 -name 'uploads.pre-restore-*')" ] || fail "old uploads not cleaned after verification"

# --- restore: wrong siteurl after import fails ---
reset_imports
rc=$(FAKE_URL_AFTER=https://elsewhere.test code bash bin/wp-restore.sh "$SITE" "$B" --yes)
[ "$rc" = 1 ] || fail "siteurl mismatch exited $rc, expected 1"
grep >/dev/null -c 'pre-restore copy' "$T/err" || fail "the failure does not name the pre-restore copy"

# --- the commands that export must call the shared script, never db export themselves ---
for c in wp-update wp-clone wp-anonymize wp-backup; do
  need_token "commands/$c.md" 'bin/wp-backup.sh' "commands/$c.md no longer takes its backup through bin/wp-backup.sh"
done
for c in wp-update wp-clone wp-anonymize; do
  need_token "commands/$c.md" '|| exit 1' "commands/$c.md does not stop when the backup command fails"
  need_token "commands/$c.md" '[ -d "$B" ]' "commands/$c.md does not check that the backup folder exists"
  need_token "commands/$c.md" 'If the backup fails, stop' "commands/$c.md lost the stop-on-failed-backup sentence"
  [ "$(grep -c '\$WP db export' "commands/$c.md" || true)" = 0 ] || fail "commands/$c.md exports the database itself again"
done
need_token commands/wp-update.md '--wrapper "$WP"' "/wp-update does not pass its resolved wrapper to the backup"
need_token commands/wp-restore.md 'AskUserQuestion' "/wp-restore no longer asks before importing"
need_token commands/wp-restore.md '--dry-run' "/wp-restore no longer shows the plan first"

echo PASS
