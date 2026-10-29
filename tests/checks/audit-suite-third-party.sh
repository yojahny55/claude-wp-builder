#!/usr/bin/env bash
# The browser suite never completed on an adopted, third-party-heavy news site (160-250
# requests a page: video embeds, analytics, currency widgets) in three runs out of three, so
# Tier 3 stayed UNMEASURED every time. Each cause is asserted here as behavior:
#   - the run's hand-tuned playwright.config.js (workers, timeout, engines, blocked hosts) was
#     overwritten by the scaffold at the start of the run, and the script had no flags for
#     any of it (an attempted --project did not exist);
#   - pages waited for network idle and never got it, and the timeout brake read those slow
#     pages as a host that had stopped answering, though the host answered in 0.8 s;
#   - a helper running on the page a timeout had closed surfaced as a metadata error;
#   - the first run refused a non-empty --dir without saying which file was in the way;
#   - bin/ux-probe.mjs could not block third-party hosts, so widgets answered it with 403s.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }

runner=bin/audit-suite.sh
tp="$PWD/bin/lib/third-party.cjs"
suite=templates/audit-suite
tmp="$(mktemp -d)"
trap 'kill "${srv:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
# 1. One allowlist, shared
# ---------------------------------------------------------------------------
node -e '
const t = require(process.argv[1]);
const ok = (c, m) => { if (!c) { console.error(m); process.exit(1); } };
const a = t.allowlistFor("https://www.site.example:8443/x", "cdn.example.net,*.static.example");
ok(a.includes("www.site.example") && a.includes("site.example"), "the audited host and its twin are not allowed: " + a);
ok(a.includes("localhost") && a.includes("127.0.0.1"), "loopback is not allowed");
ok(t.isBlocked("https://www.youtube.com/embed/x", { allow: a }), "a third party is not blocked");
ok(!t.isBlocked("https://site.example/wp-content/x.css", { allow: a }), "the audited host is blocked");
ok(!t.isBlocked("https://img.static.example/a.png", { allow: a }), "a *.domain allowlist entry does not cover subdomains");
ok(t.isBlocked("https://evilstatic.example/", { allow: a }), "a suffix match leaked to another domain");
ok(!t.isBlocked("data:image/png;base64,AA", { allow: a }), "a data: URL was blocked");
const b = t.parseHosts(".tracker.example");
ok(t.isBlocked("https://x.tracker.example/p", { block: b }) && !t.isBlocked("https://site.example/", { block: b }), "--block-hosts semantics");
const args = t.chromiumArgs(a)[0];
ok(/^--host-resolver-rules=MAP \* ~NOTFOUND, /.test(args) && args.includes("EXCLUDE site.example") && args.includes("EXCLUDE *.static.example"), args);
ok(!args.includes("[::1]"), "an IPv6 literal reached the resolver rules");
const fx = t.applyToLaunch("firefox", {}, a);
ok(fx.proxy && fx.proxy.bypass.includes("site.example"), "firefox gets no blocking proxy");
ok(t.applyToLaunch("firefox", { proxy: { server: "http://p:1" } }, a).proxy.server === "http://p:1", "an explicit proxy was overridden");
const dflt = { args: ["--ignore-certificate-errors"], proxy: { server: "http://corp:3128" } };
const cr = t.applyToLaunch("chromium", t.withDefaults(dflt, {}), a);
ok(cr.args.includes("--ignore-certificate-errors") && cr.args.some((x) => x.startsWith("--host-resolver-rules")), "the config launch args were dropped or the block was not added: " + cr.args);
ok(t.applyToLaunch("firefox", t.withDefaults(dflt, {}), a).proxy.server === "http://corp:3128", "the config proxy was replaced by the block");
ok(/proxy/.test(t.blockSkipped("firefox", t.withDefaults(dflt, {})) || ""), "a config proxy that turns the block off is not reported");
ok(/host-resolver-rules/.test(t.blockSkipped("chromium", { args: ["--host-resolver-rules=MAP foo 127.0.0.1"] }) || ""), "a resolver rule that turns the block off is not reported");
ok(/proxy/.test(t.blockSkipped("chromium", t.withDefaults(dflt, {})) || ""), "a config proxy that bypasses the chromium resolver rule is not reported");
ok(t.blockSkipped("chromium", { args: ["--ignore-certificate-errors"] }) === null && t.blockSkipped("webkit", {}) === null, "an engine the block applies to was reported as skipped");
' "$tp" || fail "$tp does not implement the allowlist"
grep -Fq "third-party.cjs" bin/lib/pw-executables.cjs || fail "the suite preload does not use the shared allowlist"
grep -Fq "lib/third-party.cjs" bin/ux-probe.mjs || fail "ux-probe does not use the shared allowlist"

