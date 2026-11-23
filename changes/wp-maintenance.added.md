- **`/wp-maintenance` closes a site to visitors while editors keep working.** WordPress
  core's `.maintenance` file locks out administrators too and is meant for the minutes of an
  update. The command copies a fixed `inc/maintenance.php` into the theme and switches it with
  one option: visitors who cannot `edit_posts` get a `503` with a `Retry-After` header, and
  anonymous REST requests get the same error. While the option is absent the file changes
  nothing a visitor sees. On a store it uses WooCommerce's coming-soon mode instead of adding
  a second switch. Each change is verified with an anonymous request.
