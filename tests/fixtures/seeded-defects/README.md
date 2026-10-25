# Seeded defects

A deliberately broken theme and plugin, plus `expected-findings.json` naming the audit check
that must fire for each defect. It is a corpus for measuring the audits, not code to copy.

- `theme/` and `plugin/` hold ten defects, each marked with a `SEEDED <check>` comment.
- `expected-findings.json` lists, per defect: `check` (id from the audit catalogs),
  `domain`, `file`, `pattern` (a literal string that must still be in that file) and `note`.
- `tests/checks/seeded-defects.sh` validates the corpus offline, and compares it with a real
  audit's findings when `SEEDED_FINDINGS` points at one.
- `WP_FIXTURE_SEEDED=1 tests/fixtures/wp/provision.sh` copies both into a provisioned
  WordPress (theme and plugin are installed, not activated) for a real audit run.

Every value that looks like a secret is a placeholder. The PHP is valid on 7.4 and is not
meant to be executed.
