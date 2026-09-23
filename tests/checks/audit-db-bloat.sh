#!/usr/bin/env bash
set -uo pipefail

# Database bloat gets a threshold instead of PERF-042's `INFO only` (PERF-061 to PERF-064).
#
# Three defects this contract prevents:
#   1. PERF-042 already prints every table's size but names no pass/fail line, so a table
#      grown to gigabytes reads exactly like a healthy one. The four new checks must each
#      carry a concrete threshold and a WP-CLI fix, not just another INFO row.
#   2. These patterns are real on production too — an Action Scheduler backlog, a stale
#      session table, old transients, dead postmeta rows are not clone artifacts — so they
#      must report normally and never get folded into Step 2.3's local-clone suppression.
#   3. Two of the five patterns the task named (autoload budget, expired transients) already
#      had a check (PERF-036/037, PERF-039). The doc must say so and must not restate them
#      as new codes — duplicating a check is worse than skipping it.
#
# Assert both directions: the contract present, and the discarded shape (INFO-only bloat,
# a blanket N/A, a silent duplicate) named as wrong.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

agent=agents/wp-audit-performance.md
changelog=CHANGELOG.md
for f in "$agent" "$changelog"; do
  [ -s "$f" ] || fail "$f is missing or empty"
done

# --- The four new codes exist, each with a threshold and a severity ---
declare -A want_severity=(
  [PERF-061]=WARNING
  [PERF-062]=WARNING
  [PERF-063]=INFO
  [PERF-064]=INFO
)
for code in "${!want_severity[@]}"; do
  grep -Fq "$code" "$agent" || fail "$agent has no $code row"
done

row() { grep -F "$1" "$agent" | grep -F '|'; }

# None of the four executable cells may hardcode the wp_ prefix: on a site whose real prefix
# isn't wp_, that table doesn't exist and the query errors instead of reporting the finding.
# The dynamic-prefix build ($($WP db prefix)<table>) is required in each cell instead.
for code in PERF-061 PERF-062 PERF-063 PERF-064; do
  r=$(row "$code")
  printf '%s' "$r" | grep -Eq 'FROM wp_[a-z]' \
    && fail "$code hardcodes the wp_ prefix in its SQL instead of reading the site's real one"
  printf '%s' "$r" | grep -Fq '$($WP db prefix)' \
    || fail "$code does not build its table name from \$($WP db prefix)"
done

# PERF-061 — Action Scheduler backlog: table name, a real row-count threshold, not "Info only".
r=$(row 'PERF-061')
printf '%s' "$r" | grep -Fq 'actionscheduler_actions' \
  || fail "PERF-061 does not name the actionscheduler_actions table"
printf '%s' "$r" | grep -Fq '10,000' \
  || fail "PERF-061 has no concrete row-count threshold"
printf '%s' "$r" | grep -Fq 'WARNING' \
  || fail "PERF-061 is not WARNING"
printf '%s' "$r" | grep -Fiq 'info only' \
  && fail "PERF-061 is still an INFO-only row like PERF-042 — it must carry a threshold"

# PERF-062 — woocommerce_sessions: table name, expiry column, threshold.
r=$(row 'PERF-062')
printf '%s' "$r" | grep -Fq 'woocommerce_sessions' \
  || fail "PERF-062 does not name the woocommerce_sessions table"
printf '%s' "$r" | grep -Fq 'session_expiry' \
  || fail "PERF-062 does not check session_expiry"
printf '%s' "$r" | grep -Fq '1,000' \
  || fail "PERF-062 has no concrete threshold"

# PERF-063 — expired-transient backlog: threshold on rows AND bytes, not just "any", and the
# LIKE pattern escapes its leading underscores so the option_name index can still be used
# (an unescaped leading `_` is a single-char wildcard MySQL can't range-scan on, which forces
# a full table scan of wp_options on every run).
r=$(row 'PERF-063')
printf '%s' "$r" | grep -Fq '_transient_timeout_' \
  || fail "PERF-063 does not query the transient timeout markers"
printf '%s' "$r" | grep -Fq '5,000' || fail "PERF-063 has no row threshold"
printf '%s' "$r" | grep -Fq '5MB' || fail "PERF-063 has no byte threshold"
printf '%s' "$r" | grep -Fq '\_transient\_timeout\_%' \
  || fail "PERF-063's LIKE pattern does not escape its leading underscores — it forces a full table scan of options"

# PERF-064 — orphaned postmeta: LEFT JOIN against posts, IS NULL, threshold.
r=$(row 'PERF-064')
printf '%s' "$r" | grep -Fq 'postmeta' || fail "PERF-064 does not query the postmeta table"
printf '%s' "$r" | grep -Fq 'LEFT JOIN' || fail "PERF-064 does not LEFT JOIN against posts"
printf '%s' "$r" | grep -Fq 'IS NULL' || fail "PERF-064 does not filter on a missing owner"
printf '%s' "$r" | grep -Fq '500' || fail "PERF-064 has no concrete row threshold"

