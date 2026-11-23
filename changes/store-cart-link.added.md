- **A store's header links to its cart.** `/wp-woo-setup` Step 6.6 now also installs a fixed
  header template part with its script, and `/wp-header` calls it on a `store` or `full` store,
  where the demo draws its cart or beside the menu toggle, never inside the menu the hamburger
  hides. The count comes from the server and is re-read from the Store API when WooCommerce
  announces a cart change (classic or block); WooCommerce's cart fragments stay off. Nothing
  renders in catalog mode, and an existing header changes only when `/wp-header` runs again.
