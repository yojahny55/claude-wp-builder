#!/usr/bin/env bash
set -euo pipefail
# Every agent must declare a model tier; wp-yolo documents the routing contract.
for f in agents/*.md; do
  m=$(sed -n "s/^model: //p" "$f")
  [ -n "$m" ] || { echo "FAIL: $f has no model: frontmatter"; exit 1; }
  case "$m" in opus|sonnet|haiku|inherit) ;; *) echo "FAIL: $f invalid model '$m'"; exit 1;; esac
done
# Tier pinning: planning=opus, mechanical=haiku
grep -q "^model: opus"  agents/wp-normalize.md || { echo "FAIL: wp-normalize not opus"; exit 1; }
grep -q "^model: opus"  agents/wp-context.md   || { echo "FAIL: wp-context not opus"; exit 1; }
grep -q "^model: haiku" agents/wp-acf.md       || { echo "FAIL: wp-acf not haiku"; exit 1; }
grep -q "^model: haiku" agents/wp-cf7.md       || { echo "FAIL: wp-cf7 not haiku"; exit 1; }
grep -q "^model: sonnet" agents/wp-template.md || { echo "FAIL: wp-template not sonnet"; exit 1; }
grep -Eq "^## Model routing" commands/wp-yolo.md || { echo "FAIL: wp-yolo.md missing Model routing section"; exit 1; }
grep -q "do \*\*not\*\* pass a \`model\` parameter" commands/wp-yolo.md || { echo "FAIL: wp-yolo.md missing no-override rule"; exit 1; }
echo PASS
