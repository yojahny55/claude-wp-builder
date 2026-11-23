#!/usr/bin/env bash
# bin/woo-launch.mjs against a real WordPress with WooCommerce, Stripe, Turnstile and store-kit,
# set up by /wp-woo-setup's script: /wp-woo-launch, asserted on the store itself.
#   - every precondition stops a launch, by name: a local site, no live Stripe keys, Turnstile's
#     test keys, an empty terms page; and a check-only run writes nothing;
#   - --confirm with any host but the site's own writes nothing, not even a backup;
#   - a launch runs in order (Stripe, cash on delivery, Turnstile, coming soon off last), takes a
#     verified backup first, and records store.launch with it;
#   - /wp-woo-setup, even with force, leaves a launched store's launch state alone;
#   - a second launch is refused, --revert puts back coming soon only and records reverted_at;
#   - a live store that fails the final verify goes back to coming soon, and nothing is recorded.
# The live keys are fakes with live prefixes: no Stripe call is made (net-guard), and a real
# card payment is a documented ceiling.
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
BACKUPS=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$PROJ" "$BACKUPS"
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
  "tax": {"enabled": True, "prices_include_tax": False, "rates": [{"country": "US", "state": "FL", "rate": "6.0000", "name": "FL Sales Tax", "shipping": True}]}}
json.dump(m, open(sys.argv[1], "w"), indent=2)
PY
setup() { $WP eval-file skills/wp-woocommerce/scripts/woo-setup.php "$PROJ" "$@" 2>&1; }
bash bin/store-kit-sync.sh "$DIR/wp-content/plugins" >/dev/null && $WP plugin activate store-kit --quiet || fail "could not activate store-kit"
setup >/dev/null || fail "setup failed on the fixture"
PRODUCT=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$PRODUCT" ] || fail "no fixture product"
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
HOST=$(q 'echo wp_parse_url( home_url(), PHP_URL_HOST ) . ( wp_parse_url( home_url(), PHP_URL_PORT ) ? ":" . wp_parse_url( home_url(), PHP_URL_PORT ) : "" );')
[ -n "$HOST" ] || fail "could not read the fixture's home host"

OUT="$PROJ/out"
# Runs a launch; prints its exit code. Its output is in $OUT.
launch() { local code=0; node bin/woo-launch.mjs "$PROJ" "$@" >"$OUT" 2>&1 || code=$?; echo "$code"; }
L() { launch --url "http://127.0.0.1:$PORT/" "$@"; }
has() { grep -F -- "$1" "$OUT" >/dev/null || fail "$2: no \"$1\" in: $(tr '\n' '|' <"$OUT")"; }
opt() { q "echo get_option( '$1' );"; }
sub() { q "\$o = get_option( '$1' ); echo is_array( \$o ) && isset( \$o['$2'] ) ? \$o['$2'] : '';"; }
launched() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["store"].get("launch")))' "$PROJ/.wp-create.json"; }
# One line per option, name and a hash of its value: a mismatch names what changed. WordPress
# writes some options on its own while the fixture serves requests, whatever this check runs:
# WP-Cron reschedules events in `cron` after any front-end request, and Action Scheduler (run
# by that cron) keeps its locks in `action_scheduler_lock_*`. Those are the scheduler's
# bookkeeping, not the store, and counting them made the wrong-host assertion fail now and
# then in CI with no change to the launch. Any other changed option still fails.
snapshot() { q 'global $wpdb; foreach ( $wpdb->get_results( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name NOT LIKE \"\\_transient%\" AND option_name NOT LIKE \"\\_site\\_transient%\" AND option_name NOT LIKE \"%session%\" AND option_name <> \"cron\" AND option_name NOT LIKE \"action\\_scheduler\\_lock\\_%\" ORDER BY option_name" ) as $r ) { echo $r->option_name, " ", md5( $r->option_value ), "\n"; }'; }
# Fails naming the options that differ from the snapshot in $1.
unchanged() {
  local now changed
  now=$(snapshot)
  [ "$now" = "$1" ] && return 0
  changed=$(diff <(printf '%s\n' "$1") <(printf '%s\n' "$now") | sed -n 's/^[<>] \([^ ]*\) .*/\1/p' | sort -u | tr '\n' ' ' || true)
  fail "$2 (options: ${changed:-none listed})"
}

