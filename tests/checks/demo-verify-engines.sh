#!/usr/bin/env bash
# Verification was Chromium-only: bin/demo-verify.mjs shot seven widths in one engine, so a
# layout that broke in Firefox, or in the 576-768 and 1024-1152 bands between its edges,
# reached the client unseen. It now shoots nine widths (620 and 1100 added) in Chromium and,
# when a Playwright Firefox build already exists, in Firefox too, and reports each layout box
# that differs by more than 2px between the engines. Nothing is ever downloaded.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=bin/demo-verify.mjs
grep -Fq 'const RESPONSIVE_WIDTHS = [375, 576, 620, 768, 1024, 1100, 1152, 1280, 1440];' "$s" \
  || fail "$s does not shoot the nine widths (620 and 1100 included)"
grep -Fq "findBrowser('firefox')" "$s" || fail "$s does not resolve an existing Firefox"
grep -Fq "captureResponsiveShots(ffBrowser, pageUrl, join(pageOut, 'firefox'))" "$s" || fail "$s takes no Firefox screenshots"
grep -Fq 'const ENGINE_DELTA_PX = 2;' "$s" || fail "$s does not report engine deltas over 2px"
grep -Fq "'engine-delta'" "$s" || fail "$s has no engine-delta finding"
grep -Fq -- '--no-firefox' "$s" || fail "$s cannot skip the Firefox pass"
grep -Fq 'nothing is downloaded' "$s" || fail "$s does not say a missing Firefox is a skip, not a download"

# Docs tell the truth about the widths.
grep -Fq '375, 576, 620, 768, 1024, 1100, 1152, 1280 and 1440' commands/wp-demo-verify.md \
  || fail "commands/wp-demo-verify.md lists other widths than the script shoots"
grep -Fq 'screenshots at 9 viewports' commands/wp-responsive-check.md || fail "wp-responsive-check still claims 7 viewports"
grep -Fq '7 viewports' README.md commands/wp-responsive-check.md && fail "a doc still says 7 viewports"
grep -Fq 'Firefox pass' commands/wp-demo-verify.md || fail "commands/wp-demo-verify.md does not document the Firefox pass"

# Runtime, when this machine can: the Firefox shots land beside Chromium's.
command -v node >/dev/null || { echo "PASS (static only: no node)"; exit 0; }
if ! probe=$(node "$s" --probe 2>&1) || ! grep -q '(firefox ' <<<"$probe"; then
  echo "PASS (static only: no playwright-core, Chromium or Firefox build here -- $probe)"
  exit 0
fi
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
node "$s" tests/fixtures/engine-delta/index.html --positions 2 --widths 1440x900 --out "$work" >/dev/null 2>&1 || true
for w in 620 1100; do
  [ -f "$work/responsive-$w.png" ] || fail "$s wrote no Chromium responsive-$w.png"
  [ -f "$work/firefox/responsive-$w.png" ] || fail "$s wrote no Firefox responsive-$w.png"
done
node -e 'const r=require(process.argv[1]); if(!r.firefox) process.exit(1)' "$work/findings.json" \
  || fail "$s ran without Firefox although the probe found one"

echo PASS
