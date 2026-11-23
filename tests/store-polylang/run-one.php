<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
/**
 * Runs a single test file. Usage: php tests/run-one.php tests/<name>-test.php
 */

require __DIR__ . '/bootstrap.php';
require $argv[1];

$name = basename( $argv[1] );
if ( $GLOBALS['wpll']['failures'] ) {
	foreach ( $GLOBALS['wpll']['failures'] as $failure ) {
		fwrite( STDERR, "FAIL {$name}: {$failure}\n" );
	}
	exit( 1 );
}
echo "ok {$name} ({$GLOBALS['wpll']['checks']})\n";
