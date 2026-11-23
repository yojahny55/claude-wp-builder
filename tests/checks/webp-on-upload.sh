#!/usr/bin/env bash
# /wp-webp upload installs templates/webp/webp-on-upload.php, a must-use plugin that swaps a
# PNG or JPEG upload for a WebP before WordPress makes its sizes. This runs the plugin's filter
# with the real cwebp against stubbed WordPress: a photo becomes a WebP and the original is
# gone; a candidate that misses the PSNR floor or is not smaller, a JPEG whose EXIF says it is
# rotated, an image over the pixel cap and an encode past its deadline keep the original;
# GIFs, failed uploads and every blocker (no cwebp, no WebP editor, the disable constant) leave
# the upload alone; a name clash gets a unique name; an s3://-style stream wrapper works
# through a local copy. Against a real WordPress: tests/checks/webp-on-upload-integration.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-webp.md
tpl=templates/webp/webp-on-upload.php
[ -f "$cmd" ] || fail "$cmd is missing"
[ -f "$tpl" ] || fail "$tpl is missing"

need_token "$cmd" 'templates/webp/webp-on-upload.php'
need_token "$cmd" 'do not retype or "improve" it'
need_token "$cmd" 'Different without `--force`: stop and show the diff'
need_token "$cmd" 'WPMU_PLUGIN_DIR'
need_token "$cmd" 'webp_on_upload_blocker'
need_token "$cmd" '**Exit `3` policy:** `adopt-or-stop`'
need_token "$tpl" "defined( 'ABSPATH' ) || exit;"
need_token "$tpl" "add_filter( 'wp_handle_upload', 'webp_on_upload', 5 );"
need_token "$tpl" "add_filter( 'wp_handle_sideload', 'webp_on_upload', 5 );"
need_token README.md '/wp-webp'
need_token docs/commands.md '(#wp-webp)'
need_token BACKLOG.md 'tests/checks/webp-on-upload.sh'
if grep -n '__[a-z]*__' "$tpl" >/dev/null; then fail "$tpl carries a token; the command copies it verbatim"; fi

require_tool php cwebp
php -l "$tpl" >/dev/null || fail "$tpl does not parse"
php -r 'exit(function_exists("imagewebp") && function_exists("imagecreatetruecolor") ? 0 : 1);' || skip "PHP GD with WebP is not available"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
CWEBP=$(command -v cwebp)

cat > "$tmp/run.php" <<'PHP'
<?php
// argv: case, dir, cwebp
define( 'ABSPATH', __DIR__ . '/' );
list( , $case, $dir, $cwebp ) = $argv;
if ( 'no-cwebp' === $case ) { define( 'WEBP_ON_UPLOAD_CWEBP', '/nonexistent/cwebp' ); } else { define( 'WEBP_ON_UPLOAD_CWEBP', $cwebp ); }
if ( 'disabled' === $case ) { define( 'WEBP_ON_UPLOAD_DISABLE', true ); }
$GLOBALS['filters'] = array();
function add_filter( $h, $f, $p = 10 ) { $GLOBALS['filters'][ $h ] = array( $f, $p ); }
function apply_filters( $h, $v ) {
    if ( 'webp_on_upload_psnr' === $h && 'floor' === $GLOBALS['case'] ) { return 99.5; }
    if ( 'webp_on_upload_max_pixels' === $h && 'cap' === $GLOBALS['case'] ) { return 1000; }
    if ( 'webp_on_upload_timeout' === $h && 'timeout' === $GLOBALS['case'] ) { return 0.0001; }
    return $v;
}
function wp_image_editor_supports( $a ) { return 'no-editor' !== $GLOBALS['case']; }
function wp_is_stream( $p ) { return false !== strpos( $p, '://' ); }
function trailingslashit( $s ) { return rtrim( $s, '/' ) . '/'; }
function wp_unique_filename( $dir, $name ) {
    $base = pathinfo( $name, PATHINFO_FILENAME ); $ext = pathinfo( $name, PATHINFO_EXTENSION );
    $try = $name; $n = 1;
    while ( file_exists( $dir . '/' . $try ) ) { $try = $base . '-' . $n++ . '.' . $ext; }
    return $try;
}
// A userland wrapper over a real directory, standing in for S3 Uploads' s3://.
class FxStream {
    public $context; private $h;
    static function real( $p ) { return $GLOBALS['dir'] . '/bucket/' . substr( $p, strlen( 'fx://' ) ); }
    function stream_open( $p, $m ) { $this->h = fopen( self::real( $p ), $m ); return (bool) $this->h; }
    function stream_read( $n ) { return fread( $this->h, $n ); }
    function stream_write( $d ) { return fwrite( $this->h, $d ); }
    function stream_eof() { return feof( $this->h ); }
    function stream_close() { fclose( $this->h ); }
    function stream_stat() { return fstat( $this->h ); }
    function url_stat( $p, $f ) { $r = self::real( $p ); return file_exists( $r ) ? stat( $r ) : false; }
    function unlink( $p ) { return unlink( self::real( $p ) ); }
    function rename( $a, $b ) { return rename( self::real( $a ), self::real( $b ) ); }
}
stream_wrapper_register( 'fx', 'FxStream' );
$GLOBALS['case'] = $case; $GLOBALS['dir'] = $dir;
require __DIR__ . '/plugin.php';
list( $filter, $prio ) = $GLOBALS['filters']['wp_handle_upload'];
if ( 5 !== $prio || ! isset( $GLOBALS['filters']['wp_handle_sideload'] ) ) { echo 'hooks'; exit; }

