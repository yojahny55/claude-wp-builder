<?php
/**
 * store-links.php -- point a demo's links to its store pages at WooCommerce's own pages.
 *
 * A demo's store pages (`role: store` in the /wp-yolo manifest) build no WP Page: WooCommerce
 * owns shop, cart, checkout and my account. /wp-seed calls this for every demo link that
 * targets one, so the link resolves to the page WooCommerce actually serves.
 *
 * Usage: wp eval-file store-links.php menu <menu> <surface> [<title>]
 *        wp eval-file store-links.php url <surface>
 *   <menu>     a menu's term id, slug or name
 *   <surface>  shop | product | cart | checkout | account (the manifest's `store` value)
 *
 *   menu  appends a menu item for that page, a `post_type` item whose object is the page id,
 *         so it follows a renamed page. Called in the demo nav's order, the item lands at the
 *         demo's position. Idempotent by object id: a menu that already holds an item for the
 *         page (an earlier run, or the client's own) gets no second one.
 *   url   prints the page's permalink, for a button or link field.
 *
 * One line, `<status> <surface>[: detail]`:
 *   added <surface>: item <id>      menu only
 *   ok <surface>: item <id>         menu only, already there
 *   url <surface>: <permalink>      url only
 *   skipped <surface>: <why>        nothing to point at, on purpose: a product has no single
 *                                   WooCommerce page; a catalog store has no cart or checkout
 *   missing <surface>: <why>        WooCommerce has no page for it (wc_get_page_id() <= 0) or
 *                                   the menu does not exist: list it for review
 *
 * Exit 0 for added, ok, url and skipped; 1 for missing and for a usage error. PHP 7.4 floor.
 */

if ( ! function_exists( 'wc_get_page_id' ) ) {
	WP_CLI::line( 'missing store: WooCommerce is not active' );
	WP_CLI::halt( 1 );
}

$store_links_args = isset( $args ) && is_array( $args ) ? array_values( $args ) : array();
$store_links_cmd  = isset( $store_links_args[0] ) ? $store_links_args[0] : '';
$store_links_map  = array(
	'shop'     => 'shop',
	'cart'     => 'cart',
	'checkout' => 'checkout',
	'account'  => 'myaccount',
	'product'  => '',
);

if ( 'menu' === $store_links_cmd ) {
	$store_links_surface = isset( $store_links_args[2] ) ? $store_links_args[2] : '';
} elseif ( 'url' === $store_links_cmd ) {
	$store_links_surface = isset( $store_links_args[1] ) ? $store_links_args[1] : '';
} else {
	$store_links_surface = '';
}
if ( '' === $store_links_surface || ! array_key_exists( $store_links_surface, $store_links_map ) ) {
	WP_CLI::line( 'usage: wp eval-file store-links.php menu <menu> <shop|product|cart|checkout|account> [<title>] | url <surface>' );
	WP_CLI::halt( 1 );
}

function store_links_done( $status, $surface, $detail ) {
	WP_CLI::line( $status . ' ' . $surface . ': ' . $detail );
	WP_CLI::halt( 'missing' === $status ? 1 : 0 );
}

if ( 'product' === $store_links_surface ) {
	store_links_done( 'skipped', 'product', 'a product page has no single WooCommerce page to link; point the link at a product or the shop' );
}
$store_links_catalog = function_exists( 'store_kit_catalog_mode' ) && store_kit_catalog_mode();
if ( $store_links_catalog && in_array( $store_links_surface, array( 'cart', 'checkout' ), true ) ) {
	store_links_done( 'skipped', $store_links_surface, 'catalog mode is on, so the store has no ' . $store_links_surface );
}

$store_links_page = (int) wc_get_page_id( $store_links_map[ $store_links_surface ] );
if ( $store_links_page <= 0 || 'publish' !== get_post_status( $store_links_page ) ) {
	store_links_done( 'missing', $store_links_surface, 'WooCommerce has no published ' . $store_links_surface . ' page; run /wp-woo-setup' );
}

if ( 'url' === $store_links_cmd ) {
	store_links_done( 'url', $store_links_surface, get_permalink( $store_links_page ) );
}

$store_links_menu_ref = isset( $store_links_args[1] ) ? $store_links_args[1] : '';
$store_links_menu     = wp_get_nav_menu_object( ctype_digit( $store_links_menu_ref ) ? (int) $store_links_menu_ref : $store_links_menu_ref );
if ( ! $store_links_menu ) {
	store_links_done( 'missing', $store_links_surface, 'no menu "' . $store_links_menu_ref . '"' );
}

foreach ( (array) wp_get_nav_menu_items( $store_links_menu->term_id, array( 'post_status' => 'any' ) ) as $store_links_item ) {
	if ( 'post_type' === $store_links_item->type && (int) $store_links_item->object_id === $store_links_page ) {
		store_links_done( 'ok', $store_links_surface, 'item ' . $store_links_item->ID );
	}
}

$store_links_title = isset( $store_links_args[3] ) && '' !== $store_links_args[3] ? $store_links_args[3] : get_the_title( $store_links_page );
$store_links_id    = wp_update_nav_menu_item(
	$store_links_menu->term_id,
	0,
	array(
		'menu-item-object-id' => $store_links_page,
		'menu-item-object'    => 'page',
		'menu-item-type'      => 'post_type',
		'menu-item-title'     => $store_links_title,
		'menu-item-status'    => 'publish',
	)
);
if ( is_wp_error( $store_links_id ) ) {
	store_links_done( 'missing', $store_links_surface, $store_links_id->get_error_message() );
}
store_links_done( 'added', $store_links_surface, 'item ' . $store_links_id );
