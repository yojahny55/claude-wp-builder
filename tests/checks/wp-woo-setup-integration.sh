#!/usr/bin/env bash
# /wp-woo-setup's script against a real WooCommerce 11.1.2. Everything the script promises is
# asserted here, not read from it:
#   - a refused run (bad block, live key in a test field, a key store-kit would ignore) and a
#     dry run write nothing;
#   - the first run turns HPOS on before any order exists, assigns the store pages in
#     Polylang's default language, and makes shipping, tax and payments equal the block;
#     a second run changes nothing and duplicates nothing;
#   - a value the client changed survives a re-run, `force` takes it back, a value the operator
#     changes in the block is updated, the checkout type switches both ways, and a page the
#     client moved to another language stays there;
#   - the store takes a real order through the Store API -- cart token, shipping, cash on
#     delivery -- stored in the HPOS table, with the total the block implies and both emails
#     captured; a failed Turnstile token is refused; the checkout limit refuses the fourth
#     attempt in a minute and stops refusing when switched off;
#   - no Stripe key is at rest, not even one typed in before setup ran; Stripe reads the
#     wp-config.php constant, and SEC-040's own detection snippet agrees -- and flags a key
#     once one is stored the ordinary way;
#   - a store with orders and no setup record runs report-only;
#   - a catalog refuses add-to-cart, redirects the cart page, and still shows prices.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks. It provisions its own store
# fixture (WP_FIXTURE_STORE=1).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi

prov=tests/fixtures/wp/provision.sh
setup=skills/wp-woocommerce/scripts/woo-setup.php
for f in "$prov" "$setup" tests/fixtures/wp/woo-product.php tests/fixtures/wp/mail-sink.php agents/wp-audit-security.md; do
  [ -r "$f" ] || fail "$f is missing or unreadable"
done
for t in curl python3 sha256sum node; do command -v "$t" >/dev/null 2>&1 || fail "$t is not on PATH"; done

DIR=""; SERVER_PID=""
PROJ=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$PROJ"
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(WP_FIXTURE_STORE=1 bash "$prov") || fail "could not provision a store fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
q() { $WP eval "$1" 2>/dev/null; }
run_setup() { $WP eval-file "$setup" "$PROJ" "$@" 2>&1; }

# Random per run, so a key printed anywhere is recognisably this run's.
SK="sk_test_fixture$(date +%s%N)"
PK="pk_test_fixture$(date +%s%N)"
STORE='{"tier":"store","address":{"street":"100 Main St","city":"Tampa","postcode":"33602","country":"US:FL"},
 "currency":"USD","units":{"weight":"lbs","dimension":"in"},"checkout":"block","payments":{"gateway":"stripe","mode":"test"},
 "shipping":[{"zone":"United States","locations":["US"],"methods":[{"type":"flat_rate","cost":"10.00"},{"type":"free_shipping","min_amount":"100"}]}],
 "tax":{"enabled":true,"prices_include_tax":false,"rates":[{"country":"US","state":"FL","rate":"6.0000","name":"FL Sales Tax","shipping":true}]}}'
CATALOG='{"tier":"catalog","address":{"street":"100 Main St","city":"Tampa","postcode":"33602","country":"US:FL"},
 "currency":"USD","units":{"weight":"lbs","dimension":"in"},"enquiry":["whatsapp"]}'

