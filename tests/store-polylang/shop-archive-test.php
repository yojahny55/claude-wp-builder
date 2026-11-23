<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/core/shop-archive.php';
store_pll_register_shop_archive();

$expected = array(
	'rewrite_rules_array'             => array( 'store_pll_shop_rewrite_rules', 10, 1 ),
	'pll_save_post'                   => array( 'store_pll_flush_on_shop_translation', 10, 1 ),
	'option_woocommerce_shop_page_id' => array( 'store_pll_shop_page_option', 10, 1 ),
	'post_type_archive_link'          => array( 'store_pll_shop_archive_link', 30, 2 ),
	'pll_translation_url'             => array( 'store_pll_shop_translation_url', 10, 2 ),
	'template_redirect'               => array( 'store_pll_redirect_untranslated_shop', 10, 1 ),
);
foreach ( $expected as $hook => $e ) {
	wpll_same( array( 'priority' => $e[1], 'args' => $e[2] ), wpll_hook( $hook, $e[0] ), "{$hook} {$e[1]}/{$e[2]}" );
}

wpll_same( 'en/catalog', store_pll_shop_path( '/', '/en/', 'catalog' ), 'language prefix + slug' );
wpll_same( 'en/catalog', store_pll_shop_path( '/shop/', '/shop/en/', 'catalog' ), 'subdirectory install' );
wpll_same( 'catalog', store_pll_shop_path( '/', '/', 'catalog' ), 'language without prefix (own domain)' );
wpll_same( 'en/store/all', store_pll_shop_path( '/', '/en/', 'store/all' ), 'child shop page' );

$rules = store_pll_shop_rules( array( 'en' => 'en/catalog' ) );
wpll_same(
	array(
		'en/catalog/?$'                   => 'index.php?post_type=product&lang=en',
		'en/catalog/page/([0-9]{1,})/?$' => 'index.php?post_type=product&lang=en&paged=$matches[1]',
	),
	$rules,
	'archive and pagination rules'
);
wpll_same( array( 'a\.b/?$', 'a\.b/page/([0-9]{1,})/?$' ), array_keys( store_pll_shop_rules( array( 'en' => 'a.b' ) ) ), 'the slug is escaped for regex' );

// The redirect compares the request with the shop path: a subfolder install and a non-ASCII
// slug must both match, or the shop redirects to itself forever.
wpll_same( true, store_pll_is_shop_request( '/en/shop/', '', 'en/shop' ), 'root install: the shop path matches' );
wpll_same( true, store_pll_is_shop_request( '/site/en/shop/', '/site/', 'en/shop' ), 'subfolder install: the home path is stripped' );
wpll_same( false, store_pll_is_shop_request( '/site/en/other/', '/site/', 'en/shop' ), 'subfolder install: another page does not match' );
wpll_same( false, store_pll_is_shop_request( '/sitex/en/shop/', '/site/', 'en/shop' ), 'a path that only starts like the home is not under it' );
wpll_same( true, store_pll_is_shop_request( '/ru/%D0%BC%D0%B0%D0%B3/', '', 'ru/%d0%bc%d0%b0%d0%b3' ), 'percent-encoding case does not matter' );
wpll_same( false, store_pll_is_shop_request( '/shop/', '', 'en/shop' ), 'the default-language path is not the translated one' );
