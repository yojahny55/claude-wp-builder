#!/usr/bin/env bash
# wp-audit-standards is read by every audit agent, and most of it had no pin: the severity
# table, the prefixes, the budgets and thresholds, the deduplication owners, the AIOS x CF7
# interaction, the WebP "new uploads only" rule, and the production-gate contract -- what
# marks a host blocked and what exit 4 and 5 mean. The gate's invocation and exit codes were
# not even written down; the only full call lived in /wp-audit's dispatch prompt, and exit 5
# said "call again" with no stop. Any of it could be deleted with every check green.
#
# Where the skill restates a script (bin/prod-gate.sh, bin/link-sweep.mjs), the script's own
# header is read too, so a change to either side fails here instead of drifting.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

k=skills/wp-audit-standards/SKILL.md
ref=skills/wp-audit-standards/references/performance-lessons.md
for f in "$k" "$ref" bin/prod-gate.sh bin/link-sweep.mjs commands/wp-audit.md; do [ -r "$f" ] || fail "$f is missing or unreadable"; done
flat=$(tr '\n' ' ' < "$k" | sed 's/  */ /g')
has() { case "$flat" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# --- grading and naming ---------------------------------------------------------------------
for row in '| **CRITICAL** |' '| **WARNING** |' '| **INFO** |'; do
  grep -Fq "$row" "$k" || fail "$k lost the severity row $row"
done
for p in '`SEC-NNN`' '`SEO-NNN`' '`A11Y-NNN`' '`PERF-NNN`' '`WP-NNN`' '`UX-NNN`' '`GEO-Dnn`'; do
  grep -Fq "| $p" "$k" || fail "$k lost the prefix row for $p"
done
grep -Fq '| `A11Y-AXE-*`, `PERF-LH-*` | Evidence rows from the browser suite — measurements of an existing criterion, never criteria of their own |' "$k" \
  || fail "$k no longer says the suite's evidence rows are not criteria"
grep -Fq 'Issue Code Prefixes' "$k" && fail "$k still calls a finding an issue in its headings"
for owner in '**Security agent** owns vulnerability-class checks' '**Practices agent** owns coding-standards checks' \
             '**SEO agent** owns heading hierarchy for search ranking' '**A11y agent** owns heading hierarchy for screen reader' \
             'deduplicates identical `file:line` findings, keeping the highest severity'; do
  grep -Fq "$owner" "$k" || fail "$k lost the deduplication rule: $owner"
done
has 'Restructuring a template, changing application logic, removing code and design decisions are never auto-fixable' \
  || fail "$k does not say what is never auto-fixable"

# --- thresholds -----------------------------------------------------------------------------
for row in '| CSS compressed | <100KB |' '| JS compressed | <300KB |' '| Total page weight | <1.5MB |' \
           '| Images above-fold | <500KB |' '| Fonts total | <100KB |' \
           '| LCP | ≤2.5s | 2.5s–4s | >4s |' '| INP | ≤200ms | 200ms–500ms | >500ms |' '| CLS | ≤0.1 | 0.1–0.25 | >0.25 |' \
           '| Normal text contrast | 4.5:1 |' '| UI component contrast | 3:1 |' '| Minimum gray on white passing 4.5:1 | `#767676` |'; do
  grep -Fq "$row" "$k" || fail "$k lost the threshold row $row"
done
grep -Fq '| Touch target size | 44x44' "$k" && fail "$k sets 44x44 as the touch-target threshold again"
has 'It adds measurement, never criteria' || fail "$k lost the Tier 3 rule"
has 'Chrome DevTools MCP for a Lighthouse run or a performance trace, Playwright MCP for everything else' \
  || fail "$k offers three browser tools with no default"

# --- the production gate, against its own script --------------------------------------------
grep -Fq '4 = the host is marked blocked; nothing was sent' bin/prod-gate.sh || fail "bin/prod-gate.sh changed exit 4 -- update the skill"
grep -Fq '5 = another command held the host longer than --wait; nothing was sent' bin/prod-gate.sh || fail "bin/prod-gate.sh changed exit 5 -- update the skill"
grep -Fq '1 = usage error, or flock is unavailable' bin/prod-gate.sh || fail "bin/prod-gate.sh changed exit 1 -- update the skill"
grep -Fq 'WP_AUDIT_GATE_DIR=<gate dir> ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh [--delay 10] <host> -- <command> [args...]' "$k" \
  || fail "$k does not show the gated call"
grep -Fq 'WP_AUDIT_GATE_DIR=<gate dir> ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh --mark-blocked <host> "<reason>"' "$k" \
  || fail "$k does not show how to mark a host blocked"
has 'every agent of the run must use the same one' || fail "$k does not say the gate directory must be shared"
has 'It needs `flock`' || fail "$k does not state the gate's flock dependency"
for trigger in '- a `429`' '- a `403` carrying a WAF signature' '- `ERR_CONNECTION_REFUSED` in a browser' '- link-sweep exit `4`'; do
  grep -Fq -- "$trigger" "$k" || fail "$k lost the block trigger: $trigger"
done
grep -Fq '| `4` | the host is marked blocked; nothing was sent |' "$k" || fail "$k does not say what gate exit 4 means"
grep -Fq 'Never retry — a retry against a ban extends the ban' "$k" || fail "$k lets an agent retry against a ban"
grep -Fq '| `5` | another agent held the host past `--wait` (300 s); nothing was sent | call again, at most twice more' "$k" \
  || fail "$k gives gate exit 5 no stop rule"
grep -Fq 'call again, at most twice more' commands/wp-audit.md \
  || fail "commands/wp-audit.md's dispatch prompt gives gate exit 5 no stop rule"

# --- the link sweep, against its own script -------------------------------------------------
grep -Fq 'exit 0 = sweep ran (findings are in the JSON), 2 = usage, 4 = --stop-on-block stopped it' bin/link-sweep.mjs \
  || fail "bin/link-sweep.mjs changed its exit codes -- update the skill"
for row in '| `0` | the sweep ran; its findings are in the JSON |' '| `2` | usage error' '| `4` | `--stop-on-block` stopped it at a block'; do
  grep -Fq "$row" "$k" || fail "$k lost the link-sweep exit row $row"
done

# --- the performance lessons the reference keeps --------------------------------------------
rflat=$(tr '\n' ' ' < "$ref" | sed 's/  */ /g')
rhas() { case "$rflat" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
rhas 'only on new uploads' || fail "$ref lost the WebP new-uploads-only rule"
rhas 'raw SCF/ACF field URLs' || fail "$ref lost why field-driven images bypass the WebP filter"
rhas "aiowps_disallow_unauthorized_rest_requests = 1" || fail "$ref lost the AIOS x CF7 interaction"
rhas '/wp-json/contact-form-7/v1/' || fail "$ref no longer names the CF7 endpoints AIOS refuses"
grep -Fq '$WP option patch update aio_wp_security_configs aiowps_disallow_unauthorized_rest_requests 0' "$ref" \
  || fail "$ref gives no exact command for the AIOS fix"
rhas 'Only the five metric audits (FCP, LCP, TBT, CLS, Speed Index) carry weight' || fail "$ref lost which audits carry score weight"
rhas 'Lighthouse 10 and later' || fail "$ref does not name the Lighthouse version its scoring facts hold for"
grep -Fqw 'TTI' "$ref" && fail "$ref names TTI, which Lighthouse 10 removed from the score"
grep -Fq 'about__bg' "$ref" && fail "$ref carries a real build's selector instead of the prefix_ placeholder"

# --- the agent interaction model ------------------------------------------------------------
for row in '| Read plugin config | `$WP option get <option_name>` |' '| Write plugin config | `$WP option update/patch` |' \
           '| wp-config changes | `$WP config set` |'; do
  grep -Fq "$row" "$k" || fail "$k lost the interaction-model row $row"
done

echo "PASS: the shared audit contract, its thresholds and the production gate are pinned against their scripts"
