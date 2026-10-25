- **`/wp-polylang` backs up first and can preview the import.** The command never mentioned
  a backup although `pll-import.php` updates posts and menus in place and rewrites
  `_menu_item_url`, and Step 3.5 moves every URL to `/<lang>/…` with no confirmation. It now
  exports the database outside the docroot (Step 2.5), runs `pll-import.php … dry-run` (lists
  what would be created or modified, writes nothing) before the real import, asks before
  setting `hide_default=0`, and calls `$WP` instead of a bare `wp`, so the `.wp-create.json`
  wrapper (Docker, custom paths) is honoured.
