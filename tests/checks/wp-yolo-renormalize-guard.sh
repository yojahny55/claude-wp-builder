#!/usr/bin/env bash
# The worst defect shape this repo has: a build that completes, reports success, and ships
# degraded output.
#
# wp-normalize derives cssRules, fonts and backgrounds from the declarations and @font-face
# rules in the demo's markup. Step 2.6's Tailwind conversion removes both -- it strips the
# <style> blocks and the project stylesheet <link> whose rules it absorbed. So a second
# /wp-yolo over a converted demo normalized markup that no longer held any of it and wrote
# an emptied manifest. Step 2.6 then correctly skipped the pages as already-native, and
# Step 4.5's font carry plus /wp-finalize's Layer 1 parity gate read the gutted manifest
# and passed over nothing. No error anywhere, and the theme ships with no carried fonts.
#
# The command documented the workaround -- restore demo/.original/ first -- three steps
# away, in Step 3's abort branch, which is a workaround nobody applies. Step 2 refuses now.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-yolo.md
[ -f "$f" ] || fail "$f is missing"
need() { grep -Fq "$1" "$f" || fail "$f $2"; }

# The guard exists, and runs BEFORE normalize is dispatched. Ordering is the entire point:
# Step 2.6 already had the evidence test and could not act on it, because Step 2 had
# already run by then.
need 'refuse to normalize a demo that has already been converted' \
  'Step 2 does not refuse an already-converted demo'
grep -n 'refuse to normalize a demo that has already been converted' "$f" >/dev/null
guard_line=$(grep -n 'refuse to normalize a demo that has already been converted' "$f" | head -1 | cut -d: -f1)
dispatch_line=$(grep -n 'dispatch the \*\*wp-normalize\*\* agent' "$f" | head -1 | cut -d: -f1)
[ -n "$dispatch_line" ] || fail "$f no longer dispatches wp-normalize where this check expects it"
[ "$guard_line" -lt "$dispatch_line" ] \
  || fail "$f states the guard at line $guard_line, AFTER the normalize dispatch at $dispatch_line -- a guard that runs after the thing it guards is not a guard"

# Silence is the defect. If the prose stops saying the failure is silent, the next reader
# reads this guard as belt-and-braces over something that would have errored anyway, and
# the first "simplification" removes it.
need 'Nothing fails' 'does not say the degradation is silent -- which is the reason the guard exists at all'
need 'reports success' 'does not say the degraded build still reports success'

# The signal, and the way out. A refusal that does not say how to proceed is a dead end.
need 'demo/.original/' 'does not name the signal that a conversion has run'
need 'cp demo/.original/*.html demo/' 'does not give the restore command in the refusal'

# --force discards the THEME. It says nothing about the demo, and letting it through here
# would rebuild from converted markup into exactly the degraded output above -- with the
# operator believing they had chosen it.
need '`--force` does not bypass this' \
  'does not state that --force cannot bypass the guard -- --force answers a different question and would produce the silent degradation with the operator believing they chose it'

# The plain path never converts, so the guard must be known not to fire there; otherwise
# someone reads it as a blanket second-run refusal and re-litigates it.
need 'On the plain path nothing converts' 'does not scope the guard to the tailwind path'

# The two evidence tests must stay distinguishable, or one gets deleted as a duplicate.
need 'The two tests are not redundant' \
  'does not distinguish the Step 2 guard from Step 2.6 per-page skip -- one will be removed as a duplicate of the other'

echo "PASS: Step 2 refuses an already-converted demo, before normalize and regardless of --force"
