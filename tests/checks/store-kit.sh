#!/usr/bin/env bash
# store-kit is PHP this repository ships into client sites. Every file must refuse direct
# access; its identity must be provable, because the audit's wp.org lookup (SEC-041/042) ties
# a slug to a plugin by author and URI; uninstall must remove every option it owns; it declares
# compatibility only with what the fixture proves; and it never enables the general Store API
# limiter, which in WooCommerce 11.1.2 shares a per-IP row with the checkout limit and dilutes
# it (measured). Its credential filters and the sync script are pure enough to run here.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

kit=plugins/store-kit
main=$kit/store-kit.php
sync=bin/store-kit-sync.sh
for f in "$main" "$kit/includes/catalog-mode.php" "$kit/includes/credentials.php" "$kit/uninstall.php" "$sync"; do
  [ -r "$f" ] || fail "$f is missing or unreadable"
done
command -v php >/dev/null 2>&1 || fail "php is not on PATH; this check runs store-kit's filters"

hdr() { sed -n "s/^ \* $1: *//p" "$main" | head -1; }
[ "$(hdr 'Update URI')" = "false" ] || fail "store-kit must set Update URI: false, or WordPress may offer a same-named plugin as an update"
[ "$(hdr 'Requires Plugins')" = "woocommerce" ] || fail "store-kit must declare Requires Plugins: woocommerce"
[ "$(hdr 'Requires PHP')" = "7.4" ] || fail "store-kit must declare the 7.4 floor"
author=$(node -e 'console.log(require("./.claude-plugin/plugin.json").author.name)')
repo=$(node -e 'console.log(require("./.claude-plugin/plugin.json").repository)')
[ "$(hdr 'Author')" = "$author" ] || fail "store-kit's Author is not plugin.json's author.name ($author): the audit could not prove the slug is ours"
[ "$(hdr 'Plugin URI')" = "$repo" ] || fail "store-kit's Plugin URI is not plugin.json's repository ($repo)"
v=$(hdr 'Version')
grep -Fq "define( 'STORE_KIT_VERSION', '$v' );" "$main" || fail "STORE_KIT_VERSION does not match the Version header ($v)"

while IFS= read -r f; do
  php -l "$f" >/dev/null 2>&1 || fail "$f does not parse"
  case "$f" in
    */uninstall.php) grep -Fq "defined( 'WP_UNINSTALL_PLUGIN' )" "$f" || fail "$f runs outside an uninstall" ;;
    *) grep -Fq "if ( ! defined( 'ABSPATH' ) )" "$f" || fail "$f can be requested directly: no ABSPATH guard" ;;
  esac
done < <(find "$kit" -name '*.php')

# Every store_kit_ option read or written by the plugin or the setup script is removed on uninstall.
for o in $(grep -rhoE "(get|update|delete|add)_option\( *'store_kit_[a-z_]+'" "$kit" skills/wp-woocommerce/scripts 2>/dev/null \
            | grep -oE "store_kit_[a-z_]+" | sort -u); do
  grep -Fq "'$o'" "$kit/uninstall.php" || fail "uninstall leaves $o behind"
done
grep -Fq "'store_kit_setup_state'" "$kit/uninstall.php" || fail "uninstall leaves store_kit_setup_state behind"

decl=$(grep -oE "declare_compatibility\( '[a-z_]+'" "$main" | sort | tr '\n' ' ')
[ "$decl" = "declare_compatibility( 'cart_checkout_blocks' declare_compatibility( 'custom_order_tables' " ] \
  || fail "store-kit must declare exactly the two features the fixture proves, found: $decl"

if grep -rq 'woocommerce_store_api_rate_limit_options' "$kit" skills/wp-woocommerce/scripts 2>/dev/null; then
  fail "the general Store API limiter is enabled somewhere: it shares a per-IP row with the checkout limit and dilutes it"
fi

