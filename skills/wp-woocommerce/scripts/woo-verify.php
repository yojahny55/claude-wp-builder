<?php
/**
 * woo-verify.php -- the WordPress side of bin/woo-verify.mjs: the facts it checks a store
 * against, and the clean-up after its test order. It never changes a setting, a page or a
 * product.
 *
 * Usage: wp eval-file woo-verify.php facts
 *        wp eval-file woo-verify.php forget-session <session-key>
 *        wp eval-file woo-verify.php finish-order <order-id>
 *   The arguments are bare words: `wp eval-file` refuses a --flag it does not know.
 *
 *   facts           one JSON line: environment type, store pages and their paths, coming soon,
 *                   catalog mode, published products, a sample product, cash on delivery, the
 *                   orders on the store, and the new-order email's recipient.
 *   forget-session  deletes the WooCommerce session row of a Store API cart token, so a
 *                   verification leaves no cart behind.
 *   finish-order    reads the verification's order (its notes, whether the new-order email was
 *                   sent), cancels it so WooCommerce puts its stock and sales count back, and
 *                   deletes it for good -- a store that keeps an order is one setup treats as a
 *                   merchant's. Refused, exit 1, unless the site is local and the order is one a
 *                   verification placed: created through the Store API, billed to the marker
 *                   address below. Prints one JSON line.
 *
 * PHP 7.4 floor.
 */

/** Billing address of every order a verification places: how finish-order knows its own. */
const WOOVERIFY_EMAIL = 'woo-verify@example.test';

function wooverify_out( array $data ) {
	WP_CLI::line( wp_json_encode( $data ) );
}

function wooverify_refuse( $message ) {
	WP_CLI::line( 'refused: ' . $message );
	WP_CLI::halt( 1 );
}

/** Order ids on the store: the verification's own (a run that stopped half way) and the rest. */
function wooverify_orders() {
	$all  = wc_get_orders( array( 'limit' => 1, 'paginate' => true, 'return' => 'ids', 'status' => 'any', 'type' => 'shop_order' ) );
	$ours = array();
	foreach ( wc_get_orders( array( 'limit' => -1, 'return' => 'ids', 'status' => 'any', 'type' => 'shop_order', 'billing_email' => WOOVERIFY_EMAIL ) ) as $id ) {
		$o = wc_get_order( $id );
		if ( $o && 'store-api' === $o->get_created_via() ) {
			$ours[] = (int) $id;
		}
	}
	return array( $ours, (int) $all->total - count( $ours ) );
}

function wooverify_page( $name ) {
	$id = (int) wc_get_page_id( $name );
	if ( $id <= 0 || 'publish' !== get_post_status( $id ) ) {
		return array( 'id' => $id, 'path' => null );
	}
	return array( 'id' => $id, 'path' => wp_make_link_relative( (string) get_permalink( $id ) ) );
}

function wooverify_facts() {
	$sample   = null;
	$products = wc_get_products( array( 'status' => 'publish', 'type' => 'simple', 'limit' => 20, 'orderby' => 'ID', 'order' => 'ASC' ) );
	foreach ( $products as $p ) {
		if ( null === $sample || ( ! $sample['purchasable'] && $p->is_purchasable() && $p->is_in_stock() ) ) {
			$sample = array(
				'id'          => $p->get_id(),
				'name'        => $p->get_name(),
				'purchasable' => $p->is_purchasable() && $p->is_in_stock(),
				'stock'       => $p->managing_stock() ? (int) $p->get_stock_quantity() : null,
				'total_sales' => (int) $p->get_total_sales(),
			);
		}
	}
	$cod       = get_option( 'woocommerce_cod_settings', array() );
	$new_order = get_option( 'woocommerce_new_order_settings', array() );
	$recipient = is_array( $new_order ) && ! empty( $new_order['recipient'] ) ? $new_order['recipient'] : get_option( 'admin_email' );
	list( $ours, $rest ) = wooverify_orders();
	$published = wp_count_posts( 'product' );
	if ( ! function_exists( 'is_plugin_active' ) ) {
		require_once ABSPATH . 'wp-admin/includes/plugin.php';
	}
	wooverify_out(
		array(
			'environment'  => wp_get_environment_type(),
			'home'         => home_url( '/' ),
			'coming_soon'  => (string) get_option( 'woocommerce_coming_soon', '' ),
			'catalog_mode' => (string) get_option( 'store_kit_catalog_mode', '' ),
			'pages'        => array(
				'shop'      => wooverify_page( 'shop' ),
				'cart'      => wooverify_page( 'cart' ),
				'checkout'  => wooverify_page( 'checkout' ),
				'myaccount' => wooverify_page( 'myaccount' ),
			),
			'products'     => isset( $published->publish ) ? (int) $published->publish : 0,
			'sample'       => $sample,
			'cod'          => is_array( $cod ) && isset( $cod['enabled'] ) && 'yes' === $cod['enabled'],
			'turnstile'    => is_plugin_active( 'simple-cloudflare-turnstile/simple-cloudflare-turnstile.php' ) && '' !== (string) get_option( 'cfturnstile_woo_checkout', '' ),
			'orders'       => $rest,
			'own_orders'   => $ours,
			'recipient'    => (string) $recipient,
			'email'        => WOOVERIFY_EMAIL,
		)
	);
}

