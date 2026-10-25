- **Inline critical CSS is now a conditional recommendation, not a rejected one.** The
  performance lessons recorded one failed experiment (FCP better, LCP worse) as "rejected",
  and the auditor only offered `.min` copies. A real build later made per-template cuts work,
  and the failures it hit were all process: the second of two build scripts forgotten (the
  cuts invalidated in silence), cuts left stale after a core or builder update, verification
  over two different page loads instead of one DOM, and a decision taken on simulated LCP.
  `performance-lessons.md` now states five conditions, `wp-audit-performance` gives the
  regenerate-and-commit order, and the new `bin/assets-fresh.mjs` recomputes content hashes
  and fails with "regenerate critical cuts"; `/wp-update` runs it in its verification step.
