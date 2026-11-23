- **A demo's store pages now style the store.** When a `/wp-yolo` demo has store pages on a
  tailwind theme with a recorded store, the build installs the store stylesheet with
  `/wp-woo-setup --store-theme` (which now goes straight to the theme step on a recorded store,
  since the setup `/wp-create` runs comes before any theme) and has `wp-css`, in a new store
  layer mode, transcribe the demo's store styling into the stylesheet's `Section: Store demo`,
  on WooCommerce's own selectors from a reference measured on WooCommerce 11.1.2. The section
  is verified: the base above it untouched, every selector scoped to a store body class, no
  `!important`, and a section an earlier run wrote is kept on `--resume`.
