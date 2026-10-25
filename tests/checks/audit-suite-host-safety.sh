#!/usr/bin/env bash
# The browser suite pointed at the wrong host. bin/audit-suite.sh wrote baseURL into the
# persistent audit.config.js, so a stale or hand-edited value sent the next run to another
# host -- once production, with 90 s timeouts, outside the production gate. Around that:
# the gate only held when the caller remembered it; a silent host was hit for minutes of
# timeouts; `npm install` ran with no lockfile; and an unmeasured Tier 3 left no trace in the
# report, so the reader assumed it passed. This asserts each behavior, not just the wording.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
hasnt() { ! grep -Fq -- "$2" "$1" || fail "$1 still contains: $2"; }

runner=bin/audit-suite.sh
suite=templates/audit-suite
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# 1. baseURL is read, never rewritten; BASE_URL travels in the environment.
hasnt "$runner" 'rewrite(source, /(\bbaseURL:'
has "$runner" 'export BASE_URL="$url"'
has "$suite/audit.config.js" 'WP_AUDIT_BASE_URL_OVERRIDE'
cat > "$tmp/rewrite.js" <<'JS'
const fs = require('fs');
const src = fs.readFileSync(process.env.RUNNER, 'utf8');
const blocks = [...src.matchAll(/<<'NODE'[^\n]*\n([\s\S]*?)\nNODE\n/g)].map((m) => m[1]);
const body = blocks.find((b) => b.includes('baseURL'));
if (!body) { console.error('no heredoc that prepares baseURL found in ' + process.env.RUNNER); process.exit(3); }
process.argv[2] = process.env.CFG;
eval(body);
JS
cfg="$tmp/audit.config.js"
sed "s#https://example.com#https://stale-host.example#" "$suite/audit.config.js" | grep -v WP_AUDIT_BASE_URL_OVERRIDE > "$cfg"
before="$(grep -F 'baseURL:' "$cfg")"
for run in 1 2; do
  RUNNER="$runner" CFG="$cfg" BASE_URL="https://audited.example" node "$tmp/rewrite.js" 2>> "$tmp/err" \
    || fail "$runner could not prepare a config holding another host"
done
[ "$(grep -F 'baseURL:' "$cfg")" = "$before" ] || fail "$runner edited baseURL in audit.config.js"
grep -Fq 'stale-host.example' "$tmp/err" || fail "$runner did not report the baseURL / --url mismatch"
[ "$(grep -c WP_AUDIT_BASE_URL_OVERRIDE "$cfg")" = 1 ] || fail "the override line was not added exactly once"
got="$(BASE_URL=https://audited.example node -e 'console.log(require(process.argv[1]).baseURL)' "$cfg")"
[ "$got" = "https://audited.example" ] || fail "audit.baseURL is $got, not the --url host, in a spec that reads the config"

