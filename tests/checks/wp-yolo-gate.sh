#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-yolo.md
for token in 'wp-finalize' 'auto-fix|auto fix' 'block' 'Review' 're-verify|re-run'; do
  grep -Eqi "$token" "$f" || { echo "FAIL: wp-yolo gate missing '$token'"; exit 1; }
done
grep -Eqi 'does not (report|claim) success|marked incomplete' "$f" || { echo "FAIL: does not state --yolo blocks on critical"; exit 1; }
echo PASS
