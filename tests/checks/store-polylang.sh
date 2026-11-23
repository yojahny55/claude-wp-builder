#!/usr/bin/env bash
# store-polylang is PHP this repository ships into client sites that run Polylang: one shared
# stock across a product's translations, store pages and customer emails per language. This
# pins what it must keep being, and how /wp-woo-setup and /wp-polylang reach it:
#   - its no-WordPress unit tests pass (tests/store-polylang/run.php);
#   - every file refuses direct access, uninstall removes every option it owns, its identity is
#     fixed (Author and Author URI name its author; Plugin URI matches plugin.json, and the
#     audit's wp.org lookup ties a slug to a plugin by author and URI), and it declares only
#     what the fixture proves;
#   - it stands down beside another bridge, because two take every sale twice from stock;
#   - store-kit-sync copies it, /wp-woo-setup installs it only on a Polylang site and reads
#     which bridge runs, setup turns on product translation only on a store with no products,
#     and pll-import gives a new product translation its store data through it.
# The behaviour on a real store is tests/checks/store-polylang-integration.sh.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1
require_tool php node

dir=plugins/store-polylang
main=$dir/store-polylang.php
for f in "$main" "$dir/includes/boot.php" "$dir/uninstall.php" tests/store-polylang/run.php; do
  [ -r "$f" ] || fail "$f is missing or unreadable"
done

out=$(php tests/store-polylang/run.php 2>&1) || fail "store-polylang's unit tests fail: $(tail -5 <<<"$out")"
grep -Fq 'store-polylang tests OK' <<<"$out" || fail "the unit tests did not report OK: $(tail -2 <<<"$out")"

while IFS= read -r f; do
  case $f in
    */uninstall.php) grep -Fq "defined( 'WP_UNINSTALL_PLUGIN' )" "$f" || fail "$f runs outside an uninstall" ;;
    *) grep -Fq "if ( ! defined( 'ABSPATH' ) )" "$f" || fail "$f can be requested directly: no ABSPATH guard" ;;
  esac
done < <(find "$dir" -name '*.php')

for o in $(grep -rhoE "(get|update|delete|add)_option\( *'store_pll_[a-z_]+'" "$dir" | grep -oE "store_pll_[a-z_]+" | sort -u); do
  grep -Fq "'$o'" "$dir/uninstall.php" || fail "uninstall leaves $o behind"
done

hdr() { sed -n "s/^ \* $1: *//p" "$main" | sed -n 1p; }
[ "$(hdr 'Update URI')" = "false" ] || fail "store-polylang must set Update URI: false, or WordPress may offer a same-named plugin as an update"
[ "$(hdr 'Requires Plugins')" = "polylang, woocommerce" ] || fail "store-polylang must declare Requires Plugins: polylang, woocommerce"
[ "$(hdr 'Requires PHP')" = "7.4" ] || fail "store-polylang must declare the 7.4 floor"
# store-polylang is signed by its own author, not by the plugin repository's owner: the
# Author header names them and Author URI links their portfolio.
repo=$(node -e 'console.log(require("./.claude-plugin/plugin.json").repository)')
[ "$(hdr 'Author')" = "Lacho00" ] || fail "store-polylang's Author is not Lacho00"
[ "$(hdr 'Author URI')" = "https://lazarosantana.dev" ] || fail "store-polylang's Author URI is not its author's portfolio"
[ "$(hdr 'Plugin URI')" = "$repo" ] || fail "store-polylang's Plugin URI is not plugin.json's repository ($repo)"
v=$(hdr 'Version')
grep -Fq "define( 'STORE_PLL_VERSION', '$v' );" "$main" || fail "STORE_PLL_VERSION does not match the Version header ($v)"
decl=$(grep -oE "declare_compatibility\( '[a-z_]+'" "$main" | sort | tr '\n' ' ')
[ "$decl" = "declare_compatibility( 'cart_checkout_blocks' declare_compatibility( 'custom_order_tables' " ] \
  || fail "store-polylang must declare exactly the two features its integration check proves, found: $decl"

boot=$dir/includes/boot.php
need_token "$boot" "defined( 'PLLWC_VERSION' )" "the bridge no longer stands down beside the paid Polylang for WooCommerce"
need_token "$boot" "define( 'PLL_WC_BRIDGE', 'store-polylang' )" "the bridge no longer announces itself through PLL_WC_BRIDGE"
need_token "$boot" "store_pll_header_is_bridge( \$data['requires'] )" "the bridge no longer looks for another plugin that requires Polylang and WooCommerce"
need_token "$dir/includes/core/emails.php" "woocommerce_store_api_checkout_update_order_from_request" \
  "a block-checkout order no longer records its language"

# The sync script copies it the same way as store-kit, and refuses anything else.
p=$(mktemp -d); trap 'rm -rf "$p"' EXIT
out=$(bash bin/store-kit-sync.sh "$p" store-polylang) || fail "store-kit-sync could not copy store-polylang: $out"
grep -q '^store-polylang absent -> ' <<<"$out" || fail "the first store-polylang sync did not install: $out"
cmp -s "$main" "$p/store-polylang/store-polylang.php" || fail "the installed store-polylang differs from the bundled one"
[ ! -e "$p/store-polylang/tests" ] || fail "the plugin's tests were copied into the site"
code=0; bash bin/store-kit-sync.sh "$p" ../etc >/dev/null 2>&1 || code=$?
[ "$code" = 1 ] || fail "store-kit-sync accepted a plugin name that is not one of ours (exit $code)"

cmd=commands/wp-woo-setup.md
need_token "$cmd" 'store-kit-sync.sh" "$2/wp-content/plugins" store-polylang' "$cmd no longer installs store-polylang"
need_token "$cmd" 'plugin is-active polylang' "$cmd installs store-polylang without asking whether the site runs Polylang"
need_token "$cmd" 'PLL_WC_BRIDGE' "$cmd no longer reads which bridge runs"
need_token "$cmd" 'Never deactivate the other one.' "$cmd may deactivate the client's own bridge"
need_token skills/wp-woocommerce/scripts/woo-setup.php "'languages:products'" "setup no longer reports product translation"
need_token skills/wp-woocommerce/scripts/woo-setup.php "exist in one language: translating products now would hide them" \
  "setup no longer refuses to translate the products of a store that already has them"
need_token skills/wp-polylang/scripts/pll-import.php "store_pll_copy_product( \$source_id, \$target_id, \$target )" \
  "pll-import no longer gives a new product translation its price, SKU and stock"

grep -Fq 'tests/checks/store-polylang-integration.sh' .github/workflows/ci.yml || fail "CI's WordPress job does not run store-polylang-integration.sh"

echo "PASS: store-polylang is tested, guarded, installed only on Polylang sites, and reached by setup and pll-import"
