#!/usr/bin/env bash
# skills/wp-robin/scripts/webp-migrate.php against a real WordPress library:
#   - plan counts the PNG attachments; a dry convert writes nothing;
#   - convert turns each PNG attachment (one large enough to get a -scaled copy) into a WebP
#     with WebP sizes, keeps every old file on disk, writes the map, and a second run converts
#     nothing;
#   - replace rewrites plain URLs in post content, JSON-escaped ones in Elementor-style meta and
#     URLs inside a serialized option, keeping it unserializable; it leaves Robin's
#     <file>.png.webp names, transients and guid alone; a dry replace writes nothing;
#   - verify passes after replace and fails while a row still names an old file;
#   - move-aside refuses a backup folder inside uploads, then moves every old PNG out of
#     uploads into the backup folder, and every new WebP is still there;
#   - a workdir inside the WordPress root is refused.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi
require_tool php python3

prov=tests/fixtures/wp/provision.sh
script=skills/wp-robin/scripts/webp-migrate.php
DIR=""
SCRATCH=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$SCRATCH"
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(bash "$prov") || fail "could not provision a WordPress fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
q() { $WP eval "$1" 2>/dev/null; }
WORK="$SCRATCH/work"
BACKUP="$SCRATCH/old-png"
run() { $WP eval-file "$script" "$@" 2>&1; }
json_field() { python3 -c "import json,sys
rows=[json.loads(l) for l in sys.stdin if l.strip().startswith('{')]
print(rows[-1].get('$1'))"; }

[ "$(q 'echo wp_image_editor_supports(array("mime_type"=>"image/webp")) ? 1 : 0;')" = 1 ] || skip "the fixture's image editor cannot write WebP"

php -r '
  $d = $argv[1];
  foreach ( array( "big" => array( 3000, 2000 ), "small" => array( 400, 300 ) ) as $n => $wh ) {
    $i = imagecreatetruecolor( $wh[0], $wh[1] );
    for ( $x = 0; $x < $wh[0]; $x += 8 ) { imagefilledrectangle( $i, $x, 0, $x + 7, $wh[1] - 1, imagecolorallocate( $i, $x % 256, ( $x * 7 ) % 256, 90 ) ); }
    imagepng( $i, "$d/$n.png" );
  }
' "$SCRATCH"
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
big=$($WP media import "$SCRATCH/big.png" --user="$AUTHOR" --porcelain)
small=$($WP media import "$SCRATCH/small.png" --user="$AUTHOR" --porcelain)
[ "$($WP post get "$big" --field=post_mime_type)" = image/png ] || fail "fixture import did not keep the PNG"

# References in the shapes a site stores them.
big_url=$(q "echo wp_get_original_image_url($big);")
big_thumb=$(q "echo wp_get_attachment_image_url($big,'medium');")
small_url=$(q "echo wp_get_attachment_url($small);")
post=$($WP post create --post_type=post --post_status=publish --post_title=refs --post_author="$AUTHOR" \
  --post_content="<img src=\"$big_thumb\"><a href=\"$big_url\">full</a> <img src=\"$small_url\"> robin:${small_url}.webp" --porcelain)
esc=$(printf '%s' "$small_url" | sed 's|/|\\/|g')
q "update_post_meta($post, '_elementor_data', wp_slash('[{\"settings\":{\"image\":{\"url\":\"$esc\"}}}]'));"
q "update_option('fx_theme_opts', array('logo' => '$small_url', 'n' => 1));"
q "set_transient('fx_cache', '$small_url', 3600);"
guid_before=$(q "echo get_post_field('guid',$big);")

# A workdir inside the WordPress root is refused.
if run plan "$DIR/wp-content/webp-work" >/dev/null; then fail "a workdir inside the WordPress root was accepted"; fi

out=$(run plan "$WORK") || fail "plan failed: $out"
[ "$(printf '%s\n' "$out" | json_field png_attachments)" = 2 ] || fail "plan did not count 2 PNG attachments: $out"

out=$(run convert "$WORK" dry-run) || fail "dry convert failed: $out"
[ "$($WP post get "$big" --field=post_mime_type)" = image/png ] || fail "dry convert changed an attachment"
[ ! -e "$WORK/map.tsv" ] || fail "dry convert wrote a map"

out=$(run convert "$WORK") || fail "convert failed: $out"
[ "$(printf '%s\n' "$out" | json_field converted)" = 2 ] || fail "convert did not convert 2: $out"
for id in "$big" "$small"; do
  python3 - "$id" "$DIR" <<'PY' || fail "attachment $id is not a WebP with WebP sizes"
import json, os, subprocess, sys
pid, root = sys.argv[1], sys.argv[2]
wp = ["wp", "--path=" + root, "--allow-root"]
assert subprocess.check_output(wp + ["post", "get", pid, "--field=post_mime_type"], text=True).strip() == "image/webp"
meta = json.loads(subprocess.check_output(wp + ["eval", "echo wp_json_encode(wp_get_attachment_metadata(%s));" % pid], text=True))
up = subprocess.check_output(wp + ["eval", "echo wp_upload_dir()['basedir'];"], text=True).strip()
base = os.path.join(up, os.path.dirname(meta["file"]))
assert meta["file"].endswith(".webp") and meta["sizes"]
for s in meta["sizes"].values():
    assert s["file"].endswith(".webp") and os.path.exists(os.path.join(base, s["file"])), s
PY
done
case "$(q "echo get_post_meta($big,'_wp_attached_file',true);")" in *-scaled.webp) ;; *) fail "the large PNG did not get a -scaled WebP" ;; esac
up=$(q 'echo wp_upload_dir()["basedir"];')
[ -n "$(find "$up" -name '*.png' | sed -n 1p)" ] || fail "convert deleted the old PNGs; it must keep them until move-aside"
rows=$(wc -l < "$WORK/map.tsv")
[ "$rows" -ge 6 ] || fail "the map has only $rows rows"
out=$(run convert "$WORK") || fail "second convert failed: $out"
[ "$(printf '%s\n' "$out" | json_field converted)" = 0 ] || fail "second convert converted again: $out"

