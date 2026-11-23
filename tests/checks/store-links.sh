#!/usr/bin/env bash
# A demo's links to its store pages (N01 piece 3): /wp-seed --store-pages points nav items and
# link fields at WooCommerce's own pages through skills/wp-woocommerce/scripts/store-links.php,
# and /wp-yolo passes the flag from pages[role=store]. This pins the contract and the script's
# shape; tests/checks/store-links-integration.sh runs it on a real store.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

script=skills/wp-woocommerce/scripts/store-links.php
[ -f "$script" ] || fail "$script is missing"

need_token commands/wp-seed.md '[--store-pages <slug=surface,...>]'
need_token commands/wp-seed.md 'Skip every `--store-pages` slug the same way'
need_token skills/wp-seed-run/references/parse-demo.md '**`--store-pages <slug=surface,...>`**'
need_token skills/wp-seed-run/references/menus.md '### Links to the demo'"'"'s store pages'
need_token skills/wp-seed-run/references/menus.md '**at the moment
the walk reaches it in the demo nav**'
need_token skills/wp-seed-run/references/menus.md 'scripts/store-links.php" menu "$2" "$3" "$4"'
need_token skills/wp-seed-run/references/menus.md '**Under `polylang`**, every language'"'"'s menu gets the WooCommerce page titled'
need_token skills/wp-seed-run/references/acf-fields.md 'scripts/store-links.php" url "$2"'
need_token commands/wp-yolo.md '1. **`/wp-seed --exclude-slugs <slugs> --store-pages <pairs>`**'
need_token commands/wp-yolo.md 'Pass `--store-pages` with every `pages[role=store]` entry as `<slug>=<store>`'
need_token BACKLOG.md 'tests/checks/store-links.sh'
need_token BACKLOG.md 'tests/checks/store-links-integration.sh'
need_token .github/workflows/ci.yml 'bash tests/checks/store-links-integration.sh'

need_token "$script" "'account'  => 'myaccount',"
need_token "$script" "if ( 'post_type' === \$store_links_item->type && (int) \$store_links_item->object_id === \$store_links_page ) {"
need_token "$script" "store_kit_catalog_mode()"
need_token "$script" "'menu-item-type'      => 'post_type',"

require_tool php
php -l "$script" >/dev/null || fail "$script does not parse"

echo "PASS: /wp-seed points a demo's store links at WooCommerce's pages, idempotently, and reports what it skips"
