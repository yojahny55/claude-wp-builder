- **`/wp-update` stops tripping on restored clones and bundled-plugin themes.** The held
  parent-theme lookup no longer asks WP-CLI for a `parent` field it does not have; the core
  backup lists root PHP files with `find` instead of `ls`, which broke under a coloured `ls`
  alias; the preflight reports an ACL mask of `r-x` (web server cannot write) and a leftover
  `.maintenance`; a vendor package that is not a zip is skipped like an unlicensed one; and
  plugins that a commercial theme ships inside itself are reinstalled when the theme moves.