$src = $dir . '/photo.jpg'; $type = 'image/jpeg';
if ( 'png' === $case ) { $src = $dir . '/alpha.png'; $type = 'image/png'; }
if ( 'gif' === $case ) { $src = $dir . '/anim.gif'; $type = 'image/gif'; }
if ( 'rotated' === $case ) { $src = $dir . '/rotated.jpg'; }
if ( 'upright' === $case ) { $src = $dir . '/upright.jpg'; }
if ( 'deep' === $case ) { $src = $dir . '/deep.jpg'; }
if ( 'stream' === $case ) { $src = 'fx://bucket/uploads/2026/11/photo.jpg'; }
$up = array( 'file' => $src, 'url' => 'https://example.test/wp-content/uploads/2026/11/' . basename( $src ), 'type' => $type );
if ( 'error' === $case ) { $up['error'] = 'too big'; }
$before = file_exists( $src ) ? md5_file( $src ) : '';
$r = $filter( $up );
$out = array( $r['type'], basename( $r['file'] ), basename( $r['url'] ), file_exists( $r['file'] ) ? 'exists' : 'missing' );
$out[] = file_exists( $src ) ? ( md5_file( $src ) === $before ? 'orig-intact' : 'orig-changed' ) : 'orig-gone';
if ( 'image/webp' === $r['type'] ) {
    $info = getimagesize( $r['file'] );
    $out[] = $info && 'image/webp' === $info['mime'] ? 'real-webp' : 'not-webp';
}
echo implode( '|', $out );
PHP
command cp -f "$tpl" "$tmp/plugin.php"

