<?php
/**
 * Behavioral test for find-missing-media-files.php's archive-date cutoff and
 * bucket decision.
 *
 * The rest of the suite greps for contract wording. This one extracts the
 * actual mmf_compute_archive_cutoff() and mmf_bucket_for() function bodies
 * from the real script and runs them, because the bug this test exists to
 * pin was invisible to any grep: a bare "Y-m-d" archive date parses to
 * midnight, so an attachment uploaded later the SAME calendar day compared
 * as "after archive" no matter what time the archive was actually taken,
 * silently suppressing a real pre-archive loss as N/A (local clone). Every
 * word a grep could match ("BEFORE-ARCHIVE", "AFTER-ARCHIVE", the archive
 * argument itself) was present and correct; only the runtime comparison for
 * a same-day timestamp was wrong.
 *
 * WordPress is not loaded; nothing here runs the script's WP-CLI body, only
 * the two pure-PHP functions it delegates the cutoff/bucket decision to.
 */

/**
 * Extract a named top-level function's full source (the `function ...` line
 * through its matching closing brace) by counting braces, not by a fixed
 * line count — the function's own body has a nested `if`, so a regex that
 * stops at the first standalone "}" would truncate it.
 */
function mmfx_extract_function( $source, $name ) {
	// Anchored at a line-start `function` token, so a docblock or comment that
	// names the function in prose cannot be sliced out instead of its definition.
	if ( ! preg_match( '/^function ' . preg_quote( $name, '/' ) . '\b/m', $source, $m, PREG_OFFSET_CAPTURE ) ) {
		return null;
	}
	$start = $m[0][1];

	$brace_start = strpos( $source, '{', $start );
	if ( false === $brace_start ) {
		return null;
	}

	$depth = 0;
	$len   = strlen( $source );

	for ( $i = $brace_start; $i < $len; $i++ ) {
		if ( '{' === $source[ $i ] ) {
			++$depth;
		} elseif ( '}' === $source[ $i ] ) {
			--$depth;
			if ( 0 === $depth ) {
				return substr( $source, $start, $i - $start + 1 );
			}
		}
	}

	return null;
}

$failed = 0;

/*
 * The extractor is tested before it is trusted, same as this repo's other
 * behavioral checks — a brace-counting bug here would silently validate
 * nothing.
 */
$extractor_fixture = "function foo( \$x ) {\n\tif ( \$x ) {\n\t\treturn 1;\n\t}\n\treturn 0;\n}\n";
$extracted          = mmfx_extract_function( "// noise\n" . $extractor_fixture . "\n// trailing noise", 'foo' );
if ( trim( (string) $extracted ) !== trim( $extractor_fixture ) ) {
	fwrite( STDERR, "extractor mishandled a nested brace:\n" . var_export( $extracted, true ) . "\n" );
	$failed++;
}

$script = dirname( __DIR__, 3 ) . '/skills/wp-cli-patterns/scripts/find-missing-media-files.php';

if ( ! is_readable( $script ) ) {
	fwrite( STDERR, "cannot read {$script}\n" );
	exit( 1 );
}

$source = (string) file_get_contents( $script );

$cutoff_fn = mmfx_extract_function( $source, 'mmf_compute_archive_cutoff' );
$bucket_fn = mmfx_extract_function( $source, 'mmf_bucket_for' );

if ( null === $cutoff_fn ) {
	fwrite( STDERR, "mmf_compute_archive_cutoff() not found in find-missing-media-files.php\n" );
	exit( 1 );
}
if ( null === $bucket_fn ) {
	fwrite( STDERR, "mmf_bucket_for() not found in find-missing-media-files.php\n" );
	exit( 1 );
}

// phpcs:ignore -- eval() runs the real script's own two functions, not a reimplementation.
eval( $cutoff_fn . "\n" . $bucket_fn );

