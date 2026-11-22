#!/usr/bin/env bash
# Defects (browser tools, input handling):
#  - demo-verify.mjs: `--widths` or `--out` as the last argument threw an uncaught
#    TypeError; `--widths 1440` (no height) became NaN and every page crashed at
#    newContext. Usage errors exit 1 with a one-line message.
#  - demo-verify.mjs: the per-page browser context was closed only on the happy
#    path, so a page that threw mid-walk leaked it in the shared browser.
#  - tailwindify-parity.mjs: two trees with no shared ancestor below `/` were
#    served from `/` (every file refused, or a machine-wide tree on loopback). Now a
#    clear exit 3, the tool's existing input-error code.
#  - composition-preview.mjs: `--tokens` ran previewTokens() outside the try, so a bad
#    token printed a raw stack at exit 1. Now the existing crash path, exit 3.
#  - tailwindify-parity.mjs: the server answers only inside the two trees (and their
#    top-level symlink targets), never the rest of the common ancestor.
# All of it runs against a stub playwright-core except the served-tree case, which
# needs PLAYWRIGHT_CORE.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp" "${far:-}"' EXIT
command -v node >/dev/null || { echo "SKIP: node not on PATH"; exit 0; }

mkdir -p "$tmp/pw"
cat > "$tmp/pw/index.mjs" <<STUB
import { appendFileSync } from 'node:fs';
const log = (m) => appendFileSync('$tmp/log', m + '\n');
const browser = {
  async newContext() {
    log('open');
    return {
      async newPage() { return { async goto() { throw new Error('boom'); } }; },
      async close() { log('close'); },
    };
  },
  async close() {},
};
export const chromium = { async launch() { return browser; } };
export const firefox = { async launch() { return browser; } };
STUB
: > "$tmp/fakechrome"; chmod +x "$tmp/fakechrome"
printf '<html><body>x</body></html>\n' > "$tmp/page.html"
dv() { PLAYWRIGHT_CORE="$tmp/pw" WP_BROWSER_CHROMIUM="$tmp/fakechrome" node "$root/bin/demo-verify.mjs" "$tmp/page.html" --no-firefox --no-gaps "$@" 2>&1; }

# --- demo-verify: value-less and malformed flag values ---
for bad in "--widths" "--out" "--widths 1440" "--widths 1440x" "--widths --out" "--widths axb"; do
  # shellcheck disable=SC2086
  rc=0; out="$(dv $bad)" || rc=$?
  [ "$rc" -eq 1 ] || fail "demo-verify $bad exited $rc, want 1: $out"
  printf '%s' "$out" | grep >/dev/null -c 'TypeError\|    at ' && fail "demo-verify $bad printed a stack: $out"
  printf '%s' "$out" | grep >/dev/null -cF 'demo-verify: --' || fail "demo-verify $bad gave no clear message: $out"
done
out="$(dv --widths 1440x900 --out "$tmp/o")" || true
printf '%s' "$out" | grep >/dev/null -c 'needs a value\|wants WIDTHxHEIGHT' && fail "a valid --widths was rejected: $out"

# --- demo-verify: every opened context is closed when the page throws ---
: > "$tmp/log"
dv --widths 1440x900 --out "$tmp/o2" >/dev/null || true
opened="$(grep -c "^open$" "$tmp/log" || true)"; closed="$(grep -c "^close$" "$tmp/log" || true)"
[ "$opened" -ge 1 ] || fail "the stub saw no context opened, the case does not exercise the walk"
[ "$closed" -ge "$opened" ] || fail "$opened context(s) opened, only $closed closed after the page threw"

# --- composition-preview --tokens: a bad token takes the crash path, exit 3, no stack ---
mkdir -p "$tmp/cp/bin" "$tmp/cp/skills/wp-demo-craft/references/design-md"
cp -R "$root/bin/lib" "$tmp/cp/bin/lib"; cp "$root/bin/composition-preview.mjs" "$tmp/cp/bin/"
sed 's/^  canvas:/  canvasx:/' "$root/skills/wp-demo-craft/references/design-md/_preview.md" \
  > "$tmp/cp/skills/wp-demo-craft/references/design-md/_preview.md"
