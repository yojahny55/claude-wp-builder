- **Record decisions and fixes in the audit ledger without auditing.** `bin/audit-report.mjs`
  gains `--accept <id> --reason`, `--unaccept`, `--mark-fixed <id> --evidence`, `--rerender`
  and `--summary [--json]`. `accepted` was defined as "set by a human" but nothing let a
  human set it, so a declined finding was proposed again every session and fixes applied
  between audits left the ledger stale (or got hand-written into the report). Accepted
  entries now leave the open and critical counts and the plan and get their own report
  section; a new `fixed_unverified` status holds a fix no check has re-measured and only a
  measured re-run turns it into `resolved`. `--rerender` rebuilds the newest report from its
  sidecar and the ledger, `--summary` prints counts by status and severity, and `ledger.md`
  documents the file's shape. The sidecar now also keeps each finding's `fix`.
