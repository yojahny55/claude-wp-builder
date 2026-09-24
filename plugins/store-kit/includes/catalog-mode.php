<?php
/**
 * Catalog mode: products and prices stay visible, nothing can be bought.
 *
 * /wp-woo-setup writes store_kit_catalog_mode = yes for a catalog tier and no otherwise. Once
 * is_purchasable() is false the Store API refuses add-to-cart on its own, so the one gate
 * covers the classic buttons, the blocks and a direct API call alike.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_kit_catalog_mode() {
	return 'yes' === get_option( 'store_kit_catalog_mode', 'no' );
}

function store_kit_purchasable( $purchasable ) {
	return store_kit_catalog_mode() ? false : $purchasable;
}
add_filter( 'woocommerce_is_purchasable', 'store_kit_purchasable' );
add_filter( 'woocommerce_variation_is_purchasable', 'store_kit_purchasable' );

// A catalog keeps its Cart and Checkout pages, so moving up a tier needs no page work, and
// sends anyone who reaches them to the shop instead of an empty cart.
function store_kit_catalog_redirect() {
	if ( ! store_kit_catalog_mode() || ! function_exists( 'is_cart' ) ) {
		return;
	}
	if ( is_cart() || is_checkout() ) {
		wp_safe_redirect( wc_get_page_permalink( 'shop' ) );
		exit;
	}
}
add_action( 'template_redirect', 'store_kit_catalog_redirect' );