# --- A local site is never launched ---------------------------------------------------------------
code=$(L)
[ "$code" = 1 ] || fail "a check on a local site exited $code, not 1: $(cat "$OUT")"
has "fail environment: reads as local" "a local site"
has "launch: blocked" "a local site"

# --- A production store as setup leaves it: every missing piece is named --------------------------
$WP config set WP_ENVIRONMENT_TYPE production --type=constant --quiet
setup >/dev/null || fail "setup failed on production"
[ "$(opt woocommerce_coming_soon)" = yes ] || fail "setup did not leave the production store coming soon"
before=$(snapshot)
code=$(L)
[ "$code" = 1 ] || fail "a production store with no live keys exited $code, not 1: $(cat "$OUT")"
has "pass environment" "production"
for f in "fail stripe:secret_key: STORE_KIT_STRIPE_SECRET_KEY is not defined" "fail stripe:publishable_key" \
         "fail stripe:webhook_secret" "fail turnstile:cfturnstile_key: CF_TURNSTILE_SITE_KEY is not defined" "fail audit: STORE-005"; do
  has "$f" "a production store as setup leaves it"
done
unchanged "$before" "a check-only run changed the store's options"
[ -z "$(ls -A "$BACKUPS")" ] || fail "a check-only run took a backup"

$WP config set CF_TURNSTILE_SITE_KEY 1x00000000000000000000AA --type=constant --quiet
L >/dev/null
has "fail turnstile:cfturnstile_key: CF_TURNSTILE_SITE_KEY is Cloudflare's test key" "Turnstile's test key"
$WP config set CF_TURNSTILE_SITE_KEY 3x00000000000000000000FF --type=constant --quiet
L >/dev/null
has "fail turnstile:cfturnstile_key: CF_TURNSTILE_SITE_KEY is Cloudflare's test key" "Turnstile's forced-challenge test key"
$WP config set STORE_KIT_STRIPE_SECRET_KEY sk_test_notlive --type=constant --quiet
L >/dev/null
has "fail stripe:secret_key: STORE_KIT_STRIPE_SECRET_KEY does not look like a live Stripe key" "a test key in the live constant"

# --- Everything in place: ready -------------------------------------------------------------------
$WP config set STORE_KIT_STRIPE_SECRET_KEY sk_live_launchfixture000000 --type=constant --quiet
$WP config set STORE_KIT_STRIPE_PUBLISHABLE_KEY pk_live_launchfixture000000 --type=constant --quiet
$WP config set STORE_KIT_STRIPE_WEBHOOK_SECRET whsec_launchfixture000000 --type=constant --quiet
$WP config set CF_TURNSTILE_SITE_KEY 0x4AAAAAAAlaunchFixtureSite --type=constant --quiet
$WP config set CF_TURNSTILE_SECRET_KEY 0x4AAAAAAAlaunchFixtureSecret --type=constant --quiet
q 'foreach ( array( "woocommerce_terms_page_id", "woocommerce_refund_returns_page_id", "wp_page_for_privacy_policy" ) as $o ) {
     wp_update_post( array( "ID" => (int) get_option( $o ), "post_status" => "publish", "post_content" => "<p>What the merchant wrote.</p>" ) ); }'
code=$(L)
[ "$code" = 0 ] || fail "a store with every piece in place exited $code, not 0: $(cat "$OUT")"
has "launch: ready" "ready"
if grep -F 'launchfixture' "$OUT" >/dev/null; then fail "a check printed a key value"; fi

# --- The wrong host writes nothing ----------------------------------------------------------------
before=$(snapshot)
code=$(L --confirm "not-$HOST" --backup-out "$BACKUPS")
[ "$code" = 1 ] || fail "a wrong --confirm exited $code, not 1"
has "is not this site's host" "a wrong --confirm"
unchanged "$before" "a wrong --confirm changed the store"
[ -z "$(ls -A "$BACKUPS")" ] || fail "a wrong --confirm took a backup"

