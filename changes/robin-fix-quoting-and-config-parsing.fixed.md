- **`robin-fix.sh` no longer pastes file names into PHP and SQL, and reads `wp-config.php`
  like PHP does.** The webp queue row was built with `php -r '... "'$s_path'" ...'` and a
  `VALUES (... '${EXTRA_DATA}' ...)` string, so an upload named `O'Brien.jpg` (or any name
  with `"` or `$`, which rsync and metadata can deliver) broke the step or injected code.
  One PHP process now receives the values as arguments, builds `extra_data` and returns
  the INSERT with every string as a hex literal. `parse_define` took the first
  `define('DB_NAME', ...)` even when it sat in a `//`, `#` or `*` comment and cut a password
  holding `\'` short; it now skips comment lines and follows PHP's escapes. ImageMagick 7
  ships `magick` and deprecates `convert`: the script, `/wp-robin` Step 2 and the skill now
  prefer `magick` and fall back to `convert`.
