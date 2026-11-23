<?php
/**
 * Product attribute labels and terms.
 *
 * Attribute terms are shared by every language: translating the taxonomies in Polylang
 * would split the terms, and translated variations store the default language's slugs
 * (attribute_pa_<name> = <slug>), which free Polylang does not sync. Names and labels
 * are registered as strings (group "WooCommerce attributes") and swapped on output;
 * slugs never change.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_attributes() {
	add_action( 'init', 'store_pll_register_attribute_strings', 20 );
	if ( ! is_admin() || wp_doing_ajax() ) {
		add_filter( 'get_term', 'store_pll_translate_attribute_term', 10, 2 );
		add_filter( 'woocommerce_attribute_label', 'store_pll_t' );
	}
}

function store_pll_register_attribute_strings() {
	if ( ! is_admin() || ! function_exists( 'pll_register_string' ) || ! function_exists( 'wc_get_attribute_taxonomies' ) ) {
		return;
	}
	foreach ( wc_get_attribute_taxonomies() as $attribute ) {
		pll_register_string( 'attribute:' . $attribute->attribute_name, $attribute->attribute_label, 'WooCommerce attributes' );
		$terms = get_terms( array( 'taxonomy' => 'pa_' . $attribute->attribute_name, 'hide_empty' => false, 'lang' => '' ) );
		foreach ( is_array( $terms ) ? $terms : array() as $term ) {
			pll_register_string( 'pa_' . $attribute->attribute_name . ':' . $term->slug, $term->name, 'WooCommerce attributes' );
		}
	}
}

function store_pll_translate_attribute_term( $term, $taxonomy ) {
	if ( $term instanceof WP_Term && 0 === strpos( $taxonomy, 'pa_' ) ) {
		$term->name = store_pll_t( $term->name );
	}
	return $term;
}
