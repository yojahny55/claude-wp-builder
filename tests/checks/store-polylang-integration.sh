#!/usr/bin/env bash
# plugins/store-polylang against a real WordPress with WooCommerce and Polylang (es default, en
# second), installed the way /wp-woo-setup installs it, asserted on the store itself:
#   - activating the bridge on a store with nothing translated leaves the shop and cart pages'
#     HTML as it was;
#   - setup turns on translation for products only on a store with none yet, and says so;
#     on a store that already has products it changes nothing and says how;
#   - /wp-polylang (pll-export, pll-import) gives a new product translation its price, SKU,
#     stock and category in its own language;
#   - a sale in one language takes the stock of every translation, once; a price edit reaches
#     the translation;
#   - each language's pages link to that language's cart;
#   - a block-checkout order placed through the Store API from an English page records `en`;
#   - another plugin that requires both Polylang and WooCommerce makes the bridge stand down,
#     so stock is not taken twice.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks. It provisions its own store
# fixture (WP_FIXTURE_STORE=1).
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi
require_tool php python3 curl

prov=tests/fixtures/wp/provision.sh
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

python3 - "$PROJ/.wp-create.json" "$WP" <<'PY'
import json, sys
m = json.load(open("tests/fixtures/manifests/valid/.wp-create.json"))
m["plugins"]["profile"] = "woo-store"
m["wp_cli"]["wrapper"] = sys.argv[2]
m["store"] = {"tier": "store", "address": {"street": "100 Main St", "city": "Tampa", "postcode": "33602", "country": "US:FL"},
  "currency": "USD", "units": {"weight": "lbs", "dimension": "in"}, "checkout": "block", "payments": {"gateway": "stripe", "mode": "test"},
  "shipping": [{"zone": "United States", "locations": ["US"], "methods": [{"type": "flat_rate", "cost": "10.00"}]}],
  "tax": {"enabled": False, "prices_include_tax": False, "rates": []}}
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
setup() { $WP eval-file skills/wp-woocommerce/scripts/woo-setup.php "$PROJ" "$@" 2>&1; }

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
BASE="http://127.0.0.1:$PORT"
$WP option update home "$BASE" --quiet
$WP option update siteurl "$BASE" --quiet
$WP rewrite structure '/%postname%/' --quiet
$WP eval-file skills/wp-polylang/scripts/pll-setup.php es en >/dev/null 2>&1 || fail "pll-setup could not configure es and en"

bash bin/store-kit-sync.sh "$DIR/wp-content/plugins" >/dev/null && $WP plugin activate store-kit --quiet || fail "could not activate store-kit"
setup >/dev/null || fail "setup failed on the fixture"
$WP option update woocommerce_coming_soon no --quiet
$WP option update woocommerce_cod_settings '{"enabled":"yes","title":"Cash on delivery","description":"","instructions":"","enable_for_methods":[],"enable_for_virtual":"yes"}' --format=json --quiet
# The cart page as the theme prints it, read at render time: a footer comment.
mkdir -p "$DIR/wp-content/mu-plugins"
cat >"$DIR/wp-content/mu-plugins/cart-probe.php" <<'PHP'
<?php
add_action( 'wp_footer', function () {
	echo '<!--cart-probe:' . esc_url( wc_get_page_permalink( 'cart' ) ) . '-->';
} );
PHP

$WP server --host=127.0.0.1 --port="$PORT" >"$DIR/pll-server.log" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/" || true)" = "200" ] && { up=1; break; }
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -10 "$DIR/pll-server.log"; fail "wp server exited before answering on port $PORT"; }
  sleep 1
done
[ -n "$up" ] || fail "the fixture site never answered on port $PORT"

# Nonces and per-request ids differ between two loads of the same page.
page() { curl -s "$1" | sed -E 's/[0-9a-f]{10}/N/g; s/(nonce|Nonce)[^,}]*/NONCE/g'; }
SHOP=$(q 'echo get_permalink( wc_get_page_id( "shop" ) );')
CART=$(q 'echo get_permalink( wc_get_page_id( "cart" ) );')
[ -n "$SHOP" ] && [ -n "$CART" ] || fail "the fixture has no shop or cart page"
before_shop=$(page "$SHOP"); before_cart=$(page "$CART")

# --- Installed the way /wp-woo-setup Step 2 installs it -------------------------------------------
bash bin/store-kit-sync.sh "$DIR/wp-content/plugins" store-polylang >/dev/null || fail "store-kit-sync could not copy store-polylang"
$WP plugin activate store-polylang --quiet || fail "could not activate store-polylang"
[ "$(q 'echo defined( "PLL_WC_BRIDGE" ) ? PLL_WC_BRIDGE : "none";')" = store-polylang ] || fail "the bridge does not run after activation"
[ "$(page "$SHOP")" = "$before_shop" ] || fail "activating the bridge changed the shop page with nothing translated"
[ "$(page "$CART")" = "$before_cart" ] || fail "activating the bridge changed the cart page with nothing translated"

