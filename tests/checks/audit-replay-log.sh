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

for t in 'replay.json' 'previous value' 'applied_on' '<out>/backups/' '>25 rows' '--replay <env>'; do
  case "$t" in '>25 rows') t='more than 25 rows';; esac
  grep -Fq -- "$t" "$fix" || fail "fix.md lacks: $t"
done
grep -Fq -- 'from `<out>/replay.json`' "$fix" || fail "fix.md does not print the repeat list from the log"

for t in 'agents/' 'run-state.json' 'fewer than 15 lines' 'before the Step 7 synthesis' '/clear'; do
  grep -Fq -- "$t" "$disp" || fail "dispatch.md lacks: $t"
done
grep -Fq 'dispatch.md' commands/wp-audit.md || fail "wp-audit.md no longer sends Step 6 to dispatch.md"
grep -Fq 'fix.md' commands/wp-audit.md || fail "wp-audit.md no longer sends Step 9 to fix.md"
echo PASS
