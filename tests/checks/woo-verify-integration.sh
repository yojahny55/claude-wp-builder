#!/usr/bin/env bash
# bin/woo-verify.mjs against a real WordPress with WooCommerce and store-kit, set up by
# /wp-woo-setup's script: what /wp-woo-verify reports, asserted on the store itself.
#   - a store as setup left it passes every check, and the run leaves no cart session and no order;
#   - a block changed since setup last ran fails the setup check, exit 1; a value the client
#     changed is setup's `client` line, reported and not failed;
#   - --order places a cash-on-delivery order, sees the new-order email sent, deletes the order
#     for good with its stock and sales count back, and setup still reads the store as one with
#     no orders; with no mail transport the email check fails instead of passing;
#   - --order is refused, with nothing written, on a store with another order and on a site that
#     is not local; an order a stopped run left behind is removed by the next;
#   - a catalog passes with its cart and checkout sending the visitor to the shop, a cart that
#     refuses the product, and --order refused;
#   - a site that does not answer exits 2; bad arguments exit 64.
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
require_tool php python3 curl node

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

STORE='{"tier":"store","address":{"street":"100 Main St","city":"Tampa","postcode":"33602","country":"US:FL"},
 "currency":"USD","units":{"weight":"lbs","dimension":"in"},"checkout":"block","payments":{"gateway":"stripe","mode":"test"},
 "shipping":[{"zone":"United States","locations":["US"],"methods":[{"type":"flat_rate","cost":"10.00"}]}],
 "tax":{"enabled":true,"prices_include_tax":false,"rates":[{"country":"US","state":"FL","rate":"6.0000","name":"FL Sales Tax","shipping":true}]}}'
CATALOG='{"tier":"catalog","address":{"street":"100 Main St","city":"Tampa","postcode":"33602","country":"US:FL"},
 "currency":"USD","units":{"weight":"lbs","dimension":"in"},"enquiry":["where-to-buy"]}'
write_manifest() {
  python3 - "$PROJ/.wp-create.json" "$1" "$WP" <<'PY'
import json, sys
m = json.load(open("tests/fixtures/manifests/valid/.wp-create.json"))
m["plugins"]["profile"] = "woo-store"
m["wp_cli"]["wrapper"] = sys.argv[3]
m["store"] = json.loads(sys.argv[2])
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
  node bin/wp-config.mjs validate "$PROJ" >/dev/null || fail "this check's store block does not validate"
}
setup() { $WP eval-file skills/wp-woocommerce/scripts/woo-setup.php "$PROJ" 2>&1; }

write_manifest "$STORE"
bash bin/store-kit-sync.sh "$DIR/wp-content/plugins" >/dev/null && $WP plugin activate store-kit --quiet || fail "could not activate store-kit"
setup >/dev/null || fail "setup failed on the fixture"
PRODUCT=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$PRODUCT" ] || fail "no fixture product"

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
$WP server --host=127.0.0.1 --port="$PORT" >"$DIR/woo-server.log" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)" = "200" ] && { up=1; break; }
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -10 "$DIR/woo-server.log"; fail "wp server exited before answering on port $PORT"; }
  sleep 1
done
[ -n "$up" ] || fail "the fixture site never answered on port $PORT"

# Every output line and the exit code: "<lines> | <code>".
verify() { local out code=0; out=$(node bin/woo-verify.mjs "$PROJ" --url "http://127.0.0.1:$PORT/" "$@" 2>&1) || code=$?; printf '%s | %s' "$out" "$code"; }
last() { printf '%s\n' "$1" | sed -n '$p'; }
has() { printf '%s\n' "$1" | grep -F -- "$2" >/dev/null || fail "no line \"$2\" in:
$1"; }
hasnt() { if printf '%s\n' "$1" | grep -F -- "$2" >/dev/null; then fail "a line \"$2\" in:
$1"; fi; }
sessions() { q 'global $wpdb; echo $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}woocommerce_sessions" );'; }
orders() { q 'echo count( wc_get_orders( array( "limit" => -1, "status" => "any", "return" => "ids" ) ) );'; }
stock() { q "\$p = wc_get_product( $PRODUCT ); echo \$p->get_stock_quantity(), '/', \$p->get_total_sales();"; }

# --- A store as setup left it ----------------------------------------------------------------
got=$(verify)
for l in 'pass setup: plan: 0 to set' 'pass page:shop: 200' 'pass page:cart: 200' 'pass page:checkout: 200' 'pass page:myaccount: 200' \
  'pass shop: 1 product(s) on the shop page, 1 published' 'pass cart: "Fixture Mug" added and removed through the Store API'; do
  has "$got" "$l"
done
hasnt "$got" 'fail '
case "$(last "$got")" in "verify: "*" passed, 0 failed, 0 skipped | 0") ;; *) fail "a store as setup left it: $got" ;; esac
[ "$(sessions)" = 0 ] || fail "a verification left a cart session behind"
[ "$(orders)" = 0 ] || fail "a verification without --order placed an order"

# --- Drift: the block changed and setup has not run since -------------------------------------
write_manifest "${STORE/\"USD\"/\"EUR\"}"
got=$(verify)
has "$got" 'note setup: would-set woocommerce_currency'
has "$got" 'fail setup: 1 value(s) no longer match the store block'
case "$(last "$got")" in *" | 1") ;; *) fail "drift did not exit 1: $got" ;; esac
write_manifest "$STORE"
# A value the client changed is theirs, by setup's own rule: reported, not a failure.
q 'update_option( "woocommerce_currency", "EUR" );'
got=$(verify)
has "$got" 'note setup: client woocommerce_currency'
has "$got" 'pass setup: plan: 0 to set'
q 'update_option( "woocommerce_currency", "USD" );'