write_manifest() {
  python3 - "$PROJ/.wp-create.json" "$1" <<'PY'
import json, sys
m = json.load(open("tests/fixtures/manifests/valid/.wp-create.json"))
m["plugins"]["profile"] = "woo-store"
m["store"] = json.loads(sys.argv[2])
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
}
write_keys() {
  printf '{"store":{"payments":{"test_secret_key":"%s","test_publishable_key":"%s"}}}\n' "$1" "$2" > "$PROJ/.wp-create.local.json"
}
set_block() {  # $1: python statements editing s, the store block, in place
  python3 - "$PROJ/.wp-create.json" "$1" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); s = m["store"]; exec(sys.argv[2])
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
}
# Every value setup writes, the rows it creates, and wp-config.php: two equal snapshots mean
# nothing setup owns was touched.
snapshot() {
  q 'global $wpdb; $o = array(); foreach ( array( "woocommerce_onboarding_profile", "woocommerce_task_list_hidden_lists", "woocommerce_allow_tracking", "woocommerce_show_marketplace_suggestions", "woocommerce_admin_created_default_shipping_zones", "woocommerce_custom_orders_table_enabled", "woocommerce_custom_orders_table_data_sync_enabled", "woocommerce_store_address", "woocommerce_store_city", "woocommerce_store_postcode", "woocommerce_default_country", "woocommerce_currency", "woocommerce_weight_unit", "woocommerce_dimension_unit", "woocommerce_manage_stock", "woocommerce_enable_reviews", "woocommerce_file_download_method", "woocommerce_enable_guest_checkout", "woocommerce_enable_delayed_account_creation", "woocommerce_enable_coupons", "woocommerce_calc_taxes", "woocommerce_prices_include_tax", "woocommerce_stripe_settings", "woocommerce_cod_settings", "woocommerce_feature_rate_limit_checkout_enabled", "woocommerce_coming_soon", "woocommerce_store_pages_only", "woocommerce_terms_page_id", "store_kit_catalog_mode", "store_kit_setup_state", "cfturnstile_key", "cfturnstile_secret", "cfturnstile_woo_checkout", "cfturnstile_tested" ) as $n ) { $o[ $n ] = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $n ) ); } foreach ( array( "woocommerce_shipping_zones", "woocommerce_shipping_zone_methods", "woocommerce_tax_rates" ) as $t ) { $o[ $t ] = $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}$t" ); } foreach ( array( "shop", "cart", "checkout", "myaccount", "terms" ) as $p ) { $o["lang:$p"] = function_exists( "pll_get_post_language" ) ? pll_get_post_language( (int) get_option( "woocommerce_{$p}_page_id" ) ) : null; } $o["config"] = md5_file( ABSPATH . "wp-config.php" ); echo hash( "sha256", serialize( $o ) );'
}
rows() { q 'global $wpdb; foreach ( array( "woocommerce_shipping_zones", "woocommerce_shipping_zone_methods", "woocommerce_tax_rates" ) as $t ) { echo $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}$t" ), " "; }'; }
# The stored row, read with no plugin loaded: Stripe 11.0.0 saves its own settings once when its
# payment-method sync cannot reach Stripe (here, always), and store-kit strips a supplied key in
# that save -- a read that loaded Stripe would clean the row it was meant to inspect.
raw_stripe() { $WP eval --skip-plugins 'global $wpdb; $raw = maybe_unserialize( $wpdb->get_var( "SELECT option_value FROM {$wpdb->options} WHERE option_name = \"woocommerce_stripe_settings\"" ) ); echo ( is_array( $raw ) && ( ! empty( $raw["test_secret_key"] ) || ! empty( $raw["test_publishable_key"] ) ) ) ? "stored" : "clean";' 2>/dev/null; }

$WP eval-file skills/wp-polylang/scripts/pll-setup.php en es >/dev/null 2>&1 || fail "Polylang languages could not be set up"
# A key typed into the Stripe screen before setup ever ran. store-kit strips a supplied field
# only when the row is saved, and with enabled and testmode already right nothing else saves it:
# only setup's own re-save can make the first run's no-key-at-rest assertion hold.
q 'update_option( "woocommerce_stripe_settings", array_merge( (array) get_option( "woocommerce_stripe_settings", array() ), array( "enabled" => "yes", "testmode" => "yes", "test_secret_key" => "sk_test_typed_before_setup" ) ) );'
[ "$(raw_stripe)" = "stored" ] || fail "could not seed a Stripe key typed before setup"

# --- Refusals write nothing ---------------------------------------------------------------
write_manifest '{"tier":"mall"}'
before=$(snapshot)
set +e; out=$(run_setup); code=$?; set -e
[ "$code" = "1" ] || fail "an unknown tier exited $code, want 1: $out"
grep -q '^refused: store.tier' <<<"$out" || fail "the refusal does not name store.tier: $out"
[ "$(snapshot)" = "$before" ] || fail "a refused run (bad tier) changed the store"

# A block edited after validate ran: the script checks the keys it reads before any write.
write_manifest "$STORE"
set_block 'del s["address"]["city"]'
set +e; out=$(run_setup); code=$?; set -e
[ "$code" = "1" ] || fail "a store block with no address.city exited $code, want 1: $out"
grep -q '^refused: store block incomplete: store.address.city' <<<"$out" || fail "the refusal does not name the missing key: $out"
[ "$(snapshot)" = "$before" ] || fail "a refused run (incomplete block) changed the store"

write_manifest "$STORE"
write_keys "sk_live_fixture$(date +%s)" "$PK"
set +e; out=$(run_setup); code=$?; set -e
[ "$code" = "1" ] || fail "a live key in a test field exited $code, want 1: $out"
grep -q '^refused: .*live Stripe key' <<<"$out" || fail "the refusal does not say a live key was found: $out"
if grep -q 'sk_live_fixture' <<<"$out"; then fail "the refusal printed the key"; fi
[ "$(snapshot)" = "$before" ] || fail "a refused run (live key) changed the store"

