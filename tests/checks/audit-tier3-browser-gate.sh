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
#
#    The first version of this scan was `grep -rln 'web-quality-skills'` and it passed while
#    four stale references were live: three agents opened with `**Web-quality skills**` and
#    `**Web-quality-skills**`, and the subagent prompt template carried
#    `- Web-quality-skills: <available|not available>`. A capital W and a space defeated it.
#    Case and separator are therefore both matched, and the retired manifest key is matched
#    in its own right because it does not contain the package name at all.
#    The scan reports LINES, not file names: the two exempted strings are single lines inside
#    a file that legitimately names the retired key, so a file-level list would either hide a
#    real offender sitting beside them or fail on the migration path itself.
stale=$(grep -rniE 'web[- ]quality[- ]skills|web_quality_skills' --include='*.md' --include='*.sh' . \
  | grep -vE '^\./(CHANGELOG\.md|tests/checks/audit-tier3-browser-gate\.sh):' \
  | grep -vF 'the legacy `audit.web_quality_skills_available`' \
  | grep -vF 'Delete `audit.web_quality_skills_available` as you write this block' || true)
[ -z "$stale" ] \
  || fail "these still reference the retired package outside the migration path:
$stale"

grep -Fq 'the legacy `audit.web_quality_skills_available`' "$audit" \
  || fail "$audit dropped the migration path for a manifest that predates the key rename"

# 2. The replacement gate is a browser, and it is re-probed rather than trusted.
# Flattened, so an assertion survives a reflow and does not depend on a heading staying
# word-for-word. What it cannot survive is the detection mechanism being deleted, which is
# the point: the three tool identifiers ARE the gate, and a check that only greps the label
# around them passes on an empty tier.
flata=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')
for id in 'mcp__playwright__browser_navigate' 'performance_start_trace' 'mcp__claude-in-chrome__navigate'; do
  case "$flata" in
    *"$id"*) ;;
    *) fail "$audit does not probe for $id — Tier 3 has a label but no detection" ;;
  esac
done
case "$flata" in
  *'browser automation tool is available'*) ;;
  *) fail "$audit does not gate Tier 3 on a browser automation tool" ;;
esac
grep -Fq 'audit.browser_measurement_available' "$audit" \
  || fail "$audit does not record the browser capability under the current manifest key"
case "$flata" in
  *'Tier 3: Browser measurement'*) ;;
  *) fail "$audit's tier line still advertises the retired package" ;;
esac

# The agents cannot probe for a browser: their `tools:` lists carry no MCP tool. The value
# has to arrive in the dispatch prompt, or every agent gates on a line nothing fills.
case "$flata" in
  *'- Browser measurement: <available|not available>'*) ;;
  *) fail "$audit's subagent prompt does not pass browser availability down to the agents" ;;
esac

# Migrating a manifest means removing the old key, not accumulating both.
case "$flata" in
  *'Delete `audit.web_quality_skills_available` as you write this block'*) ;;
  *) fail "$audit migrates the retired manifest key but never deletes it" ;;
esac

# 3. The tier adds measurement, not criteria. Said in the skill that the agents read, because
#    an agent that believes Tier 3 owns the thresholds skips them when no browser is present.
grep -Fq 'It adds measurement, never criteria' "$standards" \
  || fail "$standards must state that Tier 3 adds measurement, not criteria"

# 4. The budgets stay unconditional, and the three metrics a file scan cannot answer stay
#    honest about it. This is the actual regression the change exists to prevent.
flatp=$(tr '\n' ' ' < "$perf" | sed 's/  */ /g')
# Case- and separator-insensitive like the offender scan above: a negative assertion that
# only matches one spelling is the same defect this check was rewritten to close.
if printf '%s' "$flatp" | grep -qiE 'if web[- ]quality[- ]skills'; then
  fail "$perf still makes its budgets conditional on the package"
fi
case "$flatp" in
  *'reported `UNMEASURED` without a browser, never assumed to pass'*) ;;
  *) fail "$perf must report the Core Web Vitals UNMEASURED without a browser, not pass them" ;;
esac
grep -Fq '| LCP (Largest Contentful Paint) | <2.5s |' "$perf" \
  || fail "$perf lost the Core Web Vitals budget table"

echo PASS
