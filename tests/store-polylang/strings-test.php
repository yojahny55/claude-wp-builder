<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/core/strings.php';
store_pll_register_strings();

wpll_same( array( 'priority' => 20, 'args' => 1 ), wpll_hook( 'init', 'store_pll_register_stored_strings' ), 'string registration on init 20' );
wpll_same( array( 'priority' => 0, 'args' => 1 ), wpll_hook( 'after_setup_theme', 'store_pll_register_option_string_filters' ), 'output filters on after_setup_theme 0' );
wpll_same( array( 'priority' => 19, 'args' => 1 ), wpll_hook( 'init', 'store_pll_maybe_refresh_gateway_options' ), 'gateway refresh on init 19, before string registration (20)' );
wpll_same( null, wpll_hook( 'admin_init', 'store_pll_maybe_refresh_gateway_options' ), 'the refresh is no longer on admin_init: too late for registration' );

wpll_same(
	array( 'woocommerce_cod_settings' => array( 'title', 'description', 'instructions' ) ),
	store_pll_option_strings_from( array( 'woocommerce_cod_settings' ) ),
	'each gateway option translates title, description and instructions'
);

$GLOBALS['wpll']['options']['store_pll_gateway_options'] = array( 'woocommerce_cod_settings', 'woocommerce_x_settings' );
$GLOBALS['wpll']['filters']['store_pll_gateway_strings'] = function ( $map ) {
	$map['extra_option'] = array( 'label' );
	return $map;
};
wpll_same( array( 'woocommerce_cod_settings', 'woocommerce_x_settings', 'extra_option' ), array_keys( store_pll_option_strings() ), 'detected + filter' );
unset( $GLOBALS['wpll']['filters']['store_pll_gateway_strings'] );

// Output filters: on in the front end, off in admin without AJAX, on in admin-ajax.
$GLOBALS['wpll']['hooks']    = array();
$GLOBALS['wpll']['is_admin'] = true;
store_pll_register_option_string_filters();
wpll_same( null, wpll_hook( 'woocommerce_shipping_rate_label', 'store_pll_t' ), 'admin without AJAX: no output filters' );
$GLOBALS['wpll']['doing_ajax'] = true;
store_pll_register_option_string_filters();
wpll_same( array( 'priority' => 10, 'args' => 1 ), wpll_hook( 'woocommerce_shipping_rate_label', 'store_pll_t' ), 'admin-ajax: output filters' );
wpll_same( array( 'priority' => 10, 'args' => 1 ), wpll_hook( 'woocommerce_get_privacy_policy_text', 'store_pll_t' ), 'privacy' );
$names = array_column( $GLOBALS['wpll']['hooks'], 'hook' );
wpll_check( in_array( 'option_woocommerce_cod_settings', $names, true ), 'option_ filter per detected gateway' );
wpll_check( in_array( 'pre_update_option_woocommerce_cod_settings', $names, true ), 'pre_update_option_ filter per gateway' );

$upper = function ( $s ) {
	return strtoupper( $s );
};
wpll_same(
	array( 'title' => 'Hello', 'description' => 'something else', 'enabled' => 'yes' ),
	store_pll_restore_original_values( array( 'title' => 'HELLO', 'description' => 'something else', 'enabled' => 'yes' ), array( 'title' => 'Hello', 'description' => 'Text' ), array( 'title', 'description' ), $upper ),
	'an exact translation of the original reverts to the original; a real change is kept'
);
wpll_same( 'x', store_pll_restore_original_values( 'x', array(), array( 'title' ), $upper ), 'non-array value: unchanged' );
wpll_same(
	array( 'title' => 'Hello' ),
	store_pll_restore_original_values( array( 'title' => 'Hello' ), array( 'title' => 'Hello' ), array( 'title' ), $upper ),
	'no change: unchanged'
);