grep -Fq "find . -name '*.php' -not -path './node_modules/*'" .github/workflows/ci.yml \
  || fail "CI's PHP 7.4 lint no longer walks the whole tree, so plugins/ may not be linted"

KIT="$PWD/$kit" php <<'PHP' || fail "store-kit's credential filters misbehave"
<?php
define( 'ABSPATH', '/tmp/' );
function add_filter() {}
function add_action() {}
require getenv( 'KIT' ) . '/includes/credentials.php';
$ok = true;
function want( $cond, $msg ) { global $ok; if ( ! $cond ) { echo "  $msg\n"; $ok = false; } }
want( store_kit_stripe_inject( array( 'enabled' => 'yes' ) ) === array( 'enabled' => 'yes' ), 'with no constant, the option came back changed' );
want( store_kit_stripe_strip( array( 'test_secret_key' => 'typed' ) ) === array( 'test_secret_key' => 'typed' ), 'with no constant, a typed key was stripped (SEC-040 must see it)' );
define( 'STORE_KIT_STRIPE_TEST_SECRET_KEY', 'sk_test_const' );
define( 'STORE_KIT_STRIPE_TEST_PUBLISHABLE_KEY', '' );
$in = store_kit_stripe_inject( array( 'enabled' => 'yes', 'test_secret_key' => 'stale' ) );
want( 'sk_test_const' === $in['test_secret_key'], 'the constant does not win on read' );
want( ! isset( $in['test_publishable_key'] ), 'an empty constant supplied a value' );
$absent = store_kit_stripe_inject( false );
want( is_array( $absent ) && 'sk_test_const' === $absent['test_secret_key'], 'an absent option does not get the key' );
$out = store_kit_stripe_strip( array( 'enabled' => 'yes', 'test_secret_key' => 'sk_test_const', 'test_publishable_key' => 'pk_typed' ) );
want( ! isset( $out['test_secret_key'] ), 'the constant-backed key would reach the database' );
want( 'pk_typed' === $out['test_publishable_key'], 'a field with no constant was stripped' );

// Critical 1: the raw secret nested inside test_webhook_data by Stripe's own
// configure_webhooks() must be stripped and restored exactly like the flat field.
$saved_hook = store_kit_stripe_strip( array(
	'enabled'           => 'yes',
	'test_webhook_data' => array( 'id' => 'we_1', 'url' => 'https://example.com/wc-api/wc_stripe', 'secret' => 'sk_test_const' ),
) );
want( ! isset( $saved_hook['test_webhook_data']['secret'] ), 'a nested webhook secret matching the constant was not stripped' );
want( 'we_1' === $saved_hook['test_webhook_data']['id'], 'stripping the nested secret removed the rest of the webhook data' );
$read_hook = store_kit_stripe_inject( array(
	'enabled'           => 'yes',
	'test_webhook_data' => array( 'id' => 'we_1', 'url' => 'https://example.com/wc-api/wc_stripe' ),
) );
want( isset( $read_hook['test_webhook_data']['secret'] ) && 'sk_test_const' === $read_hook['test_webhook_data']['secret'], 'inject did not restore the nested webhook secret' );
$other_hook = array(
	'enabled'           => 'yes',
	'test_webhook_data' => array( 'id' => 'we_2', 'url' => 'https://example.com/wc-api/wc_stripe', 'secret' => 'sk_test_other' ),
);
want( 'sk_test_other' === store_kit_stripe_strip( $other_hook )['test_webhook_data']['secret'], 'a nested webhook secret that differs from the constant was stripped' );
want( 'sk_test_other' === store_kit_stripe_inject( $other_hook )['test_webhook_data']['secret'], 'inject overwrote a nested webhook secret that differs from the constant' );

