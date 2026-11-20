#!/usr/bin/env bash
# CLAUDE.md is loaded into every session, so its size is a cost paid on every task. It had
# grown to 805 lines by absorbing the history and reasoning behind each rule; that detail now
# lives in docs/ and CLAUDE.md keeps the rules and a pointer.
#
# This holds the budget and the pointers: CLAUDE.md stays under the cap, the three documents
# it delegates to exist, and CLAUDE.md names each one -- a moved section nobody links to is
# a section nobody reads.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

MAX=260
lines=$(wc -l < CLAUDE.md)
[ "$lines" -le "$MAX" ] || fail "CLAUDE.md is $lines lines, over the $MAX budget: move the reasoning to docs/ and keep the rule"

for d in docs/known-ceilings.md docs/testing.md docs/architecture.md; do
  [ -s "$d" ] || fail "$d is missing or empty"
  grep -Fq "$d" CLAUDE.md || fail "CLAUDE.md does not name $d"
done

echo PASS