# store-kit ignores a constant whose prefix does not match its field, silently -- so setup must
# refuse to write one rather than report keys configured that Stripe will never read.
BAD="fixture$(date +%s%N)"
write_keys "$BAD" "$PK"
set +e; out=$(run_setup); code=$?; set -e
[ "$code" = "1" ] || fail "a malformed test key exited $code, want 1: $out"
if grep -Fq "$BAD" <<<"$out"; then fail "the malformed-key refusal printed the key"; fi
grep -q '^refused: test_secret_key does not look like a Stripe test key' <<<"$out" || fail "the refusal does not name the malformed field: $out"
[ "$(snapshot)" = "$before" ] || fail "a refused run (malformed key) changed the store"

# --- A dry run writes nothing -----------------------------------------------------------------
write_keys "$SK" "$PK"
node bin/wp-config.mjs validate "$PROJ" >/dev/null || fail "this check's own store block does not validate"
out=$(run_setup dry-run) || fail "the dry run failed: $out"
if grep -Fq "$SK" <<<"$out"; then fail "the dry run printed the Stripe secret key"; fi
grep -q '^plan: ' <<<"$out" || fail "the dry run printed no plan summary: $out"
grep -q '^would-set ' <<<"$out" || fail "the dry run printed no would-set line"
[ "$(snapshot)" = "$before" ] || fail "a dry run changed the store"

# --- First run ------------------------------------------------------------------------------
out=$(run_setup) || fail "the first run failed: $out"
if grep -Fq "$SK" <<<"$out"; then fail "setup printed the Stripe secret key"; fi
grep -q '^setup: ' <<<"$out" || fail "the first run printed no summary: $out"
# First, before anything loads Stripe again: its one-time settings save would strip the key too.
[ "$(raw_stripe)" = "clean" ] || fail "a Stripe key is at rest in woocommerce_stripe_settings"
[ "$(q 'echo get_option( "woocommerce_custom_orders_table_enabled" );')" = "yes" ] || fail "HPOS is not on after the first run"
for p in shop cart checkout myaccount terms; do
  id=$(q "echo (int) get_option( 'woocommerce_${p}_page_id' );")
  [ "${id:-0}" -gt 0 ] || fail "the $p page is not assigned"
  [ "$(q "echo get_post_status( $id );")" = "publish" ] || fail "the $p page is not published"
  [ "$(q "echo pll_get_post_language( $id );")" = "en" ] || fail "the $p page has no language"
done
zone=$(q 'foreach ( WC_Shipping_Zones::get_zones() as $z ) { if ( "United States" === $z["zone_name"] ) { $m = array(); foreach ( $z["shipping_methods"] as $s ) { $m[ $s->id ] = array( "cost" => $s->get_option( "cost" ), "min" => $s->get_option( "min_amount" ), "requires" => $s->get_option( "requires" ) ); } echo wp_json_encode( array( "locations" => wp_list_pluck( $z["zone_locations"], "code" ), "methods" => $m ) ); } }')
python3 - "$zone" <<'PY' || fail "the United States zone is not what the block says: $zone"
import json, sys
z = json.loads(sys.argv[1])
assert z["locations"] == ["US"], z
assert set(z["methods"]) == {"flat_rate", "free_shipping"}, z
assert z["methods"]["flat_rate"]["cost"] == "10.00", z
assert z["methods"]["free_shipping"]["requires"] == "min_amount" and z["methods"]["free_shipping"]["min"] == "100", z
PY
[ "$(q 'global $wpdb; echo $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}woocommerce_tax_rates WHERE tax_rate_country = \"US\" AND tax_rate_state = \"FL\" AND tax_rate_name = \"FL Sales Tax\" AND tax_rate = \"6.0000\" AND tax_rate_shipping = 1" );')" = "1" ] \
  || fail "the FL rate is not there exactly once"
want=$(printf '%s' "$SK" | sha256sum | cut -d' ' -f1)
[ "$(q 'echo hash( "sha256", WC_Stripe_API::get_secret_key() );')" = "$want" ] || fail "Stripe does not read the secret key from wp-config.php"
[ "$(q 'echo get_option( "woocommerce_stripe_settings" )["testmode"];')" = "yes" ] || fail "Stripe is not in test mode"
[ "$(q 'echo get_option( "woocommerce_cod_settings" )["enabled"];')" = "yes" ] || fail "cash on delivery is not on in a local environment"
for pair in woocommerce_feature_rate_limit_checkout_enabled=yes woocommerce_coming_soon=no store_kit_catalog_mode=no \
            cfturnstile_tested=yes cfturnstile_woo_checkout=1 woocommerce_file_download_method=force; do
  [ "$(q "echo get_option( '${pair%%=*}' );")" = "${pair#*=}" ] || fail "${pair%%=*} is not ${pair#*=} after the first run"
