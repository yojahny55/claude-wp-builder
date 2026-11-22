- **CI and test-harness coverage.** CI jobs pin `runs-on: ubuntu-24.04` instead of the floating
  `ubuntu-latest`. New `tests/mutation.sh` (manual tool) deletes a required token from a copy
  of the repo and reports contract checks that still pass, with `tests/checks/mutation-harness.sh`
  guarding it. `seeded-defects.sh` now compares against a committed recorded audit
  (`recorded-findings.json`, plus a negative case), so the comparison runs in CI without
  `SEEDED_FINDINGS`.
