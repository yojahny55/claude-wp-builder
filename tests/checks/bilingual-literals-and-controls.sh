#!/usr/bin/env bash
# The two halves of "the demo's text is not finished text": every user-visible literal is a
# translation key, and a transcribed control's options come from real data or the control goes.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Flatten before matching multi-word prose: a line wrap inside one of these phrases
# would silently break the plain grep, the exact failure mode the sibling checks
# (wp-research.sh, design-value-transfer.sh, wp-tailwind-migrate.sh) already guard against.
flat() { tr '\n' ' ' | sed -e 's/  */ /g'; }

t_file=agents/wp-template.md
[ -f "$t_file" ] || { echo "FAIL: $t_file missing"; exit 1; }
t=$(flat < "$t_file")

grep -q 'Static translated strings' <<<"$t" || { echo "FAIL: wp-template lost the static-strings section"; exit 1; }
for token in 'aria-label' 'placeholder' 'Empty and error states' 'sprintf'; do
  grep -qi "$token" <<<"$t" || { echo "FAIL: wp-template does not name $token as a translated literal"; exit 1; }
done
grep -qi 'Never write a user-visible literal' <<<"$t" || { echo "FAIL: wp-template rules do not forbid user-visible literals"; exit 1; }

grep -qi 'control the data cannot answer\|control the demo drew' <<<"$t" || { echo "FAIL: wp-template has no data-backed-control rule"; exit 1; }
grep -qi 'get_terms()' <<<"$t" || { echo "FAIL: wp-template does not name the real option source"; exit 1; }

s=commands/wp-section.md
[ -f "$s" ] || { echo "FAIL: $s missing"; exit 1; }
st=$(flat < "$s")
grep -qi "never a control's option set" <<<"$st" || { echo "FAIL: transcription overlay has no option-set carve-out"; exit 1; }
grep -qi 'empties the grid' <<<"$st" || { echo "FAIL: overlay does not state the failure it prevents"; exit 1; }

echo PASS
