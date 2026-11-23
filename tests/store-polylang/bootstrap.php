<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
/**
 * Minimal environment to test the plugin logic without WordPress.
 * Each *-test.php file runs in its own process (see run.php), so the stubs and
 * constants a test declares do not affect the others.
 */

define( 'ABSPATH', __DIR__ . '/' );
define( 'STORE_PLL_DIR', dirname( __DIR__, 2 ) . '/plugins/store-polylang/' );
define( 'STORE_PLL_FILE', STORE_PLL_DIR . 'store-polylang.php' );
define( 'STORE_PLL_VERSION', 'test' );
define( 'WP_PLUGIN_DIR', sys_get_temp_dir() . '/wpll-plugins-' . getmypid() );

$GLOBALS['wpll'] = array(
	'hooks'      => array(),
	'filters'    => array(),
	'checks'     => 0,
	'failures'   => array(),
	'is_admin'   => false,
	'doing_ajax' => false,
	'options'    => array(),
	'site_options' => array(),
	'file_data'  => array(),
	'file_reads' => 0,
);

function add_filter( $hook, $callback, $priority = 10, $args = 1 ) {
	$GLOBALS['wpll']['hooks'][] = array( 'hook' => $hook, 'callback' => $callback, 'priority' => $priority, 'args' => $args );
	return true;
}

function add_action( $hook, $callback, $priority = 10, $args = 1 ) {
	return add_filter( $hook, $callback, $priority, $args );
}

function apply_filters( $hook, $value, ...$args ) {
	return isset( $GLOBALS['wpll']['filters'][ $hook ] ) ? $GLOBALS['wpll']['filters'][ $hook ]( $value, ...$args ) : $value;
}

function is_admin() {
	return $GLOBALS['wpll']['is_admin'];
}

function wp_doing_ajax() {
	return $GLOBALS['wpll']['doing_ajax'];
}

function get_option( $name, $default = false ) {
	return $GLOBALS['wpll']['options'][ $name ] ?? $default;
}

function update_option( $name, $value, $autoload = null ) {
	$GLOBALS['wpll']['options'][ $name ] = $value;
	return true;
}

function get_site_option( $name, $default = false ) {
	return $GLOBALS['wpll']['site_options'][ $name ] ?? $default;
}

/** Reads the fake map $GLOBALS['wpll']['file_data'][ $file ] = array( 'Plugin Name' => ..., ... ). */
function get_file_data( $file, $headers ) {
	$GLOBALS['wpll']['file_reads']++;
	$map  = $GLOBALS['wpll']['file_data'][ $file ] ?? array();
	$data = array();
	foreach ( $headers as $key => $header ) {
		$data[ $key ] = $map[ $header ] ?? '';
	}
	return $data;
}

function plugin_basename( $file ) {
	return basename( dirname( $file ) ) . '/' . basename( $file );
}

function esc_attr( $text ) {
	return htmlspecialchars( (string) $text, ENT_QUOTES, 'UTF-8' );
}

function esc_html( $text ) {
	return htmlspecialchars( (string) $text, ENT_QUOTES, 'UTF-8' );
}

function esc_url( $url ) {
	return (string) $url;
}

function __( $text, $domain = 'default' ) {
	return $text;
}

function trailingslashit( $value ) {
	return rtrim( $value, '/\\' ) . '/';
}

/** The registration of $callback on $hook: ['priority' => int, 'args' => int], or null. */
function wpll_hook( $hook, $callback ) {
	foreach ( $GLOBALS['wpll']['hooks'] as $h ) {
		if ( $h['hook'] === $hook && $h['callback'] === $callback ) {
			return array( 'priority' => $h['priority'], 'args' => $h['args'] );
		}
	}
	return null;
}

function wpll_check( $condition, $message ) {
	$GLOBALS['wpll']['checks']++;
	if ( ! $condition ) {
		$GLOBALS['wpll']['failures'][] = $message;
	}
}

function wpll_same( $expected, $actual, $message ) {
	wpll_check(
		$expected === $actual,
		$message . "\n    expected: " . var_export( $expected, true ) . "\n    actual: " . var_export( $actual, true )
	);
}
