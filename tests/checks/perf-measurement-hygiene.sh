#!/usr/bin/env bash
# Two recorded measurements, both of which cost a real session and neither of which any code
# can re-derive:
#   1. a Lighthouse score measures the machine as much as the page. The same URL under CPU
#      contention read performance 62 / LCP 10,170ms and 94 / LCP 1,580ms idle, with no theme
#      change between them. A contended run is indistinguishable from a regression by
#      inspection, so the requirement to measure alone belongs in the contract;
#   2. inlining the critical CSS — the standard advice for a render-blocking stylesheet —
#      improved FCP and made LCP WORSE on a real site, because the inline block precedes the
#      hero image on the same connection. Without the numbers written down, the experiment is
#      repeated blind and the conclusion is drawn from FCP again.
#
# Both live in the skill, and the performance agent's Tier 3 step must point at them: an agent
# that never reads them files the finding before the skill can warn it.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

skill=skills/wp-audit-standards/SKILL.md
agent=agents/wp-audit-performance.md
for f in "$skill" "$agent"; do
  [ -f "$f" ] || { echo "FAIL: $f is missing"; exit 1; }
done
flats=$(tr '\n' ' ' < "$skill" | sed 's/  */ /g')
flata=$(tr '\n' ' ' < "$agent" | sed 's/  */ /g')

# Substring test against text already flattened above, so each assertion costs a
# `case` instead of a printf and a grep. Each one keeps its own failure message:
# a loop over a list of required tokens would collapse twenty distinct diagnostics
# into one, and the message is the reason these assertions are worth having.
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# 1. Contention. The numbers are the evidence; a rule with no number is advice.
grep -Fq 'A Lighthouse run needs an idle machine' "$skill" \
  || { echo "FAIL: $skill has no section requiring an idle machine for a Lighthouse run"; exit 1; }
has '10,170 ms' "$flats" \
  || { echo "FAIL: $skill does not record the contended measurement, so the rule reads as caution rather than evidence"; exit 1; }
has '1,580 ms' "$flats" \
  || { echo "FAIL: $skill does not record the idle measurement the contended one is compared against"; exit 1; }
has 'Never run Lighthouse next to anything else' "$flats" \
  || { echo "FAIL: $skill does not forbid running Lighthouse beside another process"; exit 1; }
# The corollary that is easiest to forget, and the one that produces false findings.
has 'Re-measure before filing a metric regression' "$flats" \
  || { echo "FAIL: $skill does not require a re-measurement before a metric regression is filed"; exit 1; }
# A before/after pair measured under different conditions reports the machine, not the fix.
has 'both halves must be measured under the' "$flats" \
  || { echo "FAIL: $skill does not require both halves of a before/after pair to be measured under the same conditions"; exit 1; }

# 2. The rejected experiment. Every number in the table is load-bearing: the point is that
# FCP improved WHILE LCP got worse, and one number alone does not carry that.
grep -Fq 'Inline critical CSS' "$skill" \
  || { echo "FAIL: $skill does not record the inline-critical-CSS result"; exit 1; }
for n in '990 ms' '570 ms' '2950 ms' '3150 ms' '0.139'; do
  has "$n" "$flats" \
    || { echo "FAIL: $skill is missing the measurement $n from the inline-critical-CSS table — the result is that FCP improved while LCP got worse, which no single number shows"; exit 1; }
done
has 'the LCP number decides' "$flats" \
  || { echo "FAIL: $skill does not state that LCP decides when FCP and LCP disagree"; exit 1; }
# The real cause on that site, so the next reader looks at the render delay instead of
# re-running the rejected fix.
# The whole phrase, flattened: 'element' alone matches "the element", "LCP element" and
# half the prose in the file, so the assertion passed with the finding deleted.
has 'element render delay' "$flats" \
  || { echo "FAIL: $skill does not name element render delay as what the breakdown actually showed"; exit 1; }
has '276 ms' "$flats" \
  || { echo "FAIL: $skill does not record the render-delay measurement that located the real cause"; exit 1; }

# 3. The agent has to be sent there. A skill nobody is told to read is a skill that warns
# nobody at the moment the finding is filed.
has 'Measure on an idle machine' "$flata" \
  || { echo "FAIL: $agent Tier 3 does not require an idle machine"; exit 1; }
has 'wp-audit-standards' "$flata" \
  || { echo "FAIL: $agent Tier 3 does not point at the wp-audit-standards sections that carry the measurements"; exit 1; }
has 'it made LCP worse' "$flata" \
  || { echo "FAIL: $agent does not warn that inlining critical CSS measured worse on LCP before an agent proposes it"; exit 1; }

echo "PASS: the contention rule and the rejected inline-CSS experiment are recorded with their numbers, and the agent is sent to them"
