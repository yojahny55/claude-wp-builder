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
 * Extract a named top-level function's full source (the `function` keyword
 * through its matching closing brace) with PHP's own tokenizer, not a regex or
 * a character-level brace count: a brace inside a string, a comment or a
 * heredoc is part of that token, never a `{` / `}` token, so it cannot move
 * the end of the slice. Only a `function <name>` at brace depth 0 matches, so
 * a docblock naming the function or a same-named method is never picked up.
 */
function mmfx_extract_function( $source, $name ) {
	$tokens = token_get_all( $source );
	$n      = count( $tokens );
	$depth  = 0;
	$start  = null;
	$out    = '';

	for ( $i = 0; $i < $n; $i++ ) {
		$tok  = $tokens[ $i ];
		$id   = is_array( $tok ) ? $tok[0] : $tok;
		$text = is_array( $tok ) ? $tok[1] : $tok;

		if ( null === $start && 0 === $depth && T_FUNCTION === $id ) {
			$k = $i + 1;
			while ( $k < $n && is_array( $tokens[ $k ] ) && T_WHITESPACE === $tokens[ $k ][0] ) {
				$k++;
			}
			if ( $k < $n && is_array( $tokens[ $k ] ) && T_STRING === $tokens[ $k ][0] && $tokens[ $k ][1] === $name ) {
				$start = $i;
			}
		}
		if ( null !== $start ) {
			$out .= $text;
		}

		if ( '{' === $id || T_CURLY_OPEN === $id || T_DOLLAR_OPEN_CURLY_BRACES === $id ) {
			++$depth;
		} elseif ( '}' === $id ) {
			--$depth;
			if ( null !== $start && 0 === $depth ) {
				return $out;
			}
		}
	}

	return null;
}

/**
 * Fail loudly at extraction time, not later in the assertions: the slice must
 * start with this function's own signature, end on its closing brace and
 * parse as PHP on its own. Returns an error message, or null when it is sound.
 */
function mmfx_check_extracted( $code, $name ) {
	if ( ! preg_match( '/^function\s+' . preg_quote( $name, '/' ) . '\s*\(/', $code ) ) {
		return "{$name}(): extracted slice does not start with its own signature";
	}
	if ( '}' !== substr( rtrim( $code ), -1 ) ) {
		return "{$name}(): extracted slice does not end on a closing brace";
	}
	try {
		token_get_all( "<?php\n" . $code, TOKEN_PARSE );
	} catch ( ParseError $e ) {
		return "{$name}(): extracted slice does not parse — " . $e->getMessage();
	}
	return null;
}

$failed = 0;

/*
 * The script's frame is UTC: WordPress sets it at bootstrap, and this test does
 * not load WordPress. Without it the epoch and zeroed post_date cases flip to
 * BEFORE-ARCHIVE on a host whose default timezone is west of UTC, where
 * strtotime( '1970-01-01 00:00:00' ) is positive. The Y-m-d cases round-trip
 * through strtotime() and date() in one frame, so they do not depend on it.
 */
date_default_timezone_set( 'UTC' );

/*
 * The extractor is tested before it is trusted, same as this repo's other
 * behavioral checks — a brace-counting bug here would silently validate
 * nothing.
 */
$extractor_fixture = "function foo( \$x ) {\n\tif ( \$x ) {\n\t\treturn '} {';\n\t}\n\t// a stray } in a comment\n\treturn \"{\$x}\";\n}\n";
$extracted          = mmfx_extract_function( "<?php\n/* function foo() { */\n" . $extractor_fixture . "\nfunction bar() {}\n", 'foo' );
if ( trim( (string) $extracted ) !== trim( $extractor_fixture ) ) {
	fwrite( STDERR, "extractor mishandled a nested brace, or one inside a string or comment:\n" . var_export( $extracted, true ) . "\n" );
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

/*
 * Passing cases prove nothing if the script stopped calling these functions and
 * inlined its own comparison. With both definitions cut out, each name must still
 * be called as code — a T_STRING followed by `(` — not only named in a comment.
 */
$rest   = str_replace( array( $cutoff_fn, $bucket_fn ), '', $source );
$called = array();
$rt     = token_get_all( $rest );
foreach ( $rt as $k => $tok ) {
	if ( ! is_array( $tok ) || T_STRING !== $tok[0] ) {
		continue;
	}
	for ( $m = $k + 1; isset( $rt[ $m ] ) && is_array( $rt[ $m ] ) && T_WHITESPACE === $rt[ $m ][0]; $m++ ) {
	}
	if ( isset( $rt[ $m ] ) && '(' === $rt[ $m ] ) {
		$called[ $tok[1] ] = true;
	}
}
foreach ( array( 'mmf_compute_archive_cutoff', 'mmf_bucket_for' ) as $name ) {
	if ( empty( $called[ $name ] ) ) {
		fwrite( STDERR, "find-missing-media-files.php never calls {$name}() — the tested logic is dead code\n" );
		exit( 1 );
	}
}

foreach ( array( 'mmf_compute_archive_cutoff' => $cutoff_fn, 'mmf_bucket_for' => $bucket_fn ) as $name => $code ) {
	$problem = mmfx_check_extracted( $code, $name );
	if ( null !== $problem ) {
		fwrite( STDERR, $problem . "\n" );
		exit( 1 );
	}
}

// The real script's own two functions, loaded from a temporary file rather than eval().
$tmp = tempnam( sys_get_temp_dir(), 'mmfx_' );
if ( false !== $tmp ) {
	// Registered before anything can fail, so every exit path — a failed write, a
	// fatal in the required file, a later exit( 1 ) — removes the temporary file.
	register_shutdown_function(
		function () use ( $tmp ) {
			if ( file_exists( $tmp ) ) {
				unlink( $tmp );
			}
		}
	);
}
if ( false === $tmp || false === file_put_contents( $tmp, "<?php\n" . $cutoff_fn . "\n\n" . $bucket_fn . "\n" ) ) {
	fwrite( STDERR, "cannot write the extracted functions to a temporary file\n" );
	exit( 1 );
}
require $tmp;
unlink( $tmp );

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
	'ISO 8601 T separator keeps its time'  => array( '2026-09-23T14:30:00', '2026-09-23 14:30:00' ),
	'time without seconds'                 => array( '2026-09-23 14:30', '2026-09-23 14:30:00' ),
	'written-out date is rejected'         => array( '23 September 2026', false ),
	'relative date is rejected'            => array( 'yesterday', false ),
	'impossible calendar date is rejected' => array( '2026-02-30', false ),
	'out-of-range hour is rejected'        => array( '2026-09-23 24:00:00', false ),
	'out-of-range minute is rejected'      => array( '2026-09-23 14:75:00', false ),
	'out-of-range second is rejected'      => array( '2026-09-23 14:30:75', false ),
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
	'zeroed post_date is not BEFORE-ARCHIVE'    => array( '2026-09-23', '0000-00-00 00:00:00', 'UNDATED' ),
	'epoch post_date is not BEFORE-ARCHIVE'     => array( '2026-09-23', '1970-01-01 00:00:00', 'UNDATED' ),
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

if ( $failed > 0 ) {
	exit( 1 );
}
// The shell check requires this line, so a run that asserted nothing cannot pass.
printf( "OK %d cases\n", count( $cutoff_cases ) + count( $bucket_cases ) );
exit( 0 );
