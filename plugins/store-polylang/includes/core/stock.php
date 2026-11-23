<?php
/**
 * One shared inventory across translations.
 *
 * Free Polylang gives each translation its own post and its own stock, so a sale in one
 * language never reaches the other's. These hooks replay every stock change on the same
 * product or variation in the other languages.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_stock() {
	add_filter( 'woocommerce_update_product_stock_query', 'store_pll_record_stock_op', 10, 4 );
	add_action( 'woocommerce_product_set_stock', 'store_pll_sync_stock' );
	add_action( 'woocommerce_variation_set_stock', 'store_pll_sync_stock' );
	add_action( 'woocommerce_product_set_stock_status', 'store_pll_sync_stock_status', 10, 3 );
	add_action( 'woocommerce_variation_set_stock_status', 'store_pll_sync_stock_status', 10, 3 );
}

/**
 * Amount of a relative stock change, read from the SQL WooCommerce built, or null.
 */
function store_pll_parse_stock_op( $sql, $operation ) {
	if ( ! in_array( $operation, array( 'increase', 'decrease' ), true )
		|| ! preg_match( '/meta_value\s*=\s*meta_value\s*([+-]\s*[0-9.]+)/', (string) $sql, $m ) ) {
		return null;
	}
	return abs( (float) str_replace( ' ', '', $m[1] ) );
}

/**
 * Remember the relative operation WooCommerce is about to run, keyed by product ID.
 *
 * Orders change stock with `meta_value - N` in SQL, which is atomic. Copying the
 * resulting total to the translations with 'set' is not: two checkouts in different
 * languages at once each copy their own total over the other's, and one sale vanishes
 * (10 → both 9, instead of 8). Replaying the same operation keeps each language atomic.
 * If the SQL ever changes shape nothing is recorded and the sync copies the total.
 */
function store_pll_record_stock_op( $sql, $product_id, $new_stock, $operation ) {
	$id = (int) $product_id;
	unset( $GLOBALS['store_pll_stock_ops'][ $id ] );
	$amount = store_pll_parse_stock_op( $sql, $operation );
	if ( null !== $amount ) {
		$GLOBALS['store_pll_stock_ops'][ $id ] = array( 'amount' => $amount, 'op' => $operation );
	}
	return $sql;
}

/**
 * Push a stock change to the same product or variation in every other language.
 *
 * Fires for admin edits and for order stock reductions alike: wc_update_product_stock()
 * and the product data store both end in these actions. The static guard stops the
 * counterpart's own update from echoing back.
 */
function store_pll_sync_stock( $product ) {
	static $running = false;
	if ( ! $product instanceof WC_Product ) {
		return;
	}
	// Consumed before the guard: the counterpart writes below record their own operation,
	// and one left behind would be replayed by the next, unrelated sync of that product.
	$id      = $product->get_id();
	$pending = $GLOBALS['store_pll_stock_ops'][ $id ] ?? null;
	unset( $GLOBALS['store_pll_stock_ops'][ $id ] );
	if ( $running ) {
		return;
	}
	$amount = $pending ? $pending['amount'] : null;
	$op     = $pending ? $pending['op'] : null;

	$running = true;
	foreach ( store_pll_counterparts( $product ) as $tr ) {
		if ( $product->managing_stock() ) {
			if ( ! $tr->managing_stock() ) {
				$tr->set_manage_stock( true );
				$tr->save();
				$amount = null; // No stock to apply a change to yet: copy the total once.
			}
			if ( null !== $amount && $op ) {
				wc_update_product_stock( $tr, $amount, $op );
			} elseif ( $tr->get_stock_quantity() !== $product->get_stock_quantity() ) {
				wc_update_product_stock( $tr, $product->get_stock_quantity(), 'set' );
			}
		} elseif ( $tr->get_stock_status() !== $product->get_stock_status() ) {
			$tr->set_stock_status( $product->get_stock_status() );
			$tr->save();
		}
	}
	$running = false;
}

function store_pll_sync_stock_status( $product_id, $status, $product = null ) {
	store_pll_sync_stock( $product instanceof WC_Product ? $product : wc_get_product( $product_id ) );
}
