<?php
/**
 * Products with free Polylang: one product per language, shared data.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_products() {
	add_filter( 'pll_get_taxonomies', 'store_pll_untranslated_taxonomies', 20, 2 );
	add_filter( 'pll_copy_post_metas', 'store_pll_copy_product_metas', 20, 3 );
	add_filter( 'wc_product_has_unique_sku', 'store_pll_sku_shared_by_translations', 10, 3 );
}

/**
 * Keep product_brand out of Polylang.
 *
 * Brand names are proper nouns spelled the same in every language. Translating the
 * taxonomy duplicates every term with `<brand>-en` slugs just to relabel none of them,
 * and the duplicate slugs end up in shared archive URLs.
 */
function store_pll_untranslated_taxonomies( $taxonomies, $is_settings ) {
	unset( $taxonomies['product_brand'] );
	return $taxonomies;
}

/**
 * Product meta kept identical across translations.
 *
 * Polylang's own custom-field sync skips every protected (`_`-prefixed) key, which is
 * all of WooCommerce's, and would otherwise copy public keys such as SEO titles. So that
 * sync stays off and this list is added for products only. Stock quantity and status
 * are NOT here: WooCommerce writes them with direct SQL that fires no meta hook; see
 * stock.php.
 */
function store_pll_synced_product_meta() {
	return (array) apply_filters( 'store_pll_synced_product_meta', array(
		'_regular_price', '_sale_price', '_price', '_sale_price_dates_from', '_sale_price_dates_to',
		'_sku', '_manage_stock', '_backorders', '_low_stock_amount', '_sold_individually',
		'_weight', '_length', '_width', '_height', '_tax_status', '_tax_class',
		'_virtual', '_downloadable', '_product_attributes', '_product_image_gallery',
	) );
}

function store_pll_copy_product_metas( $keys, $sync, $from ) {
	if ( $sync && 'product' === get_post_type( $from ) ) {
		$keys = array_merge( $keys, store_pll_synced_product_meta() );
	}
	return $keys;
}

/**
 * The same product or variation in the other languages.
 *
 * Variations are not translated by Polylang (`product_variation` is not a translated
 * post type), so a variation's counterpart is the variation of the translated parent
 * that carries the same SKU. A variation without a SKU has none.
 *
 * @return WC_Product[]
 */
function store_pll_counterparts( $product ) {
	if ( ! function_exists( 'pll_get_post_translations' ) || ! $product instanceof WC_Product ) {
		return array();
	}
	$found = array();
	if ( $product->is_type( 'variation' ) ) {
		$sku = $product->get_sku( 'edit' );
		if ( '' === (string) $sku ) {
			return array();
		}
		foreach ( pll_get_post_translations( $product->get_parent_id() ) as $parent_id ) {
			if ( (int) $parent_id === $product->get_parent_id() ) {
				continue;
			}
			foreach ( get_posts( array(
				'post_type'   => 'product_variation',
				'post_parent' => (int) $parent_id,
				'post_status' => array( 'publish', 'private' ),
				'numberposts' => 50, // Variations of one product; never near this cap.
				'fields'      => 'ids',
				'meta_key'    => '_sku', // phpcs:ignore WordPress.DB.SlowDBQuery.slow_query_meta_key
				'meta_value'  => $sku, // phpcs:ignore WordPress.DB.SlowDBQuery.slow_query_meta_value
			) ) as $variation_id ) {
				$tr = wc_get_product( $variation_id );
				if ( $tr ) {
					$found[] = $tr;
				}
			}
		}
		return $found;
	}
	foreach ( pll_get_post_translations( $product->get_id() ) as $tr_id ) {
		$tr = (int) $tr_id === $product->get_id() ? null : wc_get_product( $tr_id );
		if ( $tr ) {
			$found[] = $tr;
		}
	}
	return $found;
}

/**
 * Translations share a SKU by design; don't count them as duplicates of each other.
 * A variation may share its SKU only with variations of its parent's translations; a
 * product only with its own translations. Anything else is a real duplicate, including
 * a sibling variation or the parent product itself.
 */
