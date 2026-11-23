<?php
/**
 * Shop archive per language.
 *
 * WooCommerce serves products at the shop page's slug (e.g. `shop`) and Polylang only
 * prefixes it, so the other language got /en/shop/ while /en/<translated-slug>/, the
 * translated page its menus link to, rendered as an empty page. These hooks make each
 * translation's slug the product archive for its language.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_shop_archive() {
	add_filter( 'rewrite_rules_array', 'store_pll_shop_rewrite_rules' );
	add_action( 'pll_save_post', 'store_pll_flush_on_shop_translation' );
	add_filter( 'option_woocommerce_shop_page_id', 'store_pll_shop_page_option' );
	add_filter( 'post_type_archive_link', 'store_pll_shop_archive_link', 30, 2 );
	add_filter( 'pll_translation_url', 'store_pll_shop_translation_url', 10, 2 );
	add_action( 'template_redirect', 'store_pll_redirect_untranslated_shop' );
}

/** Shop page ID in the default language, whatever the option filter below returns. */
function store_pll_shop_page_id() {
	$shop = (int) get_option( 'woocommerce_shop_page_id' );
	if ( $shop > 0 && function_exists( 'pll_get_post' ) && function_exists( 'pll_default_language' ) ) {
		$shop = (int) ( pll_get_post( $shop, pll_default_language() ) ?: $shop );
	}
	return $shop;
}

/**
 * Archive path for one language: its home prefix relative to the site home, plus the
 * translated page's URI. `('/', '/en/', '<shop-slug>')` → `en/<shop-slug>`.
 */
function store_pll_shop_path( $home_path, $lang_home_path, $page_uri ) {
	$prefix = trim( substr( (string) $lang_home_path, strlen( $home_path ) ), '/' );
	return ltrim( $prefix . '/' . $page_uri, '/' );
}

/** Slug path of each non-default language's shop page, e.g. [ 'en' => 'en/<shop-slug>' ]. */
function store_pll_shop_paths() {
	$shop = store_pll_shop_page_id();
	if ( $shop <= 0 || ! function_exists( 'pll_get_post_translations' ) || ! function_exists( 'PLL' ) ) {
		return array();
	}
	$home  = trailingslashit( wp_parse_url( get_option( 'home' ), PHP_URL_PATH ) ?: '/' ); // Raw option: Polylang filters home_url() per language.
	$paths = array();
	foreach ( pll_get_post_translations( $shop ) as $lang => $id ) {
		$language = PLL()->model->get_language( $lang );
		if ( (int) $id === $shop || ! $language || get_post_status( $id ) !== 'publish' ) {
			continue;
		}
		$paths[ $lang ] = store_pll_shop_path( $home, (string) wp_parse_url( PLL()->links_model->home_url( $language ), PHP_URL_PATH ), get_page_uri( $id ) );
	}
	return $paths;
}

/** Archive and pagination rules for each language path. */
function store_pll_shop_rules( array $paths ) {
	$rules = array();
	foreach ( $paths as $lang => $path ) {
		$base                                      = preg_quote( $path, '#' );
		$rules[ $base . '/?$' ]                    = 'index.php?post_type=product&lang=' . $lang;
		$rules[ $base . '/page/([0-9]{1,})/?$' ] = 'index.php?post_type=product&lang=' . $lang . '&paged=$matches[1]';
	}
	return $rules;
}

function store_pll_shop_rewrite_rules( $rules ) {
	return store_pll_shop_rules( store_pll_shop_paths() ) + $rules;
}

/** The shop page's translations change which rules exist. */
function store_pll_flush_on_shop_translation( $post_id ) {
	$shop = store_pll_shop_page_id();
	if ( 'page' === get_post_type( $post_id ) && in_array( $shop, array_map( 'intval', pll_get_post_translations( $post_id ) ), true ) ) {
		flush_rewrite_rules( false );
	}
}

