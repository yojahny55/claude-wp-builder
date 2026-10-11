#!/usr/bin/env bash
set -euo pipefail
. tests/checks/lib/expand-command.sh; expand_command commands/wp-page.md; f=$EXPANDED
grep -q 'search' <(grep -i 'Types:' "$f") || { echo "FAIL: search not in Types list"; exit 1; }
grep -q '### Type: search' "$f" || { echo "FAIL: no '### Type: search' dispatch section"; exit 1; }
echo PASS
