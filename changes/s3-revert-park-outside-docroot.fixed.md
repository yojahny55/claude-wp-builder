- **`/wp-s3 --revert` no longer leaves the S3 credentials in the docroot.** It parked the
  config as `s3-config.php.disabled` beside `wp-config.php`, which a web server serves as
  plain text (the `.php` extension is gone), exposing the bucket key and secret. The file now
  moves to a `0600` file inside a `0700` directory outside the docroot
  (`~/.local/state/wp-s3-backups/<key>/`, override with `WP_S3_BACKUP_DIR`), and the script
  prints the `mv` that turns S3 back on.
  A `s3-config.php.disabled` left in the docroot by the earlier version is parked the same
  way (kept beside an existing parked copy with a `.legacy-<stamp>` suffix), and the hash
  of the site root falls back to `shasum` on hosts without `sha256sum`.
