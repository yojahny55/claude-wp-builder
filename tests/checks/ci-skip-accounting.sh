#!/usr/bin/env bash
# The contract job aggregated `exit 0` and called the total PASS. Three checks in the glob
# take a skip path when an optional dependency is absent -- wp-polylang-live.sh without
# PLL_TEST_SITE, craft-kit-sync.sh without the kit checkout, wp-library.sh without the MCP
# corpus -- so each printed SKIP, exited 0, and was counted as a passing check. A CI summary
# reading "118 passed" meant 115 measured and 3 declined, and nothing said which.
#
# That is the same silent-skip failure the browser and visual jobs already refuse; it just
# had not been applied to the aggregate. This check pins the accounting, and verifies the
# skip-prone checks really do announce themselves, because accounting for a signal nothing
# emits would be a guard standing next to an open door.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
CI=".github/workflows/ci.yml"
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

[ -f "$CI" ] || { printf 'FAIL: %s is missing\n' "$CI"; exit 1; }

# --- the accounting ------------------------------------------------------------------------
grep -Fq 'skipped+=("$f")' "$CI" \
  || fail "$CI does not collect skipped checks -- a SKIP would be counted in PASS again"
grep -Fq "PASS=%d SKIP=%d FAIL=%d" "$CI" \
  || fail "$CI does not report SKIP as its own number in the aggregate line"
grep -Fq 'NOT counted as passing' "$CI" \
  || fail "$CI does not name the skipped checks in the summary"

# The ordering matters: pass must be incremented only on the non-skip branch. A file where
# both happen would report the skip AND count it, which is the defect wearing a label.
awk '
  /if printf .%s. "\$out" \| grep -q .SKIP.; then/ { inbranch = 1; next }
  inbranch && /skipped\+=/ { saw_skip = 1; next }
  inbranch && /pass=\$\(\(pass \+ 1\)\)/ { saw_pass_after_else = 1 }
  inbranch && /else/ { in_else = 1 }
  END { exit (saw_skip && saw_pass_after_else && in_else) ? 0 : 1 }
' "$CI" || fail "$CI increments pass on the SKIP branch, or no longer has an else branch"

# --- the job-owned exclusions, which this check now sits beside ------------------------------
for owned in motion-devices wp-polylang-integration wp-cf7-delivery visual-baselines baseline-approval; do
  grep -Fq "tests/checks/$owned.sh" "$CI" \
    || fail "$CI no longer excludes tests/checks/$owned.sh from the contract glob -- it would skip there and pass"
done

# --- the signal being accounted for actually exists ------------------------------------------
# Without PLL_TEST_SITE this must print SKIP and exit 0. If it ever stops saying SKIP, the
# accounting above silently starts counting it as a measured pass again.
out="$(PLL_TEST_SITE= bash tests/checks/wp-polylang-live.sh 2>&1)"
status=$?
if [ "$status" -ne 0 ]; then
  fail "wp-polylang-live.sh exits $status with no PLL_TEST_SITE; it is documented to exit 0 with SKIP"
elif ! printf '%s' "$out" | grep -q 'SKIP'; then
  fail "wp-polylang-live.sh no longer prints SKIP when it declines to run -- the aggregate cannot tell it apart from a pass"
fi

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: CI counts a skipped check as skipped, not as passing\n'
