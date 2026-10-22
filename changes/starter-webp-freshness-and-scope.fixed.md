- **Tailwind starter: stale WebP siblings, over-broad output buffering, per-request ACF scan.**
  A `.webp` sibling was used whenever it existed, so a medium replaced under the same name
  (or `wp media regenerate`) kept serving the old picture; it now counts only when it is at
  least as new as its original, and the upload hook rebuilds a stale one. The WebP output
  buffer also ran over sitemaps, embeds and non-HTML responses; it now rewrites `text/html`
  only. Indexed and alpha PNGs and tiny PNGs are no longer re-encoded to WebP, and
  `__starter___image()` with a bare URL emits `alt=""` and known dimensions. `functions.php`
  stores a signature of `fields/*.php` and skips the glob/read/regex scan when nothing
  changed (its comment already claimed so), no longer prints a nonce on every page for an AJAX
  handler that does not exist, and defers the bundle through the script `strategy` argument
  (WP 6.3+) instead of a `str_replace` on markup.
