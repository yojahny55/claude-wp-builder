- **`wp-env-setup.sh` checks its arguments before running anything privileged.**
  `permissions` resolves the path and accepts only a WordPress directory (not `/` or the
  home directory), validates `--web-user`, leaves `.git` and `node_modules` alone, and re-owns only real directories and files
  (`chown -h`, symlinks are not followed). Each `chown`/`chmod` runs through `find -execdir`, so it is
  applied relative to the directory `find` is visiting rather than to a path resolved again at exec
  time; a `wp-content` writable directory that is a symlink is skipped with a warning.
  `vhost-install` writes only under the web servers' config directories,
  `service-reload` accepts only known web server and PHP-FPM units, and `native-setup`
  validates the web server and the vhost destination before the certificate or hosts file is touched.
