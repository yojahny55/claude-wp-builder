- **`/wp-s3` no longer leaves credentials in the docroot.** The setup and revert scripts
  wrote `wp-config.php.bak-<stamp>` and `s3-config.php.bak-<stamp>` next to the originals;
  those names do not end in `.php`, so the web server served them as plain text (database
  password, previous S3 secret). Backups now go to a `0700` directory outside the docroot
  (`~/.local/state/wp-s3-backups/`, override with `WP_S3_BACKUP_DIR`) at `0600`. The
  `wp-config.php` rewrite also keeps the original mode and owner instead of resetting them;
  the revert parks its credential-bearing `s3-config.php` outside the docroot too.
  The documented secret flow (`! read … && export …`) could never work, since a `!` line
  runs in a subprocess; the command now has the user write a `0600` file and passes it with
  the new `--secret-file`.