# 2. A production host never gets a request outside the gate, even when the caller forgot it.
has bin/prod-gate.sh 'WP_AUDIT_GATE_HELD="$host"'
has bin/prod-gate.sh '--prod) force_prod=1'
has "$runner" 'the production check by manifest was skipped'
has "$runner" 'prod-gate.sh'
has "$runner" 'WP_AUDIT_GATE_HELD'
fakebin="$tmp/bin"; mkdir -p "$fakebin"; printf '#!/bin/sh\nexit 0\n' > "$fakebin/chromium"; chmod +x "$fakebin/chromium"
gate="$tmp/gate"
bin/prod-gate.sh --dir "$gate" --mark-blocked https://audited.example "test ban" 2>/dev/null
rc=0
(cd "$tmp" && WP_AUDIT_GATE_DIR="$gate" WP_BROWSER_CHROMIUM="$fakebin/chromium" \
  bash "$OLDPWD/$runner" --url https://audited.example/ --dir "$tmp/suite" > "$tmp/out" 2>&1) || rc=$?
[ "$rc" = 4 ] || { cat "$tmp/out"; fail "an ungated call to a blocked production host exited $rc, not the gate's 4"; }
[ ! -e "$tmp/suite" ] || fail "something was scaffolded before the gate refused"

# 2b. A bracketed IPv6 literal keeps one key in both scripts: the child of a gated run compares
# WP_AUDIT_GATE_HELD with its own key, and `%%:*` alone cut `[2001:db8::1]` to `[2001`.
# A missing node_modules dir makes the runner exit 1 right after the gate: no install, no browser, no network.
has bin/lib/host-key.sh 'host_key()'
has bin/prod-gate.sh 'host_key "$target"'
has "$runner" 'host_key "$url"'
hasnt "$runner" 'gate_host="${url_host%%:*}"'
(
  . bin/lib/host-key.sh
  [ "$(host_key 'https://[2001:DB8::1]:8443/x?a=1')" = '[2001:db8::1]' ] || exit 1
  [ "$(host_key 'https://user@Example.COM:443/p')" = 'example.com' ] || exit 1
  [ "$(host_key 'example.com')" = 'example.com' ] || exit 1
) || fail "host_key does not normalize an IPv6 literal, a port or userinfo"
v6="$tmp/v6"; mkdir -p "$v6/gate"
rc=0
(cd "$tmp" && WP_AUDIT_GATE_HELD='[2001:db8::1]' WP_AUDIT_GATE_DIR="$v6/gate" WP_BROWSER_CHROMIUM="$fakebin/chromium" \
  WP_AUDIT_SUITE_NODE_MODULES="$tmp/none" \
  timeout 10 bash "$OLDPWD/$runner" --url 'https://[2001:db8::1]/' --dir "$tmp/suite-v6" > "$tmp/out-v6" 2>&1) || rc=$?
! grep -Fq 're-running through bin/prod-gate.sh' "$tmp/out-v6" || { cat "$tmp/out-v6"; fail "a child holding the gate for an IPv6 host re-ran the gate"; }

# 3. Consecutive timeouts stop the run; the runner turns that into UNMEASURED, exit 2.
node "$suite/guard/timeout-guard.selfcheck.js" | grep -Fq PASS || fail "the timeout guard self-check fails"
has "$suite/playwright.guard.config.js" 'guard/timeout-guard'
has "$runner" 'UNMEASURED: the browser tier did not complete'
has "$runner" '--max-timeouts'
has "$runner" 'results/unmeasured.json'

# 4. npm ci with a committed lockfile; no unlocked install, no browser download.
[ -f "$suite/package-lock.json" ] || fail "$suite/package-lock.json is missing"
git check-ignore -q "$suite/package-lock.json" && fail "$suite/package-lock.json is gitignored"
has "$runner" 'npm ci'
hasnt "$runner" 'npm install --no-audit'
(cd "$suite" && npm ls --package-lock-only >/dev/null 2>&1) || fail "package-lock.json does not match package.json"

# 5. Tier 3 UNMEASURED is a bold line in the first 40 lines of both documents.
cat > "$tmp/run.json" <<'JSON'
{"site":"Example","tier3":"unmeasured","findings":[],"unmeasured":[{"check":"tier3-browser","reason":"no browser"}]}
JSON
node bin/audit-report.mjs --run "$tmp/run.json" --out "$tmp/out-report" --format both --date 2026-01-01 >/dev/null \
  || fail "audit-report.mjs failed on tier3-unmeasured input"
for f in md html; do
  head -n 40 "$tmp/out-report/informe-2026-01-01.$f" | grep -Eq '(\*\*|<strong>)Tier 3 \(browser measurement\) was NOT measured' \
    || fail "informe-*.$f has no bold Tier 3 UNMEASURED line in its first 40 lines"
done
echo '{"site":"Example","findings":[],"unmeasured":[]}' > "$tmp/run2.json"
node bin/audit-report.mjs --run "$tmp/run2.json" --out "$tmp/out-clean" --format both --date 2026-01-01 >/dev/null \
  || fail "audit-report.mjs failed on a clean run"
! grep -Fq 'was NOT measured' "$tmp/out-clean"/informe-2026-01-01.* || fail "the notice shows on a run that measured Tier 3"

has skills/wp-audit-run/references/browser-suite.md 'The audited host is `--url`, never the config.'
has skills/wp-audit-run/references/browser-suite.md '"tier3": "unmeasured"'

echo PASS