/**
 * Shop page ID in the current language.
 *
 * Filtered at the option, not at wc_get_page_id(), because themes read
 * `woocommerce_shop_page_id` directly for the page title, breadcrumb and page settings.
 * Only from `wp` on: WooCommerce reads it at init to build the product rewrite rules,
 * and those must stay on the default language's slug whatever language the request
 * that flushed them was in. Own code uses store_pll_shop_page_id() for the raw ID.
 */
function store_pll_shop_page_option( $page_id ) {
	if ( (int) $page_id <= 0 || ! did_action( 'wp' ) || ! function_exists( 'pll_get_post' ) || ( is_admin() && ! wp_doing_ajax() ) ) {
		return $page_id;
	}
	$lang       = store_pll_lang();
	$translated = $lang ? pll_get_post( (int) $page_id, $lang ) : 0;
	return $translated ? (string) $translated : $page_id;
}

function store_pll_shop_archive_link( $link, $post_type ) {
	if ( 'product' !== $post_type || ! function_exists( 'pll_get_post' ) ) {
		return $link;
	}
	$lang = store_pll_lang();
	$shop = store_pll_shop_page_id();
	$id   = $lang ? pll_get_post( $shop, $lang ) : 0;
	return ( $id && (int) $id !== $shop ) ? get_permalink( $id ) : $link;
}

/** Language switcher on the shop archive: Polylang only swaps the prefix. */
function store_pll_shop_translation_url( $url, $lang ) {
	if ( ! function_exists( 'is_shop' ) || ! is_shop() || is_paged() ) {
		return $url;
	}
	$id = pll_get_post( store_pll_shop_page_id(), $lang );
	return $id ? get_permalink( $id ) : $url;
}

/** /en/<default-slug>/ still resolves through WooCommerce's own rule; send it to the translated path. */
function store_pll_redirect_untranslated_shop() {
	if ( ! function_exists( 'is_shop' ) || ! is_post_type_archive( 'product' ) || is_paged() || ! function_exists( 'pll_current_language' ) ) {
		return;
	}
	$paths = store_pll_shop_paths();
	$lang  = pll_current_language();
	if ( empty( $paths[ $lang ] ) ) {
		return;
	}
	$home = (string) wp_parse_url( get_option( 'home' ), PHP_URL_PATH ); // Raw option, as in store_pll_shop_paths().
	if ( ! store_pll_is_shop_request( (string) wp_parse_url( add_query_arg( array() ), PHP_URL_PATH ), $home, $paths[ $lang ] ) ) {
		// add_query_arg() does not encode values: `?s=a%26b` came out as `?s=a&b`.
		wp_safe_redirect( add_query_arg( urlencode_deep( wp_unslash( $_GET ) ), get_post_type_archive_link( 'product' ) ), 301 ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		exit;
	}
}

/**
 * True when a request path is the language's shop path.
 *
 * The shop path is relative to the site home, the request path is not: under a site in a
 * subfolder (`/site/`) the request carries it, and without stripping it the two never match
 * and the redirect above sends the shop to itself forever. Both sides are decoded and
 * lowercased, because WordPress stores a non-ASCII slug percent-encoded in lowercase and a
 * browser sends it in uppercase.
 *
 * @param string $request_path Path of the request, e.g. `/site/en/<slug>/`.
 * @param string $home_path    Path of the site home, e.g. `/site/` or ''.
 * @param string $shop_path    store_pll_shop_paths() entry, e.g. `en/<slug>`.
 */
function store_pll_is_shop_request( $request_path, $home_path, $shop_path ) {
	$norm    = function ( $path ) {
		return strtolower( rawurldecode( trim( (string) $path, '/' ) ) );
	};
	$request = $norm( $request_path );
	$home    = $norm( $home_path );
	if ( '' !== $home ) {
		if ( $request !== $home && 0 !== strpos( $request, $home . '/' ) ) {
			return false;
		}
		$request = ltrim( substr( $request, strlen( $home ) ), '/' );
	}
	return $request === $norm( $shop_path );
}
