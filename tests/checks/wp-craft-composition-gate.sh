#!/usr/bin/env bash
# The library must pass the gate it asks builds to pass. Two compositions once
# shipped infinite loop animations that the detector reports as `marquee` at
# category=slop severity=warning — the shape that fails a round before a
# screenshot is taken — so every build using the closing or proof role failed by
# construction. This runs the real gate rather than grepping for its wording.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x bin/composition-gate.sh ] || fail "bin/composition-gate.sh is missing or not executable"

if ! out="$(bash bin/composition-gate.sh 2>&1)"; then
  fail "composition gate rejected the library: $out"
fi

# The gate must have scanned something. A green result over zero files is the
# defect this check exists to close, not a pass.
echo "$out" | grep -Eq 'assembled ([1-9][0-9]*) compositions' \
  || fail "composition gate did not report how many compositions it assembled"

n="$(echo "$out" | sed -n 's/.*assembled \([0-9]*\) compositions.*/\1/p' | head -1)"
[ "${n:-0}" -ge 13 ] \
  || fail "composition gate assembled only ${n:-0} compositions, expected at least 13"

echo PASS
