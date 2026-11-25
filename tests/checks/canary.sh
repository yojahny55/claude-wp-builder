#!/usr/bin/env bash
# /wp-update verified the local clone, then the update reached staging and production by
# git push and nothing measured the live sites afterwards: a plugin update that 404s its own
# stylesheet or throws in the browser went unnoticed until someone opened the page.
# bin/canary.mjs snapshots key pages before the push and compares them after. This check
# pins the compare rules on fixtures (no browser), the browser snapshot against a local
# server (SKIP without playwright-core), and the /wp-update step that runs it.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

tool=bin/canary.mjs
fx=tests/fixtures/canary
[ -f "$tool" ] || fail "$tool missing"
command -v node >/dev/null || { echo "PASS (SKIP: no node — $tool not exercised)"; exit 0; }

# expect <exit> <before> <after> [grep-text]: compare exits <exit> and, if given, prints the text.
# /wp-update runs the canary around the staging and production pushes.
upd=commands/wp-update.md
need() { grep -F -- "$1" "$upd" >/dev/null || fail "$upd lacks: $1"; }
need 'Step 8: After the Push'
need 'bin/canary.mjs" snapshot'
need 'bin/canary.mjs" compare'
need 'bin/prod-gate.sh'
need 'environments'
need 'A regression stops the promotion'
grep -F 'canary.mjs' docs/exit-codes.md >/dev/null || fail "docs/exit-codes.md has no canary.mjs section"

expect() {
  local want=$1 before=$2 after=$3 text=${4:-} out rc=0
  out=$(node "$tool" compare "$fx/$before.json" "$fx/$after.json" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || fail "compare $before $after: exit $rc, want $want. Output: $out"
  if [ -n "$text" ]; then
    printf '%s\n' "$out" | grep -F -- "$text" >/dev/null || fail "compare $before $after: output lacks '$text'. Output: $out"
  fi
}

expect 0 base base
expect 1 base status-500 '500'
expect 1 base console-new 'console'
expect 0 console-digits-before console-digits-after
expect 1 base asset-same-site 'style.css'
expect 1 base asset-subdomain 'app.js'
expect 0 base asset-third-party
expect 1 base footer-gone 'footer'
expect 1 base page-error 'Timeout'
expect 1 base page-missing 'missing'
expect 0 base slow-small
expect 0 slow-base slow-big 'warn'
expect 64 base other-host 'host'

json=$(node "$tool" compare "$fx/base.json" "$fx/status-500.json" --json || true)
printf '%s' "$json" | node -e 'const r=JSON.parse(require("fs").readFileSync(0,"utf8")); if (r.regressions!==1||!Array.isArray(r.pages)) process.exit(1)' \
  || fail "--json output is not the documented shape: $json"

rc=0; node "$tool" bogus >/dev/null 2>&1 || rc=$?
[ "$rc" = 64 ] || fail "unknown subcommand exits $rc, want 64"

# Browser half: snapshot a local page that has every landmark, a 404 stylesheet and one
# console error. SKIP without playwright-core or Chromium, like the other browser checks.
pw=${PLAYWRIGHT_CORE:-}
if [ -z "$pw" ] || [ ! -f "$pw/index.mjs" ] || ! node bin/lib/browsers.mjs chromium >/dev/null 2>&1; then
  echo "PASS (SKIP: no playwright-core or Chromium — snapshot not exercised)"
  exit 0
fi

tmp=$(mktemp -d)
srv=""
trap '[ -n "$srv" ] && kill "$srv" 2>/dev/null; rm -rf "$tmp"' EXIT
cat > "$tmp/server.mjs" <<'JS'
import { createServer } from 'node:http';
const html = `<!doctype html><html><head><title>Fixture</title>
<link rel="stylesheet" href="/missing.css"></head><body>
<header>h</header><nav>n</nav><main><h1>Title</h1></main><footer>f</footer>
<script>console.error('fixture boom 42')</script></body></html>`;
const s = createServer((req, res) => {
  if (req.url === '/') { res.writeHead(200, { 'content-type': 'text/html' }); res.end(html); return; }
  res.writeHead(404); res.end('nope');
});
s.listen(0, '127.0.0.1', () => console.log(s.address().port));
JS
node "$tmp/server.mjs" > "$tmp/port" &
srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
port=$(sed -n 1p "$tmp/port")
[ -n "$port" ] || fail "fixture server did not start"

node "$tool" snapshot "http://127.0.0.1:$port/" --out "$tmp/snap.json" --delay 0 >/dev/null 2>"$tmp/err" \
  || fail "snapshot failed: $(cat "$tmp/err")"
node -e '
const s = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const p = s.pages[0], bad = [];
if (s.tool !== "canary" || s.version !== 1 || s.host !== "127.0.0.1") bad.push("header " + JSON.stringify({tool:s.tool,version:s.version,host:s.host}));
if (p.status !== 200) bad.push("status " + p.status);
if (p.title !== "Fixture") bad.push("title " + p.title);
if (!p.failedRequests.some(r => r.url.endsWith("/missing.css") && r.status === 404)) bad.push("failedRequests " + JSON.stringify(p.failedRequests));
if (p.consoleErrors.length !== 1 || !/fixture boom/.test(p.consoleErrors[0])) bad.push("consoleErrors " + JSON.stringify(p.consoleErrors));
for (const l of ["h1","header","nav","main","footer"]) if (p.landmarks[l] !== true) bad.push("landmark " + l);
if (typeof p.ms !== "number") bad.push("ms");
if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
' "$tmp/snap.json" || fail "snapshot JSON is not what the page holds"

# A snapshot of itself compares clean, and the same 404 is not new.
node "$tool" compare "$tmp/snap.json" "$tmp/snap.json" >/dev/null || fail "a snapshot compared with itself is not clean"

# A page that cannot load is recorded with an error, not dropped.
kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null || true; srv=""
rc=0; node "$tool" snapshot "http://127.0.0.1:$port/" --out "$tmp/down.json" --delay 0 --timeout 5 >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "snapshot of an unreachable host exits $rc, want 2 (nothing measured)"
node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); if(!s.pages[0].error) process.exit(1)' "$tmp/down.json" \
  || fail "unreachable page not recorded with an error"

rc=0; node "$tool" snapshot "http://a.test/" "http://b.test/" --out "$tmp/x.json" >/dev/null 2>&1 || rc=$?
[ "$rc" = 64 ] || fail "snapshot of two hosts exits $rc, want 64"
rc=0; node "$tool" snapshot "http://a.test/" >/dev/null 2>&1 || rc=$?
[ "$rc" = 64 ] || fail "snapshot without --out exits $rc, want 64"

echo PASS