# --- The prefix-awareness note itself is present, not just the fixed cells ---
grep -Fq '$($WP db prefix)' "$agent" \
  || fail "$agent never explains how the real table prefix is resolved"
grep -Fq "Do not hand-edit" "$agent" \
  || fail "$agent has no warning against hardcoding wp_<table> when running these by hand"

# --- PERF-036/037 must count the autoload values WP 6.6+ actually writes, not just 'yes' ---
grep -Fq "autoload IN ('yes','on','auto-on','auto')" "$agent" \
  || fail "$agent's autoloaded-options queries (PERF-036/037) still filter only autoload='yes' — WP 6.6+ also writes on/auto-on/auto"
autoload_yes_only=$(grep -F "autoload='yes'" "$agent" | grep -v "autoload IN (" || true)
[ -z "$autoload_yes_only" ] \
  || fail "$agent still has a bare autoload='yes' filter that misses WP 6.6+ autoload values"

# --- The procedure section: fix commands named, per item ---
proc=$(awk '/^### Procedure — database bloat checks/{f=1} f{print} f && /^## Step 3/{exit}' "$agent")
[ -n "$proc" ] || fail "$agent has no 'Procedure — database bloat checks' section"

grep -Eq '\$WP action-scheduler clean' "$agent" \
  || fail "$agent does not give '\$WP action-scheduler clean' as the PERF-061 fix"
printf '%s' "$proc" | grep -Fq "do_action('woocommerce_cleanup_sessions')" \
  || fail "$agent does not give the woocommerce_cleanup_sessions fix for PERF-062"
printf '%s' "$proc" | grep -Eq '\$WP transient delete --expired' \
  || fail "$agent does not give '\$WP transient delete --expired' as the PERF-063 fix"
printf '%s' "$proc" | grep -Eq '\$WP db export' \
  || fail "$agent does not require a backup (\$WP db export) before the PERF-064 delete"
printf '%s' "$proc" | grep -Fiq 'never auto-fix' \
  || fail "$agent does not forbid auto-fixing the destructive PERF-064 delete"

# --- Not clone artifacts: must report normally, never folded into Step 2.3 suppression ---
printf '%s' "$proc" | grep -Fq 'real on production' \
  || fail "$agent does not say these bloat patterns are real on production, not clone artifacts"
printf '%s' "$proc" | grep -Fiq 'never suppressed' \
  || fail "$agent does not forbid suppressing these under the local-clone rule"

# N/A is bounded to "table genuinely absent", never a blanket commerce gate.
printf '%s' "$proc" | grep -Fq 'N/A' || fail "$agent gives no N/A condition for the DB bloat checks"
printf '%s' "$proc" | grep -Fq 'not when WooCommerce is inactive' \
  || fail "$agent does not forbid gating PERF-061 to N/A merely because WooCommerce is inactive"

# --- Duplication check: autoload and expired-transient-existence were NOT re-added ---
printf '%s' "$proc" | grep -Fq 'already covered, not duplicated' \
  || fail "$agent does not explain why the autoload budget got no new code"
printf '%s' "$proc" | grep -Fq 'PERF-036' \
  || fail "$agent does not point to the existing PERF-036 autoload threshold"
printf '%s' "$proc" | grep -Fq 'PERF-039' \
  || fail "$agent does not point to the existing PERF-039 expired-transient check"
printf '%s' "$proc" | grep -Fq 'does not duplicate that check' \
  || fail "$agent does not say PERF-063 avoids duplicating PERF-039"

# A stray fifth new code for autoload would be a silent duplicate — make sure none exists.
grep -Eq 'PERF-06[5-9]' "$agent" \
  && fail "$agent defines a PERF-065+ code — only four new codes (061-064) were asked for"

# --- CHANGELOG: an Added entry exists, names the codes, and explains the why ---
grep -Fq 'PERF-061' "$changelog" || fail "$changelog does not mention PERF-061"
grep -Fq 'PERF-064' "$changelog" || fail "$changelog does not mention PERF-064"
grep -Fq 'INFO only' "$changelog" \
  || fail "$changelog does not explain that PERF-042 was INFO-only before this change"
grep -Fq 'not duplicated' "$changelog" \
  || fail "$changelog does not explain the autoload/transient duplication check"

# The version must not have been bumped for an in-agent addition.
grep -Eq '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$changelog" \
  && head -20 "$changelog" | grep -Eq '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' \
  && fail "$changelog was bumped to a version header — new codes in an existing agent do not bump the version"

echo PASS
