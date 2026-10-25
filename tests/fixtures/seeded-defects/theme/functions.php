<?php
/**
 * Fixture functions.
 *
 * @package seeded
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// SEEDED SEC-005: credential committed in code (placeholder value).
$seeded_api_key = 'FIXTURE-PLACEHOLDER-NOT-A-REAL-KEY';

// SEEDED SEC-004: eval of a decoded string.
function seeded_run_snippet() {
	eval( base64_decode( 'cmV0dXJuIDE7' ) );
}
add_action( 'init', 'seeded_run_snippet' );
