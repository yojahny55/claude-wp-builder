<?php
/**
 * store-audit.php -- the WordPress side of bin/store-audit.mjs: the store checks that read the
 * database rather than visit the site, STORE-005 to STORE-014 of agents/wp-audit-store.md. It
 * writes nothing: no option, no transient, no post.
 *
 * Usage: wp eval-file store-audit.php <tier> <block>
 *        wp eval-file store-audit.php tier
 *   <tier>   catalog | store | full -- the recorded tier, or the one the caller inferred
 *   <block>  yes | no -- whether the manifest has a `store` block, that is, whether
 *            /wp-woo-setup's launch policy (cash on delivery only on a local site) applies
 *   The arguments are bare words: `wp eval-file` refuses a --flag it does not know.
 *
 * `tier` prints { tier } for a store with no `store` block: catalog when store-kit's catalog mode
 * is on, store otherwise (the audit checks do not tell store from full).
 *
 * Otherwise prints one JSON line: { environment, checks: [ { check, status, severity, ownership,
 * resource, message, evidence } ] }, status pass, fail or na. A check that does not apply to
 * the tier is `na` with the reason in `message`.
 *
 * PHP 7.4 floor.
 */

/** Cloudflare's documented Turnstile test site keys: always pass, always block, or challenge (AA, AB, BA, BB, FF). */
const STOREAUDIT_TURNSTILE_TEST_KEY = '/^[123]x0{20}[A-F]{2}$/';

/** How many ids a finding lists before it says "and N more". */
const STOREAUDIT_LIST = 10;

function storeaudit_refuse( $message ) {
	WP_CLI::line( 'refused: ' . $message );
	WP_CLI::halt( 1 );
}

/** One check's row. */
function storeaudit_row( $check, $status, $severity, $ownership, $resource, $message, $evidence = '' ) {
	return array(
		'check'     => $check,
		'status'    => $status,
		'severity'  => $severity,
		'ownership' => $ownership,
		'resource'  => $resource,
		'message'   => $message,
		'evidence'  => $evidence,
	);
}

function storeaudit_na( $check, $why ) {
	return storeaudit_row( $check, 'na', '', '', 'site', $why );
}

/** "12, 14, 19" or "12, 14 … and 31 more". */
function storeaudit_ids( array $ids ) {
	$more = count( $ids ) - STOREAUDIT_LIST;
	return implode( ', ', array_slice( $ids, 0, STOREAUDIT_LIST ) ) . ( $more > 0 ? " and $more more" : '' );
}

/** A page option's page: [ id, published ]. */
function storeaudit_page( $option ) {
	$id = (int) get_option( $option, 0 );
	return array( $id, $id > 0 && 'publish' === get_post_status( $id ) );
}

/** STORE-005 to STORE-007: the policy pages a checkout links to. */
function storeaudit_policy_page( $check, $option, $label, $applies, $why_na ) {
	if ( ! $applies ) {
		return storeaudit_na( $check, $why_na );
	}
	list( $id, $published ) = storeaudit_page( $option );
	// Setup publishes an empty terms page for the client to fill: published is not written.
	$empty = $published && '' === trim( wp_strip_all_tags( (string) get_post_field( 'post_content', $id ) ) );
	if ( $published && ! $empty ) {
		return storeaudit_row( $check, 'pass', '', '', "wp_options.$option", "the $label page is published", "$option = $id" );
	}
	if ( $empty ) {
		$state = 'is published empty';
	} else {
		$state = $id > 0 ? 'is ' . ( get_post_status( $id ) ? get_post_status( $id ) : 'missing' ) : 'is not set';
	}
	return storeaudit_row( $check, 'fail', 'WARNING', 'content', "wp_options.$option", "the $label page $state: the checkout has no $label to link to", "$option = $id" );
}

/** The host a sender address should share with the site, without a leading www. */
function storeaudit_host( $url ) {
	$host = strtolower( (string) wp_parse_url( $url, PHP_URL_HOST ) );
	return 0 === strpos( $host, 'www.' ) ? substr( $host, 4 ) : $host;
}

