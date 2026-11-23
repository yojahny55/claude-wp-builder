- **A demo's store pages no longer collide with WooCommerce.** `wp-normalize` classified a
  demo's `shop.html`, `product.html` or `cart.html` as an ordinary inner page, so `/wp-yolo`
  built a `page-shop.php` WooCommerce never shows and `/wp-seed` created a WP Page at the
  shop's slug. They are now `role: store`, with the WooCommerce surface they show: no WP Page,
  no section build, and the demo nav's links to them point at WooCommerce's own pages.
