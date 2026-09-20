<?php
/**
 * S3 Uploads configuration. Written by /wp-s3.
 *
 * Loaded from wp-config.php before wp-settings.php, which is why it uses __DIR__ and a
 * plain number of seconds: neither WP_CONTENT_DIR nor DAY_IN_SECONDS exists yet at that
 * point. If wp-content lives elsewhere, adjust WC_LOG_DIR by hand.
 *
 * This file can hold credentials. Keep it at 0640, owned by the web server group, and
 * out of the repository.
 */

// The plugin does not load its own Composer autoloader.
if ( file_exists( __DIR__ . '/wp-content/plugins/S3-Uploads/vendor/autoload.php' ) ) {
	require_once __DIR__ . '/wp-content/plugins/S3-Uploads/vendor/autoload.php';
}

define( 'S3_UPLOADS_BUCKET',     '{{BUCKET}}' );
define( 'S3_UPLOADS_REGION',     '{{REGION}}' );
define( 'S3_UPLOADS_BUCKET_URL', '{{BUCKET_URL}}' );
{{AUTH_BLOCK}}
{{ENDPOINT_BLOCK}}
// The bucket has ACLs disabled, which is the AWS default since 2023. The plugin sends an
// ACL on every upload and a public one fails there; this value is accepted either way.
define( 'S3_UPLOADS_OBJECT_ACL', 'bucket-owner-full-control' );

// Long cache: an edited image is written under a new name, so nothing is ever replaced
// in place. 30 days, in seconds.
define( 'S3_UPLOADS_HTTP_CACHE_CONTROL', 2592000 );

// Nothing is rewritten until `wp s3-uploads enable` runs. Activating the plugin alone
// must not move a single file.
define( 'S3_UPLOADS_AUTOENABLE', false );

// These plugins write logs and temporary files into uploads. They stay on local disk:
// logs do not belong in object storage, and a temporary file that round-trips to S3 is
// slower and, for a form attachment, needlessly public.
define( 'WC_LOG_DIR',            __DIR__ . '/wp-content/wc-logs-local/' );
define( 'WPCF7_UPLOADS_TMP_DIR', 'wpcf7-uploads-local' );