# --- The launch -------------------------------------------------------------------------------------
code=$(L --confirm "$HOST" --backup-out "$BACKUPS")
[ "$code" = 0 ] || fail "the launch exited $code, not 0: $(cat "$OUT")"
order=$(grep -E '^(set|ok) (stripe:testmode|stripe:enabled|cod:enabled|turnstile:checkout|turnstile:tested|coming-soon)$' "$OUT" | cut -d' ' -f2 | tr '\n' ' ')
[ "$order" = "stripe:testmode stripe:enabled cod:enabled turnstile:checkout turnstile:tested coming-soon " ] || fail "the launch ran out of order: $order"
[ "$(opt woocommerce_coming_soon)" = no ] || fail "the store is still coming soon after the launch"
[ "$(sub woocommerce_stripe_settings testmode)" = no ] || fail "Stripe is still in test mode"
[ "$(sub woocommerce_stripe_settings enabled)" = yes ] || fail "Stripe is not enabled"
[ "$(sub woocommerce_cod_settings enabled)" = no ] || fail "cash on delivery is still on"
[ "$(opt cfturnstile_woo_checkout)" = 1 ] || fail "Turnstile does not guard the checkout"
rec=$(launched)
backup=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["backup"])' "$rec")
case "$backup" in "$BACKUPS"/*pre-launch) ;; *) fail "store.launch.backup is not the pre-launch backup: $rec" ;; esac
[ -s "$backup/db.sql" ] && [ -f "$backup/backup.json" ] || fail "the recorded backup has no db.sql or backup.json"
problems=$(node --input-type=module -e 'import { readFileSync } from "node:fs"; import { validateStore } from "./bin/lib/manifest.mjs"; process.stdout.write(validateStore(JSON.parse(readFileSync(process.argv[1], "utf8")).store).join("; "));' "$PROJ/.wp-create.json")
[ -z "$problems" ] || fail "the launch left a store block that does not validate: $problems"

# --- Setup, even forced, leaves a launched store live ----------------------------------------------
setup force >"$PROJ/setup.out" || fail "setup failed on the launched store: $(cat "$PROJ/setup.out")"
[ "$(opt woocommerce_coming_soon)" = no ] || fail "setup force took a launched store back to coming soon"
[ "$(sub woocommerce_stripe_settings testmode)" = no ] || fail "setup force put a launched store back in test mode"
grep -F '/wp-woo-launch owns it' "$PROJ/setup.out" >/dev/null || fail "setup does not say why it left launch state alone: $(grep client "$PROJ/setup.out" | sed -n 1,3p)"

# --- Twice is refused; --revert hides it ---------------------------------------------------------
code=$(L --confirm "$HOST" --backup-out "$BACKUPS")
[ "$code" = 1 ] || fail "a second launch exited $code, not 1"
has "was launched at" "a second launch"
code=$(launch --revert)
[ "$code" = 0 ] || fail "--revert exited $code: $(cat "$OUT")"
[ "$(opt woocommerce_coming_soon)" = yes ] || fail "--revert did not bring coming soon back"
[ "$(sub woocommerce_stripe_settings testmode)" = no ] || fail "--revert changed more than coming soon"
launched | grep -F '"reverted_at"' >/dev/null || fail "--revert recorded no reverted_at: $(launched)"

# --- A live store that fails verify goes back to coming soon --------------------------------------
cat >"$DIR/wp-content/mu-plugins/00-launch-break.php" <<'PHP'
<?php
// The shop answers 500 once the store is visible: the final verify must fail.
add_action( 'template_redirect', function () {
	if ( function_exists( 'is_shop' ) && is_shop() && 'no' === get_option( 'woocommerce_coming_soon' ) ) {
		status_header( 500 );
		exit;
	}
}, 0 );
PHP
rec_before=$(launched)
code=$(L --confirm "$HOST" --backup-out "$BACKUPS")
[ "$code" = 1 ] || fail "a launch whose verify fails exited $code, not 1: $(cat "$OUT")"
has "it is coming soon again, nothing recorded" "a failed verify"
[ "$(opt woocommerce_coming_soon)" = yes ] || fail "a failed verify left the store visible"
[ "$(launched)" = "$rec_before" ] || fail "a failed launch changed store.launch: $(launched)"
rm -f "$DIR/wp-content/mu-plugins/00-launch-break.php"

# --- Usage ------------------------------------------------------------------------------------------
code=0; node bin/woo-launch.mjs "$PROJ" --bogus >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "an unknown flag exited $code, not 64"
code=0; node bin/woo-launch.mjs "$PROJ" --revert --confirm x >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "--revert with --confirm exited $code, not 64"

echo "PASS: woo-launch checks, launches in order, records it, and goes back to coming soon"
