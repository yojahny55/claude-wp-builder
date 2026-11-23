- **A Polylang bridge for WooCommerce stores.** The bundled `plugins/store-polylang/` keeps one
  product post per language with shared price, SKU and meta, takes one shared stock, resolves
  the cart, checkout, account and shop pages and `wc-ajax` to the current language, and records
  the order language for customer emails. `/wp-woo-setup` installs it when Polylang is active
  and stands it down when another bridge runs; `woo-setup.php` turns on product translation on
  a store with no products yet; `/wp-polylang`'s import maps store data into the product
  translations it creates. `bin/store-kit-sync.sh` copies either plugin. Limits are in
  `docs/known-ceilings.md`.
