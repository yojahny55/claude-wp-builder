- **`wp-config.mjs env-set` refuses a missing or invalid `--role` or `--url` up front.** A
  call without them used to write an environment entry with `undefined` values and rely on
  manifest validation to complain afterwards; it now stops with a usage message before
  touching the manifest. The CF7 HTML-scope check's mail stub also answers by key, as the
  real `WPCF7_Mail::get()` does.
