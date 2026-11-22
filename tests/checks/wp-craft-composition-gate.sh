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
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1


require_tool npx python3

# The real detector needs the npm cache or the network. Where it cannot be fetched this check
# measures nothing, so it SKIPs; any other probe failure (the detector broke, changed format
# or flag) is a FAIL. CHECKS_REQUIRE_TOOLS=1 turns even the offline SKIP into a FAIL.
# "Responded" means parseable JSON of any shape, the same bar bin/composition-gate.sh sets.
probe_dir="$(mktemp -d)"
trap 'rm -rf "$probe_dir"' EXIT
printf '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>p</title></head><body><p>probe</p></body></html>\n' > "$probe_dir/p.html"
npx -y impeccable@latest detect "$probe_dir" --json > "$probe_dir/out.json" 2> "$probe_dir/err.txt" || true
if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$probe_dir/out.json" 2>/dev/null; then
  if [ "$(grep -ciE 'ENOTFOUND|EAI_AGAIN|ETIMEDOUT|ECONNREFUSED|ENETUNREACH|ECONNRESET|network|FetchError|EACCES|EROFS' "$probe_dir/err.txt" || true)" -gt 0 ]; then
    [ "${CHECKS_REQUIRE_TOOLS:-0}" = 1 ] && fail "CHECKS_REQUIRE_TOOLS=1 and the impeccable detector cannot be fetched: $(head -c 300 "$probe_dir/err.txt")"
    skip "impeccable detector not reachable (no usable npm cache or network); gate not exercised"
  fi
  fail "the impeccable detector started badly and it is not a network problem: $(head -c 300 "$probe_dir/err.txt")"
fi

[ -x bin/composition-gate.sh ] || fail "bin/composition-gate.sh is missing or not executable"

if ! out="$(bash bin/composition-gate.sh 2>&1)"; then
  fail "composition gate rejected the library: $out"
fi

# The gate must have scanned something. A green result over zero files is the
# defect this check exists to close, not a pass.
echo "$out" | grep >/dev/null -Ec 'assembled ([1-9][0-9]*) compositions' \
  || fail "composition gate did not report how many compositions it assembled"

n="$(echo "$out" | sed -n 's/.*assembled \([0-9]*\) compositions.*/\1/p' | sed -n 1p)"
[ "${n:-0}" -ge 13 ] \
  || fail "composition gate assembled only ${n:-0} compositions, expected at least 13"

# --- negative controls -------------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work" "$probe_dir"' EXIT

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

# 3. A detector payload the gate does not understand — parseable JSON with no
#    findings list. The old fallback left `findings` bound to the dict and the
#    filter below it raised AttributeError: an unhandled Python traceback in
#    place of a verdict. It must be a deliberate "could not scan" (rc 1), not a
#    traceback and not a vacuous zero-findings pass. A stub `npx` earlier on
#    PATH is what produces the payload, so the real gate runs unmodified.
mkdir -p "$work/fakebin"
cat > "$work/fakebin/npx" <<'SH'
#!/usr/bin/env bash
echo '{"ok": true}'
SH
chmod +x "$work/fakebin/npx"
rc=0
PATH="$work/fakebin:$PATH" COMPS_DIR="$work/slop" bash bin/composition-gate.sh \
  >"$work/shape.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] \
  || fail "the composition gate returned rc=$rc on a detector payload with no findings list, expected 1 (could not scan): $(cat "$work/shape.out")"
if grep -Fq 'Traceback' "$work/shape.out"; then
  fail "the composition gate raised a Python traceback instead of a verdict on a detector payload with no findings list: $(cat "$work/shape.out")"
fi
grep -Fq 'carries no findings list' "$work/shape.out" \
  || fail "the composition gate exited 1 on an uninterpretable detector payload without saying that is why, so it is indistinguishable from any other failure"

