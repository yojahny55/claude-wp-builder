<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/boot.php';

wpll_same( array( 'Polylang', 'WooCommerce' ), store_pll_missing_dependencies(), 'without Polylang and WooCommerce both are missing' );

wpll_same( array( 'lang', 'products', 'stock', 'pages', 'shop-archive', 'emails', 'strings', 'attributes', 'cart' ), store_pll_core_files(), 'core load order' );

// A header that requires both Polylang and WooCommerce marks another bridge.
wpll_check( store_pll_header_is_bridge( 'polylang, woocommerce' ), 'polylang + woocommerce is a bridge' );
wpll_check( store_pll_header_is_bridge( 'WooCommerce,Polylang-Pro' ), 'case and spacing are ignored, polylang-pro counts' );
wpll_check( ! store_pll_header_is_bridge( 'woocommerce' ), 'woocommerce alone is not a bridge' );
wpll_check( ! store_pll_header_is_bridge( 'polylang' ), 'polylang alone is not a bridge' );
wpll_check( ! store_pll_header_is_bridge( '' ), 'empty header is not a bridge' );

// store_pll_other_bridge(): active plugins are read from the fake options, headers from the fake map.
$plugins = WP_PLUGIN_DIR . '/';
@mkdir( WP_PLUGIN_DIR );
foreach ( array( 'other-bridge', 'plain', 'store-polylang', 'network-bridge' ) as $slug ) {
	@mkdir( $plugins . $slug );
	file_put_contents( $plugins . $slug . '/' . $slug . '.php', '<?php' );
}
$GLOBALS['wpll']['file_data'] = array(
	$plugins . 'other-bridge/other-bridge.php'       => array( 'Plugin Name' => 'Other Bridge', 'Requires Plugins' => 'woocommerce, polylang' ),
	$plugins . 'plain/plain.php'                     => array( 'Plugin Name' => 'Plain', 'Requires Plugins' => 'woocommerce' ),
	$plugins . 'store-polylang/store-polylang.php'   => array( 'Plugin Name' => 'Store Polylang', 'Requires Plugins' => 'polylang, woocommerce' ),
	$plugins . 'network-bridge/network-bridge.php'   => array( 'Plugin Name' => 'Network Bridge', 'Requires Plugins' => 'woocommerce, polylang-pro' ),
);

$GLOBALS['wpll']['options']['active_plugins'] = array( 'plain/plain.php' );
wpll_same( '', store_pll_other_bridge(), 'no other bridge active: empty string' );

$GLOBALS['wpll']['options']['active_plugins'] = array( 'store-polylang/store-polylang.php', 'plain/plain.php' );
wpll_same( '', store_pll_other_bridge(), 'its own basename is ignored' );

$GLOBALS['wpll']['options']['active_plugins'] = array( 'plain/plain.php', 'other-bridge/other-bridge.php' );
wpll_same( 'Other Bridge', store_pll_other_bridge(), 'an active plugin requiring polylang + woocommerce is reported by its Plugin Name' );

// Cache: same active list, no new header reads.
$reads = $GLOBALS['wpll']['file_reads'];
wpll_same( 'Other Bridge', store_pll_other_bridge(), 'cached answer is the same' );
wpll_same( $reads, $GLOBALS['wpll']['file_reads'], 'unchanged active list: headers are not read again' );
wpll_same( 'Other Bridge', $GLOBALS['wpll']['options']['store_pll_other_bridge']['name'], 'the answer is stored in the option' );

// The active list changes: rescan.
$GLOBALS['wpll']['options']['active_plugins'] = array( 'plain/plain.php' );
wpll_same( '', store_pll_other_bridge(), 'changed active list: rescanned, no bridge any more' );
wpll_check( $GLOBALS['wpll']['file_reads'] > $reads, 'changed active list: headers are read again' );

