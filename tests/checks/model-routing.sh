#!/usr/bin/env bash
set -euo pipefail
. tests/checks/lib/expand-command.sh; expand_command commands/wp-yolo.md; wp_yolo=$EXPANDED
# Every agent must declare a model tier; wp-yolo documents the routing contract.
for f in agents/*.md; do
  m=$(sed -n "s/^model: //p" "$f")
  [ -n "$m" ] || { echo "FAIL: $f has no model: frontmatter"; exit 1; }
  case "$m" in opus|sonnet|haiku|inherit) ;; *) echo "FAIL: $f invalid model '$m'"; exit 1;; esac
done
# Tier pinning: planning=opus, mechanical=haiku.
# wp-acf and wp-cf7 stay on haiku ONLY because each ends in a mandatory validation step
# (php -l + wp-config.mjs validate); tests/checks/agent-validation-steps.sh pins that step,
# so removing it forces a decision here: restore the step or raise the tier to sonnet.
grep -q "^model: opus"  agents/wp-normalize.md || { echo "FAIL: wp-normalize not opus"; exit 1; }
grep -q "^model: opus"  agents/wp-context.md   || { echo "FAIL: wp-context not opus"; exit 1; }
grep -q "^model: haiku" agents/wp-acf.md       || { echo "FAIL: wp-acf not haiku"; exit 1; }
grep -q "^model: haiku" agents/wp-cf7.md       || { echo "FAIL: wp-cf7 not haiku"; exit 1; }
grep -q "^model: sonnet" agents/wp-template.md || { echo "FAIL: wp-template not sonnet"; exit 1; }
grep -q "^model: sonnet" agents/wp-audit-geo.md || { echo "FAIL: wp-audit-geo not sonnet"; exit 1; }
grep -q "^model: sonnet" agents/wp-agentic-surfaces.md || { echo "FAIL: wp-agentic-surfaces not sonnet"; exit 1; }
grep -Eq "^## Model routing" "$wp_yolo" || { echo "FAIL: wp-yolo.md missing Model routing section"; exit 1; }
grep -q "do \*\*not\*\* pass a \`model\` parameter" "$wp_yolo" || { echo "FAIL: wp-yolo.md missing no-override rule"; exit 1; }
# wp-normalize holds Bash for its final validation step only (agent-validation-steps.sh).
grep -Eq "^tools:.*\bBash\b" agents/wp-normalize.md || { echo "FAIL: wp-normalize has no Bash for its validation step"; exit 1; }
bash tests/checks/agent-validation-steps.sh >/dev/null || { echo "FAIL: haiku agents lost their validation step"; exit 1; }
echo PASS
