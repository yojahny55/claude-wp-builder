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

echo PASS