# 3b. Detector output the gate does not understand: an unknown severity or category, a field
#     missing or of the wrong type, an element that is not an object, a wrapper object with
#     keys besides "findings", an exit code other than 0/2, or an exit code that disagrees
#     with the payload. Every one must be rc 1 with "not understood" or "could not scan",
#     never a pass and never a traceback. Case format: name|detector exit|payload.
W='"antipattern":"x","file":"/x/slop-probe.html"'
for case in \
  "sev|0|[{$W,\"category\":\"slop\",\"severity\":\"error\"}]" \
  "cat|0|[{$W,\"category\":\"style\",\"severity\":\"advisory\"}]" \
  "sevlist|0|[{$W,\"category\":\"slop\",\"severity\":[\"warning\"]}]" \
  "nofile|2|[{\"antipattern\":\"x\",\"category\":\"slop\",\"severity\":\"warning\"}]" \
  'nonobj|0|["x"]' \
  'extrakey|0|{"findings":[],"error":"crashed"}' \
  'crash|3|[]' \
  "rc0warn|0|[{$W,\"category\":\"quality\",\"severity\":\"warning\"}]" \
  'rc2empty|2|[]'; do
  name=${case%%|*}; rest=${case#*|}; drc=${rest%%|*}; payload=${rest#*|}
  printf '#!/usr/bin/env bash\necho %q\nexit %d\n' "$payload" "$drc" > "$work/fakebin/npx"
  rc=0
  PATH="$work/fakebin:$PATH" COMPS_DIR="$work/slop" bash bin/composition-gate.sh \
    >"$work/$name.out" 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "the composition gate returned rc=$rc on the '$name' detector output, expected 1: $(cat "$work/$name.out")"
  if grep -Fq 'Traceback' "$work/$name.out"; then fail "the composition gate raised a traceback on the '$name' output: $(cat "$work/$name.out")"; fi
  [ "$(grep -Ec 'not understood|could not scan' "$work/$name.out")" -gt 0 ] \
    || fail "the composition gate exited 1 on the '$name' output without saying it was not understood: $(cat "$work/$name.out")"
done

# An empty detector payload is a dropped connection, not a verdict: the gate retries once.
grep -Eq 'for attempt in 1 2' bin/composition-gate.sh \
  || fail "bin/composition-gate.sh no longer retries the detector on an empty payload (a transient npx failure fails the gate)"

# 4. A rule ignored per composition must stay ignored only there. The stub detector reports
#    kicker-above-heading twice — once in a composition IGNORED_AT names, once in slop-probe,
#    which it does not — and the gate must block on slop-probe alone. A filter keyed on the
#    rule name (the first draft of this exclusion) passes both and turns this red.
cat > "$work/fakebin/npx" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
[{"antipattern":"kicker-above-heading","category":"slop","severity":"warning","file":"/x/proof-row.html"},
 {"antipattern":"kicker-above-heading","category":"slop","severity":"warning","file":"/x/slop-probe.html"}]
JSON
exit 2
SH
rc=0
PATH="$work/fakebin:$PATH" COMPS_DIR="$work/slop" bash bin/composition-gate.sh \
  >"$work/scoped.out" 2>&1 || rc=$?
[ "$rc" -eq 2 ] \
  || fail "the composition gate let kicker-above-heading through in a composition IGNORED_AT does not name (rc=$rc, expected 2): $(cat "$work/scoped.out")"
grep -Fq 'slop-probe fails the slop gate: kicker-above-heading' "$work/scoped.out" \
  || fail "the composition gate did not name slop-probe for kicker-above-heading: $(cat "$work/scoped.out")"
if grep -Fq 'proof-row fails' "$work/scoped.out"; then
  fail "the composition gate blocked proof-row on kicker-above-heading, which IGNORED_AT exempts there: $(cat "$work/scoped.out")"
fi

# The detector follows the newest release on purpose, so a new release is picked up without a PR.
# A pinned version would freeze the rules instead of answering them.
grep -Fq 'impeccable@latest detect' bin/composition-gate.sh \
  || fail "bin/composition-gate.sh no longer follows the newest impeccable release (pinned to a version)"
# Ignoring a rule is a debt with a named exit, not a place to park findings. Growing the list
# needs this line changed too, which makes the decision visible in review.
ign=$(grep -E '^IGNORED = ' bin/composition-gate.sh || true)
[ "$ign" = 'IGNORED = {"hero-eyebrow-chip"}' ] \
  || fail "the gate's IGNORED rules changed ($ign) — each entry needs its reason in the gate and this check updated"
grep -Eq '^    "kicker-above-heading": \{$' bin/composition-gate.sh \
  || fail "kicker-above-heading is no longer scoped per composition in IGNORED_AT — a global ignore hides it in new compositions too"

echo PASS
