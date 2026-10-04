#!/usr/bin/env bash
# One defect (a notice printed before the document) used to surface as a finding in every
# category it touched, inflating the totals. Findings sharing a root_cause fold into the most
# severe one, which lists the rest under also_affects.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/run.json" <<'JSON'
{"site":"s","findings":[
{"check":"SEC-001","resource":"site","severity":"WARNING","ownership":"setting","message":"display_errors leaks","root_cause":"display-errors"},
{"check":"SEO-002","resource":"page:/robots.txt","severity":"CRITICAL","ownership":"setting","message":"robots has a notice","root_cause":"display-errors"},
{"check":"GEO-A01","resource":"site","severity":"INFO","ownership":"setting","message":"head notice","root_cause":"display-errors"},
{"check":"PERF-001","resource":"site","severity":"INFO","ownership":"code","message":"unrelated"}]}
JSON
node bin/audit-report.mjs --run "$tmp/run.json" --out "$tmp/o" --lang en --format md >/dev/null || fail "report failed"
n=$(node -e "const fs=require('fs');const d='$tmp/o';console.log(JSON.parse(fs.readFileSync(d+'/'+fs.readdirSync(d).find(f=>f.endsWith('.json')),'utf8')).findings.length)")
[ "$n" = 2 ] || fail "expected 2 findings after folding, got $n"
grep -Fq 'same cause: SEC-001 site, GEO-A01 site' "$tmp"/o/*.md || fail "the folded checks are not named in the report"
grep -Fq 'SEO-002' "$tmp"/o/*.md || fail "the most severe finding did not become the parent"
# Contract in the dispatch prompt and aggregation step.
grep -Fq 'Root cause:' commands/wp-audit.md || fail "finding format lacks Root cause"
echo PASS
