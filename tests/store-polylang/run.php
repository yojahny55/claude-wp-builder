<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
/**
 * Full suite, without WordPress: php tests/run.php
 * Prints "store-polylang tests OK (<n> files)" and exits 0 only if everything passes.
 */

$failed = 0;
$files  = glob( __DIR__ . '/*-test.php' );
foreach ( $files as $file ) {
	passthru( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __DIR__ . '/run-one.php' ) . ' ' . escapeshellarg( $file ), $code );
	$failed += $code ? 1 : 0;
}

// The plugin declares PHP 7.4: no 8.x syntax. php -l here is 8.x and does not catch it.
$forbidden = array(
	'nullsafe operator ?->'      => '/\?->/',
	'match ()'                   => '/\bmatch\s*\(/',
	'str_contains/starts/ends'   => '/\bstr_(contains|starts_with|ends_with)\s*\(/',
	'8.x return type'        => '/\)\s*:\s*\??(mixed|never|static)\b/',
	'union type in parameter'    => '/[(,]\s*\??[A-Za-z_\\\\]+\|[A-Za-z_\\\\|]+\s+&?\$/',
	'attribute #[...]'            => '/^\s*#\[/m',
	'enum / readonly'            => '/^\s*(enum|readonly)\s+\w/m',
);
$root  = dirname( __DIR__, 2 ) . '/plugins/store-polylang';
$it    = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $root . '/includes', FilesystemIterator::SKIP_DOTS ) );
$paths = array( $root . '/store-polylang.php' );
foreach ( $it as $f ) {
	if ( 'php' === $f->getExtension() ) {
		$paths[] = $f->getPathname();
	}
}
foreach ( $paths as $path ) {
	$src = file_get_contents( $path );
	foreach ( $forbidden as $label => $pattern ) {
		if ( preg_match( $pattern, $src ) ) {
			fwrite( STDERR, 'FAIL php74: ' . $label . ' in ' . substr( $path, strlen( $root ) + 1 ) . "\n" );
			$failed++;
		}
	}
	exec( escapeshellarg( PHP_BINARY ) . ' -l ' . escapeshellarg( $path ) . ' 2>&1', $out, $code );
	if ( $code ) {
		fwrite( STDERR, 'FAIL lint: ' . $path . "\n" );
		$failed++;
	}
}

if ( $failed ) {
	fwrite( STDERR, "store-polylang tests FAILED ({$failed})\n" );
	exit( 1 );
}
echo 'store-polylang tests OK (' . count( $files ) . " files)\n";
