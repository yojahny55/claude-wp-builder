#!/usr/bin/env bash
# Step 6.8 (the coverage gate) was skipped in one run and recomputed with ad-hoc regexes over
# the catalogs in others; a first dispatch that did not hand each agent its exact must-run list
# came back at 38/61 and 58/68 and cost two extra agents; an agent answered "not measured in
# this run" to skip checks. Agents also drifted into different key names (`code`/`check`,
# `owner`/`ownership`, `fix`/`auto_fixable`), listed one code as a finding and as a pass, and
# the parent wrote throwaway scripts to build run.json. The report ignored the site's primary
# language. Pinned: the coverage script's behavior, the normalizer at aggregation, the prose
# that makes both mandatory, and the language / output-directory defaults.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
cov=bin/audit-coverage.mjs rep=bin/audit-report.mjs
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
cmd=$EXPANDED
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT

# --- prose ------------------------------------------------------------------------------
d=skills/wp-audit-run/references/dispatch.md
grep -Fq 'Must-run ids' "$d" || fail "$d does not hand each agent its must-run id list"
grep -Fq 'audit-coverage.mjs --list' "$d" || fail "$d does not source the must-run list from the script"
grep -Fq 'only the missing ids' "$cmd" || fail "Step 6.8 does not re-dispatch only the missing ids"
grep -Fq 'mandatory' "$cmd" && grep -Fq 'audit-coverage.mjs --results' "$cmd" || fail "Step 6.8 does not make the coverage script mandatory"
grep -Fq 'Allowed UNMEASURED reasons' skills/wp-audit-run/references/status-vocabulary.md \
  || fail "status-vocabulary.md lost the allowed UNMEASURED reasons"
grep -Fq 'Aliases the aggregator accepts' skills/wp-audit-standards/SKILL.md || fail "the standards skill lost the alias table"
grep -Fq -- '--agents' skills/wp-audit-run/references/deliverable.md || fail "deliverable.md does not build the run from --agents"
grep -Fq 'languages.primary' commands/wp-audit.md || fail "--report-lang does not follow languages.primary"
grep -Fq 'audit.audits_root' skills/wp-audit-run/references/deliverable.md || fail "deliverable.md does not document the audits root"
! grep -Fq 'throwaway' "$cmd" || fail "the command still mentions throwaway scripts"

# --- coverage script ----------------------------------------------------------------------
ids=$(node "$cov" --list security)
n=$(echo "$ids" | tr ',' '\n' | wc -l)
[ "$n" -gt 30 ] || fail "--list security returned $n ids"
mk() { local extra=${3:-}
  node -e "const ids='$ids'.split(',');require('fs').writeFileSync('$1',JSON.stringify({category:'security',checks_executed:ids.slice(0,$2)$extra}))"
}
mk "$t/ok.json" "$n"
node "$cov" --results "$t/ok.json" >/dev/null || fail "full coverage exits non-zero"
mk "$t/low.json" 20
rc=0; out=$(node "$cov" --results "$t/low.json") || rc=$?
[ "$rc" = 1 ] || fail "20/$n did not exit 1 (got $rc)"
echo "$out" | grep -Eq "^security 20/$n checks executed .*never run: SEC-" || fail "coverage line malformed: $out"
{ node "$cov" --results "$t/low.json" --json || true; } | node -e "const j=JSON.parse(require('fs').readFileSync(0,'utf8'));if(j.status!=='BELOW_THRESHOLD'||j.categories[0].missing.length!==$n-20)process.exit(1)" \
  || fail "--json is wrong"
# a re-dispatch list holds only what is missing
miss=$(node "$cov" --list security --results "$t/low.json")
[ "$(echo "$miss" | tr ',' '\n' | wc -l)" = "$((n-20))" ] || fail "--list --results is not the missing ids only"
# N/A with a reason leaves the denominator; UNMEASURED with an allowed reason is blocked, not missing
first=$(echo "$ids" | cut -d, -f$((n-1))); last=$(echo "$ids" | cut -d, -f$n)
mk "$t/na.json" $((n-2)) ",findings:[{code:'$first',status:'N/A',reason:'no WooCommerce'},{code:'$last',status:'UNMEASURED',reason:'needs production: no public URL'}]"
out=$(node "$cov" --results "$t/na.json" --final) || fail "allowed reasons failed --final: $out"
echo "$out" | grep -Fq "blocked $last: production" || fail "allowed reason not reported as blocked"
# "not measured in this run" is not a reason: missing, and --final reports INCOMPLETE
mk "$t/bad.json" $((n-1)) ",findings:[{check:'$last',status:'UNMEASURED',reason:'not measured in this run'}]"
rc=0; out=$(node "$cov" --results "$t/bad.json" --final) || rc=$?
[ "$rc" = 1 ] || fail "a disallowed UNMEASURED reason passed --final"
echo "$out" | grep -Fq "missing $last: UNMEASURED reason not allowed" || fail "disallowed reason not reported as missing"
node "$cov" --results "$t/bad.json" >/dev/null || fail "99% should pass the plain threshold gate"
# a finding that is also a pass is invalid input (exit 2)
mk "$t/dup.json" "$n" ",findings:[{check:'SEC-002',status:'FAIL',severity:'warning',owner:'code',message:'x',resource:'site'}],passes:['SEC-002']"
rc=0; node "$cov" --results "$t/dup.json" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "finding+pass should exit 2 (got $rc)"
rc=0; node "$cov" --results "$t/nope" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a missing --results path should exit 2"

