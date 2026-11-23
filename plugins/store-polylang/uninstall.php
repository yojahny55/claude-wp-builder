<?php
/**
 * Removes every option Store Polylang owns. Product translations, the language recorded on
 * orders and the string translations in Polylang are the site's content, and stay.
 */

if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

foreach ( array( 'store_pll_gateway_options', 'store_pll_other_bridge' ) as $store_pll_option ) {
	delete_option( $store_pll_option );
}