function wooverify_forget_session( $key ) {
	global $wpdb;
	if ( '' === $key ) {
		wooverify_refuse( 'forget-session needs the session key' );
	}
	$n = $wpdb->delete( $wpdb->prefix . 'woocommerce_sessions', array( 'session_key' => $key ), array( '%s' ) );
	wooverify_out( array( 'forgotten' => (int) $n ) );
}

function wooverify_finish_order( $id ) {
	if ( 'local' !== wp_get_environment_type() ) {
		wooverify_refuse( 'the site is not local: a verification places and deletes an order only on a local site' );
	}
	$order = $id > 0 ? wc_get_order( $id ) : false;
	if ( ! $order || 'shop_order' !== $order->get_type() ) {
		wooverify_refuse( "no order $id" );
	}
	if ( WOOVERIFY_EMAIL !== $order->get_billing_email() || 'store-api' !== $order->get_created_via() ) {
		wooverify_refuse( "order $id was not placed by a verification; left alone" );
	}
	$notes = array();
	foreach ( wc_get_order_notes( array( 'order_id' => $id ) ) as $note ) {
		$notes[] = wp_strip_all_tags( $note->content );
	}
	$status = $order->get_status();
	$total  = $order->get_total();
	// Cancelling runs WooCommerce's own hooks: the stock the order reduced and the sales count it
	// raised go back. Deleting a processing order directly would keep both. The store's
	// "Cancelled order" email is switched off for this process only: the cancel is ours.
	add_filter( 'woocommerce_email_enabled_cancelled_order', '__return_false' );
	$order->update_status( 'cancelled', 'Store verification: order placed to test the checkout, now removed.' );
	$items = array();
	foreach ( $order->get_items() as $item ) {
		$items[] = (int) $item->get_product_id();
	}
	$deleted = (bool) $order->delete( true );
	wc_delete_shop_order_transients();
	$after = array();
	foreach ( array_unique( $items ) as $pid ) {
		$p = wc_get_product( $pid );
		if ( $p ) {
			$after[ $pid ] = array(
				'stock'       => $p->managing_stock() ? (int) $p->get_stock_quantity() : null,
				'total_sales' => (int) $p->get_total_sales(),
			);
		}
	}
	wooverify_out(
		array(
			'status'   => $status,
			'total'    => $total,
			'notes'    => $notes,
			'deleted'  => $deleted && ! wc_get_order( $id ),
			'products' => $after,
		)
	);
}

$wooverify_argv = isset( $args ) ? array_values( (array) $args ) : array();
if ( ! class_exists( 'WooCommerce' ) ) {
	wooverify_refuse( 'WooCommerce is not active' );
}
switch ( isset( $wooverify_argv[0] ) ? $wooverify_argv[0] : '' ) {
	case 'facts':
		wooverify_facts();
		break;
	case 'forget-session':
		wooverify_forget_session( isset( $wooverify_argv[1] ) ? (string) $wooverify_argv[1] : '' );
		break;
	case 'finish-order':
		wooverify_finish_order( isset( $wooverify_argv[1] ) ? (int) $wooverify_argv[1] : 0 );
		break;
	default:
		wooverify_refuse( 'usage: wp eval-file woo-verify.php facts | forget-session <key> | finish-order <order-id>' );
}
