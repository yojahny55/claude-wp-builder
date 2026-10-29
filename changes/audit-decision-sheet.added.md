- **`bin/decision-sheet.mjs`, the approval page for `design_impact` findings.** Builds one
  self-contained HTML in the audit results directory: per finding a before and after picture
  at desktop and mobile (the injected CSS is forced `!important` and transitions are frozen,
  so the "after" shows the proposed value), measured values, a recommended badge, approve /
  reject / postpone / other radio options and a copy-answers box that works with a plain click.
  `--parse` reads the pasted `DECISION <id>: <option> | <note>` block back as JSON, with
  rejected findings flagged for the ledger as `accepted`. `fix.md` now routes every `visual`
  finding through it and forbids applying one without an answer.
