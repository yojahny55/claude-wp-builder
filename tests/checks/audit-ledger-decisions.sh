#!/usr/bin/env bash
# `accepted` was defined as "set by a human and by nothing else", yet no command let a human
# set it: a declined finding came back every session, fixes applied between audits left the
# ledger in `new` for days, and the report was patched by hand because it could not be
# re-rendered. This runs bin/audit-report.mjs on a temp ledger and sidecar and pins what a
# decision does, plus the prose that sends the agent to the commands.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node missing"; echo PASS; exit 0; }
R="$PWD/bin/audit-report.mjs"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T"

cat > run.json <<'JSON'
{"site":"demo","date":"2026-10-01","categories":["a11y","security"],"findings":[
{"check":"A11Y-028","resource":"btn:1","severity":"WARNING","ownership":"code","category":"a11y","message":"Target too small one","fix":"enlarge"},
{"check":"A11Y-028","resource":"btn:2","severity":"WARNING","ownership":"code","category":"a11y","message":"Target too small two"},
{"check":"SEC-036","resource":"wp_options.siteurl","severity":"CRITICAL","ownership":"setting","category":"security","message":"Dev host in siteurl","fix":"update"},
{"check":"SEO-001","severity":"INFO","ownership":"content","category":"seo","message":"Missing description"}]}
JSON
cat > .wp-audit-findings.json <<'JSON'
{"ledger_version":1,"findings":[
{"check":"A11Y-028","resource":"btn:1","status":"new","severity":"WARNING"},
{"check":"A11Y-028","resource":"btn:2","status":"still_failing","severity":"WARNING"},
{"check":"SEC-036","resource":"wp_options.siteurl","status":"still_failing","severity":"CRITICAL"},
{"check":"SEO-001","status":"new","severity":"INFO"}]}
JSON
run() { node "$R" "$@" --out out; }
st() { node -e 'const l=JSON.parse(require("fs").readFileSync(".wp-audit-findings.json"));console.log(l.findings.filter(e=>e.check+(e.resource?":"+e.resource:"")==process.argv[1])[0].status)' "$1"; }

run --run run.json >/dev/null
grep -q 'SEC-036' out/informe-2026-10-01.md || fail "baseline report lacks SEC-036"

# decisions without a reason or evidence are refused, and an unknown id changes nothing
run --accept A11Y-028 >/dev/null 2>&1 && fail "--accept without --reason was accepted"
run --mark-fixed SEC-036 >/dev/null 2>&1 && fail "--mark-fixed without --evidence was accepted"
before=$(cat .wp-audit-findings.json)
run --accept A11Y-028,NOPE-1 --reason x >/dev/null 2>&1 && fail "an unknown id was accepted"
[ "$before" = "$(cat .wp-audit-findings.json)" ] || fail "a refused --accept still wrote the ledger"

# accept by bare check hits every resource; the reason and date are stored
run --accept A11Y-028 --reason "client declined small targets" >/dev/null
[ "$(st A11Y-028:btn:1)" = accepted ] && [ "$(st A11Y-028:btn:2)" = accepted ] || fail "bare check did not accept every resource"
grep -q '"accepted_reason": "client declined small targets"' .wp-audit-findings.json || fail "reason not stored"
grep -q '"accepted_at"' .wp-audit-findings.json || fail "date not stored"

# mark-fixed gives the distinct status, never resolved
run --mark-fixed SEC-036:wp_options.siteurl --evidence "option updated" >/dev/null
[ "$(st SEC-036:wp_options.siteurl)" = fixed_unverified ] || fail "--mark-fixed did not set fixed_unverified"

# rerender: accepted and fixed leave the headline and the plan, and get their own sections
run --rerender >/dev/null
md=out/informe-2026-10-01.md
grep -Fq 'Findings: 1 (0 critical, 0 warnings, 1 info)' $md || fail "headline still counts accepted or fixed findings"
sed -n '/^## Remediation plan/,/^## Accepted/p' $md | grep -Eq 'A11Y-028|SEC-036' && fail "accepted/fixed finding still in the plan"
grep -Fq '## Accepted by a human' $md || fail "no accepted section"
grep -Fq 'client declined small targets' $md || fail "accepted reason missing from the report"
grep -Fq '## Fixed, awaiting a measured re-run' $md || fail "no fixed_unverified section"
grep -Fq 'id="accepted"' out/informe-2026-10-01.html || fail "html lacks the accepted section"
grep -Fq 'no check' $md || grep -Fq 'No check was run again' $md || fail "rerender did not say nothing was re-measured"
ls out/informe-2026-10-01.json >/dev/null

# a later run that still finds the fixed entry reports it open, not set aside
msg=$(run --run run.json 2>&1 >/dev/null || true)
printf '%s' "$msg" | grep -Fq 'still found it' || fail "a run that still finds a fixed_unverified entry did not say so"
grep -Eq 'SEC-036' <(sed -n '/^## Remediation plan/,/^## Not measured/p' out/informe-2026-10-01.md) || fail "fresh finding of a fixed_unverified entry is not in the plan"

# summary: counts by status and severity, machine readable
node "$R" --summary --json --out out | node -e '
const s=JSON.parse(require("fs").readFileSync(0));
if(s.total!==4||s.by_status.accepted.total!==2||s.by_status.fixed_unverified.CRITICAL!==1||s.open.total!==1||s.by_severity.WARNING!==2) process.exit(1)' \
  || fail "--summary --json counts are wrong"
node "$R" --summary --out out | grep -q '^accepted ' || fail "--summary text lacks the status table"

# unaccept restores the previous status
run --unaccept A11Y-028:btn:1 >/dev/null
[ "$(st A11Y-028:btn:1)" = new ] || fail "--unaccept did not restore the previous status"
grep -c accepted_reason .wp-audit-findings.json | grep -q '^1$' || fail "--unaccept left decision fields behind"

# a ledger of the wrong shape is refused with the shape
echo '{"findings":{"a":1}}' > bad.json
msg=$(node "$R" --summary --ledger bad.json --out out 2>&1 || true)
printf '%s' "$msg" | grep -Fq 'ledger_version' || fail "a malformed ledger was not refused with the expected shape"

cd - >/dev/null
# the prose sends the agent to the commands
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
c=$EXPANDED
need() { grep -Fq -- "$1" "$c" || fail "wp-audit (expanded) $2"; }
need '`fixed_unverified`' 'does not define the fixed_unverified status'
need 'does not find it turns it into `resolved`' 'does not say only a measured re-run resolves a fixed_unverified entry'
need 'returns it to `still_failing`' 'does not send a still-found fixed_unverified entry back to still_failing'
need '--accept <id> --reason' 'does not tell the agent how to record a declined finding'
need '--mark-fixed <id> --evidence' 'does not tell the agent how to record an applied fix'
need '--rerender' 'does not tell the agent to re-render instead of hand-editing a report'
need '--summary' 'does not tell the agent to quote counts from --summary'
need 'Never patch a generated report by hand' 'does not forbid hand-patching the report'
need '`accepted` entries: a human closed them' 'scoped re-audit does not skip accepted entries'
need '"findings":[{"check":"SEC-036"' 'does not show the ledger shape'
! grep -Fq 'Five statuses, and only one' "$c" || fail "ledger.md still says five statuses"

echo PASS
