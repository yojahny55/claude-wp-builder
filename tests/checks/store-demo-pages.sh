#!/usr/bin/env bash
# WooCommerce N01, piece 3 (first half): a demo's store pages. wp-normalize knew only home, inner,
# cpt-archive and blog, so a demo's shop.html came out as an inner page: /wp-yolo built a
# page-shop.php that WooCommerce never shows (it renders the shop with its own product archive)
# and /wp-seed created a WP Page at the shop's slug. This pins the store role end to end: the
# manifest schema and the demo plan carry it, the normalizer decides it from the page and not the
# file name alone, /wp-yolo builds no page or section for it and keeps it out of /wp-seed, and
# the links the demo makes to it are reported, not silently dropped.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

norm=agents/wp-normalize.md
plan=skills/wp-demo-run/references/section-plan.md
yolo=commands/wp-yolo.md

need_token "$norm" '"role": "home" | "inner" | "cpt-archive" | "blog" | "store",'
need_token "$norm" '"store": "shop" | "product" | "cart" | "checkout" | "account", // only on role store'
need_token "$norm" 'copy `role`, `store`, `kind`, `cpt` and'
need_token "$norm" '- A store page → `role: '"'"'store'"'"'`'
need_token "$norm" 'Decide from the page, not its file'
need_token "$norm" 'A marketing page with a few'
need_token "$norm" 'keep `role: '"'"'inner'"'"'` and add a'
need_token "$plan" '"role": "home" | "inner" | "cpt-archive" | "blog" | "store",'
need_token "$plan" '"store": "shop | product | cart | checkout | account'

need_token "$yolo" '**`store` pages** (`pages[role=store]`) — same: no WP Page, no `/wp-section`, no ledger'
need_token "$yolo" 'add "run /wp-woo-setup first".'
need_token "$yolo" 'slugs of every `pages[role=cpt-archive]` and `pages[role=store]` entry'
need_token "$yolo" 'no `/wp-section`, no ledger'
need_token "$yolo" 'whatever Step 2.5 recorded for them.'
need_token "$yolo" 'Links to them (nav, buttons) are not'
need_token docs/known-ceilings.md '**A demo'"'"'s links to its store pages are not rewired.**'
need_token "$norm" 'A translated'
need_token skills/wp-yolo-run/references/checkpoint.md 'blog / store, with the store surface'

# The normalizer and the demo plan name the same five surfaces, in the same order.
need_token "$norm" '"shop" | "product" | "cart" | "checkout" | "account"'
need_token "$plan" 'shop | product | cart | checkout | account'

need_token skills/wp-woocommerce/SKILL.md 'are `role: store` in the'
grep >/dev/null -c 'no starter theme renders the enquiry form' skills/wp-woocommerce/SKILL.md \
  && fail "skills/wp-woocommerce/SKILL.md still says no theme renders the enquiry channels"

echo "PASS: a demo's store pages are role store, build no WP Page or section, and their links are reported"
