- **`wp-env-setup.sh` no longer aborts in `--json` mode, and Apache on Debian is served.**
  The output helpers returned non-zero when quiet, so `set -e` ended the script at the
  first message after work was done. `native-setup` for Apache on the Debian layout now
  enables the required modules and the site before the reload instead of leaving the
  installed vhost inactive.
