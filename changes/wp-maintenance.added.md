- **`/wp-maintenance` closes a site to visitors while editors keep working.** WordPress
  core's `.maintenance` file locks out administrators too and is meant for the minutes of an
  update. The command copies a fixed `inc/maintenance.php` into the theme and switches it with
  one option: visitors who cannot `edit_posts` get a `503` with a `Retry-After` header, and
  anonymous REST requests, the Store API included, get the same error. While the option is
  absent the file changes nothing a visitor sees. Stores use the same switch: WooCommerce's
  coming-soon mode answers `200`, admits only shop managers and leaves the APIs open, so the
  command reports it and never writes it. Each change is verified with an anonymous request.
