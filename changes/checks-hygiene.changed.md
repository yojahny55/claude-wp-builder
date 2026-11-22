- **Check hygiene.** `tests/lib/assert.sh` gives checks `fail`, `skip`, `need_token` and
  `require_tool` (SKIP, not a confusing FAIL, when php, python3 or curl is missing;
  `CHECKS_REQUIRE_TOOLS=1` in CI turns that back into a failure). The composition-gate check
  SKIPs when the impeccable detector cannot start offline instead of failing. The 27 checks
  that ran without `set -e` now run under `set -euo pipefail`, `cd` failures stop them, and
  the re-audit check writes its probe to a temp dir. Every check is executable in git, and
  `assert-lib-adoption.sh` freezes the checks that still define their own `fail()`.
