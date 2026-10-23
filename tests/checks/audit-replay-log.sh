#!/usr/bin/env bash
# /wp-audit setting and database fixes were printed once and then lost, agent reports
# lived only in the conversation, and bulk database fixes kept no old value, so a run could
# not be repeated on another environment or resumed after /clear.
# fix.md must define the replay log and the bulk backup, dispatch.md the on-disk reports
# and the run state, and the parent command must still send both steps there.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
fix=skills/wp-audit-run/references/fix.md
disp=skills/wp-audit-run/references/dispatch.md

for t in 'replay.json' 'previous value' 'applied_on' '<out>/backups/' 'more than 25 rows' '--replay <env>'; do
  grep -Fq -- "$t" "$fix" || fail "fix.md lacks: $t"
done
grep -Fq -- 'from `<out>/replay.json`' "$fix" || fail "fix.md does not print the repeat list from the log"

for t in 'agents/' 'run-state.json' 'fewer than 15 lines' 'before the Step 7 synthesis' '/clear'; do
  grep -Fq -- "$t" "$disp" || fail "dispatch.md lacks: $t"
done
awk '/^## Step 6: / { step = 1; next } /^## Step / && step { exit } step && /references\/dispatch\.md/ { found = 1 } END { exit !found }' commands/wp-audit.md \
  || fail "wp-audit.md Step 6 no longer sends agents to dispatch.md"
awk '/^## Step 9: / { step = 1; next } /^## Step / && step { exit } step && /references\/fix\.md/ { found = 1 } END { exit !found }' commands/wp-audit.md \
  || fail "wp-audit.md Step 9 no longer sends fixes to fix.md"
echo PASS
