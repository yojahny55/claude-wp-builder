<?php
/**
 * Behavioral test for the __tailwind__ starter's WebP background helpers.
 *
 * The rest of the suite greps for contract wording; this one runs the code, because
 * three of the defects it guards against (a traversal probe, a filename that closes
 * the url() token, and the output buffer undoing the helper's own fallback) all pass
 * any grep written against the source.
 *
 * WordPress is not loaded: the handful of functions the file uses are stubbed, and
 * the placeholder prefix is replaced the way /wp-init replaces it.
 */

$root = dirname( __DIR__, 3 );
$base_url = 'https://example.test/wp-content/uploads';
$base_dir = sys_get_temp_dir() . '/starter-webp-test-' . getmypid();

function wp_get_upload_dir() {
	global $base_url, $base_dir;
	return array( 'baseurl' => $base_url, 'basedir' => $base_dir );
}
function set_url_scheme( $url ) { return preg_replace( '#^https?://#', 'https://', $url ); }
// Mirrors esc_url()'s whitelist closely enough for what is under test: it strips the
// quote, the angle bracket and the raw space, and keeps ( ) ' ; — which is the point.
function esc_url( $url ) {
	// The backslash is deliberately absent from this whitelist, the way it is absent from
	// WP's: a stub that let it through would keep the percent-encoding assertions passing
	// after the helper stopped encoding it.
	$url = preg_replace( '|[^a-z0-9\-~+_.?#=!&;,/:%@$\|*\'()\[\] ]|i', '', $url );
	$url = str_replace( array( '"', '<', '>' ), '', $url );
	return str_replace( ' ', '%20', $url );
}
function add_filter() {}
// Keep the template_redirect callback so the real output buffer can be exercised,
// rather than a copy of it that would pass whatever the real one does.
$GLOBALS['t_actions'] = array();
function add_action( $hook, $cb ) { $GLOBALS['t_actions'][ $hook ][] = $cb; }
function is_admin() { return false; }
function is_feed() { return false; }
function is_robots() { return false; }

// Registered before any fixture exists, so every exit path — including the early one
// when no template_redirect callback is found — removes the temporary library.
register_shutdown_function( function () use ( $base_dir ) {
	foreach ( glob( "$base_dir/2026/09/*" ) as $f ) { unlink( $f ); }
	@rmdir( "$base_dir/2026/09" ); @rmdir( "$base_dir/2026" ); @rmdir( $base_dir );
	$outside = dirname( $base_dir ) . '/starter-webp-outside-' . getmypid();
	@unlink( "$outside/secret.png.webp" ); @rmdir( $outside );
} );

$fails = array();
function check( $label, $got, $want ) {
	global $fails;
	if ( $got !== $want ) {
		$fails[] = "$label\n    got:  $got\n    want: $want";
	}
}

// Load the starter file with the prefix replaced and the ABSPATH guard removed.
$src = file_get_contents( $root . '/starter-theme/__tailwind__/inc/performance.php' );
$src = str_replace( '__starter___', 't_', $src );
$src = preg_replace( '/^<\?php/', '', $src, 1 );
$removed = 0;
$src     = preg_replace( '/^\s*if\s*\(\s*!\s*defined\(\s*.ABSPATH.\s*\)\s*\)\s*\{[^}]*\}/m', '', $src, 1, $removed );
// Without this, a reformatted guard leaves `exit;` in the eval'd source and the whole
// test ends silently, which reads exactly like a pass. The assertion looks for the guard
// itself, not the bare word: a future comment naming ABSPATH must not fail this run.
if ( 1 !== $removed || preg_match( '/defined\(\s*.ABSPATH./', $src ) ) {
	fwrite( STDERR, "FAIL: could not strip the ABSPATH guard from performance.php\n" );
	exit( 1 );
}
eval( $src );

// Fixture library: one attachment per sibling convention, one with no sibling.
@mkdir( $base_dir . '/2026/09', 0777, true );
foreach ( array( 'a.png', 'a.png.webp', 'b.jpg', 'b.webp', 'c.png', 'plan (1).png', 'plan (1).png.webp', 'photo..original.png', 'photo..original.png.webp' ) as $f ) {
	touch( "$base_dir/2026/09/$f" );
}
@mkdir( dirname( $base_dir ) . '/starter-webp-outside-' . getmypid(), 0777, true );
touch( dirname( $base_dir ) . '/starter-webp-outside-' . getmypid() . '/secret.png.webp' );

$U = $base_url . '/2026/09/';

// 1. Both sibling conventions resolve; a file with no sibling resolves to nothing.
check( 'appended sibling (what Robin writes)', t_webp_sibling_url( $U . 'a.png' ), $U . 'a.png.webp' );
check( 'replaced-extension sibling (what WordPress writes)', t_webp_sibling_url( $U . 'b.jpg' ), $U . 'b.webp' );
check( 'no sibling', t_webp_sibling_url( $U . 'c.png' ), '' );

// 2. A versioned URL names the same file.
check( 'versioned URL', t_webp_sibling_url( $U . 'a.png?ver=3' ), $U . 'a.png.webp' );

