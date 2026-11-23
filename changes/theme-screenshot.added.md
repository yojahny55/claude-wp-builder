- **A delivered theme previews as the site, not a blank tile.** Both starters ship a 1x1
  `screenshot.png`, and nothing replaced it. `bin/theme-screenshot.mjs` captures the built
  homepage at 1200x900 into the theme; `/wp-yolo` runs it after the CSS rebuild, and
  `/wp-finalize` Check 4 fails a theme that still carries the placeholder, naming the command.
  A real preview is kept unless `--force`.
