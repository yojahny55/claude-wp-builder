<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/core/stock.php';
store_pll_register_stock();

wpll_same( array( 'priority' => 10, 'args' => 4 ), wpll_hook( 'woocommerce_update_product_stock_query', 'store_pll_record_stock_op' ), 'SQL capture 10/4' );
foreach ( array( 'woocommerce_product_set_stock', 'woocommerce_variation_set_stock' ) as $hook ) {
	wpll_same( array( 'priority' => 10, 'args' => 1 ), wpll_hook( $hook, 'store_pll_sync_stock' ), "{$hook} 10/1" );
}
foreach ( array( 'woocommerce_product_set_stock_status', 'woocommerce_variation_set_stock_status' ) as $hook ) {
	wpll_same( array( 'priority' => 10, 'args' => 3 ), wpll_hook( $hook, 'store_pll_sync_stock_status' ), "{$hook} 10/3" );
}

// Real WooCommerce SQL: "meta_value = meta_value %+f".
$sql = "UPDATE wp_postmeta SET meta_value = meta_value -2.000000 WHERE post_id = 7 AND meta_key='_stock'";
wpll_same( 2.0, store_pll_parse_stock_op( $sql, 'decrease' ), 'decrease: absolute amount' );
wpll_same( 1.5, store_pll_parse_stock_op( "SET meta_value = meta_value +1.500000 WHERE", 'increase' ), 'increase with decimals' );
wpll_same( 3.0, store_pll_parse_stock_op( "SET meta_value=meta_value - 3 WHERE", 'decrease' ), 'variable spacing' );
wpll_same( null, store_pll_parse_stock_op( "SET meta_value = 5 WHERE", 'set' ), 'set: nothing to replicate' );
wpll_same( null, store_pll_parse_stock_op( "SET meta_value = GREATEST(0, meta_value - 2)", 'decrease' ), 'SQL of another shape: null (the total will be copied)' );

wpll_same( $sql, store_pll_record_stock_op( $sql, '7', 5, 'decrease' ), 'the filter returns the SQL unchanged' );
wpll_same( array( 'amount' => 2.0, 'op' => 'decrease' ), $GLOBALS['store_pll_stock_ops'][7], 'stores the operation by ID' );
store_pll_record_stock_op( "SET meta_value = 5", 7, 5, 'set' );
wpll_check( ! isset( $GLOBALS['store_pll_stock_ops'][7] ), 'a later non-relative operation clears the earlier one' );
