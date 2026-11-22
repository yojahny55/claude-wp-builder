- **`/wp-backup` and `/wp-restore`.** One verified backup script (`bin/wp-backup.sh`) replaces
  the three hand-written database exports in `/wp-update`, `/wp-clone` and `/wp-anonymize`,
  which had different permissions, no check of the dump and no uploads. The dump must start
  with a SQL header and end with its `Dump completed` footer (a PHP notice printed by the
  wrapper fails it), is written to a temp name and renamed only when complete, and the folder
  is `<slug>-<timestamp>`, 700/600, always outside the WordPress root, with sha256 sums plus
  table and post counts in `backup.json`. `/wp-restore` verifies the sums, refuses another
  database name or site URL unless `--yes`, takes a pre-restore copy, imports, swaps uploads
  with a way back, and fails unless the site URL, table count and post count match afterwards,
  printing the command to return to the pre-restore copy.
