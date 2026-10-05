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
trap 'kill "${srv:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT
cat >"$tmp/server.mjs" <<'JS'
import http from 'node:http';
import { readFileSync } from 'node:fs';
const dir = process.argv[2];
const srv = http.createServer((req, res) => {
  // /r/ redirects once a probe has set the `moved` cookie: a reload that settles elsewhere.
  if (req.url === '/r/' && /moved=1/.test(req.headers.cookie || '')) { res.writeHead(302, { location: '/second/' }); res.end(); return; }
  const f = req.url === '/' || req.url === '/r/' ? 'index.html' : req.url === '/second/' ? 'second.html' : null;
  if (!f) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': 'text/html' }); res.end(readFileSync(`${dir}/${f}`));
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
JS
node "$tmp/server.mjs" tests/fixtures/ux-probe >"$tmp/port" &
srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
[ -s "$tmp/port" ] || fail "fixture server did not start"
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
j "$d const l=P('desktop','/').dom.linkStyle;if(l.length!==1||l[0].text!=='a link that looks like text'){console.log(JSON.stringify(l));process.exit(1)}" \
  || fail "UX-018 did not flag exactly the in-text link that looks like text (not the nav link, not the coloured one)"
j "$d if(P('desktop','/').dom.imageLinks.length!==1)process.exit(1)" || fail "UX-019 did not find the unnamed image link"
j "$d const q=P('desktop','/').dom.required;const n=q.find(x=>x.name==='name'),e=q.find(x=>x.name==='email');if(!n||n.marked||!e||!e.marked)process.exit(1)" \
  || fail "UX-001 did not separate the marked and unmarked required fields"
j "$d if(P('desktop','/').site['account-popup'].value.opened!==true)process.exit(1)" || fail "site probe did not run on the loaded page"
j "$d const w=P('desktop','/').site['wanders'];if(!w||!/\/second\/$/.test(w.leftPage||''))process.exit(1)" \
  || fail "a probe that navigated away was not recorded with leftPage"
j "if(r.complete!==true)process.exit(1)" || fail "a finished run is not marked complete"
j "$d if(P('mobile','/').site['account-popup']!==undefined)process.exit(1)" || fail "a desktop-only site probe ran on the mobile viewport"
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
grep -Fq "$tmp/old.json" "$tmp/err" || fail "the budget message does not name the state file"

# A state file over an hour old belongs to an earlier audit, even with its launches spent.
node -e "require('fs').writeFileSync('$tmp/stale.json', JSON.stringify({started: Date.now() - 2*60*60*1000, launches: 3, probes: {}}))"
node "$tool" --site "$site" --pages / --out "$tmp/o6/r.json" --state "$tmp/stale.json" 2>"$tmp/err" \
  || fail "a state file from an earlier audit blocked a new one"
grep -q 'earlier audit' "$tmp/err" || fail "a stale state file was replaced without saying so"
node -e "if(JSON.parse(require('fs').readFileSync('$tmp/o6/r.json','utf8')).launch!==1)process.exit(1)" \
  || fail "a stale state file did not start a new budget"

# The wall clock is checked during the run, not only at its start. The run is admitted with
# five seconds left and a probe on the first page takes six, so the first page view is
# measured and the second is past the deadline: marked unmeasured, and the run incomplete.
cat >"$tmp/slow.mjs" <<'JS'
export default [{ id: 'slow', viewports: ['desktop'],
  run: async ({ path }) => { if (path === '/') await new Promise((r) => setTimeout(r, 6000)); return true; } }];
JS
node -e "require('fs').writeFileSync('$tmp/late.json', JSON.stringify({started: Date.now() - 15*60*1000 + 5000, launches: 0, probes: {}}))"
node "$tool" --site "$site" --pages /,/second/ --viewports desktop --probes "$tmp/slow.mjs" \
  --out "$tmp/o7/r.json" --state "$tmp/late.json" 2>"$tmp/err" || { cat "$tmp/err"; fail "a run admitted before the deadline failed"; }
node -e "const r=JSON.parse(require('fs').readFileSync('$tmp/o7/r.json','utf8'));const a=r.pages.find(x=>x.path==='/'),b=r.pages.find(x=>x.path==='/second/');if(!a||a.verdict||!a.dom||!b||b.verdict!=='unmeasured'||b.reason!=='budget'||r.complete!==false){console.log(JSON.stringify(r.pages.map(x=>[x.path,x.verdict,x.reason])),r.complete);process.exit(1)}" \
  || fail "a page view past the wall-clock deadline was measured, or the run still claims complete"

# A probe that changes where the page reloads to (a cookie that alters a redirect) cannot be
# undone by a reload: the remaining probes are unmeasured, not run against another page.
cat >"$tmp/cookie.mjs" <<'JS'
export default [
  { id: 'sets-cookie', viewports: ['desktop'], run: async ({ page, url }) => {
    await page.evaluate(() => { document.cookie = 'moved=1; path=/'; });
    await page.goto(new URL('/second/', url).href);
    return true;
  } },
  { id: 'after', viewports: ['desktop'], run: async () => true },
];
JS
node "$tool" --site "$site" --pages /r/ --viewports desktop --probes "$tmp/cookie.mjs" \
  --out "$tmp/o8/r.json" --state-reset 2>"$tmp/err" || { cat "$tmp/err"; fail "cookie-redirect run failed"; }
node -e "const r=JSON.parse(require('fs').readFileSync('$tmp/o8/r.json','utf8'));const e=r.pages[0],a=e.site['after'];if(!e.site['sets-cookie'].leftPage||!a||a.verdict!=='unmeasured'||!/page restored to/.test(a.reason)){console.log(JSON.stringify(e));process.exit(1)}" \
  || fail "a reload that settled on another page let later probes measure it"

# --state-reset clears a spent budget on purpose.
node "$tool" --site "$site" --pages / --out "$tmp/out/r.json" --state-reset 2>"$tmp/err" || fail "--state-reset run failed"
j "if(r.launch!==1)process.exit(1)" || fail "--state-reset did not start a new budget"

# A run that collects no links (no desktop viewport) keeps the previous --links-out.
node "$tool" --site "$site" --pages / --out "$tmp/out/r.json" --viewports mobile,tablet \
  --links-out "$tmp/out/links.txt" 2>"$tmp/err" || fail "mobile,tablet run failed"
[ -s "$tmp/out/links.txt" ] || fail "a run with no links truncated the earlier --links-out"

# An unreadable state file refuses instead of handing out a fresh budget.
echo '{"launches": 2, "sta' >"$tmp/bad.json"
set +e; node "$tool" --site "$site" --pages / --out "$tmp/o3/r.json" --state "$tmp/bad.json" 2>"$tmp/err"; code=$?; set -e
[ "$code" = 2 ] && grep -q 'unreadable' "$tmp/err" || fail "a corrupt state file did not stop the run"

# Bad arguments are usage errors, not a spent launch.
for bad in '--page-timeout abc' '--probe-timeout 0' '--viewports ,'; do
  set +e; node "$tool" --site "$site" --pages / --out "$tmp/o4/r.json" $bad 2>/dev/null; code=$?; set -e
  [ "$code" = 2 ] || fail "$bad exited $code, expected 2"
done
[ ! -e "$tmp/o4/ux-probe-state.json" ] || fail "a usage error consumed a launch"
# A browser that fails to start is not a spent launch.
set +e; WP_BROWSER_CHROMIUM=/bin/false node "$tool" --site "$site" --pages / --out "$tmp/o5/r.json" 2>"$tmp/err"; code=$?; set -e
[ "$code" = 2 ] && grep -q 'failed to launch' "$tmp/err" || fail "a failed Chromium launch exited $code, expected 2"
[ ! -e "$tmp/o5/ux-probe-state.json" ] || fail "a failed Chromium launch consumed a launch"

echo PASS
