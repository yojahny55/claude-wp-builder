#!/usr/bin/env bash
# The demo is what the client approved. Motion that does not survive conversion means the
# shipped site is not the thing that was signed off, and nothing errors when it happens:
# the page simply sits still. Each assertion below closes one way an attribute gets lost.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

t=agents/wp-template.md
c=agents/wp-css.md
w=agents/wp-tailwind.md
s=commands/wp-section.md
f=commands/wp-finalize.md

grep -Fq 'data-motion' "$t" || fail "$t does not carry data-motion-* attributes into template parts"
grep -Eqi 'verbatim|unchanged|as-is' "$t" \
  || fail "$t does not say the attributes are copied verbatim"
grep -Eqi 'not (an )?ACF field|never .* field' "$t" \
  || fail "$t does not forbid turning a motion attribute into an editable field"

grep -Fq -- '--motion-p' "$c" || fail "$c does not preserve rules referencing --motion-p"
grep -Fq -- '--motion-p' "$w" || fail "$w does not preserve rules referencing --motion-p"

grep -Fq 'data-motion' "$s" || fail "$s does not assert the attributes survived conversion"
grep -Eqi 'demo mode' "$s" || fail "$s does not branch on the recorded demo mode"

grep -Fq '/wp-demo-verify' "$f" || fail "$f does not run /wp-demo-verify in craft mode"
grep -Eqi 'dead scroll|overflow' "$f" || fail "$f does not fail on the verify findings"

echo PASS
