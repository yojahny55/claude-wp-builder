- **Bulk transfers are verified by their result, not their exit code.** `wp-backup.sh` counts
  the files in the uploads archive against `wp-content/uploads` and records the count in
  `backup.json`; `wp-restore.sh` checks it after extracting and leaves the current uploads alone
  on a mismatch. `store-kit-sync.sh` and `audit-suite.sh` compare each copy with its source, and
  `s3-setup.sh` refuses an unpacked archive without the plugin's main file. The rule is written
  down in `wp-contributing`, and a new check fails on a shipped script that adds a bulk copy,
  sync, archive or extraction without a `transfer-verified:` comment saying how it is confirmed.
