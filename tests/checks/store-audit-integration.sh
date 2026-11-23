#!/usr/bin/env bash
# bin/store-audit.mjs against a real WordPress with WooCommerce and store-kit, set up by
# /wp-woo-setup's script: the store category of /wp-audit, asserted on the store itself.
#   - a local store as setup left it fails nothing but what a local store lacks by design: its
#     policy pages and its launch (INFO), and the run leaves no cart session;
#   - --read-only runs no cart check (STORE-004 UNMEASURED with a reason Step 6.8 accepts) and
#     leaves the store's sessions and options byte for byte as they were;
#   - each database check fails on the defect it names: no shipping method at the store address,
#     taxes on with no rate, a product with no price, image or category, a failed scheduled
#     action, a sender on another domain;
#   - on a production site the launch state is CRITICAL;
#   - a store with no store block is audited at the tier it shows, its STORE-001 N/A;
#   - a catalog's selling-only checks are N/A.
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
block = json.loads(sys.argv[2]) if sys.argv[2] else None
if block:
    m["store"] = block
else:
    m.pop("store", None)
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
}
setup() { $WP eval-file skills/wp-woocommerce/scripts/woo-setup.php "$PROJ" 2>&1; }

write_manifest "$STORE"
bash bin/store-kit-sync.sh "$DIR/wp-content/plugins" >/dev/null && $WP plugin activate store-kit --quiet || fail "could not activate store-kit"
setup >/dev/null || fail "setup failed on the fixture"
PRODUCT=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$PRODUCT" ] || fail "no fixture product"
# The fixture product as a merchant would publish it: an image and a category of its own.
q "\$img = wp_insert_attachment( array( 'post_title' => 'Mug', 'post_mime_type' => 'image/jpeg', 'post_status' => 'inherit' ) );
   \$cat = wp_insert_term( 'Mugs', 'product_cat' );
   \$p = wc_get_product( $PRODUCT ); \$p->set_image_id( \$img ); \$p->set_category_ids( array( \$cat['term_id'] ) ); \$p->save();"

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

OUT="$PROJ/out.json"
# Runs the audit; prints its exit code. The JSON is in $OUT.
audit() { local code=0; node bin/store-audit.mjs "$PROJ" --url "http://127.0.0.1:$PORT/" "$@" >"$OUT" 2>"$PROJ/err" || code=$?; echo "$code"; }
# "<status> <severity>" of one check: PASS, FAIL <severity>, NA, UNMEASURED, or MISSING.
st() {
  python3 - "$OUT" "$1" <<'PY'
import json, sys
r, c = json.load(open(sys.argv[1])), sys.argv[2]
f = [x for x in r["findings"] if x["check"] == c]
if f: print("FAIL", f[0]["severity"]); sys.exit()
if any(x["check"] == c for x in r["not_applicable"]): print("NA"); sys.exit()
if any(x["check"] == c for x in r["unmeasured"]): print("UNMEASURED"); sys.exit()
print("PASS" if c in r["checks_executed"] else "MISSING")
PY
}
msg() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(" | ".join(x["message"]+" :: "+x.get("evidence","") for x in r["findings"]+r["not_applicable"]+r["unmeasured"] if x["check"]==sys.argv[2]))' "$OUT" "$1"; }
expect() { local got; got=$(st "$1"); [ "$got" = "$2" ] || fail "$1 is \"$got\", not \"$2\" ($3): $(msg "$1")"; }
sessions() { q 'global $wpdb; echo $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}woocommerce_sessions" );'; }
snapshot() { q 'global $wpdb; echo md5( serialize( $wpdb->get_results( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name NOT LIKE \"\\_transient%\" AND option_name NOT LIKE \"\\_site\\_transient%\" ORDER BY option_name" ) ) ), "/", $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}woocommerce_sessions" ), "/", $wpdb->get_var( "SELECT MAX(ID) FROM {$wpdb->posts}" );'; }

# --- A local store as setup left it ------------------------------------------------------------
code=$(audit)
[ "$code" = 1 ] || fail "a fresh local store exited $code, not 1 (its policy pages are drafts): $(cat "$PROJ/err")"
for c in STORE-001 STORE-002 STORE-003 STORE-004 STORE-009 STORE-010 STORE-011 STORE-012 STORE-013; do expect "$c" PASS "a local store as setup left it"; done
expect STORE-005 "FAIL WARNING" "setup publishes the terms page empty"
msg STORE-005 | grep -F 'is published empty' >/dev/null || fail "STORE-005 does not say the terms page is empty: $(msg STORE-005)"
expect STORE-006 "FAIL WARNING" "WordPress's privacy page is a draft"
expect STORE-007 "FAIL WARNING" "WooCommerce's refund page is a draft"
expect STORE-014 "FAIL INFO" "a local store is not launched, by design"
msg STORE-014 | grep -F 'cash on delivery is on' >/dev/null || fail "STORE-014 does not name cash on delivery: $(msg STORE-014)"
[ "$(sessions)" = 0 ] || fail "the audit left a cart session behind"
node -e 'const r=require(process.argv[1]); for (const k of ["category","checks_executed","findings","unmeasured","not_applicable","notes"]) if (!(k in r)) process.exit(1); if (r.category!=="store") process.exit(1)' "$OUT" \
  || fail "the output is not the report contract's findings JSON"

