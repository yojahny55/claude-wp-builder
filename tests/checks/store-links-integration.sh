#!/usr/bin/env bash
# skills/wp-woocommerce/scripts/store-links.php against a real WordPress with WooCommerce and
# store-kit: the menu item /wp-seed adds for a demo link to a store page.
#   - shop, cart, checkout and account resolve to WooCommerce's own pages (post_type items
#     whose object is the page id), appended in call order, so the demo's order holds;
#   - a second run adds nothing (idempotent by object id), and neither does a menu that already
#     holds the page;
#   - product is skipped; catalog mode skips cart and checkout; a store without the page, or a
#     menu that does not exist, is `missing` with exit 1;
#   - `url` prints the permalink a button field gets.
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
require_tool php

prov=tests/fixtures/wp/provision.sh
DIR=""
cleanup() {
  status=$?
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(WP_FIXTURE_STORE=1 bash "$prov") || fail "could not provision a store fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
script=skills/wp-woocommerce/scripts/store-links.php

# One line and the exit code, joined: "<line> | <code>".
links() { local out code=0; out=$($WP eval-file "$script" "$@" 2>&1) || code=$?; printf '%s | %s' "$(printf '%s\n' "$out" | sed -n '$p')" "$code"; }
page() { $WP eval "echo (int) wc_get_page_id( '$1' );" 2>/dev/null; }

$WP menu create 'Primary EN' >/dev/null 2>&1 || fail "could not create a menu"
ABOUT=$($WP post create --post_type=page --post_status=publish --post_title=About --porcelain 2>/dev/null)
$WP menu item add-post primary-en "$ABOUT" >/dev/null 2>&1 || fail "could not add a page item"

got=$(links menu primary-en shop)
case "$got" in "added shop: item "*" | 0") ;; *) fail "shop: $got" ;; esac
got=$(links menu primary-en cart 'Bag')
case "$got" in "added cart: item "*" | 0") ;; *) fail "cart: $got" ;; esac
got=$(links menu primary-en account)
case "$got" in "added account: item "*" | 0") ;; *) fail "account: $got" ;; esac

items=$($WP menu item list primary-en --fields=object_id,type,title --format=csv 2>/dev/null | sed 1d)
expected="$ABOUT,post_type,About
$(page shop),post_type,Shop
$(page cart),post_type,Bag
$(page myaccount),post_type,\"My account\""
[ "$items" = "$expected" ] || fail "the menu is not About, Shop, Bag, My account in that order, as WooCommerce page items:
$items"

got=$(links menu primary-en shop)
case "$got" in "ok shop: item "*" | 0") ;; *) fail "a second run for shop: $got" ;; esac
[ "$($WP menu item list primary-en --format=count 2>/dev/null)" = 4 ] || fail "a second run added an item"

got=$(links menu primary-en product)
case "$got" in "skipped product: "*" | 0") ;; *) fail "product: $got" ;; esac
got=$(links url shop)
[ "$got" = "url shop: $($WP eval "echo get_permalink( wc_get_page_id( 'shop' ) );" 2>/dev/null) | 0" ] || fail "url shop: $got"
got=$(links menu no-such-menu shop)
case "$got" in 'missing shop: no menu "no-such-menu" | 1') ;; *) fail "a missing menu: $got" ;; esac
got=$(links menu primary-en bogus)
case "$got" in "usage: "*" | 1") ;; *) fail "an unknown surface: $got" ;; esac

$WP option update store_kit_catalog_mode yes >/dev/null 2>&1 || fail "could not turn catalog mode on"
got=$(links menu primary-en checkout)
case "$got" in "skipped checkout: catalog mode is on"*" | 0") ;; *) fail "checkout in catalog mode: $got" ;; esac
$WP option update store_kit_catalog_mode no >/dev/null 2>&1 || fail "could not turn catalog mode off"

$WP post update "$(page checkout)" --post_status=draft >/dev/null 2>&1 || fail "could not unpublish checkout"
got=$(links menu primary-en checkout)
case "$got" in "missing checkout: "*" | 1") ;; *) fail "an unpublished checkout: $got" ;; esac

echo "PASS: store-links points demo links at WooCommerce's pages, in order, once, and says what it skipped"