// Network-active plugins count too.
$GLOBALS['wpll']['site_options']['active_sitewide_plugins'] = array( 'network-bridge/network-bridge.php' => 1 );
wpll_same( 'Network Bridge', store_pll_other_bridge(), 'a network-active bridge is found' );
$GLOBALS['wpll']['site_options'] = array();

// The filter has the last word.
$GLOBALS['wpll']['filters']['store_pll_other_bridge'] = function ( $name ) {
	return 'Forced';
};
wpll_same( 'Forced', store_pll_other_bridge(), 'the store_pll_other_bridge filter can override the result' );
$GLOBALS['wpll']['filters']['store_pll_other_bridge'] = function ( $name ) {
	return '';
};
$GLOBALS['wpll']['options']['active_plugins'] = array( 'other-bridge/other-bridge.php' );
wpll_same( '', store_pll_other_bridge(), 'the filter can also clear a detected bridge' );
unset( $GLOBALS['wpll']['filters']['store_pll_other_bridge'] );

foreach ( array( 'other-bridge', 'plain', 'store-polylang', 'network-bridge' ) as $slug ) {
	unlink( $plugins . $slug . '/' . $slug . '.php' );
	rmdir( $plugins . $slug );
}
rmdir( WP_PLUGIN_DIR );

// store_pll_load() calls store_pll_register_<file>() when it exists.
$dir = sys_get_temp_dir() . '/wpll-load-' . getmypid() . '/';
@mkdir( $dir );
file_put_contents( $dir . 'fake-area.php', '<?php function store_pll_register_fake_area() { $GLOBALS["wpll"]["registered"] = true; }' );
file_put_contents( $dir . 'plain.php', '<?php function wpll_plain_loaded() {}' );
store_pll_load( $dir, array( 'fake-area', 'plain' ) );
wpll_check( ! empty( $GLOBALS['wpll']['registered'] ), 'store_pll_load calls the file register function' );
wpll_check( function_exists( 'wpll_plain_loaded' ), 'store_pll_load loads files without a register function' );
array_map( 'unlink', glob( $dir . '*.php' ) );
rmdir( $dir );

function delete_option( $name ) {
	$GLOBALS['wpll']['deleted_options'][] = $name;
	return true;
}

function current_user_can( $cap ) {
	return ! empty( $GLOBALS['wpll']['can'][ $cap ] );
}

// Activation and deactivation must force the rewrite rules to be rebuilt
// (the per-language shop paths of shop-archive.php), without depending on WooCommerce.
$GLOBALS['wpll']['deleted_options'] = array();
store_pll_activate();
wpll_check( in_array( 'rewrite_rules', $GLOBALS['wpll']['deleted_options'], true ), 'activate() deletes rewrite_rules' );
wpll_check( in_array( 'store_pll_other_bridge', $GLOBALS['wpll']['deleted_options'], true ), 'activate() forgets the bridge scan' );

$GLOBALS['wpll']['deleted_options'] = array();
store_pll_deactivate();
wpll_same( array( 'rewrite_rules', 'store_pll_other_bridge' ), $GLOBALS['wpll']['deleted_options'], 'deactivate() deletes rewrite_rules and the bridge scan cache' );

// The missing-dependencies notice is only shown to those who can activate plugins.
$GLOBALS['wpll']['hooks'] = array();
store_pll_boot();
$notices = array_values( array_filter( $GLOBALS['wpll']['hooks'], function ( $h ) {
	return 'admin_notices' === $h['hook'];
} ) );
wpll_check( ! empty( $notices ), 'boot() registers the missing-dependencies notice' );
if ( $notices ) {
	$callback               = end( $notices )['callback'];
	$GLOBALS['wpll']['can'] = array();
	ob_start();
	$callback();
	wpll_same( '', ob_get_clean(), 'without activate_plugins: no notice' );

	$GLOBALS['wpll']['can'] = array( 'activate_plugins' => true );
	ob_start();
	$callback();
	wpll_check( false !== strpos( ob_get_clean(), 'notice-error' ), 'with activate_plugins: notice shown' );
}