done

# --- A second run changes nothing and duplicates nothing ------------------------------------
counts=$(rows)
out=$(run_setup) || fail "the second run failed: $out"
grep -q '^setup: 0 set' <<<"$out" || fail "the second run changed something: $(grep -E '^(set|client) ' <<<"$out" | head -5)"
[ "$(rows)" = "$counts" ] || fail "the second run added rows ($counts -> $(rows))"

# --- Ownership -------------------------------------------------------------------------------
flat=$(q 'foreach ( WC_Shipping_Zones::get_zones() as $z ) { if ( "United States" === $z["zone_name"] ) { foreach ( $z["shipping_methods"] as $s ) { if ( "flat_rate" === $s->id ) { echo "woocommerce_flat_rate_{$s->instance_id}_settings"; } } } }')
[ -n "$flat" ] || fail "no flat rate method to edit"
cost() { q "echo get_option( '$flat' )['cost'];"; }
q "\$s = get_option( '$flat' ); \$s['cost'] = '12.00'; update_option( '$flat', \$s );"
out=$(run_setup) || fail "the run after a client edit failed: $out"
grep -q '^client .*zone:United States:flat_rate' <<<"$out" || fail "the client's shipping cost was not reported as the client's: $out"
[ "$(cost)" = "12.00" ] || fail "setup overwrote the client's shipping cost (cost reads '$(cost)'): $out"
out=$(run_setup force) || fail "the forced run failed: $out"
if grep -Fq "$SK" <<<"$out"; then fail "the forced run printed the Stripe secret key"; fi
[ "$(cost)" = "10.00" ] || fail "force did not take the shipping cost back"
# A client's Turnstile secret (a local clone of a live site holds the production one) reads as
# the client's and is reported by fingerprint only.
TS="0x4AAAfixture$(date +%s%N)"
q "update_option( 'cfturnstile_secret', '$TS' );"
ts_print=$(printf '%s' "$TS" | sha256sum | cut -c1-12)
for mode in dry-run ""; do
  out=$(run_setup $mode) || fail "the run with a client's Turnstile secret failed ($mode)"
  if grep -Fq "$TS" <<<"$out"; then fail "the client note printed the Turnstile secret (${mode:-real run})"; fi
  grep -q "^client cfturnstile_secret: kept sha256:$ts_print," <<<"$out" \
    || fail "the client's Turnstile secret is not reported by its fingerprint (${mode:-real run}): $(grep cfturnstile_secret <<<"$out")"
done
[ "$(q 'echo get_option( "cfturnstile_secret" );')" = "$TS" ] || fail "setup overwrote the client's Turnstile secret"
q 'update_option( "cfturnstile_secret", "1x0000000000000000000000000000000AA" );'
# Review Focus 2: the operator changes the block; setup wrote the old value, so it updates its own.
set_block 's["shipping"][0]["methods"][0]["cost"] = "11.00"'
out=$(run_setup) || fail "the run after a block change failed: $out"
[ "$(cost)" = "11.00" ] || fail "a changed block did not update setup's own value: $out"
set_block 's["shipping"][0]["methods"][0]["cost"] = "10.00"'
run_setup >/dev/null || fail "restoring the block failed"

# Review Focus 3: the checkout type, both ways.
cid=$(q 'echo (int) get_option( "woocommerce_checkout_page_id" );')
set_block 's["checkout"] = "shortcode"; s["checkout_reason"] = "an extension that does not support the checkout block"'
out=$(run_setup) || fail "the shortcode run failed: $out"
q "echo get_post_field( 'post_content', $cid );" | grep -Fq '[woocommerce_checkout]' || fail "checkout shortcode did not reach the checkout page: $out"
set_block 's["checkout"] = "block"; s.pop("checkout_reason")'
out=$(run_setup) || fail "the block run failed: $out"
q "echo get_post_field( 'post_content', $cid );" | grep -Fq '<!-- wp:woocommerce/checkout' || fail "checkout block did not restore the block checkout: $out"

# Review Focus 5: a page the client moved to another language stays there.
cart=$(q 'echo (int) get_option( "woocommerce_cart_page_id" );')
q "pll_set_post_language( $cart, 'es' );"
run_setup >/dev/null || fail "the run after a language change failed"
[ "$(q "echo pll_get_post_language( $cart );")" = "es" ] || fail "setup moved a page the client had put in another language"
q "pll_set_post_language( $cart, 'en' );"