function storeaudit_email( $production ) {
	$from      = (string) get_option( 'woocommerce_email_from_address', '' );
	$name      = trim( (string) get_option( 'woocommerce_email_from_name', '' ) );
	$new_order = get_option( 'woocommerce_new_order_settings', array() );
	$recipient = is_array( $new_order ) && ! empty( $new_order['recipient'] ) ? (string) $new_order['recipient'] : (string) get_option( 'admin_email' );
	$site      = storeaudit_host( home_url() );
	$domain    = strtolower( (string) substr( strrchr( $from, '@' ), 1 ) );
	$problems  = array();
	if ( ! is_email( $from ) ) {
		$problems[] = 'the sender address "' . $from . '" is not an email address';
	} elseif ( '' !== $site && $domain !== $site && ! preg_match( '/\.' . preg_quote( $domain, '/' ) . '$/', $site ) && ! preg_match( '/\.' . preg_quote( $site, '/' ) . '$/', $domain ) ) {
		$problems[] = "the sender address is on $domain, not the site's $site: receiving servers that check SPF and DMARC reject or junk it";
	}
	if ( '' === $name ) {
		$problems[] = 'the sender name is empty';
	}
	foreach ( array_map( 'trim', explode( ',', $recipient ) ) as $r ) {
		if ( ! is_email( $r ) ) {
			$problems[] = 'the new-order recipient "' . $r . '" is not an email address';
		}
	}
	$evidence = "woocommerce_email_from_address = $from; woocommerce_email_from_name = $name; new-order recipient = $recipient; home host = $site";
	if ( ! $problems ) {
		return storeaudit_row( 'STORE-008', 'pass', '', '', 'wp_options.woocommerce_email_from_address', 'the store emails have a sender on the site domain and a recipient', $evidence );
	}
	// A local or staging site runs on another host than production: the domain is a launch item.
	return storeaudit_row( 'STORE-008', 'fail', $production ? 'WARNING' : 'INFO', 'setting', 'wp_options.woocommerce_email_from_address', implode( '; ', $problems ), $evidence );
}

/** Published products that need shipping: not virtual, not downloadable-only, not External. */
function storeaudit_shippable() {
	$ids = array();
	foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => -1, 'return' => 'objects', 'type' => array( 'simple', 'variable' ) ) ) as $p ) {
		if ( $p->needs_shipping() ) {
			$ids[] = $p->get_id();
		}
	}
	return $ids;
}

function storeaudit_shipping( $sells ) {
	if ( ! $sells ) {
		return storeaudit_na( 'STORE-009', 'a catalog ships nothing' );
	}
	if ( ! wc_shipping_enabled() ) {
		return storeaudit_row( 'STORE-009', 'pass', '', '', 'wp_options.woocommerce_ship_to_countries', 'shipping is switched off: the checkout asks for no address', 'woocommerce_ship_to_countries = disabled' );
	}
	$shippable = storeaudit_shippable();
	if ( ! $shippable ) {
		return storeaudit_row( 'STORE-009', 'pass', '', '', 'site', 'no published product needs shipping' );
	}
	$base    = wc_get_base_location();
	$package = array(
		'destination' => array(
			'country'  => $base['country'],
			'state'    => $base['state'],
			'postcode' => (string) get_option( 'woocommerce_store_postcode', '' ),
		),
	);
	$zone    = WC_Shipping_Zones::get_zone_matching_package( $package );
	$methods = array();
	foreach ( $zone->get_shipping_methods( true ) as $m ) {
		$methods[] = $m->id;
	}
	$where    = $base['country'] . ( $base['state'] ? ':' . $base['state'] : '' );
	$evidence = 'zone "' . $zone->get_zone_name() . '" (id ' . $zone->get_id() . ') matches the store address ' . $where . '; enabled methods: ' . ( $methods ? implode( ', ', $methods ) : 'none' );
	if ( $methods ) {
		return storeaudit_row( 'STORE-009', 'pass', '', '', 'shipping_zone:' . $zone->get_id(), 'a shopper at the store address gets a shipping method', $evidence );
	}
	return storeaudit_row( 'STORE-009', 'fail', 'CRITICAL', 'setting', 'shipping_zone:' . $zone->get_id(), count( $shippable ) . ' product(s) need shipping and the zone that covers the store address has no enabled method: the checkout cannot be completed there', $evidence );
}

function storeaudit_tax( $sells ) {
	global $wpdb;
	if ( ! $sells ) {
		return storeaudit_na( 'STORE-010', 'a catalog charges no tax' );
	}
	if ( ! wc_tax_enabled() ) {
		return storeaudit_row( 'STORE-010', 'pass', '', '', 'wp_options.woocommerce_calc_taxes', 'taxes are off: whether the store must charge tax is the merchant\'s decision, not measured here', 'woocommerce_calc_taxes = no' );
	}
	$rates = (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}woocommerce_tax_rates" );
	if ( $rates > 0 ) {
		return storeaudit_row( 'STORE-010', 'pass', '', '', 'wp_options.woocommerce_calc_taxes', "taxes are on with $rates rate(s)", "woocommerce_calc_taxes = yes; tax rates = $rates" );
	}
	return storeaudit_row( 'STORE-010', 'fail', 'WARNING', 'setting', 'wp_options.woocommerce_calc_taxes', 'taxes are on and there is no tax rate: every order is charged no tax while the store says it calculates it', 'woocommerce_calc_taxes = yes; tax rates = 0' );
}

