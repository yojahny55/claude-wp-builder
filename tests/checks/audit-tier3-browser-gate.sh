#!/usr/bin/env bash
# Tier 3 used to be gated on a third-party skill package being installed
# (web-quality-skills). The gate was hollow: every criterion it claimed to unlock — the
# weight budgets, the Core Web Vitals thresholds, the WCAG 2.2 additions, the HTML5
# cross-check — was already written into the audit agents. So an audit run on a machine
# without that package silently skipped checks it could answer from the theme source alone,
# and the tier line reported "Tier 3: not found" for a capability the plugin already had.
#
# Tier 3 is now gated on the only thing a file scan genuinely cannot substitute for: a
# browser that loads the page. This check asserts both directions — the external gate is
# gone, and the browser gate replaced it — because a positive grep alone is satisfied by
# deleting the tier.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

audit=commands/wp-audit.md
standards=skills/wp-audit-standards/SKILL.md
perf=agents/wp-audit-performance.md

for f in "$audit" "$standards" "$perf"; do
  [ -r "$f" ] || fail "$f is missing or cannot be read"
done

# 1. No check may be conditional on the third-party package any more. CHANGELOG records the
#    history and is exempt, as is this check, which has to name the thing it forbids;
#    wp-audit.md names the retired manifest key once, to read a manifest written before the
#    rename, which is a migration path and not a gate.
offenders=$(grep -rln 'web-quality-skills' --include='*.md' --include='*.sh' . \
  | grep -vE '^\./(CHANGELOG\.md|tests/checks/audit-tier3-browser-gate\.sh)$' || true)
[ -z "$offenders" ] || fail "these still reference the retired package as a gate: $offenders"

grep -Fq 'the legacy `audit.web_quality_skills_available`' "$audit" \
  || fail "$audit dropped the migration path for a manifest that predates the key rename"

# 2. The replacement gate is a browser, and it is re-probed rather than trusted.
grep -Fq '**Tier 3 (if a browser automation tool is available):**' "$audit" \
  || fail "$audit does not gate Tier 3 on a browser automation tool"
grep -Fq 'audit.browser_measurement_available' "$audit" \
  || fail "$audit does not record the browser capability under the current manifest key"
grep -Fq 'Tier 3: Browser measurement' "$audit" \
  || fail "$audit's tier line still advertises the retired package"

# 3. The tier adds measurement, not criteria. Said in the skill that the agents read, because
#    an agent that believes Tier 3 owns the thresholds skips them when no browser is present.
grep -Fq 'It adds measurement, never criteria' "$standards" \
  || fail "$standards must state that Tier 3 adds measurement, not criteria"

# 4. The budgets stay unconditional, and the three metrics a file scan cannot answer stay
#    honest about it. This is the actual regression the change exists to prevent.
flatp=$(tr '\n' ' ' < "$perf" | sed 's/  */ /g')
case "$flatp" in
  *'If web-quality-skills'*) fail "$perf still makes its budgets conditional on the package" ;;
esac
case "$flatp" in
  *'reported `UNMEASURED` without a browser, never assumed to pass'*) ;;
  *) fail "$perf must report the Core Web Vitals UNMEASURED without a browser, not pass them" ;;
esac
grep -Fq '| LCP (Largest Contentful Paint) | <2.5s |' "$perf" \
  || fail "$perf lost the Core Web Vitals budget table"

echo PASS
