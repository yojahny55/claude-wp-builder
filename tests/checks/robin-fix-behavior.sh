#!/usr/bin/env bash
# robin-fix.sh run against a fake WordPress root, a fake database client and a fake network,
# because each defect below read as success or ended the run in silence, and the greps in
# robin-queue-query.sh and robin-webp-gaps.sh read the script's text and could see none of it:
#
#   1. No WordPress root, or a wp-config.php the grep could not parse, ended the run with
#      exit 1 and no message: a failing command substitution under `set -e` exits on the line
#      that was meant to test its result and print the error.
#   2. `$table_prefix` was read with an unescaped `$`, a PCRE end-of-line anchor, so the
#      prefix was always `wp_` and a site with any other prefix had every query aimed at
#      tables that do not exist. Double-quoted defines and a DB_HOST carrying a port were
#      not read either.
#   3. Every query called `mariadb`, while the skill and /wp-robin's pre-check accept a host
#      with only `mysql`.
#   4. The download fallback saved a 404 page as the plugin zip (curl without -f) and set
#      PLUGIN_INSTALLED whether or not anything was installed.
#   5. Every settings write ended in `|| true`, and the report counted keys, not writes, so a
#      refused write read as applied.
#   6. The GD converter was inline PHP using `match`, a parse error before PHP 8.0, and had no
#      GIF branch although GIF is an allowed format.
#   7. Reading double-quoted defines stopped every value at either quote, so a single-quoted
#      password holding `"` (or a double-quoted user holding `'`) reached the client cut short.
#   8. With cwebp chosen, every GIF went to gif2webp whether or not it was installed, and
#      each one failed as a bare "conversion failed".
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

script=$PWD/skills/wp-robin/scripts/robin-fix.sh
gd=$PWD/skills/wp-robin/scripts/webp-gd.php
skill=skills/wp-robin/SKILL.md
for f in "$script" "$gd" "$skill"; do [ -f "$f" ] || fail "$f is missing"; done

# 6, statically: the PHP 7.4 floor holds for the converter wherever it lives.
! grep -nE '(^|[^_a-z])match[[:space:]]*\(' "$script" "$gd" \
  || fail "robin's GD converter uses match(), a parse error on PHP 7.4"
grep -Fq 'imagecreatefromgif' "$gd" || fail "$gd cannot read a GIF, which allowed_formats queues"
grep -Fq 'webp-gd.php' "$script" || fail "$script no longer converts through webp-gd.php"

# The skill must describe the script that exists.
! grep -Fq 'falls back to downloading the plugin zip from WordPress.org' "$skill" \
  || fail "$skill still says the zip is downloaded when wp-cli is absent; it is only the fallback for a failed wp plugin install"
! grep -Fq 'discovers the site URL and uploads directory' "$skill" \
  || fail "$skill still says the uploads directory is discovered; it is fixed at <root>/wp-content/uploads"
grep -Fq '<root>/wp-content/uploads' "$skill" || fail "$skill does not say where uploads are read from"
for bin in '`mariadb` or `mysql` client' '`php` CLI' '`curl`, `unzip`' 'gif2webp' 'imagewebp()'; do
  grep -Fq -- "$bin" "$skill" || fail "$skill does not list $bin under Requirements"
done
grep -Fq '## Exit codes' "$skill" || fail "$skill does not state the script's exit codes"

command -v php >/dev/null 2>&1 || { echo "SKIP: php not found -- the static half passed, the script was not run"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A PATH holding only what the script needs, and no `mariadb`: the queries must reach the
# fake `mysql`, which logs them with the password it was handed, refuses every settings
# write and reports no queue table. With ROBIN_QUEUE=1 the table exists, and ROBIN_GAP and
# ROBIN_META answer step 5 with one attachment (#7) that has no webp row.
mkdir -p "$tmp/bin" "$tmp/t"
for t in bash env grep sed awk sort tr wc head dirname basename mktemp rm date stat sha256sum id cat php; do
  p=$(command -v "$t") && ln -s "$p" "$tmp/bin/$t"
done
cat > "$tmp/bin/mysql" <<'SH'
#!/usr/bin/env bash
printf '%s pwd=%s\n' "$*" "${MYSQL_PWD-}" >> "$ROBIN_LOG"
case "$*" in
  *"INSERT INTO "*options*) exit 1 ;;
  *information_schema*) echo "${ROBIN_QUEUE:-0}" ;;
  *"w.item_type = 'webp'"*) [ -z "${ROBIN_GAP:-}" ] || printf '7\t%s\t0\n' "$ROBIN_GAP" ;;
  *"meta_key='_wp_attachment_metadata' LIMIT 1"*) printf '%s\n' "${ROBIN_META:-}" ;;
