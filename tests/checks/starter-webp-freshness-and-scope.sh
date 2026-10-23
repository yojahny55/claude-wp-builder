#!/usr/bin/env bash
# Starter delivery defects found in review of the Tailwind starter:
#   1. A WebP sibling was used if it merely existed, so replacing a medium under the same
#      name (or `wp media regenerate`) kept serving the previous picture.
#   2. The output buffer on template_redirect rewrote every response, XML sitemaps,
#      embeds and non-HTML content types included.
#   3. Every PNG became WebP, transparent and palette graphics too.
#   4. The ACF field scan (glob + read + regex of fields/*.php) ran on every request,
#      under a comment that promised it did not.
#   5. A nonce was printed on every page (stale inside a page cache) for an AJAX
#      handler the starter does not have, and defer was a str_replace on markup.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

perf=starter-theme/__tailwind__/inc/performance.php
fn=starter-theme/__tailwind__/functions.php
[ -f "$perf" ] && [ -f "$fn" ] || fail "starter files missing"

# 1. freshness, both at generation and at serving time
grep -Fq 'function __starter___webp_is_fresh(' "$perf" || fail "no freshness helper"
[ "$(grep -Fc '__starter___webp_is_fresh(' "$perf")" -ge 3 ] \
  || fail "freshness is not applied to both the generator and the sibling lookup"
! grep -Eq 'if \( file_exists\( \$webp \) \) \{' "$perf" || fail "generator still skips on bare file_exists"

# 2. buffer scope
grep -Fq 'is_embed()' "$perf" || fail "buffer still runs on embeds"
grep -Fq "get_query_var( 'sitemap' )" "$perf" || fail "buffer still runs on sitemaps"
grep -Fq 'headers_list()' "$perf" || fail "buffer does not look at the Content-Type"
grep -Fq 'text/html' "$perf" || fail "buffer does not restrict to text/html"

# 3. PNG conversion is conditional
grep -Fq 'function __starter___png_should_become_webp(' "$perf" || fail "no PNG gate"
grep -Fq "if ( '' === \$filename || __starter___png_should_become_webp( \$filename ) ) {" "$perf" || fail "PNG conversion is not guarded by the legacy fallback and selective check"
grep -Fq "\$formats['image/png'] = 'image/webp';" "$perf" || fail "PNG conversion mapping is missing"
grep -Fq "'' === \$filename" "$perf" || fail "older WordPress versions lost the legacy PNG format fallback"

# 4. image helper without an attachment
grep -Fq "'alt' =>" "$perf" || fail "bare-URL <img> still has no default alt"

# 5. functions.php
grep -Fq '__starter___fields_scan' "$fn" || fail "ACF scan is not cached"
! grep -Fq 'wp_create_nonce' "$fn" || fail "nonce is still printed on every page"
! grep -Fq "str_replace( ' src'" "$fn" || fail "defer is still a str_replace on markup"
grep -Fq "'strategy' => 'defer'" "$fn" || fail "main script does not use the defer strategy"

# Behavior of the two pure helpers.
if command -v php >/dev/null 2>&1; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/t.php" <<'PHP'
<?php
define( 'ABSPATH', '/' );
$GLOBALS['t_filters'] = array();
function add_filter( $hook, $cb ) { $GLOBALS['t_filters'][ $hook ][] = $cb; }
function add_action() {}
$src = str_replace( '__starter__', 'st', file_get_contents( $argv[1] ) );
eval( '?>' . $src );
$d = $argv[2];
file_put_contents( "$d/a.jpg", 'x' );
file_put_contents( "$d/a.webp", 'x' );
touch( "$d/a.jpg", time() - 100 );
touch( "$d/a.webp", time() - 50 );
if ( ! st_webp_is_fresh( "$d/a.webp", "$d/a.jpg" ) ) { fwrite( STDERR, "fresh sibling rejected\n" ); exit( 1 ); }
touch( "$d/a.jpg", time() );
if ( st_webp_is_fresh( "$d/a.webp", "$d/a.jpg" ) ) { fwrite( STDERR, "stale sibling accepted\n" ); exit( 1 ); }
// PNG: colour type 6 (alpha) stays PNG, colour type 2 (truecolor) converts.
foreach ( array( 6 => false, 2 => true ) as $type => $want ) {
	$png = "\x89PNG\r\n\x1a\n" . pack( 'N', 13 ) . 'IHDR' . pack( 'NN', 10, 10 ) . chr( 8 ) . chr( $type ) . str_repeat( "\0", 20000 );
	file_put_contents( "$d/color-$type.png", $png );
	if ( st_png_should_become_webp( "$d/color-$type.png" ) !== $want ) { fwrite( STDERR, "png colour type $type misjudged\n" ); exit( 1 ); }
}
$format = $GLOBALS['t_filters']['image_editor_output_format'][0] ?? null;
if ( ! $format ) { fwrite( STDERR, "image_editor_output_format filter not registered\n" ); exit( 1 ); }
$legacy = $format( array() );
if ( ( $legacy['image/png'] ?? '' ) !== 'image/webp' ) { fwrite( STDERR, "one-argument legacy filter lost PNG-to-WebP conversion\n" ); exit( 1 ); }
$alpha = $format( array(), "$d/color-6.png" );
if ( isset( $alpha['image/png'] ) ) { fwrite( STDERR, "modern filter converted alpha PNG\n" ); exit( 1 ); }
$photo = $format( array(), "$d/color-2.png" );
if ( ( $photo['image/png'] ?? '' ) !== 'image/webp' ) { fwrite( STDERR, "modern filter skipped truecolor PNG\n" ); exit( 1 ); }
PHP
  php "$tmp/t.php" "$perf" "$tmp" || fail "helper behavior"
else
  echo "SKIP: php not available, helper behavior not run"
fi
echo PASS
