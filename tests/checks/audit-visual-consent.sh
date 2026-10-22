#!/usr/bin/env bash
# /wp-audit Step 9 offered "Apply them? (y/n)" split by owner (code, setting, content) but not by
# whether a fix changes the render. A11y and performance fixes include CSS focus styles, size and
# spacing changes and tag or class swaps, so one "y" restyled a site that nobody had measured.
# The plugin also knew stack.builder and never used it, so a setting with a builder control was
# patched with theme CSS. fix.md must keep visual fixes out of auto-fixable, measured before and
# after, and builder-first; the agents that emit CSS must declare design_impact.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

fix=skills/wp-audit-run/references/fix.md
disp=skills/wp-audit-run/references/dispatch.md
[ -f "$fix" ] && [ -f "$disp" ] || fail "fix.md or dispatch.md is missing"
flat=$(tr '\n' ' ' < "$fix" | sed 's/  */ /g')

for needle in 'The fourth class, `visual`' '`design_impact`' 'never** counted as auto-fixable' \
  'measurement before the change' '`getComputedStyle()`' '`getBoundingClientRect()`' \
  'one at a time' 'every element that shares the class' 'desktop and mobile' \
  'is a regression to fix' 'bin/style-diff.mjs' 'Builder first' '`stack.builder`' \
  'Back up the builder' 'the reason written in the finding'; do
  printf '%s' "$flat" | grep -Fq -- "$needle" || fail "$fix lost: $needle"
done
# The offer must count visual fixes apart from the auto-fixable number.
grep -Fq 'NOT in that number' "$fix" || fail "$fix offer does not count visual fixes apart"

grep -Fq 'Design impact: <true|false>' "$disp" || fail "$disp finding format has no Design impact line"
for a in a11y ux performance; do
  grep -Fq 'Design impact is declared on every finding' "agents/wp-audit-$a.md" \
    || fail "agents/wp-audit-$a.md does not require design_impact"
done
grep -Fq 'design_impact' bin/audit-report.mjs || fail "audit-report.mjs does not carry design_impact"
grep -Fq 'designImpact' bin/audit-report.mjs || fail "audit-report.mjs does not show design_impact"

# Behavior: a finding with design_impact true is tagged in the Markdown report.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/run.json" <<'JSON'
{"site":"example","date":"2026-01-01","tier":"standard","findings":[
 {"check":"A11Y-025","severity":"CRITICAL","ownership":"code","design_impact":true,"message":"No focus styles"}]}
JSON
node bin/audit-report.mjs --run "$tmp/run.json" --out "$tmp/out" --format md >/dev/null 2>&1 \
  || fail "audit-report.mjs rejected a run with design_impact"
grep -rFq 'Visual change' "$tmp/out" || fail "the report does not tag a design_impact finding"
echo PASS
