#!/usr/bin/env bash
# The two halves of "the demo's text is not finished text": every user-visible literal is a
# translation key, and a transcribed control's options come from real data or the control goes.
set -euo pipefail
t=agents/wp-template.md

grep -q 'Static translated strings' "$t" || { echo "FAIL: wp-template lost the static-strings section"; exit 1; }
for token in 'aria-label' 'placeholder' 'Empty and error states' 'sprintf'; do
  grep -qi "$token" "$t" || { echo "FAIL: wp-template does not name $token as a translated literal"; exit 1; }
done
grep -qi 'Never write a user-visible literal' "$t" || { echo "FAIL: wp-template rules do not forbid user-visible literals"; exit 1; }

grep -qi 'control the data cannot answer\|control the demo drew' "$t" || { echo "FAIL: wp-template has no data-backed-control rule"; exit 1; }
grep -qi 'get_terms()' "$t" || { echo "FAIL: wp-template does not name the real option source"; exit 1; }

s=commands/wp-section.md
grep -qi "never a control's option set" "$s" || { echo "FAIL: transcription overlay has no option-set carve-out"; exit 1; }
grep -qi 'empties the grid' "$s" || { echo "FAIL: overlay does not state the failure it prevents"; exit 1; }

echo PASS
