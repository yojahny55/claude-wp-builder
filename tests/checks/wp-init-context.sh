#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; f=$EXPANDED
grep -q 'wp-context' "$f" || { echo "FAIL: wp-init does not reference wp-context"; exit 1; }
grep -Eq 'docs/? (folder|directory|exists)|if .*docs' "$f" || { echo "FAIL: no docs/ existence condition"; exit 1; }
echo PASS
