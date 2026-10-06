#!/usr/bin/env bash
set -euo pipefail
# `q "$text" <grep flags> <pattern>`: a here-string, never `printf | grep -q`. Under
# pipefail an early-exiting `grep -q` hands printf a SIGPIPE and the pipeline returns 141,
# which silently flips an assertion either way.
q() { local s=$1; shift; grep -q "$@" <<<"$s"; }
f=agents/wp-css.md
grep -qi 'Transcription Mode' "$f" || { echo "FAIL: no Transcription Mode section"; exit 1; }
for token in 'source of truth' 'exact' 'background:url' '@font-face' 'assigned' 'block'; do
  grep -qi "$token" "$f" || { echo "FAIL: transcription section missing '$token'"; exit 1; }
done
# Must forbid the specific 'improvements' that changed measured output.
grep -qi 'min-height' "$f" || { echo "FAIL: does not call out the 44px touch-target trap"; exit 1; }
# The skill's own "never hardcode" rule must carry the same exception. It used to be
# unconditional, so a reader of wp-css-system alone got the rule the agent is told to break
# on the transcription path.
s=skills/wp-css-system/SKILL.md
p4=$(grep -E '^4\. \*\*All values use custom properties\*\*' "$s" || true)
[ -n "$p4" ] || { echo "FAIL: $s lost Principle 4 (all values use custom properties)"; exit 1; }
q "$p4" -i 'transcription' \
  || { echo "FAIL: $s Principle 4 forbids hardcoded values with no transcription-mode exception, contradicting agents/wp-css.md"; exit 1; }
echo PASS
