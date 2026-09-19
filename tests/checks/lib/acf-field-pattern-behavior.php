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

$script = dirname( __DIR__, 3 ) . '/skills/wp-cli-patterns/scripts/find-orphan-acf-ids.php';

if ( ! is_readable( $script ) ) {
	fwrite( STDERR, "cannot read {$script}\n" );
	exit( 1 );
}

$source = (string) file_get_contents( $script );

// The first double-quoted literal passed to preg_match_all() is the field-name pattern.
if ( ! preg_match( '/preg_match_all\(\s*("(?:[^"\\\\]|\\\\.)*")/', $source, $m ) ) {
	fwrite( STDERR, "no preg_match_all() pattern literal found in find-orphan-acf-ids.php\n" );
	exit( 1 );
}

/*
 * Turn the PHP source literal into the string PHP would build at runtime, without
 * eval(). Only the two escapes that can appear inside this pattern are unescaped:
 * stripcslashes() would also eat `\s` and `\(`, which are the regex's own.
 */
$pattern = strtr( substr( $m[1], 1, -1 ), array( '\\"' => '"', '\\\\' => '\\' ) );

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

$failed = 0;

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
