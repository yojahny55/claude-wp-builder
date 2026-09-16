#!/usr/bin/env bash
# A finding is the output of a command that ran in this run. Anything else is UNVERIFIED.
set -euo pipefail
c=commands/wp-audit.md

grep -q 'Every finding is a measurement' "$c" || { echo "FAIL: /wp-audit has no findings-are-measurements contract"; exit 1; }
grep -q 'UNVERIFIED' "$c" || { echo "FAIL: /wp-audit does not define the UNVERIFIED outcome"; exit 1; }
grep -qi 'evidence' "$c" || { echo "FAIL: /wp-audit does not require an evidence line"; exit 1; }

missing=()
for a in agents/wp-audit-*.md; do
  grep -q 'Findings are measurements' "$a" || missing+=("$a")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "FAIL: audit agents without the contract: ${missing[*]}"; exit 1
fi

echo PASS
