#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-finalize.md
for token in 'site_logo' 'inner_hero_image' 'claude-in-chrome' 'getComputedStyle' 'hard delta|hard-delta' 'soft delta|soft-delta' 'skip'; do
  grep -Eqi "$token" "$f" || { echo "FAIL: finalize missing '$token'"; exit 1; }
done
grep -Eqi '3%|8px' "$f" || { echo "FAIL: no numeric visual threshold stated"; exit 1; }
echo PASS
