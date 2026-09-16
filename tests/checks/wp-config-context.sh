#!/usr/bin/env bash
# .claude/CLAUDE.md is read in 17 places for `i18n strategy` alone. Agents keep reading
# it exactly as before; what changes is that it is rendered from the manifest, so it
# can no longer disagree. Text OUTSIDE the markers is the operator's and is never touched.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -r tests/fixtures/manifests/valid "$tmp/p"
mkdir -p "$tmp/p/.claude"

printf '# Fixture Site\n\nHand written guidance the operator added.\n' > "$tmp/p/.claude/CLAUDE.md"
$cfg render-context "$tmp/p" >/dev/null 2>&1 || fail "render-context did not exit 0"

grep -q 'Hand written guidance' "$tmp/p/.claude/CLAUDE.md" || fail "render-context destroyed hand-written text outside the markers"
grep -q '<!-- wp-create:begin -->' "$tmp/p/.claude/CLAUDE.md" || fail "the generated block has no begin marker"
grep -q 'i18n strategy' "$tmp/p/.claude/CLAUDE.md" || fail "the generated block does not carry the i18n strategy"

# --- Rendering twice changes nothing. ---------------------------------------
before=$(sha256sum "$tmp/p/.claude/CLAUDE.md" | cut -d" " -f1)
$cfg render-context "$tmp/p" >/dev/null 2>&1
after=$(sha256sum "$tmp/p/.claude/CLAUDE.md" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "render-context is not idempotent"

# --- A hand-edited block is REPORTED, not silently overwritten. -------------
sed -i 's|i18n strategy:\*\* suffix|i18n strategy:** polylang|' "$tmp/p/.claude/CLAUDE.md"
set +e
$cfg validate "$tmp/p" >"$tmp/out" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a hand-edited generated block exited $code, want 1"
grep -q 'wp-create:begin' "$tmp/out" || fail "the drift message does not name the generated block"
grep -q 'polylang' "$tmp/p/.claude/CLAUDE.md" || fail "validate overwrote the hand edit instead of reporting it"

echo PASS
