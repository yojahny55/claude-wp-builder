#!/usr/bin/env bash
# The header cart link of a store (N01 piece 3): templates/store/store-cart.php and its script,
# installed by /wp-woo-setup Step 6.6, called from header.php by /wp-header on a store or full
# tier. This pins:
#   - the contract: Step 6.6 copies both files; /wp-header reads the tier and hands it on;
#     wp-template calls the fixed part, outside the menu the hamburger hides, never its own
#     cart markup;
#   - the PHP: parses once substituted, renders nothing without WooCommerce or in catalog mode,
#     escapes what it prints, filters the demo icon to SVG;
#   - the script: parses, listens for the classic (jQuery) and block events, reads the Store
#     API, never WooCommerce's cart fragments.
# On a real store: tests/checks/store-theme-integration.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

woo=commands/wp-woo-setup.md
hdr=commands/wp-header.md
tpl_dispatch=skills/wp-header-run/references/template-dispatch.md
php_tpl=templates/store/store-cart.php
js_tpl=templates/store/store-cart.js
[ -f "$php_tpl" ] || fail "$php_tpl is missing"
[ -f "$js_tpl" ] || fail "$js_tpl is missing"

need_token "$woo" '"store-cart.php:template-parts/header/store-cart.php" "store-cart.js:assets/js/store-cart.js"'
need_token "$woo" 'renders nothing in catalog mode'
need_token "$hdr" 'get "$2" store.tier'
need_token "$hdr" 'store tier included'
need_token "$tpl_dispatch" "get_template_part( 'template-parts/header/store-cart', null, array( 'link_class' => '…', 'count_class' => '…', 'icon' => '…' ) )"
need_token "$tpl_dispatch" '**Never inside the menu the'
need_token "$tpl_dispatch" 'never your own cart markup'
need_token BACKLOG.md 'tests/checks/store-cart.sh'

need_token "$php_tpl" "defined( 'ABSPATH' ) || exit;"
need_token "$php_tpl" "if ( function_exists( 'store_kit_catalog_mode' ) && store_kit_catalog_mode() ) {"
need_token "$php_tpl" "null === WC()->cart"
need_token "$php_tpl" 'wp_kses( (string) $store_cart['"'"'icon'"'"'], $store_cart_svg_tags )'
need_token "$php_tpl" "esc_url( wc_get_cart_url() )"
need_token "$php_tpl" "esc_url( rest_url( 'wc/store/v1/cart' ) )"
need_token "$php_tpl" "esc_attr( \$store_cart['link_class'] )"
need_token "$php_tpl" "esc_attr( \$store_cart['count_class'] )"

need_token "$js_tpl" "on( 'added_to_cart removed_from_cart', refresh )"
need_token "$js_tpl" "addEventListener( 'wc-blocks_added_to_cart', refresh )"
need_token "$js_tpl" "addEventListener( 'wc-blocks_removed_from_cart', refresh )"
need_token "$js_tpl" "cart.items_count"
if grep -E 'wc-cart-fragments|wc_fragments|get_refreshed_fragments' "$php_tpl" "$js_tpl" >/dev/null; then
  fail "the cart link uses WooCommerce's cart fragments; it reads the Store API on a change instead"
fi

require_tool php node
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -e 's/__prefix__/fx/g' -e 's/__textdomain__/fx-theme/g' "$php_tpl" > "$tmp/store-cart.php"
if grep -E '__prefix__|__textdomain__' "$tmp/store-cart.php" >/dev/null; then fail "$php_tpl has a token the command does not substitute"; fi
php -l "$tmp/store-cart.php" >/dev/null || fail "$php_tpl does not parse"
node --check "$js_tpl" || fail "$js_tpl does not parse"

echo "PASS: the header cart link is a fixed part, called outside the hamburger, counted by the server and refreshed from the Store API"
