- **`/wp-audit` and `/wp-update` read the exit code their tools document.** The audit fix step
  took any non-zero `bin/style-diff.mjs` exit as a moved style value, so an INCOMPLETE run
  (exit 3, a page or viewport not measured) was reported as a diff; it now repeats the
  measurement, and exit 2 is a tool failure. `/wp-update` took any non-zero
  `bin/assets-fresh.mjs` exit as stale critical cuts; exit 2 (bad usage or an unreadable
  manifest) is now reported as "critical cuts not checked".
