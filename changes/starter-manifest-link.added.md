- **Both starter themes link `site.webmanifest` when it exists.** `functions.php` prints
  `<link rel="manifest">` from `assets/img/favicon/` only if the file is there, so a theme that
  never ran `/wp-favicon` prints nothing and one that did needs no further edit.
