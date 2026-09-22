#!/usr/bin/env bash
# Target size: the a11y audit failed anything under 44x44 read from CSS, which is WCAG 2.5.5
# (AAA), while the AA criterion (2.2, 2.5.8) is 24x24. On a real build the nav items, footer
# social icons and the breadcrumb home link measured under 24 and were never flagged as the
# AA failure they were, while 44px advice drowned the report. 24x24 is the failing
# threshold, measured in a browser at desktop and mobile; 44x44 is advice. The fix grows the
# hit area with padding plus an equal negative margin, so the text does not move.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

a=agents/wp-audit-a11y.md
grep -Fq '| A11Y-028 | Target smaller than 24x24 |' "$a" || fail "$a A11Y-028 does not fail at 24x24"
grep -Fq 'Below **24x24 CSS px fails** (WCAG 2.2 AA 2.5.8)' "$a" || fail "$a does not name 2.5.8 as the failing threshold"
grep -Fq 'desktop (1440) **and** mobile (390)' "$a" || fail "$a does not measure at desktop and mobile"
grep -Fq 'report it as INFO advice, never as a finding' "$a" || fail "$a still treats 44x44 as a finding"
grep -Fq 'min 44x44px | WARNING' "$a" && fail "$a still fails targets under 44x44"
grep -Fq '| Touch target size | 24x24 CSS pixels fails' skills/wp-audit-standards/SKILL.md \
  || fail "wp-audit-standards still sets 44x44 as the threshold"
grep -Fq 'below 24×24 fails per WCAG 2.5.8' skills/wp-audit-ux-standards/SKILL.md \
  || fail "UX-009 does not use the 24x24 threshold"
grep -Fq 'equal negative margin' skills/wp-responsive/SKILL.md || fail "wp-responsive lacks the no-move fix"

# The generators of the three measured offenders.
grep -Fq 'renders at least 24x24 at desktop and mobile' commands/wp-header.md || fail "/wp-header nav items have no 24x24 rule"
grep -Fq 'renders at least 24x24 at desktop and mobile' commands/wp-footer.md || fail "/wp-footer social icons have no 24x24 rule"
for f in agents/wp-audit-rankmath.md skills/wp-audit-seo-standards/SKILL.md; do
  grep -Fq 'margin: -4px;' "$f" || fail "$f breadcrumb links do not reach 24x24"
done

echo PASS
