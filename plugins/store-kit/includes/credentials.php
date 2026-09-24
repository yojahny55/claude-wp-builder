<?php
/**
 * Stripe keys from wp-config.php, kept out of the database by default.
 *
 * The Stripe gateway reads woocommerce_stripe_settings through get_option() on every call and
 * saves it through update_option(). A key defined as a STORE_KIT_STRIPE_* constant is merged
 * into that option when it is read and stripped from it when it is saved -- including the copy
 * Stripe's own configure_webhooks() nests inside test_webhook_data/webhook_data alongside the
 * flat field -- so a routine save never writes the constant's own value back into the row.
 * SEC-040 reads the raw row, so it reports what is actually stored.
 *
 * Three things are left in the database on purpose, and SEC-040 is what surfaces each one:
 * - a rotated webhook secret. Stripe periodically recreates its webhook endpoint and saves the
 *   new secret; a *_webhook_secret constant only ever seeds an empty row, it never overrides a
 *   value Stripe itself already wrote there, so a rotation reaches the database and an admin
 *   notice says so and names the now-stale constant.
 * - a key whose prefix does not match its field's mode (test vs live). store_kit_stripe_supplied()
 *   refuses to supply it at all -- neither injected nor stripped -- so a value typed into the
 *   settings screen for that field is saved and reported exactly as if no constant existed. This
 *   is what stops an `sk_live_...` value pasted into a *_TEST_* constant from ever being used.
 * - Stripe's OAuth (test_)refresh_token, which this file does not touch. A key saved before its
 *   constant existed also stays in the row until the next save reaches sanitize_option and
 *   strips it.
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

/** Fields where a constant only seeds an empty row and never overrides a value already stored. */
function store_kit_stripe_seed_only_fields() {
	return array( 'test_webhook_secret', 'webhook_secret' );
}

/** The webhook secret Stripe nests a second time inside its own settings sub-array, per mode. */
function store_kit_stripe_nested_webhook_fields() {
	return array(
		'test_webhook_data' => 'test_secret_key',
		'webhook_data'      => 'secret_key',
	);
}

/** Accepted key prefixes per field, so a key for the wrong mode is never used at all. */
function store_kit_stripe_prefixes() {
	return array(
		'test_secret_key'      => array( 'sk_test_', 'rk_test_' ),
		'test_publishable_key' => array( 'pk_test_' ),
		'test_webhook_secret'  => array( 'whsec_' ),
		'secret_key'           => array( 'sk_live_', 'rk_live_' ),
		'publishable_key'      => array( 'pk_live_' ),
		'webhook_secret'       => array( 'whsec_' ),
	);
}

function store_kit_stripe_prefix_ok( $field, $value ) {
	$prefixes = store_kit_stripe_prefixes();
	if ( ! isset( $prefixes[ $field ] ) ) {
		return true;
	}
	foreach ( $prefixes[ $field ] as $prefix ) {
		if ( 0 === strpos( $value, $prefix ) ) {
			return true;
		}
	}
	return false;
}

/** The fields a constant currently supplies, field => value. Empty and wrong-mode constants supply none. */
function store_kit_stripe_supplied() {
	$out = array();
	foreach ( store_kit_stripe_fields() as $field => $constant ) {
		if ( ! defined( $constant ) ) {
			continue;
		}
		$value = (string) constant( $constant );
		if ( '' === $value || ! store_kit_stripe_prefix_ok( $field, $value ) ) {
			continue;
		}
		$out[ $field ] = $value;
	}
	return $out;
}

/** Defined, non-empty constants whose value does not match the key format for their field/mode. */
function store_kit_stripe_mismatches() {
	$out = array();
	foreach ( store_kit_stripe_fields() as $field => $constant ) {
		if ( ! defined( $constant ) ) {
			continue;
		}
		$value = (string) constant( $constant );
		if ( '' !== $value && ! store_kit_stripe_prefix_ok( $field, $value ) ) {
			$out[ $field ] = $constant;
		}
	}
	return $out;
}

