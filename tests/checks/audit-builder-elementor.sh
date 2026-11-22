#!/usr/bin/env bash
# Fixing audit findings on an adopted Elementor site cost repeated rediscovery (wrong flush
# command, no backup before a data edit, a thumbnail link filed as a defect on every page).
# The playbook lives in one reference; it must exist, keep its load-bearing rules, and be
# reachable from fix.md and the three agents it affects, gated on stack.builder.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
ref=skills/wp-audit-standards/references/builder-elementor.md
[ -r "$ref" ] || fail "$ref is missing"
for s in 'elementor flush-css' 'flush-cache` does not exist' 'pagination_individual_handle' \
  'fetchpriority' 'aria-allowed-role' 'elementor-post__thumbnail__link' 'aria-hidden="true"' \
  'theme_mods_<parent>' 'replay' 'style-diff.mjs' 'the_content' 'Custom CSS'; do
  grep -Fq -- "$s" "$ref" || fail "$ref lost: $s"
done
grep -Eq '^## Contents' "$ref" || fail "$ref has no Contents list"
grep -Fq 'references/builder-elementor.md' skills/wp-audit-standards/SKILL.md || fail "SKILL.md does not list the playbook"
for f in skills/wp-audit-run/references/fix.md agents/wp-audit-a11y.md agents/wp-audit-ux.md agents/wp-audit-performance.md; do
  grep -Fq '${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-standards/references/builder-elementor.md' "$f" || fail "$f does not point to the playbook"
  grep -Fq '`stack.builder` is `elementor`' "$f" || fail "$f loads the playbook without gating on stack.builder"
done
echo PASS
