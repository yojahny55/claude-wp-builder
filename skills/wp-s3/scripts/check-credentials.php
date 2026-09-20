<?php
/**
 * Proves that the credentials in s3-config.php can reach the bucket, WITHOUT activating
 * the plugin.
 *
 * `wp s3-uploads verify` cannot do this at setup time: the WP-CLI command only exists
 * once the plugin is active, and setup deliberately leaves it deactivated. This script
 * uses the same AWS SDK the plugin bundles, so a pass here means the plugin will connect
 * with the same values.
 *
 * Usage:
 *   php check-credentials.php <wp-root>
 *
 * Reads the values out of <wp-root>/s3-config.php through read-s3-config.php, so there is
 * one parser and the secret never reaches the command line. Exits 0 on success, 1 when
 * the bucket cannot be listed, 2 when the configuration itself cannot be read.
 */

$wp_root = isset( $argv[1] ) ? rtrim( $argv[1], '/' ) : '';

if ( '' === $wp_root ) {
	fwrite( STDERR, "Usage: php check-credentials.php <wp-root>\n" );
	exit( 2 );
}

$config    = $wp_root . '/s3-config.php';
$autoload  = $wp_root . '/wp-content/plugins/S3-Uploads/vendor/autoload.php';

if ( ! is_readable( $config ) ) {
	fwrite( STDERR, "Cannot read $config\n" );
	exit( 2 );
}

if ( ! is_readable( $autoload ) ) {
	fwrite( STDERR, "No AWS SDK at $autoload: the plugin's vendor/ tree is missing.\n" );
	exit( 2 );
}

// The reader prints `NAME='value'` lines quoted for /bin/sh. Parsing them here keeps a
// single copy of the regular expressions that read the constants.
if ( ! function_exists( 'exec' ) ) {
	// Hardened CLI builds disable it. Nothing here can read the constants without running
	// the reader, so say which function is missing instead of failing on an empty result.
	fwrite( STDERR, "exec() is disabled in this PHP; cannot read $config.\n" );
	exit( 2 );
}

$reader = __DIR__ . '/read-s3-config.php';
$cmd    = escapeshellcmd( PHP_BINARY ) . ' ' . escapeshellarg( $reader ) . ' ' . escapeshellarg( $config ) . ' --export';

$output = array();
$status = 0;
exec( $cmd . ' 2>/dev/null', $output, $status );

if ( 0 !== $status ) {
	fwrite( STDERR, "Could not read the constants out of $config\n" );
	exit( 2 );
}

$values = array();
foreach ( $output as $line ) {
	if ( ! preg_match( "/^([A-Z0-9_]+)='(.*)'$/s", $line, $m ) ) {
		continue;
	}
	// escapeshellarg() escapes a single quote as '\'' ; undo exactly that.
	$values[ $m[1] ] = str_replace( "'\\''", "'", $m[2] );
}

if ( empty( $values['S3_UPLOADS_BUCKET'] ) || empty( $values['S3_UPLOADS_REGION'] ) ) {
	fwrite( STDERR, "S3_UPLOADS_BUCKET and S3_UPLOADS_REGION must both be set in $config\n" );
	exit( 2 );
}

require_once $autoload;

if ( ! class_exists( 'Aws\S3\S3Client' ) ) {
	fwrite( STDERR, "The AWS SDK did not load from $autoload\n" );
	exit( 2 );
}

// S3_UPLOADS_BUCKET may carry a path prefix ("bucket/site"); only the first segment is
// the bucket, and the rest is the prefix every key starts with.
$parts  = explode( '/', $values['S3_UPLOADS_BUCKET'], 2 );
$bucket = $parts[0];
$prefix = isset( $parts[1] ) ? rtrim( $parts[1], '/' ) . '/' : '';

$params = array(
	'version' => 'latest',
	'region'  => $values['S3_UPLOADS_REGION'],
);

if ( ! empty( $values['S3_UPLOADS_ENDPOINT'] ) ) {
	$params['endpoint']                = $values['S3_UPLOADS_ENDPOINT'];
	$params['use_path_style_endpoint'] = true;
}

if ( ! empty( $values['S3_UPLOADS_KEY'] ) && ! empty( $values['S3_UPLOADS_SECRET'] ) ) {
	$params['credentials'] = array(
		'key'    => $values['S3_UPLOADS_KEY'],
		'secret' => $values['S3_UPLOADS_SECRET'],
	);
}
// Without a key pair the SDK falls back to its own provider chain, which is what an
// instance profile is.

try {
	$client = new Aws\S3\S3Client( $params );
	// ListObjects rather than HeadBucket: the policy a site needs grants ListBucket on
	// its own prefix and often nothing at the bucket root, so HeadBucket can fail on
	// credentials that work perfectly for the plugin.
	$client->listObjectsV2(
		array(
			'Bucket'  => $bucket,
			'Prefix'  => $prefix,
			'MaxKeys' => 1,
		)
	);
} catch ( Exception $e ) {
	$message = method_exists( $e, 'getAwsErrorCode' ) && $e->getAwsErrorCode()
		? $e->getAwsErrorCode()
		: $e->getMessage();
	fwrite( STDERR, "Could not list $bucket/$prefix: $message\n" );
	exit( 1 );
}

echo "Credentials work: listed $bucket/$prefix\n";
exit( 0 );
