- **`wp-agentic-surfaces` copies its PHP instead of rewriting it.** The ~700 lines of
  `inc/agentic.php` that lived inside the agent's markdown are now `templates/agentic/agentic.php`,
  copied with two tokens (`__prefix__`, `__SITE_TYPE__`) substituted. CI's `php -l` at the 7.4
  floor now covers that file, which it never did while the code sat in a fenced block, so a run can
  no longer drift from the floor. The emitted file is byte-identical to what the agent produced.
