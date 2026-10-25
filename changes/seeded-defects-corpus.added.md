- **Seeded-defects corpus for the audits.** `tests/fixtures/seeded-defects/` holds a theme and
  plugin with eleven deliberate defects (security, accessibility, SEO, performance, best
  practices) and `expected-findings.json` naming the check that must fire for each.
  `tests/checks/seeded-defects.sh` keeps the list honest offline (shape, catalog membership,
  defect still present, markers match) and compares it with a real audit's findings when
  `SEEDED_FINDINGS` is set. `WP_FIXTURE_SEEDED=1` makes `provision.sh` copy the corpus into the
  fixture. Before, nothing showed whether an edit to an audit agent stopped it seeing a defect
  it used to catch.
