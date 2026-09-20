<?php
/**
 * Plugin Name: S3 Uploads custom endpoint
 * Description: Points S3 Uploads at an S3-compatible server when S3_UPLOADS_ENDPOINT is defined. No effect on AWS, where the constant is left undefined.
 * Version: 1.0.0
 */

defined( 'ABSPATH' ) || exit;

add_filter(
	's3_uploads_s3_client_params',
	function ( $params ) {
		if ( defined( 'S3_UPLOADS_ENDPOINT' ) && S3_UPLOADS_ENDPOINT ) {
			$params['endpoint'] = S3_UPLOADS_ENDPOINT;
			// S3-compatible servers are addressed as endpoint/bucket/key, not
			// bucket.endpoint/key, and a virtual-host style request 404s there.
			$params['use_path_style_endpoint'] = true;
		}

		return $params;
	}
);
