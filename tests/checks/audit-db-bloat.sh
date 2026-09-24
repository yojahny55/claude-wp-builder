#!/usr/bin/env bash
set -euo pipefail

# Database bloat gets a threshold instead of PERF-042's `INFO only` (PERF-061 to PERF-064).
#
# Defects this contract prevents:
#   1. PERF-042 already prints every table's size but names no pass/fail line, so a table
#      grown to gigabytes reads exactly like a healthy one. The four new checks must each
#      carry a concrete threshold and a WP-CLI fix, not just another INFO row.
#   2. These patterns are real on production too — an Action Scheduler backlog, a stale
#      session table, old transients, dead postmeta rows are not clone artifacts — so they
#      must report normally and never get folded into Step 2.3's local-clone suppression.
#   3. Two of the five patterns the task named (autoload budget, expired transients) already
#      had a check (PERF-036/037, PERF-039). The doc must say so and must not restate them
#      as new codes — duplicating a check is worse than skipping it.
#   4. Every check cell hardcoded the wp_ prefix, contradicting the prefix note this same
#      doc gives — on a site with a real prefix, `FROM wp_<table>` errors instead of
#      reporting the finding. Fixed to build the table name from $($WP db prefix).
#   5. PERF-063's join used REPLACE(), a SQL word WP-CLI's `db query` treats as row-modifying
#      (regex over UPDATE/DELETE/INSERT/REPLACE/LOAD DATA) — the cell printed only
#      "Rows affected: -1" through the real command, never the row/byte numbers the Pass
#      criterion needs. Confirmed against a live `wp db query` run, not just read from docs.
#   6. PERF-063's INNER JOIN silently dropped orphaned expired-timeout markers (a value row
#      already gone) that PERF-039's own plain COUNT(*) still counts — undercounting against
#      the check it deliberately does not duplicate. Fixed to LEFT JOIN with COALESCE.
#   7. PERF-064 named "batch it" as the fix for a backlog too large for one statement, but
#      gave no runnable batched command, and a DELETE ... JOIN cannot take LIMIT at all.
#
# Assert both directions: the contract present, and the discarded shape (INFO-only bloat,
# a blanket N/A, a silent duplicate, a hardcoded prefix, a row-modifying word in a SELECT)
# named as wrong.
#
# Every command substitution below either has an explicit fallback (`|| true`, an `[ -n ]`
# check right after) or is one `grep -Fq/-Eq ... "$file" || fail` per line — never a bare
# `grep -q` piped from another command under `set -euo pipefail`, which can abort the
# script with no FAIL message the moment grep's early exit on match SIGPIPEs its writer.

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
# Severity is the row's last cell; each code's must be exactly the one it was assigned.
for code in "${!want_severity[@]}"; do
  sev=$(CODE="$code" awk -F'|' '/^\|/ { c = $2; gsub(/^[ \t]+|[ \t]+$/, "", c)
          if (c == ENVIRON["CODE"]) { s = $(NF - 1); gsub(/^[ \t]+|[ \t]+$/, "", s); print s; exit } }' "$agent")
  [ -n "$sev" ] || fail "$agent has no $code row"
  [ "$sev" = "${want_severity[$code]}" ] \
    || fail "$code is $sev, expected ${want_severity[$code]}"
done

# Every PERF-NNN table row is unique. A fixed 061-064-only ceiling (rejecting PERF-065+)
# would go red the moment any other PR adds a new code to this same file — this checks the
# actual defect (two rows claiming one code) without capping how many codes may ever exist.
dupe_codes=$(grep -oE '^\| PERF-[0-9]+ \|' "$agent" | tr -d '| ' | sort | uniq -d || true)
[ -z "$dupe_codes" ] || fail "$agent defines the same PERF-NNN code on more than one row: $dupe_codes"

# row <code>: the agent's table row whose first cell is exactly <code>. One awk pass, no
# pipeline, so there is no grep exit status or SIGPIPE to mask; a missing row is empty output
# and exit 0, and the `[ -n "$r" ]` guard at each call site reports it.
row() {
  CODE="$1" awk -F'|' '/^\|/ { cell = $2; gsub(/^[ \t]+|[ \t]+$/, "", cell); if (cell == ENVIRON["CODE"]) print }' "$agent"
}

# None of the four executable cells may hardcode the wp_ prefix: on a site whose real prefix
# isn't wp_, that table doesn't exist and the query errors instead of reporting the finding.
# The dynamic-prefix build ($($WP db prefix)<table>) is required in each cell instead. None
# may contain a word (UPDATE/DELETE/INSERT/REPLACE/LOAD DATA) that makes WP-CLI's `db query`
# treat a read-only check as row-modifying and print only "Rows affected: -1".
for code in PERF-061 PERF-062 PERF-063 PERF-064; do
  r=$(row "$code")
  [ -n "$r" ] || fail "$agent has no $code table row"
  printf '%s' "$r" | grep -Eq 'FROM wp_[a-z]' \
    && fail "$code hardcodes the wp_ prefix in its SQL instead of reading the site's real one"
  printf '%s' "$r" | grep -Fq '$($WP db prefix)' \
    || fail "$code does not build its table name from \$($WP db prefix)"
  printf '%s' "$r" | grep -Eiq '\b(UPDATE|DELETE|INSERT|REPLACE|LOAD DATA)\b' \
    && fail "$code's check cell contains a word WP-CLI's db query treats as row-modifying (UPDATE/DELETE/INSERT/REPLACE/LOAD DATA) — it would print only 'Rows affected: -1', never the number the Pass criterion needs"
done