if ( ! function_exists( 'mmf_compute_archive_cutoff' ) || ! function_exists( 'mmf_bucket_for' ) ) {
	fwrite( STDERR, "extracted function bodies did not define the expected functions\n" );
	exit( 1 );
}

/*
 * Cutoff cases: label => [archive_arg, expected effective cutoff as Y-m-d H:i:s].
 */
$cutoff_cases = array(
	'no date given'                       => array( '', false ),
	'bare ISO date'                        => array( '2026-09-23', '2026-09-23 23:59:59' ),
	'full timestamp, non-midnight'         => array( '2026-09-23 14:30:00', '2026-09-23 14:30:00' ),
	'explicit midnight is a real time'     => array( '2026-09-23 00:00:00', '2026-09-23 00:00:00' ),
	'written-out date, no time'            => array( '23 September 2026', '2026-09-23 23:59:59' ),
	'unparseable date'                     => array( 'not-a-date', false ),
);

foreach ( $cutoff_cases as $label => $case ) {
	list( $arg, $expected ) = $case;
	$got = mmf_compute_archive_cutoff( $arg );

	if ( false === $expected ) {
		if ( false !== $got ) {
			fwrite( STDERR, "mmf_compute_archive_cutoff('{$arg}') [{$label}]: expected false, got " . var_export( $got, true ) . "\n" );
			$failed++;
		}
		continue;
	}

	$got_str = ( false === $got ) ? 'false' : date( 'Y-m-d H:i:s', $got );
	if ( $got_str !== $expected ) {
		fwrite( STDERR, "mmf_compute_archive_cutoff('{$arg}') [{$label}]: expected {$expected}, got {$got_str}\n" );
		$failed++;
	}
}

/*
 * The case that actually matters: a same-day upload against a bare-date
 * archive argument must NOT land in AFTER-ARCHIVE (the suppressed bucket).
 * This is the exact defect the round found — every bucket name a grep could
 * check for was already present and spelled correctly.
 */
$bucket_cases = array(
	'same-day upload, morning, bare date arg'   => array( '2026-09-23', '2026-09-23 08:00:00', 'BEFORE-ARCHIVE' ),
	'same-day upload, last second, bare date arg' => array( '2026-09-23', '2026-09-23 23:59:59', 'BEFORE-ARCHIVE' ),
	'next-day upload, bare date arg'            => array( '2026-09-23', '2026-09-24 00:00:01', 'AFTER-ARCHIVE' ),
	'prior-day upload, bare date arg'           => array( '2026-09-23', '2026-09-22 23:59:59', 'BEFORE-ARCHIVE' ),
	'upload before an exact timestamp cutoff'   => array( '2026-09-23 14:30:00', '2026-09-23 08:00:00', 'BEFORE-ARCHIVE' ),
	'upload after an exact timestamp cutoff'    => array( '2026-09-23 14:30:00', '2026-09-23 18:00:00', 'AFTER-ARCHIVE' ),
	'empty post_date is not BEFORE-ARCHIVE'     => array( '2026-09-23', '', 'UNDATED' ),
	'unparseable post_date is not BEFORE-ARCHIVE' => array( '2026-09-23', 'not a date', 'UNDATED' ),
);

foreach ( $bucket_cases as $label => $case ) {
	list( $arg, $post_date, $expected ) = $case;
	$archive_ts = mmf_compute_archive_cutoff( $arg );

	if ( false === $archive_ts ) {
		fwrite( STDERR, "[{$label}] archive_arg '{$arg}' did not produce a cutoff\n" );
		$failed++;
		continue;
	}

	$got = mmf_bucket_for( $post_date, $archive_ts );
	if ( $got !== $expected ) {
		fwrite(
			STDERR,
			"[{$label}] archive_arg='{$arg}' post_date='{$post_date}' cutoff=" . date( 'Y-m-d H:i:s', $archive_ts )
				. " expected {$expected}, got {$got}\n"
		);
		$failed++;
	}
}

exit( $failed > 0 ? 1 : 0 );
