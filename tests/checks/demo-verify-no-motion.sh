#!/usr/bin/env bash
# /wp-responsive-check dispatches to /wp-demo-verify, which reported a blocking `no-engine`
# for every section of an existing site the plugin never built (40 rows, 0 real defects), so
# the round failed for a reason that does not apply. --no-motion drops the motion judgments;
# without it a page that lost its engine must still block.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=bin/demo-verify.mjs
grep -Fq "args.includes('--no-motion')" "$s" || fail "$s does not parse --no-motion"
grep -Fq -- '--no-motion' commands/wp-demo-verify.md || fail "commands/wp-demo-verify.md does not document --no-motion"
grep -Fq -- '--no-motion' commands/wp-responsive-check.md || fail "commands/wp-responsive-check.md does not pass --no-motion"
grep -Fq -- '--no-motion' CHANGELOG.md || fail "CHANGELOG.md has no --no-motion entry"

command -v node >/dev/null || { echo "PASS (static only: no node)"; exit 0; }
if ! probe=$(node "$s" --probe 2>&1); then
  echo "PASS (static only -- the walk was NOT exercised: no usable playwright-core or Chromium here -- $(tr '\n' ' ' <<<"$probe"))"
  echo "  To run it for real, point PLAYWRIGHT_CORE at an installed playwright-core, e.g."
  echo "  PLAYWRIGHT_CORE=\"\$(npm root -g)/@playwright/test/node_modules/playwright-core\" bash $0"
  exit 0
fi
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/index.html" <<'H'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>t</title>
<style>section{min-height:90vh;padding:2rem}</style></head><body>
<section id="a"><h1>One</h1><p>Plain static copy.</p></section>
<section id="b"><h2>Two</h2><p>More static copy.</p></section>
<section id="c"><h2>Three</h2><p>Last static copy.</p></section>
</body></html>
H
run() { node "$s" "$@" --positions 3 --widths 1440x900 --no-firefox >"$work/out.txt" 2>"$work/err.txt"; }

rc=0; run "$work/index.html" --out "$work/off" || rc=$?
[ "$rc" = 1 ] || fail "without the flag the fixture should exit 1, got $rc ($(head -3 "$work/err.txt" | tr '\n' ' '))"
grep -q '"no-engine"' "$work/off/findings.json" || fail "without the flag no-engine no longer blocks"

rc=0; run "$work/index.html" --no-motion --out "$work/on" || rc=$?
[ "$rc" = 0 ] || fail "--no-motion should exit 0, got $rc ($(cat "$work/out.txt" | head -5 | tr '\n' ' '))"
! grep -Eq '"(no-engine|dead-scroll)"' "$work/on/findings.json" || fail "--no-motion still emits a motion finding"

echo PASS
