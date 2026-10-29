- **Plugin-list drift no longer interrupts `/wp-audit`.** When the only disagreement is the
  plugin list, `refresh` runs without a question and the report logs it; the audit asks only
  for theme or code-scope changes. `refresh` now also drops plugins that are gone from disk
  out of `code_scope` (so `render-context` stops listing a deleted plugin as read-only code),
  and does nothing when nothing changed.
- **Manifest backups leave the docroot.** `adopt --replace` and `refresh` write
  `.wp-create.json.bak-<timestamp>` to `~/.local/state/wp-builder-backups/<root>-<hash>/`
  (`$XDG_STATE_HOME` honoured, newest 20 kept) instead of beside the site, where they were
  served and committable.
