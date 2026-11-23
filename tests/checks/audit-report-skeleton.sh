#!/usr/bin/env bash
# Two halves of the agent report contract that a real audit run over the seeded-defects
# corpus showed were missing.
#
# 1. The dispatch prompt carries a literal JSON skeleton. Described in prose only, four of
#    five agents left out `category`, wrote `not_applicable` as a map, and one put a vendor
#    scan note in `findings`. The skeleton must parse as JSON and carry every top-level key.
# 2. root_cause means one defect, one fix. The run folded a missing nonce under a SQL
#    injection in the same function because both shared a slug, so fixing the query would
#    have looked like it closed both. wp-audit-standards must say so, with the example.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

d=skills/wp-audit-run/references/dispatch.md
need_token "$d" 'The findings JSON you return has exactly this skeleton.' "dispatch.md lost the literal JSON skeleton"
need_token "$d" 'A note about the scan is never a row in `findings`' "dispatch.md no longer keeps scan notes out of findings"

# The skeleton: from the line after the marker sentence's paragraph to the first line that is
# exactly "}". It is inside the prompt's code block, so it is plain text there.
skeleton=$(awk '/exactly this skeleton/{on=1; next} on && /^\{$/{grab=1} grab{print} grab && /^\}$/{exit}' "$d")
[ -n "$skeleton" ] || fail "dispatch.md: could not find the JSON skeleton after its marker sentence"
SKELETON="$skeleton" node -e '
  let s;
  try { s = JSON.parse(process.env.SKELETON); } catch (e) { console.error("FAIL: dispatch.md skeleton is not valid JSON: " + e.message); process.exit(1); }
  for (const k of ["category", "checks_executed", "findings", "unmeasured", "not_applicable", "notes"]) {
    if (!(k in s)) { console.error("FAIL: dispatch.md skeleton has no \"" + k + "\" key"); process.exit(1); }
  }
  for (const k of ["unmeasured", "not_applicable", "findings"]) {
    if (!Array.isArray(s[k])) { console.error("FAIL: dispatch.md skeleton \"" + k + "\" must be an array, not a map"); process.exit(1); }
  }
  const f = s.findings[0] || {};
  for (const k of ["check", "status", "severity", "ownership", "resource", "message", "evidence", "root_cause"]) {
    if (!(k in f)) { console.error("FAIL: dispatch.md skeleton finding has no \"" + k + "\" key"); process.exit(1); }
  }
' || exit 1

s=skills/wp-audit-standards/SKILL.md
need_token "$s" '**One defect, one fix, one `root_cause`.**' "wp-audit-standards lost the one-defect-one-fix rule for root_cause"
need_token "$s" '`sqli:<file>:<line>`' "wp-audit-standards lost the SQL-injection half of the root_cause example"
need_token "$s" '`missing-nonce:<file>:<line>`' "wp-audit-standards lost the missing-nonce half of the root_cause example"
need_token "$s" 'read as the array form. Write the array form.' "wp-audit-standards no longer lists the map shape the aggregator accepts"
need_token "$s" 'takes it from its file name, `agents/wp-audit-<x>.json`' "wp-audit-standards no longer says where a missing category comes from"
echo PASS
