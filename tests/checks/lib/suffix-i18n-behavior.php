<?php
/**
 * Behavioral test for the suffix starters' inc/i18n.php.
 *
 * Usage: php suffix-i18n-behavior.php <tailwind|cinematic> [stored-es|no-query]
 *
 * A request for ?lang=es with no cookie by default; `stored-es` adds a cookie already
 * holding es, `no-query` drops ?lang= and sends Accept-Language: es instead.
 *
 * Three defects a grep could not prove gone:
 *
 *   - <html lang> never followed the request. header.php prints language_attributes(),
 *     which reads the site locale, and the skill told agents to append a second lang=""
 *     after it. A browser keeps the first of two duplicate attributes, so ?lang=es pages
 *     announced themselves as English.
 *   - The tailwind starter's language cookie was set by whichever call came first, and
 *     the first call came from wp_enqueue_scripts inside wp_head(), after output began,
 *     so setcookie() could not send its header and a language switch lasted one page.
 *   - The cinematic starter read its language cookie and never set it, so a ?lang=
 *     switch lasted exactly one request.
 *
 * WordPress is not loaded. The hooks are recorded by stubs and then invoked, so what is
 * asserted is what the file registers and what its filter returns.
 */

define( 'ABSPATH', __DIR__ );

$GLOBALS['hooks'] = array();
function add_filter( $hook, $cb, $prio = 10, $args = 1 ) { $GLOBALS['hooks'][ $hook ][] = $cb; return true; }
function add_action( $hook, $cb, $prio = 10, $args = 1 ) { return add_filter( $hook, $cb, $prio, $args ); }
function sanitize_text_field( $s ) { return trim( strip_tags( (string) $s ) ); }
function sanitize_key( $s ) { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $s ) ); }
function wp_unslash( $s ) { return $s; }
function esc_attr( $s ) { return htmlspecialchars( (string) $s, ENT_QUOTES ); }
function wp_kses( $s, $allowed ) { return $s; }
function get_field( $name, $id = false ) { return ''; }

$which = isset( $argv[1] ) ? $argv[1] : '';
$files = array(
	'tailwind'  => array( 'starter-theme/__tailwind__/inc/i18n.php', '__starter___get_current_lang' ),
	'cinematic' => array( 'starter-theme/__cinematic__/inc/i18n.php', '__starter___current_lang' ),
);
if ( ! isset( $files[ $which ] ) ) {
	fwrite( STDERR, "usage: php suffix-i18n-behavior.php <tailwind|cinematic>\n" );
	exit( 2 );
}
list( $file, $lang_fn ) = $files[ $which ];

$mode = isset( $argv[2] ) ? $argv[2] : '';
if ( 'no-query' === $mode ) {
	$_SERVER['HTTP_ACCEPT_LANGUAGE'] = 'es-ES,es;q=0.9';
} else {
	$_GET['lang'] = 'es';
}
if ( 'stored-es' === $mode ) {
	$_COOKIE['__starter___lang'] = 'es';
}
$path = dirname( __DIR__, 3 ) . '/' . $file;
if ( 'cinematic' === $which ) {
	// CLI PHP keeps no response headers, so a real setcookie() leaves nothing to assert
	// on. Load the file inside a namespace that defines its own setcookie(): an
	// unqualified call resolves there before the global function, and everything else the
	// file calls falls back to the stubs above.
	$GLOBALS['cookies'] = array();
	$src = preg_replace( '/^<\?php/', '', file_get_contents( $path ), 1 );
	eval( 'namespace SuffixI18nProbe; function setcookie( ...$a ) { $GLOBALS["cookies"][] = $a; return true; } ' . $src );
} else {
	require $path;
}

$fail = 0;
function check( $label, $ok ) {
	global $fail;
	if ( ! $ok ) {
		$fail = 1;
		echo "FAIL [$label]\n";
	}
}

$filters = isset( $GLOBALS['hooks']['language_attributes'] ) ? $GLOBALS['hooks']['language_attributes'] : array();
check( "$file registers a language_attributes filter", count( $filters ) === 1 );
if ( $filters ) {
	$cb = $filters[0];
	check( 'the filter replaces the locale with the request language',
		call_user_func( $cb, 'lang="en-US"' ) === 'lang="es"' );
	check( 'the filter keeps the dir attribute and replaces lang only',
		call_user_func( $cb, 'dir="rtl" lang="en-US"' ) === 'dir="rtl" lang="es"' );
	// preg_replace() returns null on a PCRE error; a filter must hand the next one a string.
	// The error is forced through the backtrack limit, which a JIT-compiled pattern ignores:
	// PHP 7.4 keeps using one compiled before ini_set(), hence `php -d pcre.jit=0` in the
	// caller and the probe, so this can never pass without the failure having happened.
	ini_set( 'pcre.jit', '0' );
	ini_set( 'pcre.backtrack_limit', '1' );
	$forced = null === preg_replace( '/lang="[^"]*"/', '', 'lang="en-US"' );
	$failed = call_user_func( $cb, 'lang="en-US"' );
	ini_restore( 'pcre.backtrack_limit' );
	ini_restore( 'pcre.jit' );
	check( 'this PHP can be made to fail preg_replace() (run it with -d pcre.jit=0)', $forced );
	check( 'the filter returns a string when preg_replace() fails', is_string( $failed ) );
}

$init = isset( $GLOBALS['hooks']['init'] ) ? $GLOBALS['hooks']['init'] : array();
if ( 'tailwind' === $which ) {
	check( "$file makes the first $lang_fn() call on init, before any output",
		in_array( $lang_fn, $init, true ) );
}

if ( 'cinematic' === $which ) {
	check( "$file registers an init callback, so the cookie is set before any output", count( $init ) >= 1 );
	foreach ( $init as $cb ) {
		call_user_func( $cb );
	}
	$set = $GLOBALS['cookies'];
	if ( 'stored-es' === $mode ) {
		check( 'no cookie is sent when it already holds the ?lang= language', count( $set ) === 0 );
	} elseif ( 'no-query' === $mode ) {
		check( 'no cookie is sent for a language that did not come from ?lang=', count( $set ) === 0 );
	} else {
		check( '?lang=es sets the __starter___lang cookie on init, once', count( $set ) === 1 );
		if ( $set ) {
			check( 'the cookie carries the URL language', $set[0][0] === '__starter___lang' && $set[0][1] === 'es' );
			check( 'the cookie outlives the request, site-wide',
				isset( $set[0][2], $set[0][3] ) && $set[0][2] > time() + 86400 && $set[0][3] === '/' );
		}
	}
}

echo $fail ? "PHPFAIL\n" : "PHPOK\n";
exit( $fail );
