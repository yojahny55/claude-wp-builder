#!/usr/bin/env bash
set -euo pipefail
f=agents/wp-css.md
grep -qi 'Transcription Mode' "$f" || { echo "FAIL: no Transcription Mode section"; exit 1; }
for token in 'source of truth' 'exact' 'background:url' '@font-face' 'assigned' 'block'; do
  grep -qi "$token" "$f" || { echo "FAIL: transcription section missing '$token'"; exit 1; }
done
# Must forbid the specific 'improvements' that changed measured output.
grep -qi 'min-height' "$f" || { echo "FAIL: does not call out the 44px touch-target trap"; exit 1; }
echo PASS
