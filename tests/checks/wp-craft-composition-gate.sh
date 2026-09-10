#!/usr/bin/env bash
# The library must pass the gate it asks builds to pass. `closing-block` once ran
# a 7s infinite conic sweep and `proof-row` a 38s infinite translate; the detector
# reports both as `marquee` at category=slop severity=warning — the shape that
# fails a round before a screenshot is taken — so every build using the closing
# or proof role failed by construction. Both were rewritten in the same pass onto
# the library's own anti-perpetual-motion rules, scroll-linked through the view
# timeline instead of running on a loop.
# This runs the real gate rather than grepping for its wording.
#
# And it runs the gate against a synthetic library it must REJECT, because a
# check that only ever watches a gate pass cannot tell a working gate from a
# disabled one: mutating the detector filter ("slop" -> "slopx") or zeroing
# MIN_HTML_BYTES leaves the pass half of this check green.
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

# --- negative controls -------------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. A composition carrying the exact defect the gate exists to catch: an
#    infinite translate the detector calls `marquee`. rc must be 2.
mkdir -p "$work/slop/slop-probe"
cat > "$work/slop/slop-probe/section.html" <<'HTML'
<section class="slop-probe">
  <h2 class="slop-probe__title">Trusted by teams that ship</h2>
  <div class="slop-probe__marquee"><ul class="slop-probe__track">
    <li>Northwind</li><li>Contoso</li><li>Fabrikam</li><li>Tailspin</li>
    <li>Northwind</li><li>Contoso</li><li>Fabrikam</li><li>Tailspin</li>
  </ul></div>
</section>
HTML
cat > "$work/slop/slop-probe/section.css" <<'CSS'
.slop-probe { padding-block: 6rem; padding-inline: max(1.5rem, (100% - var(--container-max, 1280px)) / 2); }
.slop-probe__title { font-family: var(--font-display); font-size: 2rem; margin: 0 0 2rem; }
.slop-probe__marquee { overflow: hidden; }
.slop-probe__track { list-style: none; margin: 0; padding: 0; display: flex; width: max-content; gap: 3.5rem; animation: slop-probe-marquee 38s linear infinite; }
@keyframes slop-probe-marquee { to { transform: translateX(-50%); } }
CSS
rc=0; COMPS_DIR="$work/slop" bash bin/composition-gate.sh >"$work/slop.out" 2>&1 || rc=$?
[ "$rc" -eq 2 ] \
  || fail "the composition gate passed a composition carrying an infinite marquee (rc=$rc, expected 2) — the gate is disabled, not clean: $(cat "$work/slop.out")"
grep -Fq 'slop-probe fails the slop gate' "$work/slop.out" \
  || fail "the composition gate exited 2 but never named the failing composition, so a real failure would be unreadable"

# 2. Truncated content. section.html is empty, section.css is real and large, so
#    the assembled document clears MIN_DOC_BYTES and only MIN_HTML_BYTES stands
#    between a zero-content scan and a green result. rc must be 1.
mkdir -p "$work/thin/thin-probe"
: > "$work/thin/thin-probe/section.html"
cp "$work/slop/slop-probe/section.css" "$work/thin/thin-probe/section.css"
cat "$work/slop/slop-probe/section.css" >> "$work/thin/thin-probe/section.css"
rc=0; COMPS_DIR="$work/thin" bash bin/composition-gate.sh >"$work/thin.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] \
  || fail "the composition gate accepted a 0-byte section.html (rc=$rc, expected 1), so a truncated composition scans as real content"
grep -Fq 'refused near-empty or truncated content' "$work/thin.out" \
  || fail "the composition gate refused truncated content without saying so"

echo PASS
