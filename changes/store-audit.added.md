- **`/wp-audit --store`: whether a WooCommerce store can sell, and is launched.** A new
  category, dispatched only when WooCommerce is active, so a site without it scores exactly as
  before. `wp-audit-store` reports the `STORE-NNN` catalog from one tool, `bin/store-audit.mjs`:
  `bin/woo-verify.mjs` from outside (setup drift, store pages, shop, a Store API cart) and a
  read-only database pass (policy pages that are published and say something, the email sender,
  a shipping method at the store's own address, tax rates when taxes are on, products with a
  price, image and category, failed scheduled actions, order-table sync, and the launch state,
  `CRITICAL` on production and `INFO` elsewhere). `woo-verify` gains `--read-only`, which skips
  the cart check so a report-only audit writes nothing, and `--tier`, for a store with no
  `store` block. Subscriptions and bookings are recorded as a known ceiling.
