<?php
/**
 * Cart: items follow the shopper's current language.
 *
 * The cart stores the product IDs of the language the item was added in. On every
 * load from the session each item is swapped for its counterpart in the current
 * language (variations through their SKU, see store_pll_counterparts()), so names,
 * links and images match the page. The cart fragments cached in sessionStorage are
 * keyed per language, otherwise the mini cart keeps showing the previous language
 * until the cart changes.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_cart() {
	add_action( 'woocommerce_cart_loaded_from_session', 'store_pll_translate_cart_items', 20 );
	add_filter( 'woocommerce_cart_fragment_name', 'store_pll_cart_fragment_name' );
}

/** The counterpart of $product in $lang, or null when it has none. */
function store_pll_product_in_language( $product, $lang ) {
	if ( ! $product instanceof WC_Product || ! $lang || ! function_exists( 'pll_get_post_language' ) ) {
		return null;
	}
	$own_id = $product->is_type( 'variation' ) ? $product->get_parent_id() : $product->get_id();
	if ( pll_get_post_language( $own_id ) === $lang ) {
		return $product;
	}
	foreach ( store_pll_counterparts( $product ) as $tr ) {
		$tr_id = $tr->is_type( 'variation' ) ? $tr->get_parent_id() : $tr->get_id();
		if ( pll_get_post_language( $tr_id ) === $lang ) {
			return $tr;
		}
	}
	return null;
}

/** Swap each cart item for its counterpart in the current language. */
function store_pll_translate_cart_items( $cart ) {
	$lang = store_pll_lang();
	if ( ! $lang || ! $cart instanceof WC_Cart ) {
		return;
	}
	foreach ( $cart->cart_contents as $key => $item ) {
		if ( empty( $item['data'] ) || ! $item['data'] instanceof WC_Product ) {
			continue;
		}
		$tr = store_pll_product_in_language( $item['data'], $lang );
		if ( ! $tr || $tr->get_id() === $item['data']->get_id() ) {
			continue;
		}
		$cart->cart_contents[ $key ]['data']         = $tr;
		$cart->cart_contents[ $key ]['product_id']   = $tr->is_type( 'variation' ) ? $tr->get_parent_id() : $tr->get_id();
		$cart->cart_contents[ $key ]['variation_id'] = $tr->is_type( 'variation' ) ? $tr->get_id() : 0;
	}
}

/** One sessionStorage entry per language for the cart fragments. */
function store_pll_cart_fragment_name( $name ) {
	$lang = store_pll_lang();
	return $lang ? $name . '_' . $lang : $name;
}