# --- --read-only writes nothing -------------------------------------------------------------------
before=$(snapshot)
code=$(audit --read-only)
[ "$(snapshot)" = "$before" ] || fail "a --read-only audit changed the store: $before -> $(snapshot)"
expect STORE-004 UNMEASURED "--read-only runs no cart"
reason=$(python3 -c 'import json,sys; print([x["reason"] for x in json.load(open(sys.argv[1]))["unmeasured"] if x["check"]=="STORE-004"][0])' "$OUT")
kind=$(node --input-type=module -e 'import { classifyUnmeasured } from "./bin/lib/audit-schema.mjs"; process.stdout.write(String(classifyUnmeasured(process.argv[1])));' "$reason")
[ "$kind" = report-only ] || fail "Step 6.8 does not accept STORE-004's read-only reason (\"$reason\" classified as $kind)"

# --- Each database check fails on its defect ----------------------------------------------------
q 'foreach ( array( "woocommerce_terms_page_id", "woocommerce_refund_returns_page_id", "wp_page_for_privacy_policy" ) as $o ) {
     wp_update_post( array( "ID" => (int) get_option( $o ), "post_status" => "publish", "post_content" => "<p>What the merchant wrote.</p>" ) ); }'
audit >/dev/null
for c in STORE-005 STORE-006 STORE-007; do expect "$c" PASS "its page is published"; done

ZONES=$(q 'foreach ( WC_Shipping_Zones::get_zones() as $z ) { $zone = new WC_Shipping_Zone( $z["id"] ); foreach ( $zone->get_shipping_methods() as $m ) { echo $z["id"], ":", $m->instance_id, " "; } }')
q 'foreach ( WC_Shipping_Zones::get_zones() as $z ) { $zone = new WC_Shipping_Zone( $z["id"] ); foreach ( $zone->get_shipping_methods() as $m ) { $zone->delete_shipping_method( $m->instance_id ); } }'
audit >/dev/null
expect STORE-009 "FAIL CRITICAL" "no shipping method at the store address [zones were: $ZONES]"
setup >/dev/null
audit >/dev/null
expect STORE-009 PASS "setup put the method back"

q 'global $wpdb; $wpdb->query( "DELETE FROM {$wpdb->prefix}woocommerce_tax_rates" );'
audit >/dev/null
expect STORE-010 "FAIL WARNING" "taxes on with no rate"
setup >/dev/null

BARE=$(q '$p = new WC_Product_Simple(); $p->set_name( "Bare" ); $p->set_status( "publish" ); $p->save(); echo $p->get_id();')
audit >/dev/null
expect STORE-011 "FAIL CRITICAL" "a product with no price"
for w in "without a price" "without an image" "only in the default category" "($BARE)"; do
  msg STORE-011 | grep -F -- "$w" >/dev/null || fail "STORE-011 does not say \"$w\": $(msg STORE-011)"
done
q "wp_delete_post( $BARE, true );"

q 'global $wpdb; $wpdb->insert( $wpdb->prefix . "actionscheduler_actions", array( "hook" => "store_audit_fixture_hook", "status" => "failed", "scheduled_date_gmt" => gmdate( "Y-m-d H:i:s" ), "scheduled_date_local" => gmdate( "Y-m-d H:i:s" ), "last_attempt_gmt" => gmdate( "Y-m-d H:i:s" ), "last_attempt_local" => gmdate( "Y-m-d H:i:s" ), "args" => "[]", "group_id" => 0 ) );'
audit >/dev/null
expect STORE-012 "FAIL WARNING" "a failed scheduled action"
msg STORE-012 | grep -F 'store_audit_fixture_hook x1' >/dev/null || fail "STORE-012 does not name the failed hook: $(msg STORE-012)"
q 'global $wpdb; $wpdb->delete( $wpdb->prefix . "actionscheduler_actions", array( "hook" => "store_audit_fixture_hook" ) );'

FROM=$(q 'echo get_option( "woocommerce_email_from_address" );')
q 'update_option( "woocommerce_email_from_address", "shop@another-domain.test" );'
audit >/dev/null
expect STORE-008 "FAIL INFO" "a sender on another domain, on a local site"
q "update_option( 'woocommerce_email_from_address', '$FROM' );"

# --- Production: the launch state blocks ----------------------------------------------------------
$WP config set WP_ENVIRONMENT_TYPE production --type=constant --quiet
audit >/dev/null
expect STORE-014 "FAIL CRITICAL" "a production store that is not launched"
$WP config set WP_ENVIRONMENT_TYPE local --type=constant --quiet

# --- No store block: the tier the store shows ---------------------------------------------------
write_manifest ''
code=$(audit)
expect STORE-001 NA "no store block"
expect STORE-004 PASS "a selling store with no block still takes a cart"
python3 -c 'import json,sys; sys.exit(0 if any("selling store" in n for n in json.load(open(sys.argv[1]))["notes"]) else 1)' "$OUT" \
  || fail "no note says which tier a store with no block was audited at"
# Cash on delivery is a merchant's choice on a store setup never set up.
if msg STORE-014 | grep -F 'cash on delivery' >/dev/null; then fail "STORE-014 flags cash on delivery on a store with no block: $(msg STORE-014)"; fi

# --- A catalog ---------------------------------------------------------------------------------
write_manifest "$CATALOG"
setup >/dev/null || fail "setup failed on the catalog"
audit >/dev/null
for c in STORE-005 STORE-007 STORE-009 STORE-010; do expect "$c" NA "a catalog sells nothing"; done
expect STORE-004 PASS "a catalog refuses the cart"

# --- Usage --------------------------------------------------------------------------------------
code=0; node bin/store-audit.mjs "$PROJ" --bogus >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "an unknown flag exited $code, not 64"

echo "PASS: store-audit measures a real store, and --read-only leaves it as it was"