# --- Setup turns on product translation on a store with no products --------------------------------
plan=$(setup dry-run) || fail "setup's dry run failed: $plan"
grep -Fq 'would-set languages:products' <<<"$plan" || fail "the dry run does not plan product translation: $(grep -F languages: <<<"$plan")"
[ "$(q '$o = get_option( "polylang" ); echo in_array( "product", (array) $o["post_types"], true ) ? "yes" : "no";')" = no ] \
  || fail "the dry run turned on product translation"
out=$(setup) || fail "setup failed: $out"
grep -Fq 'set languages:products' <<<"$out" || fail "setup did not turn on product translation: $(grep -F languages: <<<"$out")"
[ "$(q '$o = get_option( "polylang" ); echo json_encode( array( in_array( "product", (array) $o["post_types"], true ), array_values( array_intersect( array( "product_cat", "product_tag" ), (array) $o["taxonomies"] ) ) ) );')" = '[true,["product_cat","product_tag"]]' ] \
  || fail "products, product categories and tags are not all translated after setup"
out=$(setup) || fail "a second setup failed: $out"
grep -Fq 'ok languages:products' <<<"$out" || fail "a second setup did not read product translation as done"

# --- /wp-polylang translates a product with its store data -----------------------------------------
ES=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$ES" ] || fail "no fixture product"
q "\$c = wp_insert_term( 'Tazas', 'product_cat' ); wp_set_object_terms( $ES, array( (int) \$c['term_id'] ), 'product_cat' );"
[ "$(q "echo pll_get_post_language( $ES );")" = es ] || fail "a new product did not get the default language"
$WP eval-file skills/wp-polylang/scripts/pll-export.php es en "$PROJ/export.json" >/dev/null 2>&1 || fail "pll-export failed"
python3 - "$PROJ/export.json" "$PROJ/translated.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for it in m["items"]:
    f = it["fields"]
    if "post_title" in f:
        f["post_title"] += " EN"
        if f.get("post_name"):
            f["post_name"] += "-en"
    if "name" in f:
        f["name"] += " EN"
        f["slug"] = (f.get("slug") or "term") + "-en"
    if "value" in f:
        f["value"] += " EN"
json.dump(m, open(sys.argv[2], "w"))
PY
imp=$($WP eval-file skills/wp-polylang/scripts/pll-import.php "$PROJ/translated.json" 2>&1) || fail "pll-import failed: $imp"
grep -Fq 'Gave 1 new product translation(s) their price, SKU, stock and categories.' <<<"$imp" \
  || fail "pll-import did not report the product pass: $(tail -3 <<<"$imp")"
EN=$(q "echo (int) pll_get_post( $ES, 'en' );")
[ -n "$EN" ] && [ "$EN" != 0 ] || fail "the product has no English translation after the import"
got=$(q "\$p = wc_get_product( $EN ); echo implode( '|', array( \$p->get_type(), \$p->get_price(), \$p->get_sku(), \$p->get_stock_quantity(), implode( ',', wp_list_pluck( get_the_terms( $EN, 'product_cat' ) ?: array(), 'name' ) ) ) );")
[ "$got" = 'simple|20.00|FIXTURE-MUG|10|Tazas EN' ] || fail "the English product is not a priced copy in its own category: $got"

# --- One stock, shared data ------------------------------------------------------------------------
q "\$o = wc_create_order(); \$o->add_product( wc_get_product( $EN ), 2 ); \$o->save(); wc_reduce_stock_levels( \$o->get_id() );"
[ "$(q "echo wc_get_product( $ES )->get_stock_quantity() . '/' . wc_get_product( $EN )->get_stock_quantity();")" = 8/8 ] \
  || fail "a sale of 2 in English did not leave both translations at 8: $(q "echo wc_get_product( $ES )->get_stock_quantity() . '/' . wc_get_product( $EN )->get_stock_quantity();")"
q "\$p = wc_get_product( $ES ); \$p->set_regular_price( '25.00' ); \$p->save();"
[ "$(q "echo wc_get_product( $EN )->get_regular_price();")" = 25.00 ] || fail "a price edit in Spanish did not reach the English product"

# --- Each language links its own cart --------------------------------------------------------------
CART_EN=$(q 'echo get_permalink( pll_get_post( (int) get_option( "woocommerce_cart_page_id" ), "en" ) );')
[ -n "$CART_EN" ] && [ "$CART_EN" != "$CART" ] || fail "the import gave the cart page no English translation"
probe() { curl -s "$1" | sed -n 's/.*<!--cart-probe:\([^>]*\)-->.*/\1/p' | sed -n 1p; }
[ "$(probe "$(q "echo get_permalink( $EN );")")" = "$CART_EN" ] || fail "the English product page does not link the English cart"
[ "$(probe "$(q "echo get_permalink( $ES );")")" = "$CART" ] || fail "the Spanish product page does not link the Spanish cart"

