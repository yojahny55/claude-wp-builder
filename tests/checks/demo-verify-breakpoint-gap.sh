#!/usr/bin/env bash
# Page builders emit breakpoints as integer pairs: max-width:767px for mobile, min-width:768px
# for everything above. At a fractional CSS width (browser zoom, or OS display scaling other
# than 100%: a 766px window at 110% is 767.27px wide) neither query matches. On a real build
# that gave a 704px logo instead of 112px, columns with no width, and a carousel hidden on
# every device showing 119px headings. /wp-demo-verify only shot integer widths, so it could
# never see it. It must now load the page inside each max-width:N / min-width:N+1 gap, report
# a blocking `breakpoint-gap`, and stay silent when the pair has no gap.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=bin/demo-verify.mjs
. tests/checks/lib/expand-command.sh; expand_command commands/wp-demo-verify.md; c=$EXPANDED
r=skills/wp-responsive/SKILL.md
fx=tests/fixtures/breakpoint-gap

grep -Fq -- '--no-gaps' "$s" || fail "$s does not parse --no-gaps"
grep -Fq 'breakpoint-gap' "$s" || fail "$s never reports breakpoint-gap"
grep -Fq -- '--no-gaps' "$c" || fail "$c does not document --no-gaps"
grep -Fq 'breakpoint-gap' "$c" || fail "$c does not list the breakpoint-gap finding"
grep -Fq '767.98px' "$r" || fail "$r does not teach the fractional-safe max-width"

[ -f "$fx/index.html" ] || fail "$fx/index.html (the gapped pair) is missing"
[ -f "$fx/fixed.html" ] || fail "$fx/fixed.html (the gap-free pair) is missing"
grep -Fq 'max-width:767.98px' "$fx/fixed.html" || fail "$fx/fixed.html no longer closes the gap"

if probe=$(node "$s" --probe 2>&1); then
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  # Keep the run's output: when it crashes, the failure has to say why.
  node "$s" "$fx" --positions 2 --widths 1280x800 --no-firefox --out "$work/g" >"$work/g.log" 2>&1 || true
  [ -f "$work/g/findings.json" ] || fail "$s produced no findings.json for $fx: $(tail -5 "$work/g.log")"
  verdict="$(node -e '
    let r;
    try { r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("findings.json is not valid JSON: " + e.message); process.exit(); }
    const page = (n) => r.pages.find((p) => p.url.endsWith("/" + n));
    const missing = ["index.html", "fixed.html"].filter((n) => !page(n));
    if (missing.length) { console.log("no findings for " + missing.join(", ")); process.exit(); }
    const gaps = (n) => page(n).findings.filter((f) => f.kind === "breakpoint-gap");
    const bad = gaps("index.html");
    if (bad.length !== 1 || bad[0].width !== 767) { console.log("gap at 767 not reported: " + JSON.stringify(bad)); process.exit(); }
    if (!(bad[0].viewport > 767 && bad[0].viewport < 768)) { console.log("not measured inside the gap: " + bad[0].viewport); process.exit(); }
    const sel = (bad[0].culprits || []).map((x) => x.selector);
    if (!sel.includes("div.logo") || !sel.includes("div.only-gap")) { console.log("culprits not named: " + JSON.stringify(bad[0].culprits)); process.exit(); }
    if (gaps("fixed.html").length) { console.log("gap-free pair still reported"); process.exit(); }
    console.log("OK");
  ' "$work/g/findings.json")"
  [ "$verdict" = "OK" ] || fail "$s on $fx: $verdict"
  [ -f "$work/g/index/gap-767.png" ] && [ -f "$work/g/index/gap-767.jpg" ] || fail "gap-767 shots were not written"
  # --no-gaps skips the pass
  node "$s" "$fx/index.html" --positions 2 --widths 1280x800 --no-firefox --no-gaps --out "$work/n" >"$work/n.log" 2>&1 || true
  # Without this, a run that wrote nothing makes grep exit 2 and the negation reads it as a pass.
  [ -f "$work/n/findings.json" ] || fail "--no-gaps run produced no findings.json: $(tail -5 "$work/n.log")"
  ! grep -Fq breakpoint-gap "$work/n/findings.json" || fail "--no-gaps still ran the fractional pass"
else
  echo "SKIP: no usable browser; the breakpoint-gap battery did not run -- $(tr '\n' ' ' <<<"$probe")"
fi

echo PASS
