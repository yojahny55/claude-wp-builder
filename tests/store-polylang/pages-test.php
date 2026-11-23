<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/core/pages.php';
store_pll_register_pages();

wpll_same( array( 'priority' => 0, 'args' => 1 ), wpll_hook( 'after_setup_theme', 'store_pll_register_wc_page_filters' ), 'page filters on after_setup_theme 0' );
wpll_same( array( 'priority' => 10, 'args' => 2 ), wpll_hook( 'woocommerce_ajax_get_endpoint', 'store_pll_ajax_endpoint' ), 'wc-ajax 10/2' );
store_pll_register_wc_page_filters();
foreach ( array( 'cart', 'checkout', 'myaccount', 'terms' ) as $role ) {
	wpll_same( array( 'priority' => 10, 'args' => 1 ), wpll_hook( "woocommerce_get_{$role}_page_id", 'store_pll_translate_wc_page_id' ), "page {$role}" );
}

wpll_same( '/en/?wc-ajax=%%endpoint%%', store_pll_localize_ajax_endpoint( '/?wc-ajax=%%endpoint%%', '/en/' ), 'prepends the language home' );
wpll_same( '/en/?wc-ajax=%%endpoint%%', store_pll_localize_ajax_endpoint( '/?wc-ajax=%%endpoint%%', '/en' ), 'home without trailing slash' );
wpll_same( '/?wc-ajax=x', store_pll_localize_ajax_endpoint( '/?wc-ajax=x', '/' ), 'language at the root: unchanged' );
wpll_same( '/?wc-ajax=x', store_pll_localize_ajax_endpoint( '/?wc-ajax=x', null ), 'no path: unchanged' );
wpll_same( 'https://x.test/?wc-ajax=x', store_pll_localize_ajax_endpoint( 'https://x.test/?wc-ajax=x', '/en/' ), 'absolute URL: unchanged' );
wpll_same( '/sub/en/?wc-ajax=x', store_pll_localize_ajax_endpoint( '/?wc-ajax=x', '/sub/en/' ), 'subdirectory install' );
