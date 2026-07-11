#!/usr/bin/env bash
set -euo pipefail
f=agents/wp-normalize.md
for token in 'block' 'cssRules' 'backgrounds' '@font-face' 'computed' 'role' 'nav-graphic' 'hero' 'shared component'; do
  grep -qi "$token" "$f" || { echo "FAIL: missing '$token'"; exit 1; }
done
grep -qi 'unique' "$f" || { echo "FAIL: does not state block names are unique/assigned"; exit 1; }
echo PASS
