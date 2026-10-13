#!/usr/bin/env bash
# A plugin review on an adopted store found two things no audit had reported: an active
# file-manager plugin (elFinder, edits PHP from wp-admin, ignores DISALLOW_FILE_EDIT) and a
# page-cache drop-in with WP_CACHE true whose plugin was off. The second was a clone artifact
# there -- the cache plugin is active on production -- so PERF-070 must defer to Step 2.3's
# Clone-suppressed plugins instead of flagging every clone.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

sec=agents/wp-audit-security.md
perf=agents/wp-audit-performance.md
ctx=skills/wp-audit-run/references/site-context.md

# SEC-045: tabulated, covers inactive copies, and finds forks by the elFinder fingerprint.
grep -qE '^\| SEC-045 \|' "$sec" || fail "SEC-045 (file-manager plugin) not tabulated"
for slug in wp-file-manager file-manager-advanced filester; do
  grep -Eq "^# known slugs:.*${slug}" "$sec" || fail "$sec SEC-045 known-slug list lost ${slug}"
done
grep -Fq "elfinder*.js" "$sec" || fail "$sec SEC-045 lost the elFinder fingerprint"
grep -Fq 'whether the plugin is active or not' "$sec" || fail "$sec SEC-045 no longer says why an inactive copy counts"
grep -Fq 'never to deactivate it' "$sec" || fail "$sec SEC-045 fix must be removal, not deactivation"

# PERF-070: tabulated, reads the clone context by name, and has the clone-artifact row.
grep -qE '^\| PERF-070 \|' "$perf" || fail "PERF-070 (orphan page-cache drop-in) not tabulated"
grep -Fq 'Procedure — page-cache drop-in without its plugin (PERF-070)' "$perf" \
  || fail "$perf has no PERF-070 procedure"
grep -Fq '`Clone-suppressed plugins`' "$perf" || fail "$perf PERF-070 does not read Clone-suppressed plugins"
grep -Fq 'PERF-070: clone artifact' "$perf" || fail "$perf PERF-070 lost the clone-artifact outcome"
grep -Fq 'Never guess them from which plugins are inactive' "$perf" \
  || fail "$perf PERF-070 must not infer the clone list from inactive plugins"
grep -Fq 'SWCFPC_ADVANCED_CACHE' "$perf" || fail "$perf PERF-070 lost its owner markers"
# The owner check is what separates a real orphan from a working cache.
! grep -Eq '^\| PERF-070 \|.*\| INFO \|$' "$perf" || fail "PERF-070 row must not be INFO-only"

# Step 2.3 records the drop-in as a clone artifact, pointing at PERF-070.
grep -Fq 'PERF-070' "$ctx" || fail "$ctx Step 2.3 table does not name the PERF-070 clone artifact"

echo PASS
