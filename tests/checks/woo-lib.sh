#!/usr/bin/env bash
# woo-lib.php holds the decisions /wp-woo-setup makes -- whose value a setting is, how a zone,
# a location or a tax rate is matched, which Stripe key is live -- and none of them touch
# WordPress, so they run here under bare PHP against inputs chosen to break them.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
lib=skills/wp-woocommerce/scripts/woo-lib.php
[ -r "$lib" ] || fail "$lib is missing or unreadable"
command -v php >/dev/null 2>&1 || fail "php is not on PATH; this check executes the library"
php -l "$lib" >/dev/null 2>&1 || fail "$lib does not parse"

out=$(
LIB="$PWD/$lib" php -d error_reporting=E_ALL -d display_errors=1 <<'PHP' 2>&1
<?php
ob_start();
require getenv( 'LIB' );
if ( '' !== ob_get_clean() ) { echo "MISMATCH [require] the library printed output while being required\n"; exit( 1 ); }
$fail = 0;
function check( $label, $got, $want ) {
	global $fail;
	if ( $got !== $want ) {
		echo "MISMATCH [$label] got: " . var_export( $got, true ) . ' want: ' . var_export( $want, true ) . "\n";
		$fail = 1;
	}
}
// Whose value is it?
check( 'same value is ok', wooset_decide( 'yes', 'yes', null, false, false ), 'ok' );
check( "absent is nobody's choice", wooset_decide( null, 'yes', null, false, false ), 'set' );
check( 'fresh store, no record', wooset_decide( 'no', 'yes', null, true, false ), 'set' );
check( 'store with orders, no record', wooset_decide( 'no', 'yes', null, false, false ), 'client' );
check( 'our own earlier value', wooset_decide( '10.00', '11.00', wooset_hash( '10.00' ), false, false ), 'set' );
check( 'edited after we wrote it, even on a fresh store', wooset_decide( '12.00', '11.00', wooset_hash( '10.00' ), true, false ), 'client' );
check( 'force takes it back', wooset_decide( '12.00', '11.00', wooset_hash( '10.00' ), false, true ), 'set' );
check( 'a stored string equals the int WordPress would read it back as', wooset_same( '100', 100 ), true );
check( 'a stored "1" equals true', wooset_same( true, '1' ), true );
check( 'a stored "" equals false', wooset_same( false, '' ), true );
check( 'absent is not the same as an empty string', wooset_same( null, '' ), false );
check( 'floats keep their precision', wooset_same( 0.1 + 0.2, 0.3 ), false );
check( 'a string already equal to the desired int is ok', wooset_decide( '100', 100, null, false, false ), 'ok' );
check( 'map key order does not matter', wooset_same( array( 'b' => 1, 'a' => 2 ), array( 'a' => 2, 'b' => 1 ) ), true );
check( 'list order does', wooset_same( array( 'setup', 'extended' ), array( 'extended', 'setup' ) ), false );
check( 'objects compare like maps', wooset_same( (object) array( 'skipped' => true ), array( 'skipped' => true ) ), true );
check( 'no orders, created', wooset_is_fresh( false, 'created' ), true );
check( 'orders', wooset_is_fresh( true, 'created' ), false );
check( 'adopted is never fresh', wooset_is_fresh( false, 'adopted' ), false );
// Keys.
check( 'sk_live', wooset_key_mode( 'sk_live_abc' ), 'live' );
check( 'rk_test', wooset_key_mode( 'rk_test_abc' ), 'test' );
check( 'whsec has no mode', wooset_key_mode( 'whsec_abc' ), 'unknown' );
check( 'a live key in a test field is named', wooset_live_key_in_test( array( 'test_secret_key' => 'sk_live_x', 'test_publishable_key' => 'pk_test_y', 'test_webhook_secret' => '' ) ), array( 'test_secret_key' ) );
check( 'test keys pass', wooset_live_key_in_test( array( 'test_secret_key' => 'sk_test_x', 'test_publishable_key' => 'pk_test_y' ) ), array() );
// Locations.
check( 'country', wooset_location( 'US' ), array( 'code' => 'US', 'type' => 'country' ) );
check( 'state', wooset_location( 'US:FL' ), array( 'code' => 'US:FL', 'type' => 'state' ) );
check( 'postcode', wooset_location( 'postcode:33602' ), array( 'code' => '33602', 'type' => 'postcode' ) );
check( 'continent', wooset_location( 'continent:NA' ), array( 'code' => 'NA', 'type' => 'continent' ) );
check( 'junk', wooset_location( 'Florida' ), null );
check( 'locations compare as a set, objects or arrays', wooset_locations_canon( array( (object) array( 'code' => 'US:FL', 'type' => 'state' ), array( 'code' => 'US', 'type' => 'country' ) ) ), array( 'country:US', 'state:US:FL' ) );
// Tax rates.
$a = wooset_tax_row( array( 'country' => 'us', 'state' => 'fl', 'rate' => '6', 'name' => 'FL Sales Tax', 'shipping' => true ) );
$b = wooset_tax_row( array( 'country' => 'US', 'state' => 'FL', 'rate' => '6.0000', 'name' => 'FL Sales Tax', 'shipping' => '1', 'class' => '' ) );
check( 'one rate written two ways is one key', wooset_tax_key( $a ), wooset_tax_key( $b ) );
check( 'rate to four places', $a['rate'], '6.0000' );
$p = wooset_tax_row( array( 'country' => 'US', 'name' => 'x', 'rate' => '1', 'postcode' => '33602; 33601' ) );
check( 'postcodes compare as a set', $p['postcode'], '33601;33602' );
check( 'a repeated postcode is one entry', wooset_tax_list( '33602;33602' ), '33602' );
check( 'another name is another rate', wooset_tax_key( wooset_tax_row( array( 'country' => 'US', 'state' => 'FL', 'rate' => '6', 'name' => 'County' ) ) ) === wooset_tax_key( $a ), false );
$z = wooset_tax_row( array( 'country' => 'US', 'name' => 'x', 'rate' => '1', 'shipping' => '0' ) );
check( "the database's '0' is false", $z['shipping'], false );
check( 'standard is the default class', $z['class'], 'standard' );
// Shipping methods.
check( 'flat rate', wooset_method_settings( array( 'type' => 'flat_rate', 'cost' => '10.00' ) ), array( 'cost' => '10.00', 'tax_status' => 'taxable' ) );
check( 'free shipping with a minimum', wooset_method_settings( array( 'type' => 'free_shipping', 'min_amount' => '100' ) ), array( 'requires' => 'min_amount', 'min_amount' => '100' ) );
check( 'free shipping without one', wooset_method_settings( array( 'type' => 'free_shipping' ) ), array( 'requires' => '' ) );
check( 'local pickup', wooset_method_settings( array( 'type' => 'local_pickup' ) ), array( 'cost' => '' ) );
// Checkout page type.
check( 'block', wooset_page_mode( '<!-- wp:woocommerce/checkout --><div></div>', 'checkout' ), 'block' );
check( 'shortcode', wooset_page_mode( '<!-- wp:shortcode -->[woocommerce_cart]<!-- /wp:shortcode -->', 'cart' ), 'shortcode' );
check( 'other', wooset_page_mode( '<p>hello</p>', 'cart' ), 'other' );
// Output.
check( 'absent shows as absent', wooset_show( null ), '(absent)' );
check( 'long values are cut', strlen( wooset_show( str_repeat( 'x', 200 ) ) ), 60 );
check( 'a fingerprint, not the value', wooset_fingerprint( 'abc' ), 'sha256:ba7816bf8f01' );
check( 'absent has no fingerprint', wooset_fingerprint( null ), 'absent' );
check( 'the fingerprint never contains the input', strpos( wooset_fingerprint( 'abc' ), 'abc' ), false );
check( 'summary', wooset_summary( array( 'set' => 2, 'ok' => 30, 'client' => 1, 'degraded' => 1 ), false ), "setup: 2 set, 30 already right, 1 client's, 1 degraded" );
check( 'plan', wooset_summary( array( 'set' => 2, 'ok' => 30, 'client' => 1, 'degraded' => 1 ), true ), "plan: 2 to set, 30 already right, 1 client's, 1 degraded" );
exit( $fail );
PHP
) || { printf '%s\n' "$out"; fail "woo-lib.php decisions are wrong"; }
[ -z "$out" ] || { printf '%s\n' "$out"; fail "woo-lib.php printed output"; }
echo PASS
