- **A symlinked checkout no longer makes the audit suite skip Tier 3 as "no browser".**
  `bin/lib/browsers.mjs` decided it was being run as a command by comparing `argv[1]` with
  `import.meta.url`; Node resolves symlinks for the second, so reached through a link (the plugin
  directory linked into place, or a path such as `.../claude-wp-builder` that is a link) the
  comparison failed, the lookup printed nothing and exited 0, and `bin/audit-suite.sh` read that
  as "no existing Chromium" and exited 2. Both sides are now compared by real path, and
  `tests/checks/audit-suite.sh` passes again from a linked path.
  `tests/checks/browser-resolution.sh` covers it.
