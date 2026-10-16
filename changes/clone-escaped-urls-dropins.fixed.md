- **`/wp-clone` left Elementor URLs pointing at production and broke on production cache drop-ins.**
  Search-replace only matched the plain `https://old-host`, but Elementor stores URLs
  JSON-escaped (`https:\/\/old-host`) in `_elementor_data` and `_elementor_element_cache`; on a
  real store clone 149 values kept the production host (broken banners, assets loaded from
  production). Both paths now run a second, escaped pass (exact quoting shown) and `elementor
  flush-css`, and verification counts the host in postmeta in either spelling. Separately, a
  production `object-cache.php` or `advanced-cache.php` made every WP-CLI call fail on a machine
  without that backend; a new step parks them as `.bak`, sets `WP_CACHE` false and records both
  in the report.