# A rate and a method setup created, since taken out of the block, would keep charging: they are
# reported degraded and counted, and nothing is deleted.
counts=$(rows)
set_block 's["shipping"][0]["methods"].pop(); s["tax"]["rates"] = []'
out=$(run_setup) || fail "the run after removing a rate and a method from the block failed: $out"
stale=': setup created this and it is no longer in the block — remove it in WooCommerce'
grep -Fxq "degraded zone:United States:free_shipping$stale" <<<"$out" \
  || fail "a free-shipping method removed from the block was not reported: $(grep -E '^degraded ' <<<"$out")"
grep -Fxq "degraded tax:US|FL|||FL Sales Tax|standard$stale" <<<"$out" \
  || fail "a tax rate removed from the block was not reported: $(grep -E '^degraded ' <<<"$out")"
[ "$(rows)" = "$counts" ] || fail "setup deleted a row the block no longer names ($counts -> $(rows))"
deg=$(grep -c '^degraded ' <<<"$out" || true)
grep -Eq "^setup: .*, $deg degraded\$" <<<"$out" \
  || fail "the summary does not count the $deg degraded lines: $(grep '^setup: ' <<<"$out")"
set_block 's["shipping"][0]["methods"].append({"type": "free_shipping", "min_amount": "100"}); s["tax"]["rates"] = [{"country": "US", "state": "FL", "rate": "6.0000", "name": "FL Sales Tax", "shipping": True}]'
out=$(run_setup) || fail "the run after restoring the rate and the method failed: $out"
if grep -Fq "$stale" <<<"$out"; then fail "a rate or method back in the block is still reported stale: $out"; fi
grep -q '^setup: 0 set' <<<"$out" || fail "restoring the block changed something: $(grep -E '^(set|client) ' <<<"$out" | head -5)"

# An assigned page the client left unpublished is the client's: WooCommerce keeps it, setup must
# neither replace it nor report it set on every run.
terms=$(q 'echo (int) get_option( "woocommerce_terms_page_id" );')
q "wp_update_post( array( 'ID' => $terms, 'post_status' => 'draft' ) ); wp_update_post( array( 'ID' => $cart, 'post_status' => 'draft' ) );"
out=$(run_setup) || fail "the run with draft store pages failed: $out"
[ "$(q 'echo (int) get_option( "woocommerce_terms_page_id" );')" = "$terms" ] || fail "setup replaced the client's draft terms page: $out"
[ "$(q 'echo (int) get_option( "woocommerce_cart_page_id" );')" = "$cart" ] || fail "setup replaced the client's draft cart page: $out"
[ "$(q "echo get_post_status( $terms ), get_post_status( $cart );")" = "draftdraft" ] || fail "setup published the client's draft pages"
grep -q '^client page:terms: kept as draft' <<<"$out" || fail "a draft terms page was not reported as the client's: $(grep page:terms <<<"$out")"
grep -q '^client page:cart: kept as draft' <<<"$out" || fail "a draft cart page was not reported as the client's: $(grep 'page:cart' <<<"$out")"
out=$(run_setup) || fail "the second run with draft store pages failed: $out"
grep -q '^setup: 0 set' <<<"$out" || fail "draft store pages keep a re-run from reaching 0 set: $(grep -E '^(set|client) ' <<<"$out" | head -5)"
q "wp_update_post( array( 'ID' => $terms, 'post_status' => 'publish' ) ); wp_update_post( array( 'ID' => $cart, 'post_status' => 'publish' ) );"

# Review Focus 1: no keys anywhere -- say where they go.
cod_line='^(set|ok|client|would-set) woocommerce_cod_settings\.enabled'
cp "$DIR/wp-config.php" "$PROJ/wp-config.php.bak"
mv "$PROJ/.wp-create.local.json" "$PROJ/keys.json"
out=$(run_setup) || fail "the run without keys failed: $out"
grep -q '^ok stripe:keys: in wp-config.php' <<<"$out" || fail "keys already in wp-config.php were not reported ok: $(grep stripe <<<"$out")"
$WP config delete STORE_KIT_STRIPE_TEST_SECRET_KEY --quiet
$WP config delete STORE_KIT_STRIPE_TEST_PUBLISHABLE_KEY --quiet
out=$(run_setup) || fail "the run without keys or constants failed: $out"
grep -q '^degraded stripe: .*WP_CREATE_STRIPE_TEST_SECRET_KEY.*\.wp-create\.local\.json' <<<"$out" \
  || fail "missing keys are not reported with where they belong: $out"
