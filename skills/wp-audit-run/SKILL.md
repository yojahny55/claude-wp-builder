---
name: wp-audit-run
description: "The step detail of the /wp-audit run, split out of commands/wp-audit.md so the command stays a short map — site type and local clone, manifest reconciliation, page scope, the agent dispatch prompt, the browser suite, measured findings and verified fixes, the finding ledger, the status vocabulary, the dated deliverable, the fix phase and the manifest update. Use when /wp-audit reaches a step that names one of these reference files, or when changing how a /wp-audit step behaves. Not for the agents' shared audit contract (wp-audit-standards)."
user-invocable: false
---

# /wp-audit step detail

`commands/wp-audit.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading there and sends the run to one file here. The command reads the
file at that step, not before, so a run pays only for the steps it reaches.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

The agents' contract — severities, report fields, prefixes, N/A rules — is a different thing
and lives in `wp-audit-standards`. Nothing here is read by an agent unless the dispatch prompt
quotes it.

## References, by step

| Step | File | Covers |
|---|---|---|
| 2.2 | [references/adopted-site.md](references/adopted-site.md) | Editable and read-only code scope on a site `/wp-adopt` registered |
| 2.3 | [references/site-context.md](references/site-context.md) | Store detection and tier, local-clone rules, the public-URL question, clone-safe checks, live mail transport |
| 2.5 | [references/manifest-reconcile.md](references/manifest-reconcile.md) | 2.5a-2.5e: schema version, measured stack, missing decisions, coverage matrix, freshness |
| 2.7 | [references/page-scope.md](references/page-scope.md) | Choosing the page list, page-level versus site-level criteria, scores |
| 4 | [references/dependencies.md](references/dependencies.md) | Audit plugins to offer and install (Tier 2 only) |
| 6 | [references/dispatch.md](references/dispatch.md) | The agent prompt template, Owner rule, `subagent_type` values, sharding, error handling |
| 6.5 | [references/browser-suite.md](references/browser-suite.md) | Running the browser suite and merging its findings |
| 6.9 | [references/measurement.md](references/measurement.md) | What counts as a finding |
| 6.10 | [references/fix-verification.md](references/fix-verification.md) | How a fix is verified against the case that produced its finding |
| 7.5 | [references/ledger.md](references/ledger.md) | Finding identity, ledger statuses, where the ledger lives |
| 8 | [references/status-vocabulary.md](references/status-vocabulary.md) | The five statuses and the console report |
| 8.5 | [references/deliverable.md](references/deliverable.md) | Finding owners, `bin/audit-report.mjs`, report before fix |
| 9 | [references/fix.md](references/fix.md) | The report-only exit, the fix offer, the fix rules |
| 10 | [references/manifest-update.md](references/manifest-update.md) | The `audit` block written to `.wp-create.json` |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording greps the file that now holds it;
`tests/checks/wp-audit-run.sh` asserts that every file here is named both in this table and at
its step in `commands/wp-audit.md`.