esac
exit 0
SH
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/wp"
# A 404: the page is written when -f is absent, which is what curl does. -f counts as a
# short option or inside a cluster of them (-fsSL), never inside a long one (--form).
cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
out=""; f=0
while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift ;; --fail|-f*|-[!-]*f*) f=1 ;; esac; shift; done
[ "$f" = 1 ] && { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
echo "404 Not Found" > "$out"
SH
printf '#!/usr/bin/env bash\necho "not a zipfile" >&2\nexit 9\n' > "$tmp/bin/unzip"
chmod +x "$tmp/bin/mysql" "$tmp/bin/wp" "$tmp/bin/curl" "$tmp/bin/unzip"

run() {  # dir, then env assignments; prints output, returns the exit code
  local dir=$1; shift
  (cd "$dir" && env -i PATH="$tmp/bin" HOME="$tmp" TMPDIR="$tmp/t" ROBIN_LOG="$tmp/log" "$@" bash "$script" 2>&1)
}

# 1. No root.
mkdir -p "$tmp/nowhere"
out=$(run "$tmp/nowhere"); rc=$?
[ "$rc" -eq 1 ] && grep -q 'Could not find WordPress root' <<<"$out" \
  || fail "with no WordPress root the script exits $rc without saying why: $out"

# A root whose wp-config.php uses double quotes, a non-default prefix and a port, and whose
# user and password each hold the quote the other style opens with.
wp="$tmp/site"
mkdir -p "$wp/wp-content/plugins" "$wp/wp-content/uploads"
cat > "$wp/wp-config.php" <<'PHP'
<?php
define( "DB_NAME", "dqdb" );
define( "DB_USER", "dq'user" );
define( 'DB_PASSWORD', 'p"w' );
define( "DB_HOST", "127.0.0.1:3307" );
$table_prefix = "abc_";
PHP

# 4. wp plugin install fails, and the download is a 404.
out=$(run "$tmp" WP_ROOT="$wp"); rc=$?
[ "$rc" -eq 1 ] && grep -q 'could not be downloaded' <<<"$out" \
  || fail "a failed install and a 404 download did not stop the run with a reason (exit $rc): $out"
[ ! -e "$wp/wp-content/plugins/robin-image-optimizer" ] || fail "a 404 page was unpacked as the plugin"
[ -z "$(ls -A "$tmp/t")" ] || fail "the download left its temporary file behind"

# 2, 3, 5. Plugin present: settings writes are refused, then the queue table is missing.
mkdir -p "$wp/wp-content/plugins/robin-image-optimizer"
touch "$wp/wp-content/plugins/robin-image-optimizer/robin-image-optimizer.php"
: > "$tmp/log"
out=$(run "$tmp" WP_ROOT="$wp"); rc=$?
[ "$rc" -eq 1 ] || fail "a missing queue table did not stop the run (exit $rc): $out"
grep -q 'settings were NOT written' <<<"$out" || fail "refused settings writes were not reported: $out"
! grep -q 'Settings applied' <<<"$out" || fail "refused settings writes were reported as applied"
grep -q 'abc_rio_process_queue does not exist' <<<"$out" || fail "the table prefix was not read from wp-config.php: $out"
[ -s "$tmp/log" ] || fail "no query reached the mysql client when mariadb is absent"
grep -q 'abc_options' "$tmp/log" || fail "settings were written to a table without the site's prefix"
grep -q -- '-h 127.0.0.1 --port=3307 dqdb' "$tmp/log" || fail "DB_HOST's port or the double-quoted DB_NAME did not reach the client: $(head -1 "$tmp/log")"
grep -qF -- "-u dq'user -h" "$tmp/log" || fail "the double-quoted DB_USER holding a ' did not reach the client whole"
grep -q 'pwd=p"w$' "$tmp/log" || fail "the single-quoted DB_PASSWORD holding a \" did not reach the client whole"

# 6. The GD converter on all three formats, where this PHP can test it.
if php -r 'exit(function_exists("imagewebp") && function_exists("imagegif") ? 0 : 1);'; then
  php -r '$i = imagecreatetruecolor(8, 8); imagepng($i, $argv[1] . "/a.png"); imagejpeg($i, $argv[1] . "/a.jpg"); imagegif($i, $argv[1] . "/a.gif");' "$tmp"
  for ext in png jpg gif; do
    php "$gd" "$tmp/a.$ext" "$tmp/a.$ext.webp" 82 || fail "$gd could not convert a .$ext"
    [ "$(head -c 4 "$tmp/a.$ext.webp")" = RIFF ] || fail "$gd wrote something that is not a WebP for a .$ext"
  done
  echo "not an image" > "$tmp/bad.png"
  ! php "$gd" "$tmp/bad.png" "$tmp/bad.webp" 82 || fail "$gd reported success on a file that is not an image"
else
  echo "note: this PHP has no GD WebP support; the converter itself was not run"
fi

# 8. cwebp without gif2webp, and a queue with one GIF attachment missing its webp. The fake
# cwebp fails on everything, as the real one does on a GIF.
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/cwebp"
chmod +x "$tmp/bin/cwebp"
mkdir -p "$wp/wp-content/uploads/2026/10"
gif="$wp/wp-content/uploads/2026/10/a.gif"
php -r '$i = imagecreatetruecolor(8, 8); imagegif($i, $argv[1]);' "$gif" 2>/dev/null || printf 'GIF89a' > "$gif"
meta=$(php -r 'echo serialize(array("file" => "2026/10/a.gif"));')
gap=$(php -r 'echo base64_encode($argv[1]);' "$meta")
out=$(run "$tmp" WP_ROOT="$wp" ROBIN_QUEUE=1 ROBIN_META="$meta" ROBIN_GAP="$gap"); rc=$?
grep -q 'WebP converter: cwebp' <<<"$out" || fail "the fake cwebp was not chosen, so the GIF path was not exercised: $out"
if php -r 'exit(function_exists("imagewebp") ? 0 : 1);'; then
  [ "$rc" -eq 0 ] || fail "the GIF sync run exited $rc: $out"
  grep -q 'GIF converter: gd' <<<"$out" || fail "cwebp without gif2webp did not hand GIFs to GD: $out"
  [ "$(head -c 4 "$gif.webp" 2>/dev/null)" = RIFF ] || fail "the GIF got no .webp from GD when gif2webp is absent: $out"
  grep -q '#7: 1 webp entries synced' <<<"$out" || fail "the converted GIF was not synced: $out"
else
  grep -q 'GIF attachments will get no .webp file' <<<"$out" \
    || fail "cwebp without gif2webp or GD did not say that GIFs get no .webp: $out"
fi

echo PASS
