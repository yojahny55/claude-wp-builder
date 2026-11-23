<?php
/**
 * woo-launch.php -- the WordPress side of bin/woo-launch.mjs (/wp-woo-launch): what a store
 * needs before it takes real money, and the launch itself, in a fixed order.
 *
 * Usage: wp eval-file woo-launch.php check <tier>
 *        wp eval-file woo-launch.php apply <tier>
 *        wp eval-file woo-launch.php revert
 *   <tier>  catalog | store | full -- the manifest's store.tier
 *   The arguments are bare words: `wp eval-file` refuses a --flag it does not know.
 *
 * check   writes nothing. Prints `facts: {"home":…,"environment":…}`, then one line per
 *         precondition, `pass <id>: detail` or `fail <id>: detail`, and `check: N passed, N failed`.
 *           environment  wp_get_environment_type() is production
 *           stripe:*     selling tiers: the gateway is active and the three live Stripe keys are
 *                        STORE_KIT_STRIPE_* constants with live prefixes (the webhook secret too)
 *           turnstile:*  selling tiers: the plugin is active and CF_TURNSTILE_SITE_KEY and
 *                        CF_TURNSTILE_SECRET_KEY are real keys the plugin reads, not Cloudflare's
 *                        test keys
 *         It never writes a key: the operator puts them in wp-config.php.
 * apply   runs check first and refuses (`refused:`, exit 1, nothing written) on any fail. Then, in
 *         this order, each step skipped when it is already done: Stripe live (testmode no,
 *         enabled yes), cash on delivery off, Turnstile on the checkout, and coming soon off last.
 *         Every write is read back; one that did not land prints `fail <id>` and stops with the
 *         store still coming soon (exit 1). A re-run starts again and skips what is done.
 * revert  coming soon on, nothing else: the payment settings stay live behind the placeholder.
 *
 * Lines: `set <id>` changed, `ok <id>` already so, `fail <id>` did not land or does not hold,
 * `pass <id>` precondition holds. Exit 0, or 1 on any fail or refusal.
 *
 * PHP 7.4 floor.
 */

/** Cloudflare's documented Turnstile test keys (site keys end AA, AB, BA, BB or FF; secrets AA). */
const WOOLAUNCH_TURNSTILE_TEST_KEY = '/^[123]x0{20,}[A-F]{2}$/';

const WOOLAUNCH_STRIPE_PLUGIN    = 'woocommerce-gateway-stripe/woocommerce-gateway-stripe.php';
const WOOLAUNCH_TURNSTILE_PLUGIN = 'simple-cloudflare-turnstile/simple-cloudflare-turnstile.php';

function woolaunch_refuse( $message ) {
	WP_CLI::line( 'refused: ' . $message );
	WP_CLI::halt( 1 );
}

/** The preconditions, as rows of [ status, id, detail ]. */
function woolaunch_check( $sells ) {
	$rows = array();
	$env  = wp_get_environment_type();
	$rows[] = 'production' === $env
		? array( 'pass', 'environment', 'production' )
		: array( 'fail', 'environment', "reads as $env: a store launches only on production (WP_ENVIRONMENT_TYPE)" );
	if ( ! $sells ) {
		return $rows;
	}
	if ( ! function_exists( 'is_plugin_active' ) ) {
		require_once ABSPATH . 'wp-admin/includes/plugin.php';
	}

	$rows[] = is_plugin_active( WOOLAUNCH_STRIPE_PLUGIN )
		? array( 'pass', 'stripe:plugin', 'WooCommerce Stripe Gateway is active' )
		: array( 'fail', 'stripe:plugin', 'WooCommerce Stripe Gateway is not active' );
	$supplied   = store_kit_stripe_supplied();
	$mismatches = store_kit_stripe_mismatches();
	$fields     = store_kit_stripe_fields();
	foreach ( array( 'secret_key', 'publishable_key', 'webhook_secret' ) as $field ) {
		$constant = $fields[ $field ];
		if ( isset( $supplied[ $field ] ) ) {
			$rows[] = array( 'pass', "stripe:$field", "$constant is set, value not shown" );
		} elseif ( isset( $mismatches[ $field ] ) ) {
			$rows[] = array( 'fail', "stripe:$field", "$constant does not look like a live Stripe key (" . implode( ', ', store_kit_stripe_prefixes()[ $field ] ) . '): store-kit ignores it' );
		} else {
			$rows[] = array( 'fail', "stripe:$field", "$constant is not defined in wp-config.php" . ( 'webhook_secret' === $field ? ': without it Stripe\'s live webhooks are not verified' : '' ) );
		}
	}

	if ( ! is_plugin_active( WOOLAUNCH_TURNSTILE_PLUGIN ) ) {
		$rows[] = array( 'fail', 'turnstile:plugin', 'Simple Cloudflare Turnstile is not active: the checkout would have no bot check' );
		return $rows;
	}
	$rows[] = array( 'pass', 'turnstile:plugin', 'Simple Cloudflare Turnstile is active' );
	foreach ( array( 'cfturnstile_key' => 'CF_TURNSTILE_SITE_KEY', 'cfturnstile_secret' => 'CF_TURNSTILE_SECRET_KEY' ) as $option => $constant ) {
		$value = defined( $constant ) ? (string) constant( $constant ) : '';
		if ( '' === $value ) {
			$rows[] = array( 'fail', "turnstile:$option", "$constant is not defined in wp-config.php" );
		} elseif ( preg_match( WOOLAUNCH_TURNSTILE_TEST_KEY, $value ) ) {
			$rows[] = array( 'fail', "turnstile:$option", "$constant is Cloudflare's test key: it checks nothing" );
		} elseif ( (string) get_option( $option, '' ) !== $value ) {
			// The plugin reads the constant through an option filter; a version without it ignores it.
			$rows[] = array( 'fail', "turnstile:$option", "$constant is set but the plugin reads another value: this version does not take its keys from wp-config.php" );
		} else {
			$rows[] = array( 'pass', "turnstile:$option", "$constant is set, value not shown" );
		}
	}
	return $rows;
}

