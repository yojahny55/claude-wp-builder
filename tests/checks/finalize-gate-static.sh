#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-finalize.md
for token in 'undefined' 'var\(--' 'collision' 'font parity|@font-face' 'background:url|background-image' 'critical'; do
  grep -Eqi "$token" "$f" || { echo "FAIL: finalize missing static check '$token'"; exit 1; }
done
echo PASS
