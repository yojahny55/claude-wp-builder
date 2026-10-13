- **The audit report can carry a "Scope and coverage" section.** The renderer had no field for
  free text, so a user hand-added an "Alcance y cobertura" section to the generated report and
  lost it on the next run. A run file now takes `notes` (a string or an array of paragraphs) and
  `bin/audit-report.mjs` accepts `--notes <file>`; both render in the `.md` and the `.html`
  (escaped, localised) and are kept in the sidecar. `tests/checks/audit-deliverable-report.sh`
  covers it.
