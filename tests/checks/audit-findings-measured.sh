#!/usr/bin/env bash
# A finding is the output of a command that ran in this run. Anything else is UNVERIFIED.
set -euo pipefail
shopt -s nullglob

fail() { echo "FAIL: $1"; exit 1; }

c=commands/wp-audit.md
[ -f "$c" ] || fail "$c is missing"

grep -q 'Every finding is a measurement' "$c" || fail "/wp-audit has no findings-are-measurements contract"
grep -q 'UNVERIFIED' "$c" || fail "/wp-audit does not define the UNVERIFIED outcome"
grep -q 'Each finding line carries its evidence' "$c" || fail "/wp-audit does not require an evidence line per finding"

agents=(agents/wp-audit-*.md)
[ ${#agents[@]} -gt 0 ] || fail "no agents/wp-audit-*.md found (run from the repo root)"

missing=()
for a in "${agents[@]}"; do
  grep -q 'Findings are measurements' "$a" || missing+=("$a")
done
[ ${#missing[@]} -eq 0 ] || fail "audit agents without the contract: ${missing[*]}"

echo PASS
