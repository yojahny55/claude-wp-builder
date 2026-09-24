<?php
/**
 * Fixture mail sink. Captures every outbound mail to wp-content/mail-sink.log as one JSON
 * object per line, and returns true from pre_wp_mail so core never attempts a send.
 *
 * Copied into wp-content/mu-plugins by the checks that assert on mail
 * (tests/fixtures/wp/cf7-setup.php, tests/checks/wp-woo-setup-integration.sh).
 */
add_filter( 'pre_wp_mail', function ( $null, $atts ) {
	$line = json_encode( array(
		'to'      => isset( $atts['to'] ) ? $atts['to'] : '',
		'subject' => isset( $atts['subject'] ) ? $atts['subject'] : '',
		'message' => isset( $atts['message'] ) ? $atts['message'] : '',
		'at'      => gmdate( 'c' ),
	) );
	file_put_contents( WP_CONTENT_DIR . '/mail-sink.log', $line . "\n", FILE_APPEND );
	// true means "handled" -- core returns success and sends nothing itself.
	return true;
}, 10, 2 );
