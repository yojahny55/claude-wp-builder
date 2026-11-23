# /wp-seed — Phase 2.5

`commands/wp-seed.md` sends the run here at Phase 2.5 (Products), only when `--products` was
passed. Follow it in order; nothing in it is optional background.

## Contents

- What it seeds
- Gate
- Dry run, then apply
- Reading the output

### What it seeds

The store's products, from the file `--products` names: `demo/.yolo-manifest.json`, whose
`products[]` `wp-normalize` extracted from the demo's shop and product pages, or a client's own
`products.json` with the same entry shape, which `/wp-yolo` passes instead when it exists. The
shape (name, `regular_price`, `sale_price`, `sku`, descriptions, `categories`, `image`, `gallery`,
`external_url`, `options`) is documented at the top of
`${CLAUDE_PLUGIN_ROOT}/skills/wp-woocommerce/scripts/product-lib.php`. Relative image paths
resolve against the products file's own directory.

`skills/wp-woocommerce/scripts/product-seed.php` does the work, with WooCommerce's own product
classes. It resolves every product the way Phase 1.5 resolves pages: by sku, or by its seed key
when it has no sku, and it treats a product with the same name and no `_<prefix>_seeded_content`
marker as the client's. It compares field by field against the digests it recorded last run,
like Phase 4, so a price the client changed in WooCommerce is left alone. A product with an
`external_url` is External (a catalog's `where-to-buy`); one with `options` is created as a
draft, because its variations are not built.

### Gate

Skip this phase, and say so in the report, when the project's `.wp-create.json` has no `store`
block: products belong to a store `/wp-woo-setup` has set up. The script itself refuses when
WooCommerce is not active, and when WP-CLI cannot see the project's files (`environment.engine`
other than `native`): it reads the products file and the images from the host.

### Dry run, then apply

Preview first, with the rest of the seed plan (Phase 1.5), then write:

```bash
bash -c '$WP eval-file "$1/skills/wp-woocommerce/scripts/product-seed.php" "$2" "$3" dry-run' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}' '<products-file>'
bash -c '$WP eval-file "$1/skills/wp-woocommerce/scripts/product-seed.php" "$2" "$3"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}' '<products-file>'
```

With `--force-fields`, append `force` to the second call: it overwrites fields the client
edited on products this script created, never a product it did not create. With no `store`
block in the manifest and products in the demo, `/wp-yolo` passes no `--products`: its Review
already says `/wp-woo-setup` is missing.

Exit `1` is a refusal, before anything is written, with a `refused:` line; when it follows
`invalid <name>: <why>` lines, the products file is wrong. Report each line verbatim and seed no
products. Fix the file and run again; never edit the entries to get past the check by guessing a
price.

### Reading the output

One line per product, then `products: N created, N updated, N unchanged, N conflict, N degraded`.
Carry these into the Seed Report:

- `conflict <key>: exists without the seed marker` and `conflict <key>: <field> edited in
  WooCommerce` go under "Left alone — the client owns these", like a page without the marker.
- `degraded <key>: image … did not import` goes under the failed media imports: the product
  exists without that image, and the next run tries again.
- `review <key>: options … are not built as variations` goes under Review: a person builds the
  variations in WooCommerce and publishes the draft.
