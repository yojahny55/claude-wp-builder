#!/usr/bin/env bash
# robin-fix.sh pasted attachment file names into PHP source (`php -r '... "'$s_path'" ...'`) and
# into SQL (`VALUES (... '${EXTRA_DATA}' ...)`), so an upload named O'Brien.jpg broke the
# step or, through metadata, ran as PHP/SQL; `plan (1).png` from an rsync reached it too.
# It also read DB credentials with `grep | head -1`, which took a commented-out
# `// define('DB_NAME', ...)` as the live value and cut a password holding \' short, and it
# looked for the deprecated ImageMagick `convert` before `magick`.
# Run against a fake WordPress root, a fake mysql that records the SQL it is sent and fake
# converters, so nothing real is touched.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

script=$PWD/skills/wp-robin/scripts/robin-fix.sh
[ -f "$script" ] || fail "$script is missing"

# Static: the interpolation patterns that caused it are gone, and the docs say magick first.
! grep -Fq "\"'\$s_path'\"" "$script" || fail "$script pastes a file path into php -r source again"
! grep -Fq "'\${EXTRA_DATA}'" "$script" || fail "$script pastes extra_data into the INSERT again"
grep -Fq 'command -v magick || command -v convert' commands/wp-robin.md || fail "commands/wp-robin.md Step 2 does not look for magick before convert"
grep -Fq '`magick`, else the older `convert`' skills/wp-robin/SKILL.md || fail "SKILL.md does not say magick is preferred over convert"

command -v php >/dev/null 2>&1 || { echo "SKIP: php not found -- the static half passed, the script was not run"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/t" "$tmp/fake"
for t in bash env grep sed awk sort tr wc head dirname basename mktemp rm date stat sha256sum id cat php; do
  p=$(command -v "$t") && ln -s "$p" "$tmp/bin/$t"
done
# mysql records every call; the step-5 INSERT (recognised by UNHEX) goes to its own file.
cat > "$tmp/bin/mysql" <<'SH'
#!/usr/bin/env bash
printf '%s pwd=%s\n' "$*" "${MYSQL_PWD-}" >> "$ROBIN_LOG"
case "$*" in
  *"INSERT INTO "*options*) exit 1 ;;
  *"INSERT INTO "*UNHEX*) printf '%s\n' "$*" >> "$ROBIN_INSERT" ;;
  *information_schema*) echo "${ROBIN_QUEUE:-0}" ;;
  *"w.item_type = 'webp'"*) [ -z "${ROBIN_GAP:-}" ] || printf '7\t%s\t0\n' "$ROBIN_GAP" ;;
  *"meta_key='_wp_attachment_metadata' LIMIT 1"*) printf '%s\n' "${ROBIN_META:-}" ;;
esac
exit 0
SH
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/wp"
# Fake converters: log the call, write a small file where the output goes.
for c in magick convert; do
  cat > "$tmp/fake/$c" <<SH
#!/usr/bin/env bash
echo "$c \$*" >> "\$ROBIN_CONV_LOG"
for last; do :; done
printf RIFFxxxx > "\$last"
SH
done
chmod +x "$tmp/bin/mysql" "$tmp/bin/wp" "$tmp/fake/"*

run() {  # dir, then env assignments; prints output, returns the exit code
  local dir=$1; shift
  (cd "$dir" && env -i PATH="$tmp/bin" HOME="$tmp" TMPDIR="$tmp/t" ROBIN_LOG="$tmp/log" \
    ROBIN_INSERT="$tmp/insert" ROBIN_CONV_LOG="$tmp/conv" "$@" bash "$script" 2>&1)
}

wp="$tmp/site"
mkdir -p "$wp/wp-content/plugins/robin-image-optimizer" "$wp/wp-content/uploads/2026/10"
touch "$wp/wp-content/plugins/robin-image-optimizer/robin-image-optimizer.php"

# ---- wp-config.php parsing --------------------------------------------------
cat > "$wp/wp-config.php" <<'PHP'
<?php
// define('DB_NAME', 'commented_db');
# define('DB_USER', 'commented_user');
/*
 * define('DB_PASSWORD', 'commented_pw');
 */
