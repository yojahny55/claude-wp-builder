- **/wp-audit reports heavy embedded ICC profiles on images (PERF-075), unbounded queries in
  Elementor widget controls (PERF-076) and missing Elementor generated CSS (PERF-077).** A
  WooCommerce review found three costs no check named. Five attachments carried 0.5 to 1.8MB CMYK
  ICC profiles copied into 95 files, so a 300px thumbnail weighed 1.8MB. A third-party widget
  filled a control dropdown with an unbounded product query, which Elementor also runs when
  rendering on the front end, costing about 0.85s and 280MB per uncached home render. And
  Elementor had emptied its CSS folder, so pages requested `post-<id>.css` files that 404ed or
  were redirected to the home page. PERF-075 and PERF-077 read file bytes and HTTP responses, so
  a local clone and production agree. PERF-076 is a static finding on a clone, with timings
  relative only; it points to WP-026 for the general rule. All three are manual fixes.
  `tests/checks/audit-perf-elementor-images.sh` covers them.
