# /wp-audit — Step 10

`commands/wp-audit.md` sends the run here at Step 10. Follow it in order; nothing in it is optional background.

## Contents

- Step 11: Print Summary

If `.wp-create.json` exists, read it and update with audit metadata:

```bash
bash -c "cat .wp-create.json"
```

Add or update the `audit` key in the JSON:

```json
{
  "audit": {
    "last_run": "<ISO 8601 timestamp>",
    "security_level": "<basic|recommended|maximum>",
    "categories_run": ["security", "seo", "a11y", "performance", "best-practices", "geo", "usability"],
    "checks_run": {
      "security": ["SEC-001", "SEC-002", "SEC-036"],
      "geo": ["GEO-A11"],
      "usability": ["UX-014", "UX-006"]
    },
    "issues_found": N,
    "issues_fixed": M,
    "carried_over": K,
    "findings_ledger": { "path": ".wp-audit-findings.json", "written": "<ISO 8601 timestamp>" },
    "browser_measurement_available": true
  },
  "manifest_version": 3
}
```

**Delete `audit.web_quality_skills_available` as you write this block** if the manifest still
carries it. Step 2.5b reads it once, to migrate a manifest written before the rename; leaving
it in place afterwards means every later run sees two keys for one capability and no rule
saying which wins.

Then write the ledger itself, beside the manifest:

```json
{
  "ledger_version": 1,
  "findings": [
    {
      "check": "SEC-036",
      "resource": "wp_options.siteurl",
      "status": "still_failing",
      "severity": "CRITICAL",
      "first_seen": "2026-03-21T09:14:02Z",
      "last_seen": "2026-09-19T16:40:11Z",
      "evidence": "$WP option get siteurl"
    },
    {
      "check": "WP-048",
      "resource": "post:412.related_posts",
      "status": "resolved",
      "severity": "WARNING",
      "first_seen": "2026-09-01T10:00:00Z",
      "last_seen": "2026-09-12T11:22:00Z",
      "evidence": "$WP post meta get 412 related_posts"
    }
  ]
}
```

`last_seen` on a `resolved` entry is the last run that still **found** it, not the run that
noticed it was gone — the useful question afterwards is when the problem stopped being
observed, and a timestamp that moves on every clean run cannot answer it. A `resolved` entry
is kept, not deleted: deleting it means the next recurrence reports as `new`, and a defect
that keeps coming back is a different thing from one that has never been seen.

`audit.findings_ledger` is a pointer and stays a pointer. If it ever grows to hold findings,
every command that reads the manifest pays for an audit's history.

`categories_run` is a **cumulative** record, not a record of this run: union the categories
this run covered with the ones already there. Overwriting it would erase the very history
Step 2.5d reads back, and the coverage matrix would report every category as run the moment
any single category ran.

`checks_run` is cumulative the same way, and per category: union this run's executed check
IDs into the array for each category it covered, leaving the other categories untouched.
Record **every check that executed, including the ones that passed** — a check that ran and
found nothing is measured, and it is the pass that has to be distinguishable from the
never-run. A check reported `UNMEASURED` did not execute and is not recorded, so the next
run with the tier it needed still sees it as outstanding.

Write the IDs exactly as the category's catalog (Step 2.5d) spells them, revision included (`SEC-036`, `GEO-A11`, `SEC-036@2`). This is the
record Step 2.5d diffs against the catalogs, so an id invented here becomes a check that is
never reported missing and never reported run. `bin/wp-config.mjs validate` refuses a
`checks_run` whose shape is wrong — a bare string instead of an array, an unknown category,
an id that is not shaped like one — because the diff consumes it directly.

`carried_over` is `issues_found - issues_fixed` for this run — the number Step 2.5e re-opens
next time. Write `manifest_version` on every run, including the run that adds it to a project
that never had one.

Also update the `plugins.installed` array if new plugins were installed during Step 4.

Write the updated JSON back to `.wp-create.json`.

If `.wp-create.json` does not exist, skip this step.

## Step 11: Print Summary

```
=== Audit Complete ===
Fixed: M/N auto-fixable issues (C in code, S in settings)
Remaining: K issues require manual attention

Report: .wp-audit/informe-<AAAA-MM-DD>.md
        .wp-audit/informe-<AAAA-MM-DD>.html  (single file — open, send, or print to PDF)

Repeat on staging and production (settings do not travel with the commit):
  1. <the setting fix, as the command that applied it>

Manual issues:
  1. [SEC-002] SQL injection in custom-query.php:45 — use $wpdb->prepare()
  2. [A11Y-003] Color contrast ratio 3.2:1 on .hero__subtitle — increase to 4.5:1
  ...

Next steps:
  - Review and test the applied fixes
  - Address the remaining manual issues listed above
  - Re-run the audit so the next dated report shows the improvement
  - Run /wp-finalize for pre-delivery validation
```

If `--report-only` was used:
```
=== Audit Report Complete ===
Total: N issues found (X critical, Y warnings, Z info)
Auto-fixable: M/N

Report: .wp-audit/informe-<AAAA-MM-DD>.md
        .wp-audit/informe-<AAAA-MM-DD>.html  (single file — open, send, or print to PDF)

To auto-fix issues, run: /wp-audit <same flags without --report-only>

Next steps:
  - Review the report written above
  - Run /wp-audit (without --report-only) to auto-fix issues
  - Run /wp-finalize for pre-delivery validation
```

**The `Report:` lines name only what Step 8.5 actually wrote**, in both summaries above.
`--report md` or `--report html` prints one line, not two. A run with no findings is still
written — the report says nothing was found — so its paths are printed like any other.
When the renderer failed (exit `1` or `3`), print `Report: not written — <the reason>`
instead of paths, and drop the line that tells the operator to review it. A summary that
points at a file which does not exist is worse than no summary.