# ---------------------------------------------------------------------------
# 2. The guard tells a slow page from a silent host, and records closed pages
# ---------------------------------------------------------------------------
node "$suite/guard/timeout-guard.selfcheck.js" 2>/dev/null | grep -Fq PASS || fail "the timeout guard self-check fails"

# The bridge reports what the guard recorded as UNMEASURED with its reason.
b="$tmp/bridge"; cp -r "$suite/." "$b/"; mkdir -p "$b/results/audit"
echo '{"page":"Home","results":[{"c":"44","name":"html lang","status":"pass","evidence":"lang=es"}]}' > "$b/results/audit/home.json"
echo '[{"page":"News (/news/)","project":"chromium","reason":"slow page: timed out after 90s while the host answered (HTTP 200 in 800 ms) -- not measured, the run went on"}]' \
  > "$b/results/unmeasured-pages.json"
(cd "$b" && node scripts/to-run.js --out results/run.json >/dev/null) || fail "to-run.js failed with unmeasured-pages.json present"
node -e '
const r = require(process.argv[1]);
const u = r.unmeasured.find((x) => /^SUITE-PAGE-/.test(x.check));
if (!u || !/slow page/.test(u.reason) || !u.pages.includes("News (/news/)")) { console.error(JSON.stringify(r.unmeasured)); process.exit(1); }
' "$b/results/run.json" || fail "a page the guard recorded is not UNMEASURED with its reason in run.json"