function storeaudit_products( $sells ) {
	$default  = (int) get_option( 'default_product_cat', 0 );
	$no_price = array();
	$no_image = array();
	$no_cat   = array();
	$total    = 0;
	foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => -1, 'return' => 'objects' ) ) as $p ) {
		++$total;
		$id = $p->get_id();
		// A variable product's price is its variations'; a grouped one has none of its own.
		if ( $sells && ! $p->is_type( 'grouped' ) && '' === (string) $p->get_price() ) {
			$no_price[] = $id;
		}
		if ( ! $p->get_image_id() ) {
			$no_image[] = $id;
		}
		if ( ! array_diff( array_map( 'intval', $p->get_category_ids() ), array( $default ) ) ) {
			$no_cat[] = $id;
		}
	}
	if ( ! $total ) {
		return storeaudit_na( 'STORE-011', 'no published product; STORE-003 reports an empty shop' );
	}
	$problems = array();
	if ( $no_price ) {
		$problems[] = count( $no_price ) . ' without a price, which WooCommerce will not sell (' . storeaudit_ids( $no_price ) . ')';
	}
	if ( $no_image ) {
		$problems[] = count( $no_image ) . ' without an image (' . storeaudit_ids( $no_image ) . ')';
	}
	if ( $no_cat ) {
		$problems[] = count( $no_cat ) . ' only in the default category (' . storeaudit_ids( $no_cat ) . ')';
	}
	if ( ! $problems ) {
		return storeaudit_row( 'STORE-011', 'pass', '', '', 'site', "all $total published product(s) have " . ( $sells ? 'a price, ' : '' ) . 'an image and a category' );
	}
	return storeaudit_row( 'STORE-011', 'fail', $no_price ? 'CRITICAL' : 'WARNING', 'content', 'site', "of $total published product(s): " . implode( '; ', $problems ), 'product ids as listed' );
}

function storeaudit_scheduler() {
	global $wpdb;
	$table = $wpdb->prefix . 'actionscheduler_actions';
	if ( $table !== $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $table ) ) ) {
		return storeaudit_na( 'STORE-012', 'Action Scheduler has no table on this site' );
	}
	$since = gmdate( 'Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS );
	$sum   = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $table WHERE status = 'failed' AND last_attempt_gmt >= %s", $since ) );
	if ( ! $sum ) {
		return storeaudit_row( 'STORE-012', 'pass', '', '', "$table", 'no scheduled action failed in the last 7 days' );
	}
	$rows  = $wpdb->get_results( $wpdb->prepare( "SELECT hook, COUNT(*) AS n FROM $table WHERE status = 'failed' AND last_attempt_gmt >= %s GROUP BY hook ORDER BY n DESC LIMIT 5", $since ) );
	$parts = array();
	foreach ( $rows as $r ) {
		$parts[] = $r->hook . ' x' . $r->n;
	}
	return storeaudit_row( 'STORE-012', 'fail', 'WARNING', 'manual', "$table", "$sum scheduled action(s) failed in the last 7 days -- WooCommerce runs emails, webhooks, stock and analytics through them; most failed hooks: " . implode( ', ', $parts ), "status = failed, last_attempt_gmt >= $since" );
}

function storeaudit_hpos() {
	$class = 'Automattic\\WooCommerce\\Internal\\DataStores\\Orders\\DataSynchronizer';
	if ( ! function_exists( 'wc_get_container' ) || ! class_exists( $class ) ) {
		return storeaudit_na( 'STORE-013', 'this WooCommerce predates order tables (HPOS)' );
	}
	$hpos = 'yes' === get_option( 'woocommerce_custom_orders_table_enabled', 'no' );
	$sync = 'yes' === get_option( 'woocommerce_custom_orders_table_data_sync_enabled', 'no' );
	$evidence = 'woocommerce_custom_orders_table_enabled = ' . ( $hpos ? 'yes' : 'no' ) . '; data_sync_enabled = ' . ( $sync ? 'yes' : 'no' );
	// Without compatibility mode the other storage is not meant to follow, so nothing is pending.
	if ( ! $sync ) {
		return storeaudit_row( 'STORE-013', 'pass', '', '', 'wp_options.woocommerce_custom_orders_table_enabled', 'orders live in ' . ( $hpos ? 'the order tables' : 'posts' ) . ' and compatibility mode is off: nothing is kept in sync', $evidence );
	}
	$pending   = (int) wc_get_container()->get( $class )->get_current_orders_pending_sync_count();
	$evidence .= "; orders pending sync = $pending";
	if ( 0 === $pending ) {
		return storeaudit_row( 'STORE-013', 'pass', '', '', 'wp_options.woocommerce_custom_orders_table_enabled', 'no order waits to be copied between the order tables and posts', $evidence );
	}
	return storeaudit_row( 'STORE-013', 'fail', 'WARNING', 'setting', 'wp_options.woocommerce_custom_orders_table_enabled', "$pending order(s) differ between the order tables and posts: the storage WooCommerce does not read is stale", $evidence );
}

