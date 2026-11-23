<?php
/**
 * Plugin Name:       Store Polylang
 * Description:       Polylang (free) + WooCommerce: one shared inventory across translations, per-language store pages, cart and customer emails, translatable stored strings. Installed by /wp-woo-setup on a Polylang site.
 * Plugin URI:        https://github.com/yojahny55/claude-wp-builder
 * Version:           1.0.0
 * Author:            Lacho00
 * Author URI:        https://lazarosantana.dev
 * License:           GPL-2.0-or-later
 * Requires at least: 6.5
 * Requires PHP:      7.4
 * Requires Plugins:  polylang, woocommerce
 * Update URI:        false
 * WC requires at least: 11.1
 * WC tested up to:   11.1.2
 * Text Domain:       store-polylang
 * Domain Path:       /languages
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'STORE_PLL_VERSION', '1.0.0' );
define( 'STORE_PLL_FILE', __FILE__ );
define( 'STORE_PLL_DIR', plugin_dir_path( __FILE__ ) );

require_once STORE_PLL_DIR . 'includes/boot.php';

// After Polylang (which defines its API on plugins_loaded) and WooCommerce.
add_action( 'plugins_loaded', 'store_pll_boot', 20 );

// Declared because tests/checks/store-polylang-integration.sh proves both against a real
// WooCommerce: a block-checkout order placed through the Store API, in the HPOS table, carries
// the shopper's language.
add_action(
	'before_woocommerce_init',
	function () {
		if ( class_exists( '\Automattic\WooCommerce\Utilities\FeaturesUtil' ) ) {
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'cart_checkout_blocks', __FILE__, true );
		}
	}
);

register_activation_hook( __FILE__, 'store_pll_activate' );
register_deactivation_hook( __FILE__, 'store_pll_deactivate' );
