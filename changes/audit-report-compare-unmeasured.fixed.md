- **A finding whose check was not measured in this run is no longer reported as resolved.**
  `compare()` in `bin/audit-report.mjs` counted every previous finding that was missing from the
  new run as resolved, including those whose check the run listed under `unmeasured` (a
  production-only check skipped on a local run) or whose category it did not cover, so skipping a
  check read as fixing it. Those findings now appear under "Not re-measured in this run" and stay
  in the sidecar flagged `not_remeasured`, so the first run that does measure them can resolve
  them. `tests/checks/audit-deliverable-report.sh` covers it.
