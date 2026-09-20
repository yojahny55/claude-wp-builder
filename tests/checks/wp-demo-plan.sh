#!/usr/bin/env bash
# The demo plan: /wp-demo records its own section decisions, wp-normalize trusts
# them per page, /wp-yolo says so, and a hand-edited page still gets classified.
set -euo pipefail

d=commands/wp-demo.md
n=agents/wp-normalize.md
y=commands/wp-yolo.md
for f in "$d" "$n" "$y"; do test -f "$f" || { echo "FAIL: $f missing"; exit 1; }; done

# /wp-demo writes it, in both modes, with the decided keys and not the read ones.
grep -q 'Step 4.9' "$d" || { echo "FAIL: wp-demo has no Step 4.9"; exit 1; }
for token in '\.demo-plan\.json' '"generator": "wp-demo"' 'cpt-teaser' '"block"' 'verbatim'; do
  grep -Eq "$token" "$d" || { echo "FAIL: wp-demo missing '$token'"; exit 1; }
done
# The plan must not claim to carry what only the markup can answer.
grep -Eq 'Keys deliberately absent.*' "$d" || { echo "FAIL: wp-demo does not state the absent keys"; exit 1; }
grep -Eq 'then write Step 4\.9' "$d" || { echo "FAIL: craft path does not reach Step 4.9"; exit 1; }

# wp-normalize reads it, skips the rubric, and keeps the trust boundary.
for token in '\.demo-plan\.json' 'skip the Classifier Rubric' 'Trust it per page' 'unparseable'; do
  grep -Eq "$token" "$n" || { echo "FAIL: wp-normalize missing '$token'"; exit 1; }
done
# It still does the markup reading — the plan is not a substitute for the manifest.
grep -Eq 'cssRules.*backgrounds.*fonts|fonts.*backgrounds' "$n" || { echo "FAIL: wp-normalize drops fidelity capture on the plan path"; exit 1; }

# inert[]: declared while authoring, graded as a declaration, read as a worklist.
grep -Eq '"inert"' "$d" || { echo "FAIL: wp-demo does not write inert[]"; exit 1; }
grep -Eq 'Write it while authoring, or do not write it' "$d" || { echo "FAIL: wp-demo does not forbid backfilling inert[]"; exit 1; }
grep -Eq 'Grade the declaration, never the control' commands/wp-demo-verify.md || { echo "FAIL: verify grades the control"; exit 1; }
grep -Eq 'inert\[\]' "$y" || { echo "FAIL: wp-yolo does not read inert[] as a worklist"; exit 1; }
grep -Eq 'Never transcribe the demo.s switcher markup' commands/wp-header.md || { echo "FAIL: wp-header may still transcribe a mock switcher"; exit 1; }
# A form with no action is inert too, and it is the one that costs a lead.
grep -Eq 'action="#". or no .action. is inert' "$d" || { echo "FAIL: wp-demo does not count a dead form as inert"; exit 1; }
# The switcher heuristic must key off the href, not off hreflang/aria-current.
grep -Eq 'the proof is the .href., never the trappings' commands/wp-header.md || { echo "FAIL: wp-header switcher test could read hreflang as proof"; exit 1; }

# /wp-yolo states it, and states that normalize still runs.
grep -Eq '\.demo-plan\.json' "$y" || { echo "FAIL: wp-yolo does not mention the plan"; exit 1; }
grep -Eq 'still dispatched rather than skipped' "$y" || { echo "FAIL: wp-yolo does not say normalize still runs"; exit 1; }

echo PASS