# PERF-036/037/039 pre-date this PR, but this PR edits them anyway (autoload values; and,
# same as the four new codes, they hardcoded wp_ too) — hold them to the same prefix rule so
# this PR does not fix the bug in one place and leave it in the lines right above it.
for code in PERF-036 PERF-037 PERF-039; do
  r=$(row "$code")
  [ -n "$r" ] || fail "$agent has no $code table row"
  printf '%s' "$r" | grep -Eq 'FROM wp_[a-z]' \
    && fail "$code hardcodes the wp_ prefix in its SQL instead of reading the site's real one"
  printf '%s' "$r" | grep -Fq '$($WP db prefix)' \
    || fail "$code does not build its table name from \$($WP db prefix)"
done
printf '%s' "$(row 'PERF-039')" | grep -Fq '\_transient\_timeout\_%' \
  || fail "PERF-039's LIKE pattern does not escape its leading underscores — same full-scan bug as PERF-063 had"

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

# PERF-063 — expired-transient backlog: threshold on rows AND bytes, not just "any"; the LIKE
# pattern escapes its leading underscores so the option_name index can still be used (an
# unescaped leading `_` is a single-char wildcard MySQL can't range-scan on, which forces a
# full table scan of wp_options on every run); the join to the value row is a LEFT JOIN with
# a COALESCE'd byte sum, not an INNER JOIN, so an orphaned timeout marker is still counted —
# matching PERF-039's own plain COUNT(*) of the same expired markers instead of undercounting
# against it.
r=$(row 'PERF-063')
printf '%s' "$r" | grep -Fq '_transient_timeout_' \
  || fail "PERF-063 does not query the transient timeout markers"
printf '%s' "$r" | grep -Fq '5,000' || fail "PERF-063 has no row threshold"
printf '%s' "$r" | grep -Fq '5MB' || fail "PERF-063 has no byte threshold"
printf '%s' "$r" | grep -Fq '\_transient\_timeout\_%' \
  || fail "PERF-063's LIKE pattern does not escape its leading underscores — it forces a full table scan of options"
printf '%s' "$r" | grep -Fq 'LEFT JOIN' \
  || fail "PERF-063 does not LEFT JOIN to the transient value row — an INNER JOIN drops orphaned expired-timeout markers that PERF-039 still counts"
printf '%s' "$r" | grep -Fq 'COALESCE' \
  || fail "PERF-063 does not COALESCE its byte sum — an all-orphan match set would sum to NULL instead of a comparable 0"
printf '%s' "$r" | grep -Fq 'CONCAT(' \
  || fail "PERF-063's join condition does not use CONCAT/SUBSTRING to build the value option's name"

# PERF-064 — orphaned postmeta: LEFT JOIN against posts, IS NULL, threshold.
r=$(row 'PERF-064')
printf '%s' "$r" | grep -Fq 'postmeta' || fail "PERF-064 does not query the postmeta table"
printf '%s' "$r" | grep -Fq 'LEFT JOIN' || fail "PERF-064 does not LEFT JOIN against posts"
printf '%s' "$r" | grep -Fq 'IS NULL' || fail "PERF-064 does not filter on a missing owner"
printf '%s' "$r" | grep -Fq '≤500 orphaned rows' || fail "PERF-064's threshold is not ≤500 orphaned rows"

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
proc=$(awk '/^### Procedure — database bloat checks/{f=1} f{print} f && /^## Step 3/{exit}' "$agent" || true)
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

# PERF-064's batched form must actually be runnable: a DELETE ... JOIN can't take LIMIT, so
# the batch has to go through a LIMIT-able subquery, materialized in a derived table (the
# classic "can't specify target table for update in FROM clause" workaround), built with the
# dynamic prefix like every other cell, and repeated until it deletes 0 rows.
printf '%s' "$proc" | grep -Fq 'cannot take a `LIMIT`' \
  || fail "$agent does not explain that DELETE ... JOIN cannot take LIMIT, which is why PERF-064 needs a subquery batch form"
printf '%s' "$proc" | grep -Fq 'WHERE meta_id IN (SELECT meta_id FROM (SELECT' \
  || fail "$agent gives no runnable batched-delete command for PERF-064 (subquery form with a derived table)"
printf '%s' "$proc" | grep -Fq 'LIMIT 5000' \
  || fail "$agent's PERF-064 batch command has no LIMIT, so it is not actually batched"
printf '%s' "$proc" | grep -Fq '$($WP db prefix)postmeta' \
  || fail "$agent's PERF-064 batch command hardcodes the table name instead of resolving the real prefix"
printf '%s' "$proc" | grep -Fiq 'run this repeatedly, in a loop' \
  || fail "$agent does not say to run the PERF-064 batch repeatedly"
printf '%s' "$proc" | grep -Fq '0 rows affected' \
  || fail "$agent does not say to stop the PERF-064 batch loop at 0 rows affected"

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

# --- CHANGELOG: an Added entry exists, names the codes, and explains the why ---
grep -Fq 'PERF-061' "$changelog" || fail "$changelog does not mention PERF-061"
grep -Fq 'PERF-064' "$changelog" || fail "$changelog does not mention PERF-064"
grep -Fq 'INFO only' "$changelog" \
  || fail "$changelog does not explain that PERF-042 was INFO-only before this change"
grep -Fq 'not duplicated' "$changelog" \
  || fail "$changelog does not explain the autoload/transient duplication check"

# The version must not have been bumped for an in-agent addition: a bump turns the top
# release heading from [Unreleased] into a version number. Read that first heading itself,
# not a fixed window of lines, which grows with every entry added under [Unreleased].
top="$(grep -m1 '^## ' "$changelog")"
[ "$top" = '## [Unreleased]' ] \
  || fail "$changelog's top heading is '$top', not '## [Unreleased]' — new codes in an existing agent do not bump the version"

echo PASS
