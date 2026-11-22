#!/usr/bin/env bash
# Defect: bin/demo-verify.mjs given a directory with no .html files, or a mistyped page
# path, reached the summary as "no machine findings on 0 page(s)" and exited 0, so an
# empty demo/ or a typo read as a clean verification. Both must exit 1 (not 2, which
# means "no browser") before any browser is looked for, with a "no pages to verify" line.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
command -v node >/dev/null || { echo "SKIP: node not on PATH"; exit 0; }

mkdir -p "$tmp/empty"
for t in "$tmp/empty" "$tmp/missing.html"; do
  rc=0; out="$(node "$root/bin/demo-verify.mjs" "$t" 2>&1)" || rc=$?
  [ "$rc" -eq 1 ] || fail "demo-verify on $t exited $rc, want 1: $out"
  [ "$(printf '%s' "$out" | grep -cF 'no pages to verify' || true)" -gt 0 ] || fail "demo-verify on $t did not say 'no pages to verify': $out"
done

# --probe takes no target and must still reach the browser probe, not the page check.
out="$(node "$root/bin/demo-verify.mjs" --probe 2>&1)"
[ "$(printf '%s' "$out" | grep -cF 'no pages to verify' || true)" -eq 0 ] || fail "--probe hit the page check: $out"

echo PASS
