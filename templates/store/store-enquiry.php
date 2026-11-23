<?php
/**
 * Store enquiry: the WhatsApp button and the enquiry form of a catalog store.
 * Copied by /wp-woo-setup when the store block's enquiry lists `whatsapp` or `form`.
 * PHP 7.4 floor.
 *
 * A catalog sells nothing online, so a product page needs another way to ask. The number, the
 * message and the form live in the theme's settings page, where the client edits them; nothing
 * here invents one. Until a field is filled, that channel renders nothing, so installing this
 * file changes nothing a visitor sees. It renders only while store-kit's catalog mode is on: a
 * store that moves up a tier gets its add-to-cart button back and these disappear on their own.
 */

defined( 'ABSPATH' ) || exit;

/**
 * A setting from the theme's options page, through the i18n helper when the theme has one.
 * Without ACF/SCF active there is no setting at all: the theme's helper calls get_field()
 * unguarded, so it is not reached either.
 */
function __prefix___store_enquiry_setting( $name ) {
	if ( ! function_exists( 'get_field' ) ) {
		return '';
	}
	if ( function_exists( '__prefix___get_field' ) ) {
		return __prefix___get_field( $name, 'option' );
	}
	return get_field( $name, 'option' );
}

/**
 * Digits only, 8 to 15 of them (E.164 without the plus), or '' when it is not one number.
 * Only a plus, digits, spaces, dots, dashes and brackets are accepted: "ext 22" or a second
 * number after a slash would otherwise be glued onto the first and link to a stranger.
 */
function __prefix___store_whatsapp_number() {
	$raw = trim( (string) __prefix___store_enquiry_setting( 'store_whatsapp_number' ) );
	if ( ! preg_match( '/^\+?[\d\s().-]+$/', $raw ) ) {
		return '';
	}
	$digits = preg_replace( '/\D+/', '', $raw );
	$len    = strlen( $digits );
	return ( $len >= 8 && $len <= 15 ) ? $digits : '';
}

// The fields, on the theme's own settings page. Registered in code: they are this file's
// contract with the render below, not a dashboard-editable group.
add_action( 'acf/init', function () {
	if ( ! function_exists( 'acf_add_local_field_group' ) ) {
		return;
	}
	acf_add_local_field_group( array(
		'key'      => 'group_store_enquiry',
		'title'    => __( 'Store enquiries', '__textdomain__' ),
		'fields'   => array(
			array(
				'key'          => 'field_store_whatsapp_number',
				'label'        => __( 'WhatsApp number', '__textdomain__' ),
				'name'         => 'store_whatsapp_number',
				'type'         => 'text',
				'instructions' => __( 'With the country code, for example +1 813 555 0100. Empty hides the button.', '__textdomain__' ),
			),
			array(
				'key'           => 'field_store_whatsapp_message',
				'label'         => __( 'WhatsApp message', '__textdomain__' ),
				'name'          => 'store_whatsapp_message',
				'type'          => 'text',
				'instructions'  => __( '{product} is replaced by the product name and link.', '__textdomain__' ),
				'default_value' => __( 'Hello, I would like to know more about {product}', '__textdomain__' ),
			),
			array(
				'key'          => 'field_store_enquiry_form',
				'label'        => __( 'Enquiry form', '__textdomain__' ),
				'name'         => 'store_enquiry_form',
				'type'         => 'number',
				'instructions' => __( 'The Contact Form 7 form ID shown on product pages. Empty hides the form.', '__textdomain__' ),
			),
		),
		'location' => array(
			array(
				array(
					'param'    => 'options_page',
					'operator' => '==',
					'value'    => '__textdomain__-settings', // the starter's menu_slug is <theme slug>-settings
				),
			),
		),
	) );
} );

/** The enquiry block for one product, or '' when no channel is filled in or the store sells. */
function __prefix___store_enquiry_html( $product ) {
	if ( ! function_exists( 'store_kit_catalog_mode' ) || ! store_kit_catalog_mode() || ! $product instanceof WC_Product ) {
		return '';
	}
	$parts  = array();
	$number = __prefix___store_whatsapp_number();
	if ( '' !== $number ) {
		$message = (string) __prefix___store_enquiry_setting( 'store_whatsapp_message' );
		if ( '' === trim( $message ) ) {
			$message = __( 'Hello, I would like to know more about {product}', '__textdomain__' );
		}
		$about   = $product->get_name() . ' ' . get_permalink( $product->get_id() );
		$message = false !== strpos( $message, '{product}' ) ? str_replace( '{product}', $about, $message ) : $message . ' ' . $about;
		$parts[] = sprintf(
			'<a class="store-enquiry__whatsapp" href="%s" target="_blank" rel="noopener">%s</a>',
			esc_url( 'https://wa.me/' . $number . '?text=' . rawurlencode( $message ) ),
			esc_html__( 'Ask on WhatsApp', '__textdomain__' )
		);
	}
	$form = absint( __prefix___store_enquiry_setting( 'store_enquiry_form' ) );
	if ( $form && shortcode_exists( 'contact-form-7' ) && 'wpcf7_contact_form' === get_post_type( $form ) ) {
		$parts[] = '<div class="store-enquiry__form">' . do_shortcode( '[contact-form-7 id="' . $form . '"]' ) . '</div>';
	}
	if ( ! $parts ) {
		return '';
	}
	return '<div class="store-enquiry">' . implode( '', $parts ) . '</div>';
}

// After the price and the summary, where add-to-cart would be (priority 30).
add_action( 'woocommerce_single_product_summary', function () {
	global $product;
	echo __prefix___store_enquiry_html( $product ); // phpcs:ignore WordPress.Security.EscapeOutput -- built from escaped parts
}, 31 );
