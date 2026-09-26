#!/usr/bin/env bash
# wp-audit-ux wrote a new script and launched a new Chromium for every question (16 launches
# on one 8-page audit) and never gave up on a guessed selector. bin/ux-probe.mjs is the one
# harness: one launch per run, every page opened once per viewport, built-in DOM probes, site
# probes from a module, and a state file that enforces 3 launches, 15 minutes and 2 attempts
# per probe. This drives it in a real Chromium against a static fixture and asserts all of it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tool=bin/ux-probe.mjs
[ -f "$tool" ] || fail "$tool missing"
grep -Fq 'const MAX_LAUNCHES = 3;' "$tool" || fail "launch cap is not 3"
grep -Fq 'const MAX_ATTEMPTS = 2;' "$tool" || fail "attempt cap is not 2"
grep -Fq 'const WALL_CLOCK_MS = 15 * 60 * 1000;' "$tool" || fail "wall clock is not 15 minutes"
grep -Fq "waitUntil: 'load'" "$tool" || fail "pages are not loaded with waitUntil load"
grep -Fq "networkidle'" "$tool" && fail "$tool waits for networkidle"

a=agents/wp-audit-ux.md
grep -Fq 'bin/ux-probe.mjs' "$a" || fail "$a does not use the harness"
grep -Fq -- '--probes' "$a" || fail "$a does not say where site probes go"
grep -Fq 'Exit `3` means the budget is spent.' "$a" || fail "$a does not say what an exhausted budget means"

skip() {
  echo "PASS (static only -- the harness was NOT exercised in a browser: $1)"
  echo "  To run it for real: PLAYWRIGHT_CORE=\"\$(npm root -g)/@playwright/test/node_modules/playwright-core\" bash $0"
  [ "${UX_PROBE_REQUIRE_BROWSER:-0}" = 1 ] && fail "UX_PROBE_REQUIRE_BROWSER=1 and $1"
  exit 0
}
command -v node >/dev/null || skip "no node"
node bin/lib/browsers.mjs chromium >/dev/null 2>&1 || skip "no existing Chromium"
if [ -z "${PLAYWRIGHT_CORE:-}" ] && ! node -e "import('playwright-core')" >/dev/null 2>&1; then
  skip "no playwright-core"
fi

tmp=$(mktemp -d)
trap 'kill "$srv" 2>/dev/null || true; rm -rf "$tmp"' EXIT
cat >"$tmp/server.mjs" <<'JS'
import http from 'node:http';
import { readFileSync } from 'node:fs';
const dir = process.argv[2];
const srv = http.createServer((req, res) => {
  const f = req.url === '/' ? 'index.html' : req.url === '/second/' ? 'second.html' : null;
  if (!f) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': 'text/html' }); res.end(readFileSync(`${dir}/${f}`));
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
JS
node "$tmp/server.mjs" tests/fixtures/ux-probe >"$tmp/port" &
srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
site="http://127.0.0.1:$(cat "$tmp/port")"

run() { node "$tool" --site "$site" --pages /,/second/ --out "$tmp/out/r.json" \
  --probes tests/fixtures/ux-probe/probes.mjs --links-out "$tmp/out/links.txt" 2>"$tmp/err"; }
j() { node -e "const r=JSON.parse(require('fs').readFileSync('$tmp/out/r.json','utf8'));$1"; }

run || { cat "$tmp/err"; fail "first run failed"; }
j "if(r.launch!==1)process.exit(1)" || fail "first run is not launch 1"
j "if(r.pages.length!==6)process.exit(1)" || fail "2 pages x 3 viewports did not give 6 page views in one launch"
d="const P=(v,p)=>r.pages.find(x=>x.viewport===v&&x.path===p);"
j "$d const a=P('desktop','/').dom.lineLength[0].longestLineChars,b=P('mobile','/').dom.lineLength[0].longestLineChars;if(!(a>120&&b<60)){console.log(a,b);process.exit(1)}" \
  || fail "UX-006 line length not measured per viewport"
j "$d const g=P('desktop','/').dom.actionGaps;if(g.length!==1||g[0].gapPx!==4){console.log(JSON.stringify(g));process.exit(1)}" \
  || fail "UX-009 did not find exactly the 4px pair"
j "$d const l=P('desktop','/').dom.linkStyle;if(!l.length||l[0].colorDiffers)process.exit(1)" \
  || fail "UX-018 did not flag the link that looks like text"
j "$d if(P('desktop','/').dom.imageLinks.length!==1)process.exit(1)" || fail "UX-019 did not find the unnamed image link"
j "$d const q=P('desktop','/').dom.required;const n=q.find(x=>x.name==='name'),e=q.find(x=>x.name==='email');if(!n||n.marked||!e||!e.marked)process.exit(1)" \
  || fail "UX-001 did not separate the marked and unmarked required fields"
j "$d if(P('desktop','/').site['account-popup'].value.opened!==true)process.exit(1)" || fail "site probe did not run on the loaded page"
j "$d const s=P('desktop','/').site['guessed-selector'];if(s.verdict!=='error'||s.attemptsLeft!==1)process.exit(1)" \
  || fail "a failing site probe is not an error with one attempt left"
grep -Fq "$(printf '#top\t%s/' "$site")" "$tmp/out/links.txt" || fail "--links-out lost the raw fragment href"
grep -Fq "$(printf '%s/second/\t%s/' "$site" "$site")" "$tmp/out/links.txt" || fail "--links-out is not href TAB page"

run || fail "second run failed"
run || fail "third run failed"
j "$d const s=P('desktop','/').site['guessed-selector'];if(s.verdict!=='unmeasured'||s.tried.length!==2)process.exit(1)" \
  || fail "after two failed runs the probe is not UNMEASURED with both attempts"
j "if(r.launch!==3)process.exit(1)" || fail "third run is not launch 3"

set +e; run; code=$?; set -e
[ "$code" = 3 ] || fail "fourth launch exited $code, expected 3 (launch budget)"
grep -q 'launch budget spent' "$tmp/err" || fail "fourth launch did not say the budget is spent"

node -e "require('fs').writeFileSync('$tmp/old.json', JSON.stringify({started: Date.now() - 16*60*1000, launches: 0, probes: {}}))"
set +e; node "$tool" --site "$site" --pages / --out "$tmp/o2/r.json" --state "$tmp/old.json" 2>"$tmp/err"; code=$?; set -e
[ "$code" = 3 ] && grep -q 'wall-clock budget spent' "$tmp/err" || fail "a run past 15 minutes did not exit 3"

echo PASS
