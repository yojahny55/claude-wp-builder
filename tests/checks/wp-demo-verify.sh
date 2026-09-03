#!/usr/bin/env bash
# A scroll page has no single state: every scroll position is a different frame and the
# failures live between the two anyone happened to look at. This check pins the contract
# that makes the walk trustworthy, including the part a green run cannot cover, which is
# why "read the sheet" is asserted as hard as the machine findings.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-demo-verify.md
s=bin/demo-verify.mjs
r=commands/wp-responsive-check.md

[ -f "$c" ] || fail "$c is missing"
[ -f "$s" ] || fail "$s is missing"
[ -x "$s" ] || fail "$s is not executable"

awk 'NR<=8 && /^argument-hint:/ { f = 1 } END { exit !f }' "$c" || fail "$c has no argument-hint"
awk 'NR<=8 && /^allowed-tools:/ { f = 1 } END { exit !f }' "$c" || fail "$c has no allowed-tools"

# --- It must accept a live URL, or it can never verify the converted theme. --
grep -Eqi 'url' "$c" || fail "$c does not accept a URL as well as a file path"

# --- The walk. Uniform sampling moves every position when any section resizes,
#     so findings would appear and vanish with unrelated edits.
grep -Eqi 'per section|positions per' "$c" || fail "$c does not sample per section"
grep -Fq '390' "$c" || fail "$c does not walk a phone width"
grep -Fq '1440' "$c" || fail "$c does not walk a desktop width"
grep -Eqi 'reduced.motion' "$c" || fail "$c does not run a reduced-motion pass"

# --- Responsive coverage moved here, so the old viewports must still be walked.
for v in 375 576 768 1024; do
  grep -Fq "$v" "$c" || fail "$c dropped the $v viewport that /wp-responsive-check covered"
done

# --- The findings the machine can actually make. ----------------------------
grep -Eqi 'dead scroll' "$c" || fail "$c does not report dead scroll"
grep -Eqi 'overflow' "$c" || fail "$c does not report horizontal overflow"
grep -Eqi 'never reach|never peak' "$c" || fail "$c does not report cues that never reach full opacity"

# --- The half a machine cannot do. ------------------------------------------
grep -Fq 'sheet.png' "$c" || fail "$c does not produce a contact sheet"
grep -Eqi 'feel check' "$c" || fail "$c does not require the feel check"
grep -Eqi 'not a pass' "$c" || fail "$c does not state that a green run alone is not a pass"

# --- Fallbacks, in order, so a machine without Chrome still gets a review. ---
grep -Eqi 'exit code 2|exits 2' "$c" || fail "$c does not document the no-browser exit code"
grep -Eqi 'playwright|chrome' "$c" || fail "$c does not name the browser fallback ladder"

# --- The script's own contract. ---------------------------------------------
grep -Fq 'playwright-core' "$s" || fail "$s does not use playwright-core"
grep -Fq -- '--motion-p' "$s" || fail "$s does not read --motion-p when detecting dead scroll"
grep -Fq 'process.exit(2)' "$s" || fail "$s does not exit 2 when no browser is available"
node --check "$s" || fail "$s is not valid JavaScript"

# --- The five legacy viewports must be IMPLEMENTED, not just promised in prose.
#     A grep-gate that only greps the markdown proves the promise was written,
#     not that it was kept: this asserts the script itself writes the shots.
grep -Fq 'responsive-' "$s" || fail "$s does not write responsive-<width>.png files"
grep -Fq 'fullPage: true' "$s" || fail "$s does not take a full-page screenshot"
for v in 375 576 768 1024 1440; do
  grep -Fq "$v" "$s" || fail "$s does not implement the $v viewport (docs promise it, code must too)"
done

# --- The alias. The old command keeps working or every existing doc breaks. --
grep -Fq '/wp-demo-verify' "$r" || fail "$r does not dispatch to /wp-demo-verify"

echo PASS
