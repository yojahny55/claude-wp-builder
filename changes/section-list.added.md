- **`/wp-section --list` lists a demo's sections without initializing anything.**
  `bin/demo-sections.mjs` reads the delimiters of every `demo/*.html` page and prints each
  section's name, the slug `/wp-section` takes, its line range and whether the theme already
  has `template-parts/section-<slug>.php`. It also reports the delimiter defects that make
  `/wp-init`, `/wp-section` and `/wp-yolo` misread a demo (a section never closed, an END with
  no open section or another section's name, a nested or duplicate section, a page with no
  delimiters) and exits 1 on any of them. Before this, the only way to see the sections was
  to run `/wp-init`.
