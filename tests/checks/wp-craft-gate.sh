#!/usr/bin/env bash
# The gate is the whole difference between v1 and v2: a craft build that cannot
# render stops. The last failed build shipped because verification exited 2 and
# nobody noticed.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=commands/wp-demo.md
grep -Fq -- 'demo-verify.mjs" --probe' "$d" || fail "$d does not run the probe"
grep -Eqi 'exit(s| code)? 2' "$d" || fail "$d does not branch on probe exit 2"
grep -Fq 'npm i -D playwright-core' "$d" || fail "$d does not try to install playwright-core"
# Anchored to the gate itself: a bare 'stop' is satisfied by the verify loop's
# own stop-after-three-rounds, which would leave this check green with Step 0
# deleted outright.
grep -Fq 'probe again' "$d" || fail "$d does not retry the probe after installing playwright-core"
grep -Fq 'way **stop**' "$d" || fail "$d does not stop on a missing browser"
# The second alternative this used to carry, 'any other exit code', is wrapped
# across a line break in the prose ("...any other exit\n   code...") and a
# single-line grep can never match it; it worked only because this first
# alternative already does. Dropped rather than fixed to span the wrap: this
# phrase alone already states the rule the fail message names.
grep -Fq 'only exit 0 continues' "$d" || fail "$d proceeds to build when the probe fails in any way other than exit 2"
grep -Eqi 'never fall(s)? back to plain|not fall back to plain' "$d" || fail "$d may still fall back to plain"
grep -Fq 'demo/DESIGN.md' "$d" || fail "$d does not write demo/DESIGN.md"
grep -Fq 'designlang' "$d" || fail "$d does not run designlang on the client's site"
grep -Fq 'design-md/INDEX.md' "$d" || fail "$d does not read the catalogue index"
grep -Fq 'compositions/README.md' "$d" || fail "$d does not plan from the composition role table"
grep -Fq 'data-motion-peak' "$d" || fail "$d does not mark the peak"
grep -Eqi 'three rounds' "$d" || fail "$d does not cap the loop"
# The loop must walk the directory: an index-only walk is how empty interior
# pages shipped, and it is also why the build step must name them.
grep -Fq '/wp-demo-verify demo/' "$d" || fail "$d verifies a single page instead of walking demo/"
grep -Fq 'one file per page' "$d" || fail "$d does not tell a craft build to write the interior pages"
grep -Eqi 'Steps 3 and 4 are the plain path' "$d" || fail "$d does not resolve what a craft build takes from Steps 3 and 4"
grep -Fq 'as a subagent' "$d" || fail "$d grades its own render instead of dispatching the critique"
grep -Fq 'demo/VERIFY.md' "$d" || fail "$d does not read the score card"
grep -Eqi 'no fingerprint|not record' "$d" || fail "$d records a fingerprint for a failing build"
grep -Fq '"design_md"' "$d" || fail "$d does not record design_md in the manifest"
grep -Fq 'firecrawl_url' "$d" || fail "$d does not document firecrawl_url"
grep -Eqi 'four device families|never the same device|signature move' "$d" && fail "$d still carries a removed v1 rule"

# The same gate through the other entry point. /wp-yolo in craft mode never calls
# /wp-demo, so nothing in /wp-demo.md above reaches a yolo run: without these the
# multi-page path builds craft blind, which is exactly how the 12,000px page with
# an empty first screen shipped. The only verification a yolo run otherwise reaches
# is /wp-responsive-check, whose findings are folded into a review list, not a gate.
y=commands/wp-yolo.md
grep -Fq -- 'demo-verify.mjs" --probe' "$y" || fail "$y does not run the probe in craft mode"
grep -Fq 'only exit 0 continues' "$y" || fail "$y proceeds to build when the craft probe fails"
grep -Fq 'Either way **stop**' "$y" || fail "$y does not stop the run on a missing browser"
grep -Eqi 'never fall(s)? back to plain|not fall back to plain' "$y" || fail "$y may still fall back to plain"
# Anchored to the consequence, not to the bare number: 'three rounds' on its own
# would stay green if the loop kept counting but never stopped.
grep -Fq 'after three rounds with failures' "$y" || fail "$y does not cap the craft verify loop at three rounds"
grep -Fq 'demo/VERIFY.md' "$y" || fail "$y does not read the score card"
grep -Fq '/wp-demo-verify demo/' "$y" || fail "$y verifies a single page instead of walking demo/"

# The same-client rule: a repeat client cannot be handed back the structure they
# rejected. Structure stays uncompared across clients (v1's six axes stay retired);
# this only binds when a row already exists for the same client.
#
# This is a refusal ("must differ", "is not an answer"), not a heading-presence
# check, so a bare grep -Fq is not enough: a build under pressure writes exactly
# the negation that keeps the anchor substring while discharging the obligation
# ("...unless the client has approved the reuse."). Three defenses, each aimed at
# a different escape:
#   1. The heading is anchored to the whole line, not a substring of it — a
#      negating rewrite of the heading itself ("...does not apply") no longer
#      equals the line, where a bare substring match would still find it.
#   2. Both checks are scoped to their own section/sub-step, extracted with awk,
#      so the anchor cannot be satisfied by parking it in unrelated prose
#      elsewhere in the file while the real instruction is deleted.
#   3. Alongside the positive anchor, a negative check fails the section on
#      excuse vocabulary ("unless", "not required", "may say how, where it is
#      material", ...) — the shape that let Task 6's ship blocker invert to
#      "...is acceptable in rounds one and two" while its check stayed green.
excuse_vocab='unless|except|need not|not required|no longer required|does not apply|is optional|is fine|acceptable|may match|only if|approved the reuse|not necessary|may say how|where it is material|not true|not the case|false that|is wrong that'

fp=skills/wp-demo-craft/references/fingerprint.md
grep -Eq '^## The same-client rule$' "$fp" \
  || fail "fingerprint.md has no same-client rule, so a repeat client can get the prior structure back"
same_client_section=$(awk '/^## The same-client rule$/{f=1;next} /^## /{f=0} f' "$fp")
[ -n "$same_client_section" ] \
  || fail "fingerprint.md's same-client rule heading has no body beneath it"
grep -Fq 'differ in grammar and in the hero composition' <<<"$same_client_section" \
  || fail "fingerprint.md does not say what a repeat build must differ in"
grep -Fq 'composition plan must say how' <<<"$same_client_section" \
  || fail "fingerprint.md does not require the plan to say how a repeat build differs"
grep -Eiq "$excuse_vocab" <<<"$same_client_section" \
  && fail "fingerprint.md's same-client rule carries an excuse clause a repeat build could reach for"

d=commands/wp-demo.md
fp_gate_section=$(awk '/^2\. \*\*Fingerprint gate\.\*\*/{f=1} /^3\. \*\*Brief\.\*\*/{f=0} f' "$d")
[ -n "$fp_gate_section" ] \
  || fail "$d has no Step 2.6 sub-step 2 (the fingerprint gate)"
grep -Fq 'is not an answer' <<<"$fp_gate_section" \
  || fail "$d does not require the plan to say how a repeat build differs"
grep -Fq 'the plan states how' <<<"$fp_gate_section" \
  || fail "$d does not require the plan to say how a repeat build differs"
grep -Eiq "$excuse_vocab" <<<"$fp_gate_section" \
  && fail "$d's fingerprint gate carries an excuse clause that lets a repeat build skip saying how it differs"

echo PASS