function storeaudit_launch( $sells, $block, $production ) {
	$items = array();
	if ( 'yes' === get_option( 'woocommerce_coming_soon', 'no' ) ) {
		$items[] = 'the store is "coming soon": visitors see a placeholder';
	}
	if ( $sells ) {
		$stripe = get_option( 'woocommerce_stripe_settings', array() );
		if ( is_array( $stripe ) && 'yes' === ( isset( $stripe['enabled'] ) ? $stripe['enabled'] : '' ) && 'yes' === ( isset( $stripe['testmode'] ) ? $stripe['testmode'] : '' ) ) {
			$items[] = 'Stripe is in test mode: no card is charged';
		}
		$cod = get_option( 'woocommerce_cod_settings', array() );
		// Cash on delivery is setup's local test-order gateway; a merchant's own store may take it on purpose.
		if ( $block && is_array( $cod ) && 'yes' === ( isset( $cod['enabled'] ) ? $cod['enabled'] : '' ) ) {
			$items[] = 'cash on delivery is on: setup turns it on only to pay the local test order';
		}
		if ( ! function_exists( 'is_plugin_active' ) ) {
			require_once ABSPATH . 'wp-admin/includes/plugin.php';
		}
		if ( is_plugin_active( 'simple-cloudflare-turnstile/simple-cloudflare-turnstile.php' ) && '' !== (string) get_option( 'cfturnstile_woo_checkout', '' ) ) {
			$key = (string) get_option( 'cfturnstile_key', '' );
			if ( '' === $key || preg_match( STOREAUDIT_TURNSTILE_TEST_KEY, $key ) ) {
				$items[] = 'Turnstile has ' . ( '' === $key ? 'no site key' : "Cloudflare's test site key" ) . ': the checkout has no bot check';
			}
		}
	}
	if ( ! $items ) {
		return storeaudit_row( 'STORE-014', 'pass', '', '', 'site', 'the store is live: no coming-soon page, test payment or test bot check' );
	}
	$env = wp_get_environment_type();
	return storeaudit_row(
		'STORE-014',
		'fail',
		$production ? 'CRITICAL' : 'INFO',
		'manual',
		'site',
		( $production ? 'a production store is not launched: ' : "not launched, as expected on a $env site until launch: " ) . implode( '; ', $items ),
		"wp_get_environment_type() = $env"
	);
}

$storeaudit_argv = isset( $args ) ? array_values( (array) $args ) : array();
if ( ! class_exists( 'WooCommerce' ) ) {
	storeaudit_refuse( 'WooCommerce is not active' );
}
$storeaudit_tier  = isset( $storeaudit_argv[0] ) ? (string) $storeaudit_argv[0] : '';
if ( 'tier' === $storeaudit_tier ) {
	WP_CLI::line( wp_json_encode( array( 'tier' => 'yes' === get_option( 'store_kit_catalog_mode', 'no' ) ? 'catalog' : 'store' ) ) );
	return;
}
$storeaudit_block = isset( $storeaudit_argv[1] ) ? (string) $storeaudit_argv[1] : '';
if ( ! in_array( $storeaudit_tier, array( 'catalog', 'store', 'full' ), true ) || ! in_array( $storeaudit_block, array( 'yes', 'no' ), true ) ) {
	storeaudit_refuse( 'usage: wp eval-file store-audit.php <catalog|store|full> <yes|no> | tier' );
}
$storeaudit_sells      = 'catalog' !== $storeaudit_tier;
$storeaudit_production = 'production' === wp_get_environment_type();
WP_CLI::line(
	wp_json_encode(
		array(
			'environment' => wp_get_environment_type(),
			'checks'      => array(
				storeaudit_policy_page( 'STORE-005', 'woocommerce_terms_page_id', 'terms and conditions', $storeaudit_sells, 'a catalog takes no order to agree terms to' ),
				storeaudit_policy_page( 'STORE-006', 'wp_page_for_privacy_policy', 'privacy policy', true, '' ),
				storeaudit_policy_page( 'STORE-007', 'woocommerce_refund_returns_page_id', 'refund and returns policy', $storeaudit_sells, 'a catalog sells nothing to return' ),
				storeaudit_email( $storeaudit_production ),
				storeaudit_shipping( $storeaudit_sells ),
				storeaudit_tax( $storeaudit_sells ),
				storeaudit_products( $storeaudit_sells ),
				storeaudit_scheduler(),
				storeaudit_hpos(),
				storeaudit_launch( $storeaudit_sells, 'yes' === $storeaudit_block, $storeaudit_production ),
			),
		)
	)
);