// Important 2: a webhook-secret constant seeds an empty row but never overrides a value Stripe
// itself already wrote there (a rotation), and strip only discards an unrotated copy.
define( 'STORE_KIT_STRIPE_TEST_WEBHOOK_SECRET', 'whsec_const' );
$seeded = store_kit_stripe_inject( array( 'enabled' => 'yes' ) );
want( isset( $seeded['test_webhook_secret'] ) && 'whsec_const' === $seeded['test_webhook_secret'], 'an empty row did not get the webhook secret constant' );
$rotated = array( 'enabled' => 'yes', 'test_webhook_secret' => 'whsec_rotated' );
want( 'whsec_rotated' === store_kit_stripe_inject( $rotated )['test_webhook_secret'], 'a rotated webhook secret in the row was overridden by the constant on read' );
want( 'whsec_rotated' === store_kit_stripe_strip( $rotated )['test_webhook_secret'], 'a rotated webhook secret was stripped even though it differs from the constant' );
$unrotated = array( 'enabled' => 'yes', 'test_webhook_secret' => 'whsec_const' );
want( ! isset( store_kit_stripe_strip( $unrotated )['test_webhook_secret'] ), 'a webhook secret equal to the constant was not stripped' );

exit( $ok ? 0 : 1 );
PHP

KIT="$PWD/$kit" php <<'PHP2' || fail "store-kit's prefix-mismatch guard misbehaves"
<?php
define( 'ABSPATH', '/tmp/' );
function add_filter() {}
function add_action() {}
require getenv( 'KIT' ) . '/includes/credentials.php';
$ok = true;
function want( $cond, $msg ) { global $ok; if ( ! $cond ) { echo "  $msg\n"; $ok = false; } }
// Important 3: a live-mode key placed in a test-mode constant must never be used -- it would
// charge real cards while the admin screen still says test mode.
define( 'STORE_KIT_STRIPE_TEST_SECRET_KEY', 'sk_live_should_not_charge_real_cards' );
want( array() === store_kit_stripe_supplied(), 'a mismatched-prefix constant was supplied anyway' );
$injected = store_kit_stripe_inject( array( 'enabled' => 'yes' ) );
want( ! isset( $injected['test_secret_key'] ), 'a mismatched-prefix constant was injected' );
$row = array( 'test_secret_key' => 'sk_live_should_not_charge_real_cards' );
want( isset( store_kit_stripe_strip( $row )['test_secret_key'] ), 'strip discarded a row value for a mismatched constant, hiding it from SEC-040' );
$mismatches = store_kit_stripe_mismatches();
want( isset( $mismatches['test_secret_key'] ) && 'STORE_KIT_STRIPE_TEST_SECRET_KEY' === $mismatches['test_secret_key'], 'the mismatch was not reported by field and constant name' );
exit( $ok ? 0 : 1 );
PHP2

p=$(mktemp -d); trap 'rm -rf "$p"' EXIT
out=$(bash "$sync" "$p") || fail "the first sync failed: $out"
grep -q '^store-kit absent -> ' <<<"$out" || fail "the first sync did not install: $out"
cmp -s "$main" "$p/store-kit/store-kit.php" || fail "the installed copy differs from the bundled one"
out=$(bash "$sync" "$p"); grep -q 'is current' <<<"$out" || fail "a second sync did not report current: $out"
sed -i 's/^ \* Version: .*/ * Version: 99.0.0/' "$p/store-kit/store-kit.php"
out=$(bash "$sync" "$p"); grep -q 'left alone' <<<"$out" && grep -q '99.0.0' "$p/store-kit/store-kit.php" \
  || fail "a newer copy on the site was downgraded: $out"
sed -i 's/^ \* Version: .*/ * Version: 0.0.1/' "$p/store-kit/store-kit.php"
out=$(bash "$sync" "$p"); grep -q '^store-kit 0.0.1 -> ' <<<"$out" && cmp -s "$main" "$p/store-kit/store-kit.php" \
  || fail "an older copy on the site was not replaced: $out"
set +e; bash "$sync" "$p/missing" >/dev/null 2>&1; code=$?; set -e
[ "$code" = "1" ] || fail "a plugins directory that does not exist exited $code, want 1"
echo PASS
