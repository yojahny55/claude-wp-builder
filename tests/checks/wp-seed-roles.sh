#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-seed.md
for token in 'role' 'site_logo' 'inner_hero_image' 'nav-graphic'; do
  grep -q "$token" "$f" || { echo "FAIL: wp-seed missing '$token' role handling"; exit 1; }
done
grep -qi 'teaser' agents/wp-template.md || { echo "FAIL: wp-template missing teaser-fidelity note"; exit 1; }
echo PASS
