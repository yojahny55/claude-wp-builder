<?php
/**
 * Plugin Name:       Store Kit
 * Plugin URI:        https://github.com/yojahny55/claude-wp-builder
 * Description:       Store behaviour for sites built with claude-wp-builder: catalog mode, and Stripe keys read from wp-config.php instead of the database. Configured by /wp-woo-setup, not by a settings screen.
 * Version:           1.0.0
 * Author:            Yojahny
 * License:           MIT
 * Requires at least: 7.0
 * Requires PHP:      7.4
 * Requires Plugins:  woocommerce
 * Update URI:        false
 * WC requires at least: 11.1
 * WC tested up to:   11.1.2
 * Text Domain:       store-kit
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'STORE_KIT_VERSION', '1.0.0' );

require_once __DIR__ . '/includes/catalog-mode.php';
require_once __DIR__ . '/includes/credentials.php';

// Declared because tests/checks/wp-woo-setup-integration.sh proves both against a real
// WooCommerce: an order is placed through the block checkout's Store API and lands in the
// HPOS table.
add_action(
	'before_woocommerce_init',
	function () {
		if ( class_exists( '\Automattic\WooCommerce\Utilities\FeaturesUtil' ) ) {
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'cart_checkout_blocks', __FILE__, true );
		}
	}
);