// 2b. The answer comes back in the scheme it was asked in: the output buffer replaces the
// exact text it matched, so a normalized https sibling for an http match would leave a
// mixed-scheme URL in the page.
check( 'http input, http sibling', t_webp_sibling_url( 'http://example.test/wp-content/uploads/2026/09/a.png' ), 'http://example.test/wp-content/uploads/2026/09/a.png.webp' );

// 3. Remote URLs and parent segments never reach the filesystem.
check( 'remote URL', t_webp_sibling_url( 'https://cdn.example.com/x.png' ), '' );
check(
	'parent segment refused',
	t_webp_sibling_url( $base_url . '/../starter-webp-outside-' . getmypid() . '/secret.png' ),
	''
);

// 3b. The traversal guard tests the path SEGMENT, so an honest name carrying two dots
// is not collateral damage.
check( 'two dots inside a filename still resolve', t_webp_sibling_url( $U . 'photo..original.png' ), $U . 'photo..original.png.webp' );

// 4. A filename CSS would read as syntax cannot close the url() token or the declaration.
$hostile = t_background_image( $U . 'plan (1).png' );
check(
	'CSS-syntax characters in the filename are percent-encoded everywhere',
	$hostile,
	"background-image:url('{$U}plan%20%281%29.png');background-image:image-set("
		. "url('{$U}plan%20%281%29.png.webp') type('image/webp'), "
		. "url('{$U}plan%20%281%29.png') type('image/png'));"
);
// Stated separately: the assertion above would still hold if a later edit encoded only
// the WebP branch, which is how an earlier version of this test passed a broken helper.
check( 'no unencoded parenthesis inside any url() token', (string) (int) ( (bool) preg_match( "/url\('[^']*[()][^']*'\)/", $hostile ) ), '0' );
check( 'no unencoded semicolon inside any url() token', (string) (int) ( (bool) preg_match( "/url\('[^']*;[^']*'\)/", $hostile ) ), '0' );

// 4b. The encoder's contract, pinned directly: the assertion above compares one rendered
// declaration, and a replacement list that lost an entry could still render that one the
// same way.
check(
	'every CSS-syntax character is encoded',
	t_css_url( 'a(b)c\'d"e;f,g\\h' ),
	'a%28b%29c%27d%22e%3Bf%2Cg%5Ch'
);

// 5. The fallback declaration comes first and keeps the original format.
$css = t_background_image( $U . 'a.png' );
check(
	'fallback first, image-set second',
	$css,
	"background-image:url('{$U}a.png');background-image:image-set(url('{$U}a.png.webp') type('image/webp'), url('{$U}a.png') type('image/png'));"
);
check( 'no sibling means one plain declaration', t_background_image( $U . 'c.png' ), "background-image:url('{$U}c.png');" );
check( 'empty input', t_background_image( '' ), '' );

// 6. The output buffer swaps a plain <img>, and leaves the helper's own output alone.
$html = '<img src="' . $U . 'a.png"><div style="' . $css . '"></div>';
$callbacks = $GLOBALS['t_actions']['template_redirect'] ?? array();
if ( ! $callbacks ) {
	echo "FAIL:\n  the file registered no template_redirect callback — the output buffer is gone\n";
	exit( 1 );
}
ob_start();                 // outer: catches what the theme's buffer flushes
foreach ( $callbacks as $cb ) { $cb(); }  // registers the theme's own ob_start()
echo $html;
ob_end_flush();             // runs the theme's callback for real
$out = ob_get_clean();

check( '<img> src swapped', (string) (int) ( false !== strpos( $out, 'src="' . $U . 'a.png.webp"' ) ), '1' );
check( "helper's fallback URL untouched", (string) (int) ( false !== strpos( $out, "url('{$U}a.png');background-image:image-set(" ) ), '1' );
check( "helper's image-set candidate untouched", (string) (int) ( false !== strpos( $out, "url('{$U}a.png') type('image/png')" ) ), '1' );
// The WebP candidate is the case the guard prefixes do NOT cover: the lazy pattern
// matches the `a.png` inside `a.png.webp`, and its sibling resolves, so without the
// look-ahead in the pattern the buffer turns it into `a.png.webp.webp`.
check( "helper's WebP candidate not double-suffixed", (string) (int) ( false !== strpos( $out, "url('{$U}a.png.webp') type('image/webp')" ) ), '1' );
check( 'no .webp.webp anywhere in the output', (string) (int) ( false !== strpos( $out, '.webp.webp' ) ), '0' );

// A sibling URL printed straight into the markup — by a plugin, or by a template that
// resolved it itself — must survive the buffer too.
$plain = '<img src="' . $U . 'b.webp"><img src="' . $U . 'a.png.webp">';
ob_start();
foreach ( $callbacks as $cb ) { $cb(); }
echo $plain;
ob_end_flush();
$plain_out = ob_get_clean();
check( 'an already-sibling URL in the markup is left alone', $plain_out, $plain );

if ( $fails ) {
	echo "FAIL:\n  " . implode( "\n  ", $fails ) . "\n";
	exit( 1 );
}
echo "OK\n";