rc=0; out="$(node "$tmp/cp/bin/composition-preview.mjs" --tokens 2>&1)" || rc=$?
[ "$rc" -eq 3 ] || fail "composition-preview --tokens with a bad token exited $rc, want 3: $out"
printf '%s' "$out" | grep >/dev/null -c '    at ' && fail "composition-preview --tokens printed a stack: $out"
printf '%s' "$out" | grep >/dev/null -cF 'missing the token: canvas' || fail "composition-preview --tokens lost the token name: $out"
out="$(node "$root/bin/composition-preview.mjs" --tokens 2>&1)" || fail "composition-preview --tokens fails on the real tokens: $out"

# --- tailwindify-parity: trees with no useful common ancestor ---
far="$(mktemp -d -p /dev/shm 2>/dev/null || true)"
if [ -n "$far" ]; then
  mkdir -p "$tmp/a"; cp "$tmp/page.html" "$tmp/a/a.html"; cp "$tmp/page.html" "$far/a.html"
  tp() { PLAYWRIGHT_CORE="$tmp/pw" WP_BROWSER_CHROMIUM="$tmp/fakechrome" node "$root/bin/tailwindify-parity.mjs" "$1" --against "$2" --widths 1440x900 2>&1; }
  rc=0; out="$(tp "$tmp/a/a.html" "$far/a.html")" || rc=$?
  [ "$rc" -eq 3 ] || fail "tailwindify-parity on disjoint trees exited $rc, want 3: $out"
  printf '%s' "$out" | grep >/dev/null -cF 'share no ancestor' || fail "tailwindify-parity gave no clear message: $out"
  mkdir -p "$tmp/b"; cp "$tmp/page.html" "$tmp/b/a.html"
  out="$(tp "$tmp/a/a.html" "$tmp/b/a.html")" || true
  printf '%s' "$out" | grep >/dev/null -cF 'share no ancestor' && fail "sibling trees were rejected: $out"
else
  echo "note: /dev/shm unavailable, disjoint-tree case not exercised"
fi

# --- tailwindify-parity serves only the two trees, not their common ancestor ---
# Real browser only (the stub cannot run the page's fetch). The converted page reads
# a file that sits in the common ancestor but in neither tree; the original page shows
# what a refused read shows. Served, the texts differ and the run is not clean.
if [ -n "${PLAYWRIGHT_CORE:-}" ] && [ -d "${PLAYWRIGHT_CORE:-}" ]; then
  anc="$tmp/anc"; mkdir -p "$anc/a/conv" "$anc/b/orig"
  echo leaked > "$anc/secret.txt"
  cat > "$anc/a/conv/index.html" <<'HTML'
<!doctype html><title>t</title><p id="r">pending</p>
<script>fetch('../../secret.txt').then(r=>r.ok?r.text():'blocked').catch(()=>'blocked').then(t=>{document.getElementById('r').textContent=t.trim()})</script>
HTML
  printf '<!doctype html><title>t</title><p id="r">blocked</p>\n' > "$anc/b/orig/index.html"
  rc=0; out="$(node "$root/bin/tailwindify-parity.mjs" "$anc/a/conv/index.html" --against "$anc/b/orig/index.html" --widths 400x300 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || fail "tailwindify-parity served a file outside both trees (rc $rc): $out"
elif [ "${CHECKS_REQUIRE_BROWSER:-}" = 1 ]; then
  fail "CHECKS_REQUIRE_BROWSER=1 but PLAYWRIGHT_CORE is not set"
else
  echo "note: PLAYWRIGHT_CORE not set, the served-tree case was NOT exercised"
fi

echo PASS