# --- A block-checkout order records the shopper's language -----------------------------------------
JAR="$PROJ/cookies"
curl -s -c "$JAR" -b "$JAR" -o /dev/null "$(q "echo get_permalink( $EN );")"
API="$BASE/wp-json/wc/store/v1"
NONCE=$(curl -s -c "$JAR" -b "$JAR" -D - -o /dev/null "$API/cart" | sed -n 's/^[Nn]once: *//p' | tr -d '\r')
[ -n "$NONCE" ] || fail "the Store API gave no nonce"
code=$(curl -s -c "$JAR" -b "$JAR" -H "Nonce: $NONCE" -H 'Content-Type: application/json' -o /dev/null -w '%{http_code}' \
  -X POST "$API/cart/add-item" -d "{\"id\":$EN,\"quantity\":1}")
[ "$code" = 201 ] || fail "the Store API did not add the English product to the cart: HTTP $code"
# Setup protects checkout with Turnstile in test mode, which accepts this dummy token.
addr='{"first_name":"Ada","last_name":"Byron","address_1":"100 Main St","city":"Tampa","state":"FL","postcode":"33602","country":"US","email":"buyer@example.invalid","phone":"5550100"}'
curl -s -c "$JAR" -b "$JAR" -H "Nonce: $NONCE" -H 'Content-Type: application/json' -X POST "$API/checkout" \
  -d "{\"billing_address\":$addr,\"shipping_address\":$addr,\"payment_method\":\"cod\",\"extensions\":{\"simple-cloudflare-turnstile\":{\"token\":\"XXXX.DUMMY.TOKEN.XXXX\"}}}" >"$PROJ/checkout.json" || true
ORDER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("order_id") or "")' "$PROJ/checkout.json" 2>/dev/null || true)
[ -n "$ORDER" ] || fail "the Store API checkout placed no order: $(head -c 400 "$PROJ/checkout.json")"
[ "$(q "echo wc_get_order( $ORDER )->get_meta( '_store_pll_order_lang' );")" = en ] \
  || fail "an order placed from an English page did not record en: '$(q "echo wc_get_order( $ORDER )->get_meta( '_store_pll_order_lang' );")'"
[ "$(q 'echo get_option( "woocommerce_custom_orders_table_enabled" );')" = yes ] || fail "the order was not placed on HPOS, which the plugin declares"
[ "$(q "echo wc_get_product( $ES )->get_stock_quantity() . '/' . wc_get_product( $EN )->get_stock_quantity();")" = 7/7 ] \
  || fail "the Store API sale did not leave both translations at 7"

# --- A store that already has products: setup changes nothing --------------------------------------
q '$o = get_option( "polylang" ); $o["post_types"] = array_values( array_diff( (array) $o["post_types"], array( "product" ) ) ); update_option( "polylang", $o );'
out=$(setup) || fail "setup failed on a store with products: $out"
grep -Eq '^degraded languages:products: [0-9]+ product\(s\) exist in one language' <<<"$out" \
  || fail "setup did not explain why it left products untranslated: $(grep -F languages: <<<"$out")"
[ "$(q '$o = get_option( "polylang" ); echo in_array( "product", (array) $o["post_types"], true ) ? "yes" : "no";')" = no ] \
  || fail "setup turned on product translation on a store that already has products"
q '$o = get_option( "polylang" ); $o["post_types"][] = "product"; update_option( "polylang", $o );'

# --- Another bridge: this one stands down ----------------------------------------------------------
mkdir -p "$DIR/wp-content/plugins/other-bridge"
printf '%s\n' '<?php' '/**' ' * Plugin Name: Other Bridge' ' * Requires Plugins: polylang, woocommerce' ' */' >"$DIR/wp-content/plugins/other-bridge/other-bridge.php"
$WP plugin activate other-bridge --quiet || fail "could not activate the stand-in bridge"
[ "$(q 'echo defined( "PLL_WC_BRIDGE" ) ? PLL_WC_BRIDGE : "none";')" = none ] || fail "store-polylang still runs beside another bridge"
q "wc_update_product_stock( wc_get_product( $ES ), 1, 'decrease' );"
[ "$(q "echo wc_get_product( $ES )->get_stock_quantity() . '/' . wc_get_product( $EN )->get_stock_quantity();")" = 6/7 ] \
  || fail "store-polylang replayed a stock change while standing down"
$WP plugin deactivate other-bridge --quiet
[ "$(q 'echo defined( "PLL_WC_BRIDGE" ) ? PLL_WC_BRIDGE : "none";')" = store-polylang ] || fail "the bridge did not come back once the other one was gone"

echo "PASS: store-polylang shares stock and data across translations, links each language's pages, records the order language, and stands down beside another bridge"
