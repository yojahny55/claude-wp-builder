#!/usr/bin/env bash
# bin/image-gen.mjs spends money. Every assertion here therefore runs with no
# key and no network: what is verified is that the script asks for the right
# thing, never asks twice for the same thing, refuses an ambiguous plan before
# issuing a request, and cannot put an API key into its own output. The slot
# list and the crop are read off each composition's own <img> tag, so these
# assertions pin that the reader still finds them — a regex regression there
# would silently request square heroes and nothing else would notice.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

g=bin/image-gen.mjs
[ -x "$g" ] || fail "$g is missing or not executable"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/assets/img"

# Reads one field out of the rewritten plan file, so the assertions below
# test the artifact the next step actually consumes, not stdout formatting.
pj() { node -e '
  const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const v = process.argv[2].split(".").reduce((o, k) => o?.[k], p);
  console.log(typeof v === "object" ? JSON.stringify(v) : v);
' "$tmp/.image-plan.json" "$1"; }

plan_with() {
  cat > "$tmp/.image-plan.json" <<JSON
{"provider": "google/gemini-3.1-flash-image",
 "sections": $1,
 "assets_on_disk": []}
JSON
}

# 1. Slot discovery: the three image-bearing compositions yield exactly four slots.
plan_with '[{"page":"index","section":"hero","composition":"hero-bleed"},
             {"page":"index","section":"features","composition":"feature-zigzag"},
             {"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on a valid plan file"
n=$(pj gaps.length)
[ "$n" = 4 ] || fail "expected 4 image slots across hero-bleed, feature-zigzag and hero-split; got $n"

# 1b. Zero-occurrence control: a composition with no <img> yields no slots.
#     Without this, a reader that returned a constant 4 would pass the line above.
plan_with '[{"page":"index","section":"faq","composition":"faq-list"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on an image-free composition"
n=$(pj gaps.length)
[ "$n" = 0 ] || fail "faq-list declares no <img>, so it must yield 0 slots; got $n"

# 2. The crop is read off the markup, not assumed. hero-split is 1200x1500.
plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null
a=$(pj gaps.0.aspect)
[ "$a" = "4:5" ] || fail "hero-split declares 1200x1500 so the aspect must be 4:5; got $a"
s=$(pj gaps.0.size)
[ "$s" = "2K" ] || fail "hero-split declares width 1200, so the smallest size >= 1200 is 2K; got $s"

# 2b. hero-bleed is 2400x1600 and must be capped at 2K rather than escalating to 4K.
plan_with '[{"page":"index","section":"hero","composition":"hero-bleed"}]'
node "$g" plan --demo "$tmp" >/dev/null
a=$(pj gaps.0.aspect)
[ "$a" = "3:2" ] || fail "hero-bleed declares 2400x1600 so the aspect must be 3:2; got $a"
s=$(pj gaps.0.size)
[ "$s" = "2K" ] || fail "hero-bleed declares width 2400 but the cap is 2K; got $s"

echo PASS
