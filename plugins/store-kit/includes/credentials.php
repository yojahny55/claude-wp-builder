<?php
/**
 * Stripe keys from wp-config.php, never at rest in the database.
 *
 * The Stripe gateway reads woocommerce_stripe_settings through get_option() on every call and
 * saves it through update_option(). A key defined as a STORE_KIT_STRIPE_* constant is merged
 * into that option when it is read and stripped from it when it is saved, so the database --
 * and every dump, staging copy and /wp-clone of it -- never carries a working key. SEC-040
 * reads the raw row, so it reports what is actually stored.
 *
 * A field with no constant is left alone: a key typed into the settings screen is saved as
 * usual, and SEC-040 reports it.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_kit_stripe_fields() {
	return array(
		'test_secret_key'      => 'STORE_KIT_STRIPE_TEST_SECRET_KEY',
		'test_publishable_key' => 'STORE_KIT_STRIPE_TEST_PUBLISHABLE_KEY',
		'test_webhook_secret'  => 'STORE_KIT_STRIPE_TEST_WEBHOOK_SECRET',
		'secret_key'           => 'STORE_KIT_STRIPE_SECRET_KEY',
		'publishable_key'      => 'STORE_KIT_STRIPE_PUBLISHABLE_KEY',
		'webhook_secret'       => 'STORE_KIT_STRIPE_WEBHOOK_SECRET',
	);
}

/** The fields a constant currently supplies, field => value. An empty constant supplies none. */
function store_kit_stripe_supplied() {
	$out = array();
	foreach ( store_kit_stripe_fields() as $field => $constant ) {
		if ( defined( $constant ) && '' !== (string) constant( $constant ) ) {
			$out[ $field ] = (string) constant( $constant );
		}
	}
	return $out;
}

function store_kit_stripe_inject( $value ) {
	$supplied = store_kit_stripe_supplied();
	if ( ! $supplied ) {
		return $value;
	}
	return array_merge( is_array( $value ) ? $value : array(), $supplied );
}

function store_kit_stripe_strip( $value ) {
	if ( is_array( $value ) ) {
		foreach ( array_keys( store_kit_stripe_supplied() ) as $field ) {
			unset( $value[ $field ] );
		}
	}
	return $value;
}

add_filter( 'option_woocommerce_stripe_settings', 'store_kit_stripe_inject' );
add_filter( 'default_option_woocommerce_stripe_settings', 'store_kit_stripe_inject' );
// sanitize_option runs inside both add_option() and update_option(), before the write.
add_filter( 'sanitize_option_woocommerce_stripe_settings', 'store_kit_stripe_strip' );

function store_kit_stripe_notice() {
	// phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only screen check.
	if ( ! store_kit_stripe_supplied() || ! isset( $_GET['section'] ) || 'stripe' !== $_GET['section'] ) {
		return;
	}
	echo '<div class="notice notice-info"><p>' . esc_html__( 'Stripe keys for this site are set in wp-config.php by Store Kit. Keys typed here are not saved.', 'store-kit' ) . '</p></div>';
}
add_action( 'admin_notices', 'store_kit_stripe_notice' );