function store_kit_stripe_inject( $value ) {
	$supplied = store_kit_stripe_supplied();
	if ( ! $supplied ) {
		return $value;
	}
	$out        = is_array( $value ) ? $value : array();
	$seed_only  = store_kit_stripe_seed_only_fields();
	foreach ( $supplied as $field => $constant_value ) {
		if ( in_array( $field, $seed_only, true ) ) {
			// Seed, not override: Stripe may already have saved a rotated secret, and that
			// value must win so signature verification keeps matching what Stripe sends.
			if ( empty( $out[ $field ] ) ) {
				$out[ $field ] = $constant_value;
			}
			continue;
		}
		$out[ $field ] = $constant_value;
	}
	// Restore the same secret Stripe nests a second time inside test_webhook_data/webhook_data,
	// but only when it is missing there -- a differing nested value is left alone, same as above.
	foreach ( store_kit_stripe_nested_webhook_fields() as $data_field => $secret_field ) {
		if ( isset( $out[ $data_field ] ) && is_array( $out[ $data_field ] )
			&& empty( $out[ $data_field ]['secret'] ) && isset( $supplied[ $secret_field ] ) ) {
			$out[ $data_field ]['secret'] = $supplied[ $secret_field ];
		}
	}
	return $out;
}

function store_kit_stripe_strip( $value ) {
	if ( ! is_array( $value ) ) {
		return $value;
	}
	$supplied = store_kit_stripe_supplied();

	// Strip the nested copy only when it still matches the constant, so a secret Stripe itself
	// rotated into the row is never thrown away.
	foreach ( store_kit_stripe_nested_webhook_fields() as $data_field => $secret_field ) {
		if ( isset( $value[ $data_field ]['secret'], $supplied[ $secret_field ] )
			&& $value[ $data_field ]['secret'] === $supplied[ $secret_field ] ) {
			unset( $value[ $data_field ]['secret'] );
		}
	}

	$seed_only = store_kit_stripe_seed_only_fields();
	foreach ( $supplied as $field => $constant_value ) {
		if ( in_array( $field, $seed_only, true ) ) {
			// Seed, not override: only discard an incoming value that still equals the
			// constant. A rotated value differs and must reach the database -- with a notice,
			// since wp-config.php's copy is now the stale one.
			if ( isset( $value[ $field ] ) && $value[ $field ] === $constant_value ) {
				unset( $value[ $field ] );
			}
			continue;
		}
		unset( $value[ $field ] );
	}

	return $value;
}

add_filter( 'option_woocommerce_stripe_settings', 'store_kit_stripe_inject' );
add_filter( 'default_option_woocommerce_stripe_settings', 'store_kit_stripe_inject' );
// sanitize_option runs inside both add_option() and update_option(), before the write.
add_filter( 'sanitize_option_woocommerce_stripe_settings', 'store_kit_stripe_strip' );

function store_kit_stripe_notice() {
	// phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only screen check.
	if ( ! isset( $_GET['section'] ) || 'stripe' !== $_GET['section'] ) {
		return;
	}

	$supplied = store_kit_stripe_supplied();
	if ( $supplied ) {
		echo '<div class="notice notice-info"><p>' . sprintf(
			/* translators: %s: comma-separated list of settings field names supplied by wp-config.php */
			esc_html__( 'These Stripe fields are set in wp-config.php by Store Kit and are not saved from this screen: %s.', 'store-kit' ),
			esc_html( implode( ', ', array_keys( $supplied ) ) )
		) . '</p></div>';
	}

	foreach ( store_kit_stripe_mismatches() as $constant ) {
		echo '<div class="notice notice-warning"><p>' . sprintf(
			/* translators: %s: PHP constant name */
			esc_html__( '%s in wp-config.php does not match the expected Stripe key format for its mode and was ignored.', 'store-kit' ),
			esc_html( $constant )
		) . '</p></div>';
	}

	$stored = get_option( 'woocommerce_stripe_settings' );
	foreach ( array(
		'test_webhook_secret' => 'STORE_KIT_STRIPE_TEST_WEBHOOK_SECRET',
		'webhook_secret'      => 'STORE_KIT_STRIPE_WEBHOOK_SECRET',
	) as $field => $constant ) {
		if ( defined( $constant ) && '' !== (string) constant( $constant )
			&& ! empty( $stored[ $field ] ) && $stored[ $field ] !== (string) constant( $constant ) ) {
			echo '<div class="notice notice-warning"><p>' . sprintf(
				/* translators: %s: PHP constant name */
				esc_html__( 'Stripe rotated the webhook secret; the new one now sits in the database. Update %s in wp-config.php.', 'store-kit' ),
				esc_html( $constant )
			) . '</p></div>';
		}
	}
}
add_action( 'admin_notices', 'store_kit_stripe_notice' );