# --- --order: the email, the deletion, the stock ------------------------------------------------
before=$(stock)
# No mail transport, whatever this machine's PHP would deliver to.
cp tests/fixtures/wp/mail-fail.php "$DIR/wp-content/mu-plugins/00-mail-fail.php"
got=$(verify --order)
rm -f "$DIR/wp-content/mu-plugins/00-mail-fail.php"
has "$got" 'fail email: Email "New order" failed to send'
case "$(last "$got")" in *" | 1") ;; *) fail "a failed new-order email did not exit 1: $got" ;; esac
has "$got" 'pass cleanup: order '
cp tests/fixtures/wp/mail-sink.php "$DIR/wp-content/mu-plugins/00-mail-sink.php"
rm -f "$DIR/wp-content/mail-sink.log"
got=$(verify --order)
has "$got" 'pass order: order '
has "$got" ', 31.80, paid by cash on delivery'
has "$got" 'pass email: the new-order email was sent to '
has "$got" 'pass cleanup: order '
case "$(last "$got")" in "verify: "*" passed, 0 failed, 0 skipped | 0") ;; *) fail "--order on a clean local store: $got" ;; esac
[ "$(orders)" = 0 ] || fail "--order left an order on the store"
[ "$(stock)" = "$before" ] || fail "the product's stock and sales count are $(stock), not $before as before the order"
[ "$(sessions)" = 0 ] || fail "--order left a cart session behind"
subjects=$(python3 -c 'import json,sys; [print(json.loads(l)["subject"]) for l in open(sys.argv[1])]' "$DIR/wp-content/mail-sink.log")
grep -F 'New order #' <<<"$subjects" >/dev/null || fail "the mail sink caught no new-order email: $subjects"
if grep -Fi 'cancelled' <<<"$subjects" >/dev/null; then fail "removing the test order emailed a cancellation: $subjects"; fi
out=$(setup)
if grep -F "report-only" <<<"$out" >/dev/null; then fail "setup reads the store as one with orders after --order: $out"; fi
has "$(verify)" 'pass setup: plan: 0 to set'

# --- --order refused: another order, a site that is not local ----------------------------------
CLIENT=$(q '$o = wc_create_order(); $o->set_billing_email( "client@example.test" ); $o->save(); echo $o->get_id();')
got=$(verify --order)
has "$got" "refused: --order places an order only on a local store that sells and has none -- the store has 1 order(s)"
case "$(last "$got")" in "refused: "*" | 1") ;; *) fail "--order beside another order: $got" ;; esac
[ "$(orders)" = 1 ] || fail "a refused --order changed the store's orders"
q "wc_get_order( $CLIENT )->delete( true );"
got=$(node bin/woo-verify.mjs "$PROJ" --url "http://shop.example.test/" --order 2>&1 || true)
has "$got" 'refused: --order places an order only on a local store that sells and has none -- --url points at shop.example.test'
# Loopback on another port is another site: a stand-in Store API whose cart is not in this
# database. No order may be placed, on it or here.
FAKE=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
python3 tests/fixtures/wp/fake-store-api.py "$FAKE" "$PRODUCT" >/dev/null 2>&1 &
FAKE_PID=$!
for _ in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:$FAKE/" && break; sleep 0.2; done
got=$(node bin/woo-verify.mjs "$PROJ" --url "http://127.0.0.1:$FAKE/" --order 2>&1 || true)
kill "$FAKE_PID" 2>/dev/null || true
has "$got" 'pass cart: "Fixture Mug" added and removed through the Store API'
has "$got" "fail order: no order placed: the cart the site at http://127.0.0.1:$FAKE opened is not in the database WP-CLI reads"
[ "$(orders)" = 0 ] || fail "--order placed an order through a site WP-CLI does not read"
$WP config set WP_ENVIRONMENT_TYPE staging --type=constant --quiet
got=$(verify --order)
has "$got" 'refused: --order places an order only on a local store that sells and has none -- the site reads as staging, not local'
$WP config set WP_ENVIRONMENT_TYPE local --type=constant --quiet

# A run that stopped after its checkout left its order behind: the next run removes it.
LEFT=$(q '$o = wc_create_order(); $o->set_billing_email( "woo-verify@example.test" ); $o->set_created_via( "store-api" ); $o->save(); echo $o->get_id();')
got=$(verify --order)
has "$got" "note order: a previous verification's order $LEFT removed"
[ "$(orders)" = 0 ] || fail "a previous verification's order was not removed"

# --- A catalog ------------------------------------------------------------------------------
write_manifest "$CATALOG"
setup >/dev/null || fail "setup failed on the catalog"
got=$(verify)
has "$got" 'pass page:cart: a catalog sends the visitor to the shop'
has "$got" 'pass page:checkout: a catalog sends the visitor to the shop'
has "$got" 'pass cart: a catalog refuses "Fixture Mug" in a cart'
case "$(last "$got")" in "verify: "*" passed, 0 failed, 0 skipped | 0") ;; *) fail "a catalog as setup left it: $got" ;; esac
got=$(verify --order)
has "$got" 'refused: --order places an order only on a local store that sells and has none -- a catalog sells nothing'

# --- Could not measure, usage --------------------------------------------------------------------
DEAD=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
code=0; out=$(node bin/woo-verify.mjs "$PROJ" --url "http://127.0.0.1:$DEAD/" 2>&1) || code=$?
[ "$code" = 2 ] || fail "a site that does not answer exited $code, not 2: $out"
code=0; node bin/woo-verify.mjs "$PROJ" --bogus >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "an unknown flag exited $code, not 64"

echo "PASS: woo-verify checks a real store from outside, and its test order leaves nothing behind"
