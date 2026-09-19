<?php
/**
 * Create a CF7 form and a page carrying it, and install a mail sink.
 *
 * Prints two lines the calling check parses:
 *   FORM_ID=<id>
 *   PAGE_URL=<url>
 *
 * The sink is a must-use plugin hooked on `pre_wp_mail`, the same seam /wp-clone Step 5.5
 * captures mail at, and for the same reason: it short-circuits core's own send, so nothing
 * escapes even if a plugin reactivates or an option is rewritten. An SMTP plugin would not
 * do -- core falls back to PHP mail() and the site keeps sending while merely logging it
 * somewhere nobody looks.
 */

$sink_dir = WP_CONTENT_DIR . '/mu-plugins';
if ( ! is_dir( $sink_dir ) ) {
	mkdir( $sink_dir, 0755, true );
}

$sink = <<<'PHP'
<?php
/**
 * Fixture mail sink. Captures every outbound mail to wp-content/mail-sink.log as one JSON
 * object per line, and returns true from pre_wp_mail so core never attempts a send.
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
PHP;

file_put_contents( $sink_dir . '/00-mail-sink.php', $sink );
@unlink( WP_CONTENT_DIR . '/mail-sink.log' );

if ( ! class_exists( 'WPCF7_ContactForm' ) ) {
	echo "FAIL [setup] Contact Form 7 is not loaded\n";
	exit( 1 );
}

// A form in the shape agents/wp-cf7.md contracts: required name, required email, message.
$form = WPCF7_ContactForm::get_template( array( 'title' => 'Fixture contact' ) );
$form->set_properties( array(
	'form' => "[text* your-name]\n[email* your-email]\n[textarea your-message]\n[submit \"Send\"]",
	'mail' => array(
		'subject'            => 'Fixture: [your-name]',
		'sender'             => 'Fixture <fixture@example.invalid>',
		'recipient'          => 'owner@example.invalid',
		'body'               => "From: [your-name] <[your-email]>\n\n[your-message]",
		'additional_headers' => 'Reply-To: [your-email]',
		'attachments'        => '',
		'use_html'           => 0,
		'exclude_blank'      => 0,
	),
) );
$id = $form->save();
if ( ! $id ) {
	echo "FAIL [setup] could not save the contact form\n";
	exit( 1 );
}

$page = wp_insert_post( array(
	'post_title'   => 'Contact',
	'post_name'    => 'contact',
	'post_status'  => 'publish',
	'post_type'    => 'page',
	'post_content' => '[contact-form-7 id="' . $id . '" title="Fixture contact"]',
) );
if ( ! $page ) {
	echo "FAIL [setup] could not create the contact page\n";
	exit( 1 );
}

echo 'FORM_ID=' . $id . "\n";
echo 'PAGE_URL=' . get_permalink( $page ) . "\n";
