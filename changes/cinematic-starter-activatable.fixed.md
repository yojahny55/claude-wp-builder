- **The cinematic starter is now an activatable classic theme.** It shipped no `index.php`,
  `page.php`, `single.php` or `404.php`, so WordPress refused to activate the generated theme
  and any non-front-page request had no template. Minimal escaped versions are added. The
  loader also looked for a `templates/cinematic.php` page template that no command or agent
  ever creates; it now keys on the front page alone, which is where the reel renders, and the
  `_is_cinematic` filter remains the way to opt other pages in.
