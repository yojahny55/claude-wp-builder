#!/usr/bin/env bash
set -euo pipefail
f=commands/wp-yolo.md
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'argument-hint:' "$f" || { echo "FAIL: frontmatter"; exit 1; }
for token in 'wp-normalize' 'yolo-manifest' 'checkpoint' '--yolo' '--careful' 'wp-cpt' 'wp-settings' 'wp-header' 'wp-footer' 'wp-section' 'wp-page 404' 'wp-page search' 'wp-seed' 'wp-finalize' 'Review'; do
  grep -q -- "$token" "$f" || { echo "FAIL: missing '$token'"; exit 1; }
done
# every referenced command/agent file must exist
for name in wp-normalize; do test -f "agents/$name.md" || { echo "FAIL: agents/$name.md"; exit 1; }; done
for name in wp-cpt wp-settings wp-header wp-footer wp-section wp-page wp-seed wp-finalize wp-polish wp-responsive-check wp-audit; do test -f "commands/$name.md" || { echo "FAIL: commands/$name.md"; exit 1; }; done
echo PASS
