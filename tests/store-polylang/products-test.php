<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
function get_post_type( $id ) {
	return $GLOBALS['wpll']['post_types'][ $id ] ?? false;
}
require_once STORE_PLL_DIR . 'includes/core/products.php';
store_pll_register_products();

wpll_same( array( 'priority' => 20, 'args' => 2 ), wpll_hook( 'pll_get_taxonomies', 'store_pll_untranslated_taxonomies' ), 'pll_get_taxonomies 20/2' );
wpll_same( array( 'priority' => 20, 'args' => 3 ), wpll_hook( 'pll_copy_post_metas', 'store_pll_copy_product_metas' ), 'pll_copy_post_metas 20/3' );
wpll_same( array( 'priority' => 10, 'args' => 3 ), wpll_hook( 'wc_product_has_unique_sku', 'store_pll_sku_shared_by_translations' ), 'wc_product_has_unique_sku 10/3' );

wpll_same(
	array( 'product_cat' => 'product_cat' ),
	store_pll_untranslated_taxonomies( array( 'product_cat' => 'product_cat', 'product_brand' => 'product_brand' ), false ),
	'product_brand is left out of Polylang'
);

$meta = store_pll_synced_product_meta();
foreach ( array( '_regular_price', '_sale_price', '_price', '_sale_price_dates_from', '_sale_price_dates_to', '_sku', '_manage_stock', '_backorders', '_low_stock_amount', '_sold_individually', '_weight', '_length', '_width', '_height', '_tax_status', '_tax_class', '_virtual', '_downloadable', '_product_attributes', '_product_image_gallery' ) as $key ) {
	wpll_check( in_array( $key, $meta, true ), "synced meta includes {$key}" );
}
wpll_check( ! in_array( '_stock', $meta, true ) && ! in_array( '_stock_status', $meta, true ), 'stock and status are NOT in the synced meta' );

$GLOBALS['wpll']['post_types'] = array( 1 => 'product', 2 => 'page' );
wpll_same( array_merge( array( 'x' ), $meta ), store_pll_copy_product_metas( array( 'x' ), true, 1 ), 'product in sync: adds the list' );
wpll_same( array( 'x' ), store_pll_copy_product_metas( array( 'x' ), false, 1 ), 'initial copy (not sync): adds nothing' );
wpll_same( array( 'x' ), store_pll_copy_product_metas( array( 'x' ), true, 2 ), 'other post type: adds nothing' );

$GLOBALS['wpll']['filters']['store_pll_synced_product_meta'] = function ( $keys ) {
	$keys[] = '_custom';
	return $keys;
};
wpll_check( in_array( '_custom', store_pll_synced_product_meta(), true ), 'the list is filterable' );
