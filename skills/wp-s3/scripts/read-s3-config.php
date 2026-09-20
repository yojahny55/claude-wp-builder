<?php
/**
 * Reads the S3 Uploads constants out of a site's s3-config.php WITHOUT including it.
 *
 * Including the file would define the constants in this process and, worse, run whatever
 * else the site put in there. The values are extracted with a regular expression instead,
 * exactly as bin/db-cnf.php reads wp-config.php.
 *
 * Usage:
 *   php read-s3-config.php <path-to-s3-config.php> --names     # names only, safe to print
 *   php read-s3-config.php <path-to-s3-config.php> --export    # shell exports, CONTAINS THE SECRET
 *
 * --export is meant to be consumed by `eval "$(...)"` so the secret stays in the process
 * environment. Never redirect it to a file, a log or a terminal.
 */

$wanted = array(
	'S3_UPLOADS_BUCKET',
	'S3_UPLOADS_REGION',
	'S3_UPLOADS_BUCKET_URL',
	'S3_UPLOADS_ENDPOINT',
	'S3_UPLOADS_KEY',
	'S3_UPLOADS_SECRET',
	'S3_UPLOADS_USE_INSTANCE_PROFILE',
);

$path = isset( $argv[1] ) ? $argv[1] : '';
$mode = isset( $argv[2] ) ? $argv[2] : '';

if ( '' === $path || ! in_array( $mode, array( '--names', '--export' ), true ) ) {
	fwrite( STDERR, "Usage: php read-s3-config.php <s3-config.php> --names|--export\n" );
	exit( 1 );
}

if ( ! is_readable( $path ) ) {
	fwrite( STDERR, "Cannot read $path\n" );
	exit( 1 );
}

$source = file_get_contents( $path );
if ( false === $source ) {
	fwrite( STDERR, "Cannot read $path\n" );
	exit( 1 );
}

$found = array();

foreach ( $wanted as $name ) {
	// define( 'NAME', 'value' ) or define( 'NAME', true ). Single or double quotes.
	$pattern = "/define\(\s*['\"]" . preg_quote( $name, '/' ) . "['\"]\s*,\s*(.+?)\s*\)\s*;/s";
	if ( ! preg_match( $pattern, $source, $m ) ) {
		continue;
	}

	$raw = trim( $m[1] );

	if ( preg_match( "/^'(.*)'$/s", $raw, $q ) ) {
		$value = str_replace( array( "\\'", '\\\\' ), array( "'", '\\' ), $q[1] );
	} elseif ( preg_match( '/^"(.*)"$/s', $raw, $q ) ) {
		$value = stripcslashes( $q[1] );
	} elseif ( 'true' === strtolower( $raw ) ) {
		$value = '1';
	} elseif ( 'false' === strtolower( $raw ) ) {
		$value = '';
	} else {
		// An expression rather than a literal: report it instead of guessing.
		fwrite( STDERR, "$name is not a literal; cannot read it safely.\n" );
		exit( 2 );
	}

	$found[ $name ] = $value;
}

if ( ! isset( $found['S3_UPLOADS_BUCKET'] ) ) {
	fwrite( STDERR, "No S3_UPLOADS_BUCKET in $path: this site is not configured yet.\n" );
	exit( 1 );
}

if ( '--names' === $mode ) {
	foreach ( $found as $name => $value ) {
		$shown = in_array( $name, array( 'S3_UPLOADS_KEY', 'S3_UPLOADS_SECRET' ), true )
			? 'set, ' . strlen( $value ) . ' characters'
			: $value;
		echo "$name: $shown\n";
	}
	exit( 0 );
}

foreach ( $found as $name => $value ) {
	// escapeshellarg() quotes for /bin/sh, which is what eval will parse.
	echo $name . '=' . escapeshellarg( $value ) . "\n";
}
