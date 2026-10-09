- **Two measured lessons from a WooCommerce store.** `skills/wp-robin/references/png-to-webp-conversion.md`
  converts PNG attachments to WebP originals instead of adding `.webp` siblings: when it is
  worth it (uploads 3.5 GB to 509 MB on that store), a map of every old file to its new one
  because `-scaled` sizes change name, a serialization-safe database replacement that skips
  Robin's queue, a regex 301, and the traps of an interrupted run. `performance-lessons.md`
  gains "Per-template used CSS": keep every vendor sheet and load it asynchronously behind a
  per-template used-CSS file (blocking CSS 1.2-1.4 MB to 0.33-0.44 MB), why dropping the
  WooCommerce sheet broke header panels, and the CSP `'unsafe-hashes'` the inline `onload`
  needs.
