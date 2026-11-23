- **A demo's links to its store pages reach WooCommerce.** `/wp-seed --store-pages
  <slug=surface,...>` (passed by `/wp-yolo` from the demo's store pages) builds no WP Page for
  them and points the demo's nav items and link fields at WooCommerce's own shop, cart,
  checkout and account pages: a menu item whose object is the WooCommerce page, added at the
  demo's position and never twice, and the page's permalink in a button field. A product link,
  and cart and checkout on a catalog store, are listed for review instead.
