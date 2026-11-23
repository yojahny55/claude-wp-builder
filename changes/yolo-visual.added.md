- **`/wp-yolo --visual`.** A full build can now run the visual QA loop: once the pages are
  seeded and before `/wp-finalize`, it pixel-compares every section it built with its demo
  section and hands a difference back to the CSS agent, up to three rounds per section, one
  section at a time. What stays over tolerance is reported, never blocking. `/wp-section
  --visual` also finds an inner page whose `page-<slug>.php` template applies by slug, which
  it reported as "not measured" before.
