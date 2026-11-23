<?php
/**
 * Bootstrap: dependency guard, the one-bridge guard, core loading.
 *
 * Every file under includes/ only defines functions. Hooks are added by the file's
 * store_pll_register_<file>() function, called here, so each file can be loaded in
 * the tests without WordPress.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Core files, in load order: strings defines store_pll_t(), used by later files. */
function store_pll_core_files() {
	return array( 'lang', 'products', 'stock', 'pages', 'shop-archive', 'emails', 'strings', 'attributes', 'cart' );
}

/**
 * Dependencies missing at runtime. `Requires Plugins` already blocks activation without
 * them, but a must-use loader, a renamed folder or Polylang Pro can still get here.
 */
function store_pll_missing_dependencies() {
	$missing = array();
	if ( ! function_exists( 'pll_current_language' ) ) {
		$missing[] = 'Polylang';
	}
	if ( ! class_exists( 'WooCommerce' ) ) {
		$missing[] = 'WooCommerce';
	}
	return $missing;
}

/**
 * True when a plugin header's `Requires Plugins` names both Polylang and WooCommerce:
 * the mark of another bridge between the two.
 */
function store_pll_header_is_bridge( $requires ) {
	$slugs = array_map( 'trim', explode( ',', strtolower( (string) $requires ) ) );
	return in_array( 'woocommerce', $slugs, true ) && (bool) array_intersect( array( 'polylang', 'polylang-pro' ), $slugs );
}

/**
 * Name of another Polylang-WooCommerce bridge running on this site, or ''.
 *
 * Two bridges both replay every stock change on the translations, so one sale takes two
 * units from each of them. Whichever bridge is already there wins: the paid Polylang for
 * WooCommerce, any plugin that defined PLL_WC_BRIDGE first, or any other active plugin
 * whose header requires both Polylang and WooCommerce. The header scan reads files, so
 * its answer is kept until the list of active plugins changes.
 */
function store_pll_other_bridge() {
	if ( defined( 'PLLWC_VERSION' ) ) {
		return 'Polylang for WooCommerce';
	}
	if ( defined( 'PLL_WC_BRIDGE' ) && 'store-polylang' !== PLL_WC_BRIDGE ) {
		return (string) PLL_WC_BRIDGE;
	}
	$active = array_merge(
		(array) get_option( 'active_plugins', array() ),
		array_keys( (array) get_site_option( 'active_sitewide_plugins', array() ) )
	);
	$own    = plugin_basename( STORE_PLL_FILE );
	$hash   = md5( implode( '|', $active ) );
	$cached = get_option( 'store_pll_other_bridge' );
	if ( is_array( $cached ) && isset( $cached['hash'], $cached['name'] ) && $cached['hash'] === $hash ) {
		$name = (string) $cached['name'];
	} else {
		$name = '';
		foreach ( $active as $plugin ) {
			if ( $plugin === $own || ! is_string( $plugin ) ) {
				continue;
			}
			$file = WP_PLUGIN_DIR . '/' . $plugin;
			if ( ! is_readable( $file ) ) {
				continue;
			}
			$data = get_file_data( $file, array( 'name' => 'Plugin Name', 'requires' => 'Requires Plugins' ) );
			if ( store_pll_header_is_bridge( $data['requires'] ) ) {
				$name = '' !== $data['name'] ? $data['name'] : $plugin;
				break;
			}
		}
		update_option( 'store_pll_other_bridge', array( 'hash' => $hash, 'name' => $name ), true );
	}
	return (string) apply_filters( 'store_pll_other_bridge', $name );
}

/** Require each file of $dir and call its store_pll_register_<file>() if it has one. */
function store_pll_load( $dir, array $files ) {
	foreach ( $files as $file ) {
		require_once $dir . $file . '.php';
		$register = 'store_pll_register_' . str_replace( '-', '_', $file );
		if ( function_exists( $register ) ) {
			$register();
		}
	}
}

/** One admin notice for administrators, when the bridge stands down. */
function store_pll_notice( $message ) {
	add_action( 'admin_notices', function () use ( $message ) {
		if ( ! current_user_can( 'activate_plugins' ) ) {
			return;
		}
		echo '<div class="notice notice-error"><p>' . esc_html( $message ) . '</p></div>';
	} );
}

function store_pll_boot() {
	$missing = store_pll_missing_dependencies();
	if ( $missing ) {
		/* translators: %s: comma-separated plugin names. */
		store_pll_notice( sprintf( __( 'Store Polylang is not running: %s is missing.', 'store-polylang' ), implode( ', ', $missing ) ) );
		return;
	}
	$other = store_pll_other_bridge();
	if ( '' !== $other ) {
		/* translators: %s: name of the other plugin. */
		store_pll_notice( sprintf( __( 'Store Polylang is not running: %s already connects Polylang and WooCommerce, and with two of them every sale would leave stock twice. Deactivate one.', 'store-polylang' ), $other ) );
		return;
	}
	if ( ! defined( 'PLL_WC_BRIDGE' ) ) {
		define( 'PLL_WC_BRIDGE', 'store-polylang' );
	}
	store_pll_load( STORE_PLL_DIR . 'includes/core/', store_pll_core_files() );
	add_action( 'init', 'store_pll_load_textdomain' );
}

function store_pll_load_textdomain() {
	load_plugin_textdomain( 'store-polylang', false, dirname( plugin_basename( STORE_PLL_FILE ) ) . '/languages' );
}

/**
 * Activation: drop the rewrite rules so WordPress rebuilds them, on the next request,
 * with the per-language shop paths (see shop-archive.php); forget the last bridge scan;
 * then record which gateways have translatable settings (see strings.php). The boot
 * already ran on this request's plugins_loaded without this plugin, so the file is
 * loaded here directly.
 */
function store_pll_activate() {
	delete_option( 'rewrite_rules' );
	delete_option( 'store_pll_other_bridge' );
	if ( ! function_exists( 'WC' ) ) {
		return;
	}
	require_once STORE_PLL_DIR . 'includes/core/lang.php';
	require_once STORE_PLL_DIR . 'includes/core/strings.php';
	store_pll_refresh_gateway_options();
}

/**
 * Deactivation: drop the rewrite rules too, so a site left without the plugin doesn't
 * keep serving the per-language shop paths this plugin added.
 */
function store_pll_deactivate() {
	delete_option( 'rewrite_rules' );
	delete_option( 'store_pll_other_bridge' );
}
