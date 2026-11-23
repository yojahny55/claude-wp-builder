#!/usr/bin/env bash
# templates/store/store-enquiry.php against a real WordPress with WooCommerce, store-kit,
# Contact Form 7 and SCF, served over HTTP:
#   - installed with every field empty, a catalog product page shows no enquiry block;
#   - with a number and a real CF7 form ID filled in, the page shows the wa.me link (product
#     name and link in the message) and the rendered form;
#   - an ID that is not a CF7 form renders no form;
#   - the same filled fields on a store that sells (catalog mode off) render nothing.
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
require_tool python3 curl php

prov=tests/fixtures/wp/provision.sh
tpl=templates/store/store-enquiry.php
DIR=""; SERVER_PID=""
cleanup() {
  status=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(WP_FIXTURE_STORE=1 bash "$prov") || fail "could not provision a store fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
q() { $WP eval "$1" 2>/dev/null; }

# The file as /wp-woo-setup installs it, loaded as a must-use plugin: the render does not
# depend on which theme is active, and the fixture has no starter theme.
mkdir -p "$DIR/wp-content/mu-plugins"
sed -e 's/__prefix__/fx/g' -e 's/__textdomain__/fx-theme/g' "$tpl" > "$DIR/wp-content/mu-plugins/store-enquiry.php"
php -l "$DIR/wp-content/mu-plugins/store-enquiry.php" >/dev/null || fail "the substituted file does not parse"

PRODUCT=$($WP eval-file tests/fixtures/wp/woo-product.php 2>/dev/null | sed -n 's/^PRODUCT_ID=//p')
[ -n "$PRODUCT" ] || fail "no fixture product"
FORM=$(q 'echo (int) wp_insert_post( array( "post_type" => "wpcf7_contact_form", "post_status" => "publish", "post_title" => "Enquiry" ) );')
[ "${FORM:-0}" -gt 0 ] || fail "could not create a Contact Form 7 form"
PAGE=$(q 'echo (int) wp_insert_post( array( "post_type" => "page", "post_status" => "publish", "post_title" => "Not a form" ) );')
q 'update_option( "store_kit_catalog_mode", "yes" );'

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
$WP server --host=127.0.0.1 --port="$PORT" >"$DIR/enquiry-server.log" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)" = "200" ] && { up=1; break; }
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -10 "$DIR/enquiry-server.log"; fail "wp server exited before answering on port $PORT"; }
  sleep 1
done
[ -n "$up" ] || { tail -5 "$DIR/enquiry-server.log"; fail "the fixture site never answered on port $PORT"; }
page() { curl -s "http://127.0.0.1:$PORT/?post_type=product&p=$PRODUCT"; }
has() { grep -F -- "$1" >/dev/null <<<"$2"; }

html=$(page)
has 'Fixture Mug' "$html" || fail "the product page did not render the product"
has 'store-enquiry' "$html" && fail "an enquiry block rendered with every field empty"

q "update_option( 'options_store_whatsapp_number', '+1 (813) 555-0100' ); update_option( 'options_store_enquiry_form', '$FORM' );"
html=$(page)
has 'href="https://wa.me/18135550100?text=' "$html" || fail "no wa.me link with the number's digits: $(grep -o 'store-enquiry[^>]*>' <<<"$html" | sed -n 1p)"
has 'Fixture%20Mug' "$html" || fail "the WhatsApp message does not name the product"
has 'class="store-enquiry__form"' "$html" || fail "the Contact Form 7 form did not render"
has 'wpcf7' "$html" || fail "the form block holds no rendered Contact Form 7 markup"

q "update_option( 'options_store_enquiry_form', '$PAGE' );"
html=$(page)
has 'store-enquiry__form' "$html" && fail "an ID that is not a Contact Form 7 form rendered a form"
has 'wa.me/18135550100' "$html" || fail "the WhatsApp link went away with the form"

q 'update_option( "store_kit_catalog_mode", "no" );'
html=$(page)
has 'store-enquiry' "$html" && fail "a store that sells shows the enquiry block"

echo "PASS: store-enquiry renders the filled channels on a real catalog product page, and nothing when empty or selling"
