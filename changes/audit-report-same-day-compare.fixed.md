- **A second audit report on the same day no longer erases the first one.** `bin/audit-report.mjs`
  names its files after the date only and skipped its own output path when it looked for the
  previous sidecar, so a re-run on the same day overwrote the morning's `.md`, `.html` and
  `.json` and then reported "No previous audit found". The earlier set is now kept as
  `informe-<date>-<HHMM>.*` (the time its sidecar was written) and becomes the previous run;
  sidecars sort by date and time. `tests/checks/audit-deliverable-report.sh` covers it.
