- **SEO and performance audits catch three false readings on WooCommerce and Elementor sites.**
  `wp-audit-seo` SEO-039 now counts BreadcrumbList blocks in the rendered shop and category
  pages: `WC_Structured_Data` adds its own to every `woocommerce_breadcrumb()` call, next to
  Rank Math's, and no theme grep sees it. The fix removes only WooCommerce's schema.
  `wp-audit-performance` PERF-048 explains Elementor's "Optimized Image Loading", which gives
  `fetchpriority="high"` to the logo and lazy-loads the real LCP after the theme has printed
  the page, and accepts one high-priority image per viewport. PERF-010 counts blocking scripts
  from the served HTML, not from a loaded DOM that holds scripts inserted after load.
