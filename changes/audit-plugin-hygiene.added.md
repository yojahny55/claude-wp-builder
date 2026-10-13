- **SEC-045 reports file-manager plugins, and PERF-070 reports a page-cache drop-in left
  without its plugin.** A plugin review on an adopted store found both, and no audit had
  reported either. A file manager (File Manager, Filester, Advanced File Manager, or any fork
  that bundles elFinder) edits PHP from wp-admin and ignores `DISALLOW_FILE_EDIT`; its elFinder
  connector answers direct requests even when the plugin is inactive, so SEC-045 checks
  inactive copies too. PERF-070 flags `advanced-cache.php` loaded with `WP_CACHE` true while the
  plugin that wrote it is off, since nothing purges that cache any more. On a local clone it
  defers to Step 2.3: when the owner is on `Clone-suppressed plugins` (active on production),
  it prints a clone-artifact line instead of a finding. `tests/checks/audit-plugin-hygiene.sh`
  covers both.
