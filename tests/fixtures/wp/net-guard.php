<?php
/**
 * Fixture network guard: once provisioning is done, no request leaves the machine.
 *
 * Installed by tests/fixtures/wp/provision.sh after every download, as a must-use plugin so
 * nothing a check does can switch it off. A check must never pass or fail because a real
 * service answered, or did not. Loopback is allowed -- the checks talk to `wp server` -- and
 * every other host is refused and logged to wp-content/net-guard.log.
 */
add_filter(
	'pre_http_request',
	function ( $pre, $args, $url ) {
		$host = (string) wp_parse_url( $url, PHP_URL_HOST );
		if ( in_array( $host, array( '127.0.0.1', 'localhost', '::1', '[::1]' ), true ) ) {
			return $pre;
		}
		// Cloudflare Turnstile's siteverify, answered here the way Cloudflare answers its
		// documented test secrets: 1x… passes, 2x… fails. A check can then prove the checkout
		// is gated without depending on Cloudflare.
		if ( 'challenges.cloudflare.com' === $host && false !== strpos( $url, '/turnstile/v0/siteverify' ) ) {
			$body = isset( $args['body'] ) ? $args['body'] : array();
			if ( is_string( $body ) ) {
				parse_str( $body, $body );
			}
			$pass = 0 === strpos( isset( $body['secret'] ) ? (string) $body['secret'] : '', '1x' );
			return array(
				'headers'  => array(),
				'body'     => wp_json_encode( $pass ? array( 'success' => true ) : array( 'success' => false, 'error-codes' => array( 'invalid-input-response' ) ) ),
				'response' => array( 'code' => 200, 'message' => 'OK' ),
				'cookies'  => array(),
				'filename' => null,
			);
		}
		file_put_contents( WP_CONTENT_DIR . '/net-guard.log', gmdate( 'c' ) . ' ' . $host . "\n", FILE_APPEND );
		return new WP_Error( 'fixture_offline', 'The test fixture refuses outbound HTTP: ' . $host );
	},
	10,
	3
);
