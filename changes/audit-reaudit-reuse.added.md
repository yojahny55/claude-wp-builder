- **`/wp-audit` recognizes a re-audit.** Step 1.5 detects a prior run (`audit.last_run`,
  the findings ledger, the dated sidecar), prints `Re-audit of <date>`, and asks one
  question to reuse the stored mode, browser suite and production URL (or clone-only)
  instead of re-asking each, with a scoped option that re-measures only open findings and
  categories touching files changed since the last run. Stale or unconfirmed answers are
  never reused silently. Answers persist in `audit.last_answers`, validated by
  `bin/wp-config.mjs`, and the report states its baseline.
