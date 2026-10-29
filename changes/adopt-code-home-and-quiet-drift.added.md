- **An adopted site records where its own code lives.** When adoption finds no editable
  theme or plugin of the site's own (a commercial theme and, at most, a sync plugin), it asks
  once for a child theme, a site plugin or an mu-plugin and stores the answer as `code_home`
  (`--code-home=`, `wp-config.mjs code-home`). Hook-based audit fixes read that field instead
  of improvising a location. For a child theme the command prints the `theme_mods_<parent>`
  copy that must run before the theme is activated.
- **`wp-config.mjs keep-inactive` and `remove-plugin`.** A plugin deactivated on purpose is
  recorded in `plugins.intentionally_inactive` and is no longer drift (it stays in the
  stack); a deleted plugin is dropped from the manifest, both scope lists and the generated
  block in one step.
- **`adopt --json`.** Stdout is exactly one JSON document (dry run and real run), with the
  human lines under `notes` and the backup path under `backup`; the dry run also reports
  `code_home_needed` and `code_home_options`.