# ---------------------------------------------------------------------------
# 3. bin/audit-suite.sh, driven with fake npm / npx and a fake browser
# ---------------------------------------------------------------------------
fake="$tmp/fakebin"; mkdir -p "$fake" "$tmp/modules" "$tmp/home" "$tmp/browsers"
printf '#!/bin/sh\nexit 0\n' > "$fake/chromium"
printf '#!/bin/sh\nexit 0\n' > "$fake/firefox"
# npm run <script> -- <args>: log the script, its args and the run settings, then succeed.
cat > "$fake/npm" <<'SH'
#!/bin/sh
[ "$1" = run ] || { echo "fake npm: $*"; exit 0; }
echo "npm $3 ${*#run --silent $3 -- } block=$WP_AUDIT_BLOCK_THIRD_PARTY allow=$WP_AUDIT_ALLOW_HOSTS settle=$WP_AUDIT_SETTLE_MS" >> "$CALLS"
SH
cat > "$fake/npx" <<'SH'
#!/bin/sh
case "$*" in *"playwright --version"*) echo "Version 1.0.0"; exit 0 ;; esac
echo "npx $*" >> "$CALLS"
SH
chmod +x "$fake"/*
suite_run() {
  (cd "$tmp" && env PATH="$fake:$PATH" HOME="$tmp/home" PLAYWRIGHT_BROWSERS_PATH="$tmp/browsers" CALLS="$tmp/calls" \
    WP_AUDIT_SUITE_NODE_MODULES="$tmp/modules" WP_BROWSER_CHROMIUM="$fake/chromium" WP_BROWSER_FIREFOX="$fake/firefox" \
    WP_AUDIT_GATE_DIR="$tmp/gate" bash "$OLDPWD/$runner" "$@")
}

# 3a. Flags that do not exist, or values that make no sense, are refused before anything runs.
rc=0; suite_run --url http://site.localhost/ --project=chromium > "$tmp/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -Fq -- '--engines' "$tmp/out" || fail "--project was not refused with a pointer to --engines (exit $rc)"
rc=0; suite_run --url http://site.localhost/ --engines firefox > "$tmp/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -Fq 'must include chromium' "$tmp/out" || fail "--engines without chromium was accepted"
rc=0; suite_run --url https://audited.example/ --workers 4 > "$tmp/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -Fq 'refusing --workers 4 against production' "$tmp/out" || fail "--workers 4 against production was not refused (exit $rc)"
[ ! -e "$tmp/gate" ] || fail "a refused --workers still went through the production gate"

# 3b. A non-empty directory that is not a scaffold is refused, naming what is in it.
mkdir -p "$tmp/notsuite"; echo log > "$tmp/notsuite/run.log"
rc=0; suite_run --url http://site.localhost/ --dir "$tmp/notsuite" > "$tmp/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -Fq 'run.log' "$tmp/out" || { cat "$tmp/out"; fail "the non-empty --dir refusal does not name the stray file"; }

# 3c. A local run: flags reach the passes, third parties are blocked by default, the
# Lighthouse pass keeps one worker, and an engine not requested is not run.
: > "$tmp/calls"
rc=0; suite_run --url http://site.localhost/ --dir "$tmp/s" --workers 2 --timeout 240 --settle 3 \
  --engines chromium --allow-hosts cdn.example.net > "$tmp/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -Fq 'produced no results' "$tmp/out" || { cat "$tmp/out"; fail "the fake local run did not reach the passes (exit $rc)"; }
grep -Fq 'third-party hosts blocked; allowed:' "$tmp/out" || fail "a local run did not block third parties by default"
grep -Eq '^npm test:a11y .*--workers=2 --timeout=240000 .*block=1 allow=cdn.example.net settle=3000' "$tmp/calls" \
  || { cat "$tmp/calls"; fail "--workers/--timeout/--settle/--allow-hosts did not reach the accessibility pass"; }
grep -E '^npm test:perf' "$tmp/calls" | grep -Fq -- '--workers=' && fail "the Lighthouse pass got a --workers that overrides its own 1"
grep -Fq 'firefox pass not requested' "$tmp/out" || fail "--engines chromium still ran the firefox pass"
grep -Fq 'project=firefox' "$tmp/calls" && fail "--engines chromium still invoked a firefox project"

# Without --engines the existing firefox runs; --no-block-third-party turns the block off.
: > "$tmp/calls"
suite_run --url http://site.localhost/ --dir "$tmp/s" --no-block-third-party > "$tmp/out" 2>&1 || true
grep -Fq 'project=firefox' "$tmp/calls" || { cat "$tmp/out"; fail "the default engines did not run the firefox pass"; }
grep -Eq '^npm test:a11y .*block=0' "$tmp/calls" || fail "--no-block-third-party did not turn the block off"

# 3d. An edited generated config survives a re-run; an untouched one is refreshed.
cfg="$tmp/s/playwright.config.js"
[ -f "$tmp/s/.scaffold-sums" ] || fail "the scaffold records no checksums"
echo '// operator edit: workers 1' >> "$cfg"
echo '// stale' >> "$tmp/s/lib/plan.js"
suite_run --url http://site.localhost/ --dir "$tmp/s" > "$tmp/out" 2>&1 || true
grep -Fq 'operator edit' "$cfg" || fail "a re-run overwrote the edited playwright.config.js"
grep -Fq 'keeping your edited' "$tmp/out" || fail "a kept config was kept without a notice"
grep -Fq '// stale' "$tmp/s/lib/plan.js" && fail "the template's own lib/ was not refreshed"
suite_run --url http://site.localhost/ --dir "$tmp/s" > /dev/null 2>&1 || true
grep -Fq 'operator edit' "$cfg" || fail "a second re-run overwrote the edited config"
rm "$cfg"
suite_run --url http://site.localhost/ --dir "$tmp/s" > /dev/null 2>&1 || true
cmp -s "$cfg" "$suite/playwright.config.js" || fail "deleting the kept config did not restore the template's"
# A scaffold from before the checksum record: a config that differs from the template is kept.
rm "$tmp/s/.scaffold-sums"; echo '// older edit' >> "$tmp/s/global-setup.js"
echo '// stale wrapper' >> "$tmp/s/playwright.guard.config.js"
suite_run --url http://site.localhost/ --dir "$tmp/s" > /dev/null 2>&1 || true
grep -Fq 'older edit' "$tmp/s/global-setup.js" || fail "an edit in a scaffold without .scaffold-sums was discarded"
# The plugin's own guard wrapper is always refreshed: an old copy would never get its fixes.
cmp -s "$tmp/s/playwright.guard.config.js" "$suite/playwright.guard.config.js" || fail "a stale playwright.guard.config.js was kept"

# ---------------------------------------------------------------------------
# 4. Real browser: the preload's settle and block, and ux-probe's --block-* flags
# ---------------------------------------------------------------------------
skip() { echo "PASS (browser half SKIPPED: $1)"; echo "  To run it: PLAYWRIGHT_CORE=\"\$(npm root -g)/@playwright/test/node_modules/playwright-core\" bash $0"; exit 0; }
chrome="$(node bin/lib/browsers.mjs chromium 2>/dev/null)" || skip "no existing Chromium"
[ -n "${PLAYWRIGHT_CORE:-}" ] || skip "PLAYWRIGHT_CORE is not set"
pwtest="$(cd "$PLAYWRIGHT_CORE/../.." 2>/dev/null && pwd)"
[ -f "$pwtest/package.json" ] && grep -Fq '"name": "@playwright/test"' "$pwtest/package.json" \
  || skip "PLAYWRIGHT_CORE is not inside an @playwright/test install"

# A page that never goes network-idle (it polls) and loads from a third party and from a
# second local name (localhost, allowed as loopback).
cat > "$tmp/server.cjs" <<'JS'
const http = require('http');
const srv = http.createServer((q, r) => {
  if (q.url === '/poll') { setTimeout(() => r.end('ok'), 150); return; }
  if (q.url === '/own.png') {
    r.setHeader('content-type', 'image/png');
    r.end(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', 'base64'));
    return;
  }
  r.setHeader('content-type', 'text/html');
  r.end(`<html lang="en"><head><title>t</title></head><body><p>hi</p>
<img src="http://widget.example/w.png" alt=""><img src="http://localhost:${srv.address().port}/own.png" alt="">
<script>setInterval(() => fetch('/poll'), 250)</script></body></html>`);
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
JS
node "$tmp/server.cjs" > "$tmp/port" &
srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
[ -s "$tmp/port" ] || fail "fixture server did not start"
site="http://127.0.0.1:$(cat "$tmp/port")"

proj="$tmp/proj"; mkdir -p "$proj/node_modules/@playwright"
ln -s "$pwtest" "$proj/node_modules/@playwright/test"
cat > "$proj/drive.cjs" <<'JS'
const { chromium } = require('@playwright/test');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const failed = [];
  page.on('requestfailed', (r) => failed.push(`${new URL(r.url()).hostname} ${r.failure().errorText}`));
  const t0 = Date.now();
  await page.goto(process.env.BASE_URL + '/', { waitUntil: 'networkidle', timeout: 15000 });
  const ms = Date.now() - t0;
  await browser.close();
  console.log(JSON.stringify({ ms, failed }));
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).split('\n')[0] })); });
JS
out="$(cd "$proj" && BASE_URL="$site" WP_AUDIT_CHROMIUM="$chrome" WP_AUDIT_SETTLE_MS=1500 WP_AUDIT_BLOCK_THIRD_PARTY=1 \
  NODE_OPTIONS="--require $OLDPWD/bin/lib/pw-executables.cjs" timeout 60 node drive.cjs 2>/dev/null)"
node -e '
const r = JSON.parse(process.argv[1]);
if (r.error) { console.error("networkidle on a polling page still failed: " + r.error); process.exit(1); }
if (!(r.ms >= 1400 && r.ms < 10000)) { console.error("goto took " + r.ms + " ms, not domcontentloaded plus a 1.5 s settle"); process.exit(1); }
if (!r.failed.some((f) => f.startsWith("widget.example "))) { console.error("the third party was not blocked: " + r.failed); process.exit(1); }
if (r.failed.some((f) => f.startsWith("localhost "))) { console.error("loopback was blocked: " + r.failed); process.exit(1); }
' "$out" || fail "the suite preload did not settle and block in a real Chromium ($out)"

j() { node -e "const r=JSON.parse(require('fs').readFileSync('$1','utf8'));$2"; }
node bin/ux-probe.mjs --site "$site" --pages / --viewports desktop --out "$tmp/ux1/r.json" --block-third-party 2>"$tmp/err" \
  || { cat "$tmp/err"; fail "ux-probe --block-third-party failed"; }
j "$tmp/ux1/r.json" "const b=r.blocked;if(!b||b.mode!=='third-party'||!b.hosts['widget.example']||b.hosts['localhost']||!r.pages[0].dom)process.exit(1)" \
  || fail "ux-probe --block-third-party did not block exactly the third party while measuring the page"
node bin/ux-probe.mjs --site "$site" --pages / --viewports desktop --out "$tmp/ux2/r.json" --block-hosts widget.example 2>"$tmp/err" \
  || { cat "$tmp/err"; fail "ux-probe --block-hosts failed"; }
j "$tmp/ux2/r.json" "const b=r.blocked;if(!b||b.mode!=='hosts'||b.hosts['widget.example']!==1)process.exit(1)" \
  || fail "ux-probe --block-hosts did not block the listed host"
node bin/ux-probe.mjs --site "$site" --pages / --viewports desktop --out "$tmp/ux3/r.json" 2>/dev/null || fail "ux-probe without blocking failed"
j "$tmp/ux3/r.json" "if(r.blocked)process.exit(1)" || fail "ux-probe blocked hosts without being asked"
rc=0; node bin/ux-probe.mjs --site "$site" --pages / --out "$tmp/ux4/r.json" --block-hosts a.example --block-third-party 2>/dev/null || rc=$?
[ "$rc" = 2 ] || fail "--block-hosts with --block-third-party was not a usage error"

echo PASS
