- **`wp-env-setup.sh` checks its arguments before running anything privileged.**
  `permissions` resolves the path and accepts only a WordPress directory (not `/` or the
  home directory), validates `--web-user`, leaves `.git` and `node_modules` alone, and re-owns only real directories and files
  (`chown -h`, symlinks are not followed). Each `chown`/`chmod` runs through `sudo env PATH=<absolute system path> find -execdir`
  (a relative or empty `PATH` entry would abort `-execdir`, and `sudo` may keep the caller's `PATH`),
  so it is applied relative to the directory `find` is visiting. That closes the race on intermediate
  directories, and a symlink is excluded by type. GNU `chmod` has no `-h`, so a leaf swapped for a
  symlink between `find`'s stat and the exec remains a narrow residual risk. The `wp-content` writable
  directories are changed in the same pass (`-type d`); one that is a symlink is skipped with a warning.
  `vhost-install` writes only under the web servers' config directories,
  `service-reload` accepts only known web server and PHP-FPM units, and `native-setup`
  validates the web server and the vhost destination before the certificate or hosts file is touched.