mv "$PROJ/keys.json" "$PROJ/.wp-create.local.json"
# Review Focus 6: keys to write and a wp-config.php that cannot take them. Only Stripe's steps
# are skipped: cash on delivery is still converged.
chmod 444 "$DIR/wp-config.php"
if [ -w "$DIR/wp-config.php" ]; then
  echo "  note: running as root, so chmod cannot make wp-config.php unwritable; the failed-write case below takes the same path"
else
  out=$(run_setup) || fail "the run with an unwritable wp-config.php failed: $out"
  grep -q '^degraded stripe:keys: wp-config.php is not writable' <<<"$out" || fail "an unwritable wp-config.php was not reported: $(grep stripe <<<"$out")"
  grep -Eq "$cod_line" <<<"$out" || fail "cash on delivery was skipped when wp-config.php was not writable: $out"
fi
chmod 644 "$DIR/wp-config.php"
# No placement anchor, so WPConfigTransformer throws when it adds a constant.
sed -i "/That's all, stop editing/d" "$DIR/wp-config.php"
out=$(run_setup) || fail "the run with a wp-config.php that cannot be written failed: $out"
if grep -Fq "$SK" <<<"$out"; then fail "a failed wp-config.php write printed the Stripe secret key"; fi
grep -q '^degraded stripe:keys: wp-config.php could not be written (Exception)' <<<"$out" \
  || fail "a failed wp-config.php write was not reported by exception class: $(grep stripe <<<"$out")"
grep -Eq "$cod_line" <<<"$out" || fail "cash on delivery was skipped when wp-config.php could not be written: $out"
cp "$PROJ/wp-config.php.bak" "$DIR/wp-config.php"
run_setup >/dev/null || fail "the run after restoring wp-config.php failed"

# --- A real order through the Store API --------------------------------------------------------
PRODUCT=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$PRODUCT" ] || fail "no fixture product"
cp tests/fixtures/wp/mail-sink.php "$DIR/wp-content/mu-plugins/00-mail-sink.php"
rm -f "$DIR/wp-content/mail-sink.log"
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
$WP server --host=127.0.0.1 --port="$PORT" >"$DIR/woo-server.log" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)" = "200" ] && { up=1; break; }
  sleep 1
done
[ -n "$up" ] || { tail -5 "$DIR/woo-server.log"; fail "the fixture site never answered on port $PORT"; }
S="http://127.0.0.1:$PORT/?rest_route=/wc/store/v1"
token() { curl -s -D - -o /dev/null "$S/cart" | tr -d '\r' | awk -F': ' 'tolower($1)=="cart-token"{print $2}'; }
post() { curl -s -H "Cart-Token: $1" -H 'Content-Type: application/json' -X POST "$S/$2" -d "$3"; }
# "-" for a response with no code, so a burst always yields four words and positions never shift.
code_of() { python3 -c 'import json,sys; print(json.load(sys.stdin).get("code") or "-")'; }
ADDR='{"first_name":"QA","last_name":"Bot","address_1":"1 Test St","city":"Tampa","state":"FL","postcode":"33602","country":"US"}'
BILL='{"first_name":"QA","last_name":"Bot","address_1":"1 Test St","city":"Tampa","state":"FL","postcode":"33602","country":"US","email":"qa@example.test"}'
checkout() {  # $1 cart token, $2 Turnstile token; prints the checkout response
  post "$1" cart/add-item "{\"id\":$PRODUCT,\"quantity\":2}" >/dev/null
  rates=$(post "$1" cart/update-customer "{\"shipping_address\":$ADDR,\"billing_address\":$BILL}")
  rate=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(r["rate_id"] for p in d["shipping_rates"] for r in p["shipping_rates"] if r["rate_id"].startswith("flat_rate")))' <<<"$rates")
  post "$1" cart/select-shipping-rate "{\"package_id\":0,\"rate_id\":\"$rate\"}" >/dev/null
  post "$1" checkout "{\"billing_address\":$BILL,\"shipping_address\":$ADDR,\"payment_method\":\"cod\",\"extensions\":{\"simple-cloudflare-turnstile\":{\"token\":\"$2\"}}}"
}
clear_limits() { q 'global $wpdb; $wpdb->query( "DELETE FROM {$wpdb->prefix}wc_rate_limits" );'; }

