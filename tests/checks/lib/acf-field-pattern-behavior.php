<?php
/**
 * Behavioral test for find-orphan-acf-ids.php's field-name pattern.
 *
 * The rest of the suite greps for contract wording. This one extracts the regex the
 * script actually uses and runs it, because every grep written against the source was
 * wrong in a way that still passed:
 *
 *   - a fixed-string match on `['\"]` pins the order of the character class, so
 *     reordering it breaks the check without breaking the script;
 *   - testing the two quote characters against the whole line passes on a pattern that
 *     dropped the double quote entirely, because the PHP string literal is itself
 *     delimited by double quotes.
 *
 * A field name the pattern misses is classified DEAD-DATA rather than
 * REACHES-TEMPLATE, which under-reports the finding that matters.
 *
 * WordPress is not loaded; nothing here runs the script, only its pattern.
 */

/**
 * Pull the first string literal passed to preg_match_all() out of PHP source, and
 * return the string PHP would build from it at runtime.
 *
 * Both quoting styles, because reading only one is a false negative rather than a
 * failure: a script that switched its pattern to a single-quoted literal — same
 * pattern, same behavior — made this test report "no pattern literal found" and exit
 * 1, which reads as a broken pattern instead of a test that could not see it.
 *
 * No eval(). stripcslashes() is not an option either: it would eat `\s` and `\(`,
 * which belong to the regex. Only the escapes each quoting style actually defines
 * are undone — `\"` and `\\` inside double quotes, `\'` and `\\` inside single ones.
 *
 * Returns null when no literal is found.
 */
function acfx_extract_pattern( $source ) {
	$re = '/preg_match_all\(\s*("(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\')/';

	if ( ! preg_match( $re, $source, $m ) ) {
		return null;
	}

	$literal = $m[1];
	$body    = substr( $literal, 1, -1 );

	return ( '"' === $literal[0] )
		? strtr( $body, array( '\\"' => '"', '\\\\' => '\\' ) )
		: strtr( $body, array( "\\'" => "'", '\\\\' => '\\' ) );
}

$failed = 0;

/*
 * The extractor is tested before it is trusted. Each fixture is the same pattern
 * written in one quoting style; both must yield the string PHP would build.
 */
$extractor_fixtures = array(
	'double-quoted literal'          => array( 'preg_match_all( "/x/i", $s, $m )', '/x/i' ),
	'single-quoted literal'          => array( "preg_match_all( '/x/i', \$s, \$m )", '/x/i' ),
	'escaped quote, double-quoted'   => array( 'preg_match_all( "/a\\"b/i", $s, $m )', '/a"b/i' ),
	'escaped quote, single-quoted'   => array( "preg_match_all( '/a\\'b/i', \$s, \$m )", "/a'b/i" ),
	'regex escape survives, double'  => array( 'preg_match_all( "/a\\s(b/i", $s, $m )', '/a\\s(b/i' ),
	'regex escape survives, single'  => array( "preg_match_all( '/a\\s(b/i', \$s, \$m )", '/a\\s(b/i' ),
);

foreach ( $extractor_fixtures as $label => $fixture ) {
	list( $source_fixture, $expected ) = $fixture;
	$got = acfx_extract_pattern( $source_fixture );

	if ( $got !== $expected ) {
		fwrite( STDERR, "extractor returned " . var_export( $got, true ) . " for {$label}, expected " . var_export( $expected, true ) . "\n" );
		$failed++;
	}
}

$script = dirname( __DIR__, 3 ) . '/skills/wp-cli-patterns/scripts/find-orphan-acf-ids.php';

if ( ! is_readable( $script ) ) {
	fwrite( STDERR, "cannot read {$script}\n" );
	exit( 1 );
}

$pattern = acfx_extract_pattern( (string) file_get_contents( $script ) );

if ( null === $pattern ) {
	fwrite( STDERR, "no preg_match_all() pattern literal found in find-orphan-acf-ids.php\n" );
	exit( 1 );
}

$cases = array(
	'single quotes'        => "get_field( 'hero_items' )",
	'double quotes'        => 'get_field( "hero_items" )',
	'no space after paren' => "get_field('hero_items')",
	// Themes this plugin builds read fields through a prefixed wrapper, and WP-034
	// treats that wrapper as the correct call. A \b before the name would drop every
	// one of those reads and classify the whole theme's fields as dead data.
	'prefixed wrapper'     => "acme_get_field( 'hero_items' )",
	'starter wrapper'      => "__starter___get_field( 'hero_items' )",
);

// A word that merely ends in the function name is not a call to it.
$must_not_match = array(
	'forget_field'  => "forget_field( 'hero_items' )",
	'noget_field'   => "widget_field( 'hero_items' )",
);

foreach ( $cases as $label => $code ) {
	if ( ! preg_match( $pattern, $code, $hit ) ) {
		fwrite( STDERR, "pattern does not match {$label}: {$code}\n" );
		$failed++;
		continue;
	}

	if ( 'hero_items' !== $hit[2] ) {
		fwrite( STDERR, "pattern captured '{$hit[2]}' instead of 'hero_items' for {$label}\n" );
		$failed++;
	}
}

foreach ( $must_not_match as $label => $code ) {
	if ( preg_match( $pattern, $code ) ) {
		fwrite( STDERR, "pattern matches {$label}, which is not a call to the function\n" );
		$failed++;
	}
}

// A mismatched pair is a typo in the theme, not a field read; it must not be captured.
if ( preg_match( $pattern, 'get_field( "mismatched\' )' ) ) {
	fwrite( STDERR, "pattern matches a mismatched quote pair\n" );
	$failed++;
}

exit( $failed > 0 ? 1 : 0 );
