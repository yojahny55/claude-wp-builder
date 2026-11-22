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
# The Model routing list is the contract: every agent in agents/ appears under the tier its
# frontmatter declares (the `wp-audit-a|b|c` shorthand is expanded), and no tier names an
# agent that does not exist.
routed=$(awk '/^## Model routing/{on=1;next} /^## /{on=0} on' "$wp_yolo" | tr '\n' ' ' | sed 's/- \*\*/\n&/g')
for f in agents/*.md; do
  n=$(basename "$f" .md); m=$(sed -n "s/^model: //p" "$f")
  line=$(printf '%s\n' "$routed" | grep -E "^- \*\*$m\*\*" || true)
  # expand wp-audit-a|b|c into wp-audit-a, wp-audit-b, wp-audit-c
  names=$(printf '%s' "$line" | sed 's/\. .*//' | grep -oE 'wp-[a-z0-9-]+(\|[a-z0-9]+)*' | awk -F'|' '{print $1; for(i=2;i<=NF;i++){p=$1; sub(/-[a-z0-9]+$/,"",p); print p "-" $i}}')
  printf '%s\n' "$names" | grep >/dev/null -cxF "$n" || { echo "FAIL: $n ($m) missing from the $m line of wp-yolo Model routing"; exit 1; }
done
for tier in opus sonnet haiku; do
  line=$(printf '%s\n' "$routed" | grep -E "^- \*\*$tier\*\*" || true)
  names=$(printf '%s' "$line" | sed 's/\. .*//' | grep -oE 'wp-[a-z0-9-]+(\|[a-z0-9]+)*' | awk -F'|' '{print $1; for(i=2;i<=NF;i++){p=$1; sub(/-[a-z0-9]+$/,"",p); print p "-" $i}}')
  for n in $names; do
    [ -f "agents/$n.md" ] || continue
    [ "$(sed -n 's/^model: //p' "agents/$n.md")" = "$tier" ] || { echo "FAIL: wp-yolo lists $n under $tier but its frontmatter says otherwise"; exit 1; }
  done
done
bash tests/checks/agent-validation-steps.sh
echo PASS
