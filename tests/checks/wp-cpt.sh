#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-cpt.md
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
head -1 "$f" | grep >/dev/null -c '^---$' || { echo "FAIL: no frontmatter"; exit 1; }
grep -q 'allowed-tools:' "$f" || { echo "FAIL: no allowed-tools"; exit 1; }
grep -q 'argument-hint:' "$f" || { echo "FAIL: no argument-hint"; exit 1; }
for token in register_post_type 'inc/post-types' 'archive-' 'single-' has_archive get_post_type_archive_link 'wp-acf' 'wp-template'; do
  grep -q "$token" "$f" || { echo "FAIL: missing '$token'"; exit 1; }
done
echo PASS