function store_pll_sku_shared_by_translations( $sku_found, $product_id, $sku ) {
	if ( ! $sku_found || ! function_exists( 'pll_get_post_translations' ) ) {
		return $sku_found;
	}
	global $wpdb;
	$is_variation = 'product_variation' === get_post_type( $product_id );
	$root         = $is_variation ? (int) wp_get_post_parent_id( $product_id ) : (int) $product_id;
	$allowed      = array_diff( array_map( 'intval', array_values( pll_get_post_translations( $root ) ) ), array( $root ) );
	$owners       = $wpdb->get_results( $wpdb->prepare(
		"SELECT pm.post_id, p.post_type, p.post_parent FROM {$wpdb->postmeta} pm
		 JOIN {$wpdb->posts} p ON p.ID = pm.post_id
		 WHERE pm.meta_key = '_sku' AND pm.meta_value = %s
		   AND p.post_type IN ( 'product', 'product_variation' ) AND p.post_status != 'trash'",
		$sku
	) );
	foreach ( $owners as $owner ) {
		if ( (int) $owner->post_id === (int) $product_id ) {
			continue;
		}
		$shared = $is_variation
			? 'product_variation' === $owner->post_type && in_array( (int) $owner->post_parent, $allowed, true )
			: 'product' === $owner->post_type && in_array( (int) $owner->post_id, $allowed, true );
		if ( ! $shared ) {
			return true;
		}
	}
	return false;
}

/**
 * Give a new translation the data its product shares: type, price, SKU, stock, sizes,
 * attributes, gallery, and its categories and tags in its own language.
 *
 * For translations made outside the editor (an import), where Polylang copies nothing.
 * Runs once the translation is in the product's Polylang group, so the SKU check accepts
 * the shared SKU. A category or tag with no translation in $lang yet is left off and
 * counted in the return value, so the caller can say so.
 *
 * @return array{copied: bool, terms_missing: int}
 */
function store_pll_copy_product( $from, $to, $lang ) {
	$source = wc_get_product( $from );
	if ( ! $source || $source->is_type( 'variation' ) || 'product' !== get_post_type( $to ) ) {
		return array( 'copied' => false, 'terms_missing' => 0 );
	}
	foreach ( array( 'product_type', 'product_visibility', 'product_shipping_class' ) as $taxonomy ) {
		$ids = wp_get_object_terms( $from, $taxonomy, array( 'fields' => 'ids' ) );
		if ( ! is_wp_error( $ids ) ) {
			wp_set_object_terms( $to, array_map( 'intval', $ids ), $taxonomy );
		}
	}
	$missing = 0;
	foreach ( array( 'product_cat', 'product_tag' ) as $taxonomy ) {
		$ids = wp_get_object_terms( $from, $taxonomy, array( 'fields' => 'ids' ) );
		if ( is_wp_error( $ids ) ) {
			continue;
		}
		$mapped = array();
		foreach ( $ids as $id ) {
			$tr = function_exists( 'pll_get_term' ) ? pll_get_term( (int) $id, $lang ) : 0;
			if ( $tr ) {
				$mapped[] = (int) $tr;
			} else {
				$missing++;
			}
		}
		wp_set_object_terms( $to, $mapped, $taxonomy );
	}
	foreach ( store_pll_synced_product_meta() as $key ) {
		if ( metadata_exists( 'post', $from, $key ) ) {
			update_post_meta( $to, $key, get_post_meta( $from, $key, true ) );
		}
	}
	// Through WC_Product, not meta: saving also fills the lookup table that price sorting
	// and filters read. The stock is copied as a total: nothing has been sold in the new
	// language yet, and every later change is replayed by stock.php.
	$target = wc_get_product( $to );
	if ( ! $target ) {
		return array( 'copied' => false, 'terms_missing' => $missing );
	}
	$target->set_manage_stock( $source->get_manage_stock() );
	$target->set_stock_quantity( $source->get_stock_quantity() );
	$target->set_stock_status( $source->get_stock_status() );
	if ( $source->is_type( 'external' ) && $target->is_type( 'external' ) ) {
		$target->set_product_url( $source->get_product_url( 'edit' ) );
		$target->set_button_text( $source->get_button_text( 'edit' ) );
	}
	$target->save();
	return array( 'copied' => true, 'terms_missing' => $missing );
}
