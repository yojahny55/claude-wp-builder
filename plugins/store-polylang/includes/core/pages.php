<?php
/**
 * WooCommerce pages and wc-ajax requests in the current language.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_pages() {
	add_action( 'after_setup_theme', 'store_pll_register_wc_page_filters', 0 );
	add_filter( 'woocommerce_ajax_get_endpoint', 'store_pll_ajax_endpoint', 10, 2 );
}

/**
 * WooCommerce stores one page ID per role, so without this every cart and checkout link
 * points at the default language's page and is_checkout() misses the translation.
 */
function store_pll_register_wc_page_filters() {
	foreach ( array( 'cart', 'checkout', 'myaccount', 'terms' ) as $wc_page ) {
		add_filter( "woocommerce_get_{$wc_page}_page_id", 'store_pll_translate_wc_page_id' );
	}
}

/**
 * Admin screens keep the stored ID, unless an email forced a language.
 */
function store_pll_translate_wc_page_id( $page_id ) {
	$lang = store_pll_lang();
	if ( $page_id <= 0 || ! function_exists( 'pll_get_post' ) || ! $lang ) {
		return $page_id;
	}
	if ( is_admin() && ! wp_doing_ajax() && ! store_pll_lang( null, true ) ) {
		return $page_id;
	}
	$translated = pll_get_post( $page_id, $lang );
	return $translated ? (int) $translated : $page_id;
}

/**
 * `/?wc-ajax=…` with the language home's path in front of the `?`.
 *
 * @param string      $url       Endpoint as WooCommerce built it.
 * @param string|null $home_path Path of the current language's home, e.g. `/en/`.
 */
function store_pll_localize_ajax_endpoint( $url, $home_path ) {
	$home = $home_path ? trailingslashit( $home_path ) : '/';
	if ( '/' === $home ) {
		return $url;
	}
	return preg_replace( '#^/(?=\?)#', $home, $url, 1 );
}

/**
 * wc-ajax requests through the current language's home: `/?wc-ajax=…` reads as the
 * default language to Polylang, so order review, checkout errors and the thank-you
 * redirect came back in it.
 */
function store_pll_ajax_endpoint( $url, $request ) {
	if ( ! function_exists( 'PLL' ) || empty( PLL()->curlang ) || empty( PLL()->links_model ) ) {
		return $url;
	}
	// Not pll_home_url(): with a static front page that returns the page's permalink
	// (/en/home/), not the language root.
	return store_pll_localize_ajax_endpoint( $url, wp_parse_url( PLL()->links_model->home_url( PLL()->curlang ), PHP_URL_PATH ) );
}
