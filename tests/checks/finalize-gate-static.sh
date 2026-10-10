#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-finalize.md; f=$EXPANDED
for token in 'undefined' 'var\(--' 'collision' 'font parity|@font-face' 'background:url|background-image' 'critical'; do
  grep -Eqi "$token" "$f" || { echo "FAIL: finalize missing static check '$token'"; exit 1; }
done
echo PASS
