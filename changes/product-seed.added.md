- **A store's products come from its demo.** `wp-normalize` now extracts the products a
  demo's shop and product pages show into `products[]`, and `/wp-seed --products <file>`
  (passed by `/wp-yolo` on a store, with a client's `products.json` winning over the demo)
  creates them through `skills/wp-woocommerce/scripts/product-seed.php`: simple products, or
  External ones for a link to a dealer, with prices, categories and images. A re-run updates
  only what it wrote, leaves a price the client changed and a product the client created
  alone, and a product with size or colour options is a draft reported for review, because
  its variations are not built.
