#!/usr/bin/env bash
# PERF-061..064 count database rows but never say whose they are. A real store carried 1.9M
# pending Action Scheduler actions from never-connected plugins, 739k temporary options from one
# plugin, a 289k-row Rank Math 404 log and orphan autoloaded options, with no audit naming the
# owner. PERF-071..074 attribute them. They must stay read-only, prefix-aware, never auto-fixed
# and clone-neutral (a clone-suppressed plugin counts as active).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

perf=$(bash tests/checks/lib/agent-text.sh wp-audit-performance)
for c in 071 072 073 074; do
  grep -qE "^\| PERF-$c \|" "$perf" || fail "PERF-$c not tabulated in $perf"
  grep -Fq "PERF-$c" "$perf" || fail "PERF-$c missing"
done
grep -Fq 'Procedure — database bloat attribution (PERF-071 to PERF-074)' "$perf" \
  || fail "$perf has no PERF-071..074 procedure"
grep -Fq '`Clone-suppressed plugins`' "$perf" || fail "attribution procedure lost the clone-suppressed rule"
grep -Fq 'treat those as **active**' "$perf" || fail "clone-suppressed plugins must count as active"
grep -Fq 'No fix here is auto-applied' "$perf" || fail "fixes must be stated as never auto-applied"
grep -Fq "'auto-on','auto'" "$perf" || fail "autoload filter lost the WP 6.6+ values"
grep -Fq 'rank_math_404_logs' "$perf" || fail "PERF-073 lost its table"
grep -Fq 'PERF-060' "$perf" || fail "PERF-073 must cross-reference PERF-060"

# The row cells run through `wp db query`, which treats these words as row-modifying and prints
# only "Rows affected"; and none may hardcode wp_.
for c in 071 072; do
  row="$(grep -E "^\| PERF-$c \|" "$perf")"
  case "$row" in *'$($WP db prefix)'*) ;; *) fail "PERF-$c row must use \$(\$WP db prefix)";; esac
  if printf '%s' "$row" | grep -Eiq '\b(UPDATE|DELETE|INSERT|REPLACE|LOAD DATA)\b'; then
    fail "PERF-$c row contains a word WP-CLI db query treats as row-modifying"
  fi
  printf '%s' "$row" | grep -Eq '(FROM|JOIN) wp_' && fail "PERF-$c row hardcodes the wp_ prefix"
done
! grep -Eq '^\| PERF-07[1-4] \|.*\| CRITICAL \|$' "$perf" || fail "PERF-071..074 must not be CRITICAL"

grep -Fq 'PERF-071' CHANGELOG.md || fail "changelog entry missing"
echo PASS