# --- normalizer at aggregation -------------------------------------------------------------
mkdir "$t/agents"
cat > "$t/agents/a.json" <<'J'
{"category":"security","checks_executed":["SEC-001","SEC-002"],"findings":[
 {"code":"SEC-002","severity":"warn","owner":"Code","title":"SQL not prepared","resource":"inc/a.php:3","fix":"auto","method":"use prepare"},
 {"id":"SEC-001","status":"PASS"}]}
J
echo '{"site":"demo","date":"2026-01-02","categories":["security"]}' > "$t/run.json"
node "$rep" --run "$t/run.json" --agents "$t/agents" --out "$t/o" --lang en --format md >/dev/null || fail "aliased agent report was not accepted"
grep -Fq 'SEC-002' "$t/o/informe-2026-01-02.md" || fail "aliased finding missing from the report"
node -e "const j=JSON.parse(require('fs').readFileSync('$t/o/informe-2026-01-02.json','utf8'));const f=j.findings[0];if(f.check!=='SEC-002'||f.ownership!=='code'||f.severity!=='WARNING')process.exit(1)" \
  || fail "aliases were not translated to the canonical keys"
cat > "$t/agents/a.json" <<'J'
{"category":"security","findings":[{"check":"SEC-9999","severity":"WARNING","ownership":"code","message":"x"}]}
J
rc=0; node "$rep" --run "$t/run.json" --agents "$t/agents" --out "$t/o2" --format md >/dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] || fail "a finding with no catalog code was accepted"
cat > "$t/agents/a.json" <<'J'
{"category":"security","passes":["SEC-002"],"findings":[{"check":"SEC-002","severity":"WARNING","ownership":"code","message":"x"}]}
J
rc=0; node "$rep" --run "$t/run.json" --agents "$t/agents" --out "$t/o2" --format md >/dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] || fail "a finding that is also a pass was accepted"

# --- --lang and --out defaults ---------------------------------------------------------------
site=$t/site; mkdir "$site"
echo '{"project":{"slug":"demo-site"},"languages":{"primary":"es"}}' > "$site/.wp-create.json"
echo '{"site":"demo","date":"2026-01-02","findings":[]}' > "$t/empty.json"
node "$rep" --run "$t/empty.json" --site-root "$site" --out "$t/o3" --format md >/dev/null
grep -Fq 'Auditoría web' "$t/o3/informe-2026-01-02.md" || fail "--lang did not default to the manifest's es"
node "$rep" --run "$t/empty.json" --site-root "$site" --out "$t/o4" --lang en --format md >/dev/null
grep -Fq 'Web audit' "$t/o4/informe-2026-01-02.md" || fail "--lang en no longer overrides the manifest"
echo '{"languages":{"primary":"fr"}}' > "$site/.wp-create.json"
node "$rep" --run "$t/empty.json" --site-root "$site" --out "$t/o5" --format md >/dev/null
grep -Fq 'Web audit' "$t/o5/informe-2026-01-02.md" || fail "an unsupported language did not fall back to en"
echo '{"project":{"slug":"demo-site"},"languages":{"primary":"es"}}' > "$site/.wp-create.json"
WP_AUDITS_ROOT="$t/audits" node "$rep" --run "$t/empty.json" --site-root "$site" --format md >/dev/null
[ -f "$t/audits/demo-site/results/informe-2026-01-02.md" ] || fail "audits root did not give <root>/<site>/results"
(cd "$t" && WP_AUDITS_ROOT="$t/audits" node "$OLDPWD/$rep" --run empty.json --out "$t/explicit" --format md >/dev/null)
[ -f "$t/explicit/informe-2026-01-02.md" ] || fail "--out no longer wins over the audits root"
(cd "$t" && node "$OLDPWD/$rep" --run empty.json --format md >/dev/null)
[ -f "$t/.wp-audit/informe-2026-01-02.md" ] || fail "the .wp-audit default changed with no audits root set"

echo PASS