clear_limits
res=$(checkout "$(token)" "XXXX.DUMMY.TOKEN.1")
read -r OID OSTATUS PSTATUS <<<"$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("order_id",""), d.get("status",""), d.get("payment_result",{}).get("payment_status",""))' <<<"$res")"
[ "$OSTATUS" = "processing" ] && [ "$PSTATUS" = "success" ] || fail "the Store API checkout did not produce a processing order: $res"
[ "$(q "global \$wpdb; echo \$wpdb->get_var( \$wpdb->prepare( \"SELECT COUNT(*) FROM {\$wpdb->prefix}wc_orders WHERE id = %d\", $OID ) );")" = "1" ] \
  || fail "order $OID is not in the HPOS table"
want_total=$(python3 -c 'print(f"{(20.00 * 2 + 10.00) * 1.06:.2f}")')
[ "$(q "echo wc_get_order( $OID )->get_total();")" = "$want_total" ] || fail "order $OID's total is not two mugs + flat rate + 6% tax on both ($want_total)"
notes=$(q "foreach ( wc_get_order_notes( array( 'order_id' => $OID ) ) as \$n ) { echo \$n->content, \"\\n\"; }")
grep -Fq 'Email "New order" sent.' <<<"$notes" || fail "the new-order email was not sent: $notes"
grep -Fq 'Email "Processing order" sent.' <<<"$notes" || fail "the customer's processing email was not sent: $notes"
[ "$(wc -l < "$DIR/wp-content/mail-sink.log")" -ge 2 ] || fail "the mail sink captured fewer than two emails"

# The bot check: a secret Cloudflare fails for (the guard answers 2x... with failure).
q 'update_option( "cfturnstile_secret", "2x0000000000000000000000000000000AA" );'
res=$(checkout "$(token)" "XXXX.DUMMY.TOKEN.2")
grep -q 'verify that you are human' <<<"$res" || fail "a failed Turnstile token was not refused: $res"
q 'update_option( "cfturnstile_secret", "1x0000000000000000000000000000000AA" );'

# The checkout limit: the fourth attempt in a minute is refused -- and only because of the setting.
burst() { t=$(token); c=""; for _ in 1 2 3 4; do c="$c $(post "$t" checkout '{"payment_method":"cod"}' | code_of)"; done; echo "$c"; }
clear_limits
set -- $(burst)
[ "${4:-}" = "rate_limit_exceeded" ] || fail "the fourth checkout attempt in a minute was not refused: $*"
for c in "$1" "$2" "$3"; do [ "$c" != "rate_limit_exceeded" ] || fail "an attempt under the limit was refused: $*"; done
q 'update_option( "woocommerce_feature_rate_limit_checkout_enabled", "no" );'
clear_limits
codes=$(burst)
if grep -q rate_limit_exceeded <<<"$codes"; then fail "attempts were refused with the checkout limit off: $codes"; fi
q 'update_option( "woocommerce_feature_rate_limit_checkout_enabled", "yes" );'

# --- No key at rest, by SEC-040's own detection snippet --------------------------------------
proc=$(awk '/^### Procedure — SEC-040/{f=1;print;next} /^##/{f=0} f' agents/wp-audit-security.md)
awk -v out="$PROJ/sec040.php" '
  { line = $0; sub(/[ \t\r]+$/, "", line) }
  line == "$WP eval '"'"'" && !done { f = 1; print "<?php" > out; next }
  f && line == "'"'"'" { f = 0; done = 1; next }
  f { print > out }' <<<"$proc"
[ -s "$PROJ/sec040.php" ] || fail "could not extract SEC-040's detection snippet"
sec040=$($WP eval-file "$PROJ/sec040.php" 2>/dev/null)
if grep -q '^CRITICAL woocommerce_stripe_settings' <<<"$sec040"; then fail "SEC-040 reports a Stripe key at rest on a store-kit store: $sec040"; fi
$WP plugin deactivate store-kit --quiet
q 'update_option( "woocommerce_stripe_settings", array_merge( (array) get_option( "woocommerce_stripe_settings", array() ), array( "test_secret_key" => "sk_test_stored_by_hand" ) ) );'
sec040=$($WP eval-file "$PROJ/sec040.php" 2>/dev/null)
grep -q '^CRITICAL woocommerce_stripe_settings: .*key=test_secret_key' <<<"$sec040" || fail "SEC-040 does not see a key that is at rest: $sec040"
$WP plugin activate store-kit --quiet
q 'update_option( "woocommerce_stripe_settings", get_option( "woocommerce_stripe_settings" ) );'
[ "$(raw_stripe)" = "clean" ] || fail "saving through store-kit did not strip the stored key"

# --- Review Focus 4: a store with orders and no setup record is report-only ------------------
q 'delete_option( "store_kit_setup_state" );'
# The merchant's launch state differs from what the block implies for a local store.
q 'update_option( "woocommerce_coming_soon", "yes" ); $s = get_option( "woocommerce_stripe_settings" ); $s["testmode"] = "no"; update_option( "woocommerce_stripe_settings", $s );'
testmode() { q 'echo get_option( "woocommerce_stripe_settings" )["testmode"];'; }
before=$(snapshot)
out=$(run_setup) || fail "the report-only run failed: $out"
grep -q '^report-only' <<<"$out" || fail "a store with orders and no setup record was not run report-only: $out"
grep -q '^report-only: .*force never changes launch state' <<<"$out" || fail "the report-only line does not say force leaves launch state alone: $out"
[ "$(snapshot)" = "$before" ] || fail "a report-only run wrote to the store"
out=$(run_setup force) || fail "the forced run after report-only failed: $out"
if grep -Fq "$SK" <<<"$out"; then fail "the forced run after report-only printed the Stripe secret key"; fi
[ "$(q 'echo get_option( "woocommerce_coming_soon" );')" = "yes" ] || fail "force changed coming soon on a store with orders"
[ "$(testmode)" = "no" ] || fail "force changed Stripe test mode on a store with orders"
for id in woocommerce_coming_soon woocommerce_stripe_settings.testmode; do
  grep -q "^client $id: .*launch state on a store with orders: change it in WooCommerce, force does not" <<<"$out" \
    || fail "force on a store with orders did not report $id as launch state: $(grep "$id" <<<"$out")"
done
# An absent row is launch state too: WooCommerce reads it as a live shop, so writing one on an
# older adopted store would take it offline.
q 'delete_option( "woocommerce_coming_soon" );'
out=$(run_setup force) || fail "the forced run with no coming-soon row failed: $out"
[ "$(q 'global $wpdb; echo $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->options} WHERE option_name = \"woocommerce_coming_soon\"" );')" = "0" ] \
  || fail "setup wrote a coming-soon row on a store with orders: $(grep woocommerce_coming_soon <<<"$out")"
grep -q '^client woocommerce_coming_soon: kept absent, .*launch state on a store with orders: change it in WooCommerce, force does not' <<<"$out" \
  || fail "an absent coming-soon row was not reported as launch state: $(grep woocommerce_coming_soon <<<"$out")"
q 'update_option( "woocommerce_coming_soon", "no" ); $s = get_option( "woocommerce_stripe_settings" ); $s["testmode"] = "yes"; update_option( "woocommerce_stripe_settings", $s );'
[ "$(q 'echo count( (array) get_option( "store_kit_setup_state", array() ) );')" -gt 0 ] || fail "force did not record ownership"

# --- A catalog ----------------------------------------------------------------------------------
write_manifest "$CATALOG"
node bin/wp-config.mjs validate "$PROJ" >/dev/null || fail "this check's catalog block does not validate"
out=$(run_setup) || fail "the catalog run failed: $out"
[ "$(q 'echo get_option( "store_kit_catalog_mode" );')" = "yes" ] || fail "catalog mode is not on for a catalog: $out"
[ "$(post "$(token)" cart/add-item "{\"id\":$PRODUCT,\"quantity\":1}" | code_of)" = "woocommerce_rest_product_not_purchasable" ] \
  || fail "a catalog product can be added to a cart through the Store API"
prod=$(curl -s "$S/products/$PRODUCT")
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["is_purchasable"] is False, d["is_purchasable"]; assert d["prices"]["price"] == "2000", d["prices"]' <<<"$prod" \
  || fail "a catalog product must show its price and not be purchasable: $prod"
cart_id=$(q 'echo (int) get_option( "woocommerce_cart_page_id" );')
# `wp server`'s router filters home to the request's Host, so the site answers on this port while
# a `wp eval` permalink reads the stored home: same page, different host.
shop_url="http://127.0.0.1:$PORT$(q 'echo wp_make_link_relative( wc_get_page_permalink( "shop" ) );')"
hop=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "http://127.0.0.1:$PORT/?page_id=$cart_id")
[ "$hop" = "302 $shop_url" ] || fail "the cart page does not send a catalog visitor to the shop: $hop (want 302 $shop_url)"

if [ -s "$DIR/wp-content/net-guard.log" ]; then
  echo "  outbound refused: $(awk '{print $2}' "$DIR/wp-content/net-guard.log" | sort | uniq -c | awk '{printf "%s x%s, ", $2, $1}')"
fi
echo "PASS: /wp-woo-setup brings a real WooCommerce in line with its block, and the store takes a real order"
