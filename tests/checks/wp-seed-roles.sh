#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-seed.md; wp_seed=$EXPANDED
f=$wp_seed
for token in 'role' 'site_logo' 'inner_hero_image' 'nav-graphic'; do
  grep -q "$token" "$f" || { echo "FAIL: wp-seed missing '$token' role handling"; exit 1; }
done
grep -qi 'teaser' agents/wp-template.md || { echo "FAIL: wp-template missing teaser-fidelity note"; exit 1; }
echo PASS