fresh() {
  rm -rf "$tmp/d"; mkdir -p "$tmp/d/bucket/bucket/uploads/2026/11"
  php -r '
    $d = $argv[1];
    $i = imagecreatetruecolor( 640, 480 );
    for ( $y = 0; $y < 480; $y++ ) { for ( $x = 0; $x < 640; $x += 2 ) {
      $c = imagecolorallocate( $i, (int) ( 255 * $x / 640 ), (int) ( 255 * $y / 480 ), (int) ( 128 + 100 * sin( ( $x + $y ) / 40 ) ) );
      imagesetpixel( $i, $x, $y, $c ); imagesetpixel( $i, $x + 1, $y, $c ); } }
    imagejpeg( $i, "$d/photo.jpg", 95 ); imagejpeg( $i, "$d/bucket/bucket/uploads/2026/11/photo.jpg", 95 );
    $a = imagecreatetruecolor( 320, 240 ); imagesavealpha( $a, true ); imagealphablending( $a, false );
    for ( $x = 0; $x < 320; $x++ ) { imagefilledrectangle( $a, $x, 0, $x, 239, imagecolorallocatealpha( $a, 200, (int) ( 255 * $x / 320 ), 60, (int) ( 127 * $x / 320 ) ) ); }
    imagepng( $a, "$d/alpha.png" );
    $g = imagecreate( 10, 10 ); imagecolorallocate( $g, 1, 2, 3 ); imagegif( $g, "$d/anim.gif" );
    // EXIF Orientation in an APP1 segment right after SOI: big-endian 6 (rotated), little-endian 1.
    $jpg = file_get_contents( "$d/photo.jpg" );
    $app1 = function ( $le, $orientation ) {
      $p16 = function ( $v ) use ( $le ) { return pack( $le ? "v" : "n", $v ); };
      $p32 = function ( $v ) use ( $le ) { return pack( $le ? "V" : "N", $v ); };
      $tiff = ( $le ? "II" : "MM" ) . $p16( 42 ) . $p32( 8 ) . $p16( 1 ) . $p16( 0x0112 ) . $p16( 3 ) . $p32( 1 ) . $p16( $orientation ) . $p16( 0 ) . $p32( 0 );
      $body = "Exif\0\0" . $tiff;
      return "\xFF\xE1" . pack( "n", strlen( $body ) + 2 ) . $body;
    };
    file_put_contents( "$d/rotated.jpg", "\xFF\xD8" . $app1( false, 6 ) . substr( $jpg, 2 ) );
    file_put_contents( "$d/upright.jpg", "\xFF\xD8" . $app1( true, 1 ) . substr( $jpg, 2 ) );
    // Rotated, but its EXIF sits past the first 256 KiB, behind five full APP2 segments: the
    // plugin cannot see it, so it must not convert.
    $app2 = str_repeat( "\xFF\xE2" . pack( "n", 65535 ) . str_repeat( "x", 65533 ), 5 );
    file_put_contents( "$d/deep.jpg", "\xFF\xD8" . $app2 . $app1( false, 6 ) . substr( $jpg, 2 ) );
  ' "$tmp/d"
}
expect() {
  fresh
  [ "${2:-}" = clash ] && : > "$tmp/d/photo.webp"
  rm -rf "$tmp/systmp"; mkdir "$tmp/systmp"
  got=$(TMPDIR="$tmp/systmp" php "$tmp/run.php" "$1" "$tmp/d" "$CWEBP")
  [ "$got" = "$3" ] || fail "case $1${2:+ ($2)}: expected '$3', got '$got'"
  # The plugin's temporary files go to sys_get_temp_dir(), which PHP takes from TMPDIR: a
  # private one per case, so a parallel check cleaning the shared /tmp cannot make find fail.
  stray=$(find "$tmp/systmp" -name 'webp*' | sed -n 1,5p)
  [ -z "$stray" ] || fail "case $1 left temporary files behind: $stray"
}

expect photo     ''    'image/webp|photo.webp|photo.webp|exists|orig-gone|real-webp'
expect photo     clash 'image/webp|photo-1.webp|photo-1.webp|exists|orig-gone|real-webp'
expect png       ''    'image/webp|alpha.webp|alpha.webp|exists|orig-gone|real-webp'
expect stream    ''    'image/webp|photo.webp|photo.webp|exists|orig-gone|real-webp'
expect floor     ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect rotated   ''    'image/jpeg|rotated.jpg|rotated.jpg|exists|orig-intact'
expect upright   ''    'image/webp|upright.webp|upright.webp|exists|orig-gone|real-webp'
expect deep      ''    'image/jpeg|deep.jpg|deep.jpg|exists|orig-intact'
expect cap       ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect timeout   ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect gif       ''    'image/gif|anim.gif|anim.gif|exists|orig-intact'
expect error     ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect no-cwebp  ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect no-editor ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
expect disabled  ''    'image/jpeg|photo.jpg|photo.jpg|exists|orig-intact'
[ -z "$(find "$tmp/d" -name '*.webp' -newer "$tmp/run.php")" ] || fail "a refused conversion left a .webp in uploads"
echo "PASS: webp-on-upload converts photos above the PSNR floor and leaves everything else untouched"
