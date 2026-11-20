- **`wp-env-setup.sh` checks its arguments before running anything privileged.**
  `permissions` resolves the path and accepts only a WordPress directory (not `/` or the
  home directory), validates `--web-user`, leaves `.git` and `node_modules` alone, and re-owns only real directories and files
  (`chown -h`, never through a symlink).
  `vhost-install` writes only under the web servers' config directories,
  `service-reload` accepts only known web server and PHP-FPM units, and `native-setup`
  validates the web server and the vhost destination before the certificate or hosts file is touched.