/** One launch value: skipped when already so, written and read back otherwise. False when the write did not land. */
function woolaunch_step( $id, $get, $set, $want ) {
	if ( call_user_func( $get ) === $want ) {
		WP_CLI::line( "ok $id" );
		return true;
	}
	call_user_func( $set, $want );
	wp_cache_delete( 'alloptions', 'options' );
	if ( call_user_func( $get ) !== $want ) {
		WP_CLI::line( "fail $id: the write did not land; the store is still coming soon" );
		return false;
	}
	WP_CLI::line( "set $id" );
	return true;
}

function woolaunch_option( $id, $option, $want ) {
	return woolaunch_step(
		$id,
		function () use ( $option ) {
			$v = get_option( $option, null );
			return null === $v ? null : (string) $v;
		},
		function ( $v ) use ( $option ) {
			update_option( $option, $v );
		},
		$want
	);
}

function woolaunch_suboption( $id, $option, $key, $want ) {
	return woolaunch_step(
		$id,
		function () use ( $option, $key ) {
			$o = get_option( $option, array() );
			return is_array( $o ) && isset( $o[ $key ] ) ? (string) $o[ $key ] : null;
		},
		function ( $v ) use ( $option, $key ) {
			$o         = get_option( $option, array() );
			$o         = is_array( $o ) ? $o : array();
			$o[ $key ] = $v;
			update_option( $option, $o );
		},
		$want
	);
}

$woolaunch_argv = isset( $args ) ? array_values( (array) $args ) : array();
$woolaunch_mode = isset( $woolaunch_argv[0] ) ? (string) $woolaunch_argv[0] : '';
$woolaunch_tier = isset( $woolaunch_argv[1] ) ? (string) $woolaunch_argv[1] : '';
if ( ! in_array( $woolaunch_mode, array( 'check', 'apply', 'revert' ), true )
	|| ( 'revert' !== $woolaunch_mode && ! in_array( $woolaunch_tier, array( 'catalog', 'store', 'full' ), true ) ) ) {
	woolaunch_refuse( 'usage: wp eval-file woo-launch.php check|apply <catalog|store|full>, or revert' );
}
if ( ! class_exists( 'WooCommerce' ) ) {
	woolaunch_refuse( 'WooCommerce is not active' );
}
if ( ! defined( 'STORE_KIT_VERSION' ) ) {
	woolaunch_refuse( 'store-kit is not active -- /wp-woo-setup copies and activates it' );
}

if ( 'revert' === $woolaunch_mode ) {
	$woolaunch_ok = woolaunch_option( 'coming-soon', 'woocommerce_coming_soon', 'yes' );
	WP_CLI::line( $woolaunch_ok ? 'revert: the store is coming soon again' : 'revert: coming soon did not take' );
	WP_CLI::halt( $woolaunch_ok ? 0 : 1 );
}

$woolaunch_sells = 'catalog' !== $woolaunch_tier;
WP_CLI::line( 'facts: ' . wp_json_encode( array( 'home' => home_url( '/' ), 'environment' => wp_get_environment_type() ) ) );
$woolaunch_rows = woolaunch_check( $woolaunch_sells );
$woolaunch_fail = 0;
foreach ( $woolaunch_rows as $woolaunch_row ) {
	WP_CLI::line( $woolaunch_row[0] . ' ' . $woolaunch_row[1] . ': ' . $woolaunch_row[2] );
	$woolaunch_fail += 'fail' === $woolaunch_row[0] ? 1 : 0;
}
WP_CLI::line( sprintf( 'check: %d passed, %d failed', count( $woolaunch_rows ) - $woolaunch_fail, $woolaunch_fail ) );
if ( 'check' === $woolaunch_mode ) {
	WP_CLI::halt( $woolaunch_fail ? 1 : 0 );
}
if ( $woolaunch_fail ) {
	woolaunch_refuse( "$woolaunch_fail precondition(s) fail: nothing was written" );
}

// The order is the point: everything that takes money first, the store's visibility last, so a
// step that does not land leaves a store visitors still cannot reach.
$woolaunch_steps = array();
if ( $woolaunch_sells ) {
	$woolaunch_steps[] = function () {
		return woolaunch_suboption( 'stripe:testmode', 'woocommerce_stripe_settings', 'testmode', 'no' );
	};
	$woolaunch_steps[] = function () {
		return woolaunch_suboption( 'stripe:enabled', 'woocommerce_stripe_settings', 'enabled', 'yes' );
	};
	$woolaunch_steps[] = function () {
		return woolaunch_suboption( 'cod:enabled', 'woocommerce_cod_settings', 'enabled', 'no' );
	};
	$woolaunch_steps[] = function () {
		return woolaunch_option( 'turnstile:checkout', 'cfturnstile_woo_checkout', '1' );
	};
	$woolaunch_steps[] = function () {
		// The plugin loads its WooCommerce checks only once tested is yes.
		return woolaunch_option( 'turnstile:tested', 'cfturnstile_tested', 'yes' );
	};
}
$woolaunch_steps[] = function () {
	return woolaunch_option( 'coming-soon', 'woocommerce_coming_soon', 'no' );
};
foreach ( $woolaunch_steps as $woolaunch_step ) {
	if ( ! call_user_func( $woolaunch_step ) ) {
		WP_CLI::halt( 1 );
	}
}
WP_CLI::line( 'launch: the store is live' );
