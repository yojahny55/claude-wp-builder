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
		file_put_contents( WP_CONTENT_DIR . '/net-guard.log', gmdate( 'c' ) . ' ' . $host . "\n", FILE_APPEND );
		return new WP_Error( 'fixture_offline', 'The test fixture refuses outbound HTTP: ' . $host );
	},
	10,
	3
);
