- **Store pages in the theme's own look.** The starter themes never declared WooCommerce
  support, so WooCommerce squeezed the shop and every product into `page.php`, without gallery
  zoom, lightbox or slider, in its default purple and olive, with Tailwind's preflight stripping
  the borders off its form controls. `/wp-woo-setup` Step 6.6 now installs
  `templates/store/store-theme.php` and `templates/store/store.css` into a tailwind theme:
  WooCommerce support, its wrapper and sidebar replaced so the page keeps one `<main>`, and a
  stylesheet in the theme's tokens loaded on store pages only. It installs on a new store, or on
  an existing one only with `--store-theme`, because it changes how the store looks.
