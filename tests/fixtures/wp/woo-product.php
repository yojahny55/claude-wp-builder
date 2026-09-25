<?php
/**
 * One simple product for the store checks: SKU FIXTURE-MUG, $20.00, 10 in stock.
 * Keyed by SKU, so running it twice changes nothing. Prints PRODUCT_ID=<id>.
 */
$id = wc_get_product_id_by_sku( 'FIXTURE-MUG' );
$p  = $id ? wc_get_product( $id ) : new WC_Product_Simple();
$p->set_name( 'Fixture Mug' );
$p->set_sku( 'FIXTURE-MUG' );
$p->set_regular_price( '20.00' );
$p->set_status( 'publish' );
$p->set_manage_stock( true );
$p->set_stock_quantity( 10 );
echo 'PRODUCT_ID=', $p->save(), "\n";
