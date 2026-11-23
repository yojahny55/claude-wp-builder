#!/usr/bin/env bash
# templates/webp/webp-on-upload.php installed as a must-use plugin in a real WordPress:
#   - a JPEG photo and a PNG imported with `wp media import` become WebP attachments: mime
#     type, attached file, and every generated size are WebP, and no JPEG or PNG is left in
#     uploads;
#   - with WEBP_ON_UPLOAD_DISABLE the same import stays a JPEG with JPEG sizes;
#   - the plugin's own status line, the one /wp-webp prints, reads "ready" on this server.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks. Needs cwebp.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi
require_tool php cwebp python3

prov=tests/fixtures/wp/provision.sh
tpl=templates/webp/webp-on-upload.php
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

mu=$(q 'echo WPMU_PLUGIN_DIR;')
mkdir -p "$mu"
command cp -f "$tpl" "$mu/webp-on-upload.php"
status=$(q 'echo function_exists("webp_on_upload_blocker") ? ( "" === webp_on_upload_blocker() ? "ready" : webp_on_upload_blocker() ) : "not loaded";')
[ "$status" = ready ] || fail "the plugin is not ready on the fixture: $status"

php -r '
  $d = $argv[1];
  $i = imagecreatetruecolor( 1600, 1000 );
  for ( $y = 0; $y < 1000; $y += 2 ) { for ( $x = 0; $x < 1600; $x += 2 ) {
    $c = imagecolorallocate( $i, (int) ( 255 * $x / 1600 ), (int) ( 255 * $y / 1000 ), (int) ( 128 + 100 * sin( ( $x + $y ) / 60 ) ) );
    imagefilledrectangle( $i, $x, $y, $x + 1, $y + 1, $c ); } }
  imagejpeg( $i, "$d/photo.jpg", 95 );
  imagepng( $i, "$d/shot.png" );
' "$SCRATCH"

assert_webp() { # id label
  python3 - "$1" "$2" "$DIR" <<'PY' || fail "$2 is not a WebP attachment"
import json, os, subprocess, sys
pid, label, root = sys.argv[1], sys.argv[2], sys.argv[3]
wp = ["wp", "--path=" + root, "--allow-root"]
mime = subprocess.check_output(wp + ["post", "get", pid, "--field=post_mime_type"], text=True).strip()
meta = json.loads(subprocess.check_output(wp + ["eval", "echo wp_json_encode(wp_get_attachment_metadata(%s));" % pid], text=True))
up = subprocess.check_output(wp + ["eval", "echo wp_upload_dir()['basedir'];"], text=True).strip()
assert mime == "image/webp", (label, mime)
assert meta["file"].endswith(".webp"), (label, meta["file"])
assert meta["sizes"], (label, "no sizes were made")
base = os.path.join(up, os.path.dirname(meta["file"]))
for name, s in meta["sizes"].items():
    assert s["mime-type"] == "image/webp" and s["file"].endswith(".webp"), (label, name, s)
    assert os.path.exists(os.path.join(base, s["file"])), (label, name, "missing on disk")
PY
}

jpg=$($WP media import "$SCRATCH/photo.jpg" --porcelain)
assert_webp "$jpg" "the imported JPEG"
png=$($WP media import "$SCRATCH/shot.png" --porcelain)
assert_webp "$png" "the imported PNG"
up=$(q 'echo wp_upload_dir()["basedir"];')
left=$(find "$up" -type f \( -name '*.jpg' -o -name '*.png' \) | sed -n 1,3p)
[ -z "$left" ] || fail "a JPEG or PNG was left in uploads: $left"

# Paused: the same import stays JPEG.
$WP config set WEBP_ON_UPLOAD_DISABLE true --raw --quiet
off=$($WP media import "$SCRATCH/photo.jpg" --porcelain)
[ "$($WP post get "$off" --field=post_mime_type)" = image/jpeg ] || fail "WEBP_ON_UPLOAD_DISABLE did not stop the conversion"
case "$(q "echo get_post_meta($off,'_wp_attached_file',true);")" in *.jpg) ;; *) fail "the paused import does not keep its .jpg file" ;; esac

echo "PASS: uploads through WordPress become WebP with WebP sizes, and the switch pauses it"