/* define('DB_HOST', 'commented_host'); */
define('DB_NAME', 'livedb');
define("DB_USER", "us\"er");
define('DB_PASSWORD', 'a\'b\\c"d$e');
define('DB_HOST', 'localhost'); // define('DB_HOST', 'trailing_comment_host');
// $table_prefix = 'bad_';
$table_prefix = 'pfx_';
PHP
: > "$tmp/log"
out=$(run "$tmp" WP_ROOT="$wp"); rc=$?
[ -s "$tmp/log" ] || fail "no query reached the client: $out"
first=$(head -1 "$tmp/log")
grep -Fq -- 'livedb' <<<"$first" || fail "a commented-out DB_NAME won over the live define: $first"
! grep -Eq 'commented_|trailing_comment' "$tmp/log" || fail "a commented define reached the client: $first"
grep -Fq -- '-u us"er -h localhost livedb' <<<"$first" || fail "the double-quoted DB_USER with an escaped quote was not read whole: $first"
grep -Fq -- "pwd=a'b\\c\"d\$e" "$tmp/log" || fail "the password with \\' and \\\\ was cut short or left escaped: $first"
grep -Fq 'pfx_options' "$tmp/log" || fail "a commented \$table_prefix won over the live one"

# ---- file names with quotes, backslashes and $ ------------------------------
name="O'Brien \"q\" \$HOME \`id\` plan (1).png"
rel="2026/10/$name"
printf 'PNGDATA' > "$wp/wp-content/uploads/$rel"
cat > "$wp/wp-config.php" <<'PHP'
<?php
define('DB_NAME', 'db'); define('DB_USER', 'u'); define('DB_PASSWORD', 'p'); define('DB_HOST', 'localhost');
$table_prefix = 'wp_';
PHP
meta=$(php -r 'echo serialize(array("file" => $argv[1], "sizes" => array("thumb" => array("file" => "t.png"))));' "$rel")
gap=$(php -r 'echo base64_encode($argv[1]);' "$meta")

sync() {  # extra PATH dirs as args; leaves the INSERT in $tmp/insert
  rm -f "$wp/wp-content/uploads/$rel.webp" "$tmp/insert" "$tmp/conv"
  rm -rf "$tmp/cbin"; mkdir "$tmp/cbin"
  for c in "$@"; do ln -s "$tmp/fake/$c" "$tmp/cbin/$c"; done
  out=$(env -i PATH="$tmp/cbin:$tmp/bin" HOME="$tmp" TMPDIR="$tmp/t" ROBIN_LOG="$tmp/log" ROBIN_INSERT="$tmp/insert" \
    ROBIN_CONV_LOG="$tmp/conv" ROBIN_QUEUE=1 ROBIN_META="$meta" ROBIN_GAP="$gap" WP_ROOT="$wp" bash "$script" 2>&1); rc=$?
}

sync magick convert
[ "$rc" -eq 0 ] || fail "the sync run exited $rc: $out"
grep -Fq 'WebP converter: imagemagick' <<<"$out" || fail "ImageMagick was not chosen: $out"
[ -s "$tmp/conv" ] && grep -q '^magick ' "$tmp/conv" || fail "magick was not preferred over convert: $(cat "$tmp/conv" 2>/dev/null)"
! grep -q '^convert ' "$tmp/conv" || fail "the deprecated convert was used although magick exists"
[ -s "$tmp/insert" ] || fail "no queue row was inserted for a file name with quotes: $out"
sql=$(head -1 "$tmp/insert")
# The name never appears in the SQL text: every string travels as a hex literal.
! grep -Fq "Brien" <<<"$sql" || fail "the file name reached the SQL in the clear: $sql"
grep -q "INSERT INTO wp_rio_process_queue .*VALUES (7,'webp',CONVERT(UNHEX(" <<<"$sql" || fail "the INSERT lost its shape: ${sql:0:300}"
# Decode extra_data back and compare with the real path.
hexes=$(grep -o "UNHEX('[0-9a-f]*')" <<<"$sql" | sed "s/UNHEX('//; s/')//")
decoded=$(php -r 'foreach (explode("\n", trim(stream_get_contents(STDIN))) as $h) { $j = json_decode(hex2bin($h), true); if (is_array($j) && isset($j["source_path"])) { echo $j["source_path"], "\n", $j["converted_path"], "\n", $j["converted_from_size"], "\n"; } }' <<<"$hexes")
want_src="$wp/wp-content/uploads/$rel"
[ "$(sed -n 1p <<<"$decoded")" = "$want_src" ] || fail "source_path did not round-trip: $decoded"
[ "$(sed -n 2p <<<"$decoded")" = "$want_src.webp" ] || fail "converted_path did not round-trip: $decoded"
[ "$(sed -n 3p <<<"$decoded")" = "original" ] || fail "converted_from_size did not round-trip: $decoded"
! grep -q 'could not build the queue row' <<<"$out" || fail "the row builder refused a valid file name: $out"

# convert is still the fallback when magick is absent.
sync convert
[ "$rc" -eq 0 ] || fail "the convert-only run exited $rc: $out"
grep -q '^convert ' "$tmp/conv" || fail "convert was not used as the fallback when magick is absent"

echo PASS