# A row still names an old file: verify must fail.
if run verify "$WORK" >/dev/null; then fail "verify passed while content still names the old PNGs"; fi

content_before=$(q "echo md5(get_post_field('post_content',$post));")
out=$(run replace "$WORK" dry-run) || fail "dry replace failed: $out"
[ "$(printf '%s\n' "$out" | json_field rows)" -ge 3 ] || fail "dry replace found fewer than 3 rows: $out"
[ "$(q "echo md5(get_post_field('post_content',$post));")" = "$content_before" ] || fail "dry replace changed content"

out=$(run replace "$WORK") || fail "replace failed: $out"
content=$(q "echo get_post_field('post_content',$post);")
case "$content" in *.png\"*|*.png\>*) fail "post content still names a PNG: $content" ;; esac
printf '%s' "$content" | grep -c 'robin:.*\.png\.webp' >/dev/null || fail "Robin's .png.webp name was rewritten: $content"
printf '%s' "$content" | grep -c '\.webp\.webp' >/dev/null && fail "a .png.webp became .webp.webp: $content"
[ "$(q "\$d=json_decode(get_post_meta($post,'_elementor_data',true),true); echo substr(\$d[0]['settings']['image']['url'],-5);")" = .webp ] || fail "the JSON-escaped Elementor URL was not replaced"
[ "$(q "\$o=get_option('fx_theme_opts'); echo is_array(\$o) ? substr(\$o['logo'],-5) . '|' . \$o['n'] : 'broken';")" = ".webp|1" ] || fail "the serialized option was not replaced cleanly"
[ "$(q "echo substr(get_transient('fx_cache'),-4);")" = .png ] || fail "a transient was rewritten"
[ "$(q "echo get_post_field('guid',$big);")" = "$guid_before" ] || fail "guid was rewritten"

out=$(run verify "$WORK") || fail "verify failed after replace: $out"

if run move-aside "$WORK" "backup=$up/old" >/dev/null; then fail "move-aside accepted a backup folder inside uploads"; fi
out=$(run move-aside "$WORK" "backup=$BACKUP") || fail "move-aside failed: $out"
[ -z "$(find "$up" -name '*.png' | sed -n 1p)" ] || fail "a PNG is still in uploads after move-aside"
[ -n "$(find "$BACKUP" -name '*.png' | sed -n 1p)" ] || fail "the backup folder holds no PNG"
cut -f2 "$WORK/map.tsv" | sort -u | while read -r rel; do
  [ -f "$up/$rel" ] || fail "new file $rel is missing after move-aside"
done
[ "$(q "echo file_exists(get_attached_file($big)) ? 1 : 0;")" = 1 ] || fail "the attachment's own file is gone"

echo "PASS: a PNG library converts to WebP, references follow it, and old files move aside only after verify"
