#!/usr/bin/env bash
# An operable a11y fix usually swaps a tag: a clickable <span> or <div> becomes a <button>. That
# is a visual change, not a markup change — the browser applies its own styles to the new
# element, and a reset class added to neutralise them ties with the utility classes already on
# it, which source order then decides in the reset's favour.
#
# The case this exists for: <span class="icon-search text-white text-[1.625rem]"> became
# <button class="btn-reset icon-search text-white text-[1.625rem]">, `.btn-reset` declared
# `color: inherit` and `font: inherit`, and the icon painted black at 18px instead of white at
# 26px. No colour or size value was edited, the diff read as an accessibility fix, and the client
# found the regression.
#
# Two layers have to carry it: the a11y agent, which is what performs the swap, and the CSS
# skill, which is where the specificity rule lives. Neither is sufficient alone — the agent
# without the measurement ships the regression, and the skill without the agent is never read at
# the moment the tag changes.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

a11y=agents/wp-audit-a11y.md
css=skills/wp-css-system/SKILL.md
for f in "$a11y" "$css"; do
  [ -f "$f" ] || { echo "FAIL: $f is missing"; exit 1; }
done
flata=$(tr '\n' ' ' < "$a11y" | sed 's/  */ /g')
flatc=$(tr '\n' ' ' < "$css" | sed 's/  */ /g')

# 1. The agent's fix phase must state that a tag swap is a visual change, and mandate it.
grep -Fq 'A tag swap is a visual change' "$a11y" \
  || { echo "FAIL: $a11y Step 8 does not state that a tag swap is a visual change"; exit 1; }
printf '%s' "$flata" | grep -Fq 'MANDATORY' \
  || { echo "FAIL: the tag-swap measurement in $a11y is not mandatory, so it is the first thing skipped"; exit 1; }
# The specific measurements. A rule that says "check it looks right" is not a measurement.
for needle in 'getComputedStyle(el)' 'getBoundingClientRect()' 'fontSize' 'borderRadius'; do
  printf '%s' "$flata" | grep -Fq "$needle" \
    || { echo "FAIL: $a11y does not require $needle in the before/after comparison"; exit 1; }
done
# Before AND after. Measuring only afterwards has nothing to compare against.
printf '%s' "$flata" | grep -Fq 'before and after' \
  || { echo "FAIL: $a11y does not require the measurement on BOTH sides of the change"; exit 1; }
# A mismatch is a regression, not a trade-off to explain in the report.
printf '%s' "$flata" | grep -Fq 'is a regression to fix before the work is reported' \
  || { echo "FAIL: $a11y treats a changed computed value as acceptable — a difference has to block the fix"; exit 1; }
# Scope: every element sharing the class, and both viewports.
printf '%s' "$flata" | grep -Fq 'every element that shares the class' \
  || { echo "FAIL: $a11y measures only the element in hand — a reset class reaches every element already carrying it"; exit 1; }
printf '%s' "$flata" | grep -Fq 'desktop and mobile' \
  || { echo "FAIL: $a11y does not require both viewports"; exit 1; }
# And why the page-level screenshot gate does not cover this.
printf '%s' "$flata" | grep -Fq 'is not this measurement' \
  || { echo "FAIL: $a11y does not say why a screenshot diff cannot see this — a 26px icon becoming 18px in a flex row moves nothing else"; exit 1; }

# 2. The CSS skill must carry the specificity reason, or the rule reads as superstition.
grep -Fq 'A reset class loses to nothing and wins on source order' "$css" \
  || { echo "FAIL: $css does not explain why a reset class beats the utilities already on the element"; exit 1; }
printf '%s' "$flatc" | grep -Fq 'source order' \
  || { echo "FAIL: $css does not name source order as what decides the tie"; exit 1; }
printf '%s' "$flatc" | grep -Fq ':where(.btn-reset)' \
  || { echo "FAIL: $css offers no weightless form of the reset class"; exit 1; }
# The rule list shows both declarations applying, which is what makes this invisible in DevTools.
printf '%s' "$flatc" | grep -Fq 'both declarations show as applying' \
  || { echo "FAIL: $css does not warn that the DevTools rule list shows nothing wrong in this case"; exit 1; }

echo "PASS: a tag swap is measured before and after, and the specificity reason is written down where the CSS rules live"
