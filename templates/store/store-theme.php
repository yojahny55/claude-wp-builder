<?php
/**
 * Store theme: WooCommerce support and the store stylesheet of a theme this plugin scaffolded.
 * Copied by /wp-woo-setup into the theme's inc/, with its stylesheet, templates/store/store.css,
 * copied to assets/css/store.css. PHP 7.4 floor.
 *
 * Without add_theme_support( 'woocommerce' ) WooCommerce runs a classic theme in its
 * compatibility mode: the shop and every product page are squeezed into page.php's content,
 * with no gallery zoom, lightbox or slider. Declaring support hands those pages to
 * WooCommerce's own templates, which open their own wrapper and call a sidebar; both are
 * replaced here, because the theme's header already opens <main id="primary"> and the theme
 * has no sidebar.php.
 *
 * The stylesheet loads on store pages only (shop, product, product taxonomies, cart, checkout,
 * my account): every other page of the site renders exactly as before.
 *
 * Tailwind emits only the theme variables something uses, and store.css sits outside its
 * build. This file is in the build's @source, so naming the variables here keeps them in
 * assets/css/dist/main.css once the theme is rebuilt: var(--color-primary) var(--color-dark)
 * var(--color-light) var(--color-gray) var(--color-accent) var(--font-primary)
 * var(--font-secondary)
 */

defined( 'ABSPATH' ) || exit;

add_action( 'after_setup_theme', function () {
	add_theme_support( 'woocommerce' );
	add_theme_support( 'wc-product-gallery-zoom' );
	add_theme_support( 'wc-product-gallery-lightbox' );
	add_theme_support( 'wc-product-gallery-slider' );
} );

// WooCommerce's wrapper opens a second <main> with a second id="primary" inside the theme's,
// and its sidebar hook falls back to WordPress's deprecated theme-compat sidebar.
add_action( 'init', function () {
	if ( ! function_exists( 'woocommerce_output_content_wrapper' ) ) {
		return;
	}
	remove_action( 'woocommerce_before_main_content', 'woocommerce_output_content_wrapper', 10 );
	remove_action( 'woocommerce_after_main_content', 'woocommerce_output_content_wrapper_end', 10 );
	remove_action( 'woocommerce_sidebar', 'woocommerce_get_sidebar', 10 );
	add_action( 'woocommerce_before_main_content', '__prefix___store_page_open', 10 );
	add_action( 'woocommerce_after_main_content', '__prefix___store_page_close', 10 );
} );

function __prefix___store_page_open() {
	echo '<div class="store-page">';
}

function __prefix___store_page_close() {
	echo '</div>';
}

/** True on every page WooCommerce renders or owns: shop, product, its taxonomies, cart, checkout, my account. */
function __prefix___is_store_page() {
	if ( ! function_exists( 'is_woocommerce' ) ) {
		return false;
	}
	return is_woocommerce() || is_cart() || is_checkout() || is_account_page();
}

// After WooCommerce's own stylesheets (priority 10), so equal selectors resolve to this file.
add_action( 'wp_enqueue_scripts', function () {
	if ( ! __prefix___is_store_page() ) {
		return;
	}
	$file = get_theme_file_path( 'assets/css/store.css' );
	if ( ! file_exists( $file ) ) {
		return;
	}
	wp_enqueue_style( '__textdomain__-store', get_theme_file_uri( 'assets/css/store.css' ), array(), (string) filemtime( $file ) );
}, 20 );
