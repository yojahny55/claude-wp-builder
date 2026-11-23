<?php
/**
 * Stored strings shown to shoppers: gateway titles, descriptions and instructions, the
 * privacy notices and shipping method titles. They live in the database, not in gettext,
 * so they are registered with Polylang (Languages > Translations, group "WooCommerce")
 * and swapped on output.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_strings() {
	add_action( 'init', 'store_pll_maybe_refresh_gateway_options', 19 ); // Before the strings are registered (20).
	add_action( 'init', 'store_pll_register_stored_strings', 20 );
	add_action( 'after_setup_theme', 'store_pll_register_option_string_filters', 0 );
}

/**
 * Refresh the recorded gateway list once per real admin request, just before
 * store_pll_register_stored_strings() reads it, so a newly installed gateway's strings
 * are registered on the first admin screen that loads. Skipped on admin-ajax, which is hit
 * far more often (cart fragments, add-to-cart) for no benefit: gateways are added or
 * removed from a real admin screen.
 */
function store_pll_maybe_refresh_gateway_options() {
	if ( ! is_admin() || wp_doing_ajax() ) {
		return;
	}
	store_pll_refresh_gateway_options();
}

/** Translate one stored string into the language in use, unless that is the default. */
function store_pll_t( $text ) {
	$lang = store_pll_lang();
	if ( ! is_string( $text ) || '' === $text || ! $lang || ! function_exists( 'pll_translate_string' ) || pll_default_language() === $lang ) {
		return $text;
	}
	return pll_translate_string( $text, $lang );
}

/** Settings option names of the payment gateways seen last time the admin loaded. */
function store_pll_gateway_option_keys() {
	return array_values( array_filter( (array) get_option( 'store_pll_gateway_options', array() ), 'is_string' ) );
}

/**
 * Record the gateways' settings option names. Gateways read their settings in their
 * constructor, so the front end cannot instantiate them to find out without loading
 * those settings before the translation filters exist; it reads this list instead.
 */
function store_pll_refresh_gateway_options() {
	if ( ! function_exists( 'WC' ) || ! WC()->payment_gateways() ) {
		return;
	}
	$keys = array();
	foreach ( WC()->payment_gateways()->payment_gateways() as $gateway ) {
		$keys[] = $gateway->get_option_key();
	}
	sort( $keys );
	if ( store_pll_gateway_option_keys() !== $keys ) {
		update_option( 'store_pll_gateway_options', $keys, true );
	}
}

/** [ option => translated keys ] for a list of gateway settings options. */
function store_pll_option_strings_from( array $option_keys ) {
	$map = array();
	foreach ( $option_keys as $option ) {
		$map[ $option ] = array( 'title', 'description', 'instructions' );
	}
	return $map;
}

/** Array options with translated keys: the detected gateways plus whatever the filter adds. */
function store_pll_option_strings() {
	return (array) apply_filters( 'store_pll_gateway_strings', store_pll_option_strings_from( store_pll_gateway_option_keys() ) );
}

/**
 * Registration only matters on the Strings Translations screen and must read the
 * untranslated values, so it runs in admin, where the output filters are off.
 */
function store_pll_register_stored_strings() {
	if ( ! is_admin() || ! function_exists( 'pll_register_string' ) ) {
		return;
	}
	foreach ( store_pll_option_strings() as $option => $keys ) {
		$settings = get_option( $option );
		foreach ( $keys as $key ) {
			if ( ! empty( $settings[ $key ] ) && is_string( $settings[ $key ] ) ) {
				pll_register_string( $option . ':' . $key, $settings[ $key ], 'WooCommerce', 'title' !== $key );
			}
		}
	}
	foreach ( array( 'woocommerce_checkout_privacy_policy_text', 'woocommerce_registration_privacy_policy_text' ) as $option ) {
		pll_register_string( $option, (string) get_option( $option ), 'WooCommerce', true );
	}
	if ( class_exists( 'WC_Shipping_Zones' ) ) {
		foreach ( array_merge( array( 0 ), array_keys( WC_Shipping_Zones::get_zones() ) ) as $zone_id ) {
			foreach ( ( new WC_Shipping_Zone( $zone_id ) )->get_shipping_methods() as $method ) {
				pll_register_string( 'shipping:' . $method->id, $method->get_title(), 'WooCommerce' );
			}
		}
	}
}

/**
 * Output filters, front end and admin-ajax only. At after_setup_theme so modules and
 * themes have added their options to `store_pll_gateway_strings` by then.
 */
function store_pll_register_option_string_filters() {
	if ( is_admin() && ! wp_doing_ajax() ) {
		return;
	}
	foreach ( store_pll_option_strings() as $option_name => $keys ) {
		add_filter( 'option_' . $option_name, function ( $settings ) use ( $keys ) {
			return store_pll_translate_option_values( $settings, $keys );
		} );
		// The filter above also runs on admin-ajax, and a gateway saved there (WooCommerce's
		// enable/disable toggle calls update_option() with what get_option() returned) would
		// write the translation over the source string.
		add_filter( 'pre_update_option_' . $option_name, function ( $value, $old_value, $option ) use ( $keys ) {
			if ( ! is_array( $value ) ) {
				return $value;
			}
			$GLOBALS['store_pll_raw_options'] = true;
			$raw                                = get_option( $option );
			$GLOBALS['store_pll_raw_options'] = false;
			return store_pll_restore_original_values( $value, $raw, $keys, 'store_pll_t' );
		}, 10, 3 );
	}
	add_filter( 'woocommerce_get_privacy_policy_text', 'store_pll_t' );
	add_filter( 'woocommerce_shipping_rate_label', 'store_pll_t' );
}

function store_pll_translate_option_values( $settings, array $keys ) {
	if ( ! empty( $GLOBALS['store_pll_raw_options'] ) || ! is_array( $settings ) ) {
		return $settings;
	}
	foreach ( $keys as $key ) {
		if ( isset( $settings[ $key ] ) ) {
			$settings[ $key ] = store_pll_t( $settings[ $key ] );
		}
	}
	return $settings;
}

/**
 * Any value that is exactly the translation of the stored original goes back to that
 * original before it is saved. A real edit (anything else) is kept.
 */
function store_pll_restore_original_values( $value, $raw, array $keys, callable $translate ) {
	if ( ! is_array( $value ) || ! is_array( $raw ) ) {
		return $value;
	}
	foreach ( $keys as $key ) {
		if ( isset( $value[ $key ], $raw[ $key ] ) && $value[ $key ] !== $raw[ $key ]
			&& $value[ $key ] === call_user_func( $translate, $raw[ $key ] ) ) {
			$value[ $key ] = $raw[ $key ];
		}
	}
	return $value;
}
