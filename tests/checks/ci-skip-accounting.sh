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
# It lives in tests/run.sh; ci.yml must call it, with the exclusion list.
RUN=tests/run.sh
[ -f "$RUN" ] || { printf 'FAIL: %s is missing\n' "$RUN"; exit 1; }
grep -Fq 'bash tests/run.sh' "$CI" || fail "$CI does not run the checks through tests/run.sh"
grep -Fq -- '--exclude "$skip_here"' "$CI" || fail "$CI does not pass skip_here to tests/run.sh"
grep -Fq 'skipped+=("$i")' "$RUN" \
  || fail "$RUN does not collect skipped checks -- a SKIP would be counted in PASS again"
grep -Fq "PASS=%d SKIP=%d FAIL=%d" "$RUN" \
  || fail "$RUN does not report SKIP as its own number in the aggregate line"
grep -Fq 'NOT counted as passing' "$RUN" \
  || fail "$RUN does not name the skipped checks in the summary"
grep -Fq 'NOT exercised' "$RUN" \
  || fail "$RUN does not treat 'NOT exercised' (the browser checks' static-only pass) as a skip"

# The ordering matters: pass must be incremented only on the non-skip branch. A file where
# both happen would report the skip AND count it, which is the defect wearing a label.
awk '
  /grep -Eq .\^SKIP\|NOT exercised/ { inbranch = 1; next }
  inbranch && /skipped\+=/ { saw_skip = 1; next }
  inbranch && /else/ { in_else = 1; next }
  inbranch && in_else && /pass=\$\(\(pass \+ 1\)\)/ { saw_pass_after_else = 1 }
  END { exit (saw_skip && saw_pass_after_else && in_else) ? 0 : 1 }
' "$RUN" || fail "$RUN increments pass on the SKIP branch, or no longer has an else branch"

# Behaviour, on fixtures outside tests/checks: the runner must classify them as it claims.
fx=$(mktemp -d)
trap 'rm -rf "$fx"' EXIT
printf '#!/usr/bin/env bash\necho "PASS (static only -- the walk was NOT exercised: no browser)"\n' >"$fx/static.sh"
printf '#!/usr/bin/env bash\necho "SKIP: no kit"\n' >"$fx/skip.sh"
printf '#!/usr/bin/env bash\necho PASS\n' >"$fx/ok.sh"
printf '#!/usr/bin/env bash\necho boom\nexit 1\n' >"$fx/bad.sh"
rout=$(bash "$RUN" -j 2 "$fx/static.sh" "$fx/skip.sh" "$fx/ok.sh" 2>&1); rrc=$?
[ "$rrc" -eq 0 ] || fail "$RUN exits $rrc when nothing failed"
grep -Fq 'PASS=1 SKIP=2 FAIL=0' <<<"$rout" \
  || fail "$RUN did not classify a 'NOT exercised' pass and a SKIP as skips (got: $(grep -F 'PASS=' <<<"$rout"))"
rout=$(bash "$RUN" -j 2 "$fx/ok.sh" "$fx/bad.sh" 2>&1); rrc=$?
[ "$rrc" -eq 1 ] && grep -Fq 'PASS=1 SKIP=0 FAIL=1' <<<"$rout" || fail "$RUN does not fail the run on a failing check"
rout=$(bash "$RUN" --exclude "$fx/bad.sh" "$fx/ok.sh" "$fx/bad.sh" 2>&1) \
  && grep -Fq 'PASS=1 SKIP=0 FAIL=0' <<<"$rout" || fail "$RUN ignores --exclude"

# --- the job-owned exclusions, which this check now sits beside ------------------------------
# Read from the skip_here value itself: every name below is also invoked by its own job elsewhere
# in the workflow, so a whole-file grep could never fail.
skip_list=$(sed -n "s/^[[:space:]]*skip_here='\(.*\)'\$/\1/p" "$CI")
[ -n "$skip_list" ] || fail "$CI has no skip_here list to read"
for owned in motion-devices wp-polylang-integration wp-cf7-delivery wp-woo-setup-integration audit-resolve-links-integration audit-ux-probe visual-baselines baseline-approval; do
  case " $skip_list " in *" tests/checks/$owned.sh "*) ;; *)
    fail "$CI no longer excludes tests/checks/$owned.sh from the contract glob -- it would skip there and pass" ;;
  esac
done

# --- the signal being accounted for actually exists ------------------------------------------
# Without PLL_TEST_SITE this must print SKIP and exit 0. If it ever stops saying SKIP, the
# accounting above silently starts counting it as a measured pass again.
out=$(PLL_TEST_SITE='' bash tests/checks/wp-polylang-live.sh 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  fail "wp-polylang-live.sh exits $status with no PLL_TEST_SITE; it is documented to exit 0 with SKIP"
elif ! grep -q '^SKIP' <<<"$out"; then
  fail "wp-polylang-live.sh no longer prints SKIP when it declines to run -- the aggregate cannot tell it apart from a pass"
fi

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: CI counts a skipped check as skipped, not as passing\n'
