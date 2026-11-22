- **`/wp-backup` and `/wp-restore`.** One verified backup script (`bin/wp-backup.sh`) replaces
  the three hand-written database exports in `/wp-update`, `/wp-clone` and `/wp-anonymize`,
  which had different permissions, no check of the dump and no uploads. The dump is written
  to a temp name and kept only if it ends with its `Dump completed` footer; folders are 700 and
  files 600, always outside the WordPress root, with sha256 sums in `backup.json`. `/wp-restore`
  verifies the sums before touching anything, checks the database name, takes a pre-restore
  copy, imports, and fails unless the site URL matches afterwards.
