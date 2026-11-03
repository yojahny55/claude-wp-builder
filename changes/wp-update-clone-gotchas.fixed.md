- **`/wp-update` stops tripping on restored clones and bundled-plugin themes.** The held
  parent-theme lookup no longer asks WP-CLI for a `parent` field it does not have; the core
  backup lists root PHP files with `find` instead of `ls`, which broke under a coloured `ls`
  alias; the preflight reports an ACL mask of `r-x` (web server cannot write) and a leftover
  `.maintenance`; a vendor package that is not a zip is skipped like an unlicensed one; and
  plugins that a commercial theme ships inside itself are reinstalled when the theme moves.
  A core release whose translation package for the site locale is not out yet is now
  reported as skipped instead of aborting the run (core, plugins and themes run as separate
  commands, no `&&` chain); long updates over SSH go through the harness's background run (no `nohup`);
  paid-plugin updates that only wp-admin shows (`Update package not available`, `already
  updated`) are listed as admin-only; language packs are refreshed after the migrations; and an
  "update everything" answer is no longer narrowed by the run on its own judgement.
