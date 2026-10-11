#!/usr/bin/env bash
set -euo pipefail
. tests/checks/lib/expand-command.sh; expand_command commands/wp-page.md; f=$EXPANDED
grep -q 'embed' <(grep -i 'Types:' "$f") || { echo "FAIL: embed not in Types list"; exit 1; }
grep -q '### Type: embed' "$f" || { echo "FAIL: no '### Type: embed' section"; exit 1; }
grep -q 'EMBED:' "$f" || { echo "FAIL: no marked insertion point"; exit 1; }
grep -q -- '--provider' "$f" || { echo "FAIL: no --provider flag"; exit 1; }
echo PASS
