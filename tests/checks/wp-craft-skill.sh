#!/usr/bin/env bash
# wp-demo-craft as a skill: what an agent reads first, and when it reads the rest.
#
# The References section used to be one fixed reading order — every build read all
# thirteen files (about 37k tokens, devices.md alone 37 KB) before writing markup, and
# only one file said when it was needed. domains.csv was named nowhere, so the "domain
# signal" the plan requires had no defined source. The seven-dimension table lived in
# uniqueness.md while fingerprint.md, which owns the gate, sent readers there. The skill
# never said which commands run its order of work, or which parts a cinematic build takes.
# The manifest's "fingerprint" write had no field names. image-gen.mjs was relied on
# with no invocation or exit codes. And stale wording ("current latest", "until v3.1")
# rotted in place.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

K=skills/wp-demo-craft
S=$K/SKILL.md
R=$K/references
[ -f "$S" ] || fail "$S is missing"

# --- every reference has a row with a read-when cell --------------------------------
refs=$(awk '/^## References/{p=1} p' "$S")
[ -n "$refs" ] || fail "$S has no References section"
for f in "$R"/*.md "$K/compositions/README.md" "$R/domains/domains.csv" "$R/design-md/INDEX.md"; do
  rel=${f#"$K/"}
  row=$(printf '%s\n' "$refs" | grep '^|' | grep -F "| \`$rel\` |" | head -1 || true)
  [ -n "$row" ] || fail "$S's References table has no row for $rel"
  cells=$(printf '%s' "$row" | awk -F'|' '{print NF-2}')
  [ "$cells" -eq 3 ] || fail "$S's row for $rel is not file | what it holds | read when"
  when=$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
  [ -n "$when" ] || fail "$S gives $rel no read-when condition"
done
printf '%s\n' "$refs" | grep -Eq '^Read `references/taste.md` \(the floor\), then' \
  && fail "$S is back to one fixed reading order"

# --- the recorded decision, the runners, the cinematic scope ------------------------
grep -Fq 'read it, do not re-derive it' "$S" || fail "$S does not read the recorded demo mode"
grep -Fq '`/wp-demo` Step 2.6 and `/wp-yolo` Step 2' "$S" || fail "$S does not name the commands that run its order of work"
grep -Fq 'A **cinematic** build' "$S" || fail "$S does not say which parts a cinematic build takes"
grep -Eq '^- \[ \] 1\. demo/DESIGN.md' "$S" || fail "$S's order of work has no checklist to copy"
grep -Fq 'two distinct' "$S" || fail "$S does not say what domain classification produces"

# --- the description finds the skill ------------------------------------------------
desc=$(awk 'NR<=6 && /^description:/' "$S")
for t in DESIGN.md BRIEF.md data-motion fingerprint 'Avoid list' /wp-polish 'Not for plain-mode demos'; do
  printf '%s' "$desc" | grep -Fq -- "$t" || fail "$S's description does not name $t"
done

# --- one copy of the gate's table, with the manifest shape ---------------------------
grep -Fq '| 4 | Section-sequence shape |' "$R/fingerprint.md" || fail "$R/fingerprint.md does not carry the seven-dimension table"
grep -Fq '"fingerprint": {' "$R/fingerprint.md" || fail "$R/fingerprint.md does not give the manifest's fingerprint keys"
for k in client grammar chrome hero sequence close signature display text accent canvas date; do
  grep -Fq "\"$k\":" "$R/fingerprint.md" || fail "$R/fingerprint.md's manifest shape lacks the $k column"
done

# --- the generator is run, with its contract ------------------------------------------
ip=$R/image-prompt.md
grep -Fq 'node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" plan --demo demo/' "$ip" || fail "$ip does not give the plan invocation"
grep -Fq 'node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" run --demo demo/' "$ip" || fail "$ip does not give the run invocation"
for code in '`2` the plan was' '`3` no API key' '`4` one or more slots failed'; do
  grep -Fq "$code" "$ip" || fail "$ip does not state exit code: $code"
done
grep -Fq "Exit codes: 0 clean, 2 the plan was refused" bin/image-gen.mjs \
  || fail "bin/image-gen.mjs changed its exit codes; re-check $ip"

# --- devices.md: the Contents list names every subsection -----------------------------
contents=$(awk '/^## Contents/{p=1;next} p && /^## /{exit} p' "$R/devices.md")
while IFS= read -r h; do
  printf '%s\n' "$contents" | grep -Fq -- "$h" || fail "$R/devices.md's Contents omits the subsection: $h"
done < <(awk '/^## Two kinds of motion/{p=1;next} p && /^## /{exit} p && /^### /{sub(/^### /,""); print}' "$R/devices.md")

# --- nothing goes stale with the calendar -----------------------------------------------
grep -nE 'current latest|until v[0-9]|for several releases|published this year|until recently|until now' \
  "$S" "$R"/*.md "$K/compositions/README.md" && fail "a craft file carries wording that goes stale with the calendar"

echo PASS
