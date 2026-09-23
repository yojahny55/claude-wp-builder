#!/usr/bin/env bash
# A horizontal-overflow finding said only `overflow: true`. On a real build the box
# stretching the document was a 1px screen-reader span inside a carousel card: it was
# position:absolute, its containing block sat outside the carousel's overflow-x:auto
# strip, so the strip never clipped it, and every off-screen card's span widened the
# page at every width. Invisible in every screenshot, so the finding sent the reader
# hunting. The finding must name the boxes that stick out and, for this case, the
# clipping box they escaped -- and must stay silent once the cards are positioned.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=bin/demo-verify.mjs
c=commands/wp-demo-verify.md
fx=tests/fixtures/overflow-escape

grep -Fq 'culprits' "$s" || fail "$s does not name the boxes behind an overflow finding"
grep -Fq 'escapes' "$s" || fail "$s does not name the clipping box an absolute culprit got past"
grep -Fq 'overflowSeen' "$s" || fail "$s reports the same overflow once per sampled position instead of once per width"
grep -Fq 'culprits' "$c" || fail "$c does not tell the reader where the overflow finding names its culprits"
grep -Fq 'escapes' "$c" || fail "$c does not explain the escapes field or its fix"

[ -f "$fx/index.html" ] || fail "$fx/index.html (the escaping strip) is missing"
[ -f "$fx/contained.html" ] || fail "$fx/contained.html (the fixed strip) is missing"
grep -Fq 'position: relative; min-height' "$fx/contained.html" \
  || fail "$fx/contained.html no longer differs from index.html by the positioned card"

if probe=$(node "$s" --probe 2>&1); then
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  node "$s" "$fx" --positions 2 --widths 1280x800 --no-firefox --out "$work/ov" >/dev/null 2>&1 || true
  [ -f "$work/ov/findings.json" ] || fail "$s produced no findings.json for $fx"
  verdict="$(node -e '
    const r = require(process.argv[1]);
    const page = (n) => r.pages.find((p) => p.url.endsWith("/" + n));
    const missing = ["index.html", "contained.html"].filter((n) => !page(n));
    if (missing.length) { console.log("no findings for " + missing.join(", ")); process.exit(); }
    const ov = (n) => page(n).findings.filter((f) => f.kind === "overflow");
    const bad = ov("index.html");
    if (!bad.length) { console.log("escaping strip not reported"); process.exit(); }
    const c = bad[0].culprits || [];
    if (!c.some((x) => x.selector === "span.sr" && x.escapes === "div.strip")) { console.log("culprit not named: " + JSON.stringify(c)); process.exit(); }
    if (c.some((x) => x.selector.startsWith("li") || x.selector.startsWith("ul"))) { console.log("clipped cards reported as culprits: " + JSON.stringify(c)); process.exit(); }
    if (ov("contained.html").length) { console.log("positioned cards still reported"); process.exit(); }
    console.log("OK");
  ' "$work/ov/findings.json")"
  [ "$verdict" = "OK" ] || fail "$s on $fx: $verdict"
else
  echo "NOTE: no usable browser; the overflow culprit battery did not run -- $(tr '\n' ' ' <<<"$probe")"
fi

echo PASS
