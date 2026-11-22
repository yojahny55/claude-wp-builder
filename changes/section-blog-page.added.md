- **A blog section now builds the blog templates it links to.** `/wp-section blog` (also
  `journal`, `news` or `posts`) runs `/wp-page blog` at a new Step 6.7, so the posts it lists
  have an archive and a single view to open. It is skipped under `--no-blog-page`, under
  `--transcribe` (the `/wp-yolo` walk, which already runs `/wp-page blog` once), on a cinematic
  project (`/wp-page` has no cinematic CSS route), when the theme already has
  `template-parts/journal/content-journal-card.php`, and when `archive.php` or `single.php`
  exists and the operator does not confirm the overwrite. Before this, a blog section built by hand left the archive and
  single templates to be remembered.
