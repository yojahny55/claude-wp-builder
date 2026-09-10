#!/usr/bin/env bash
# The evaluator rubric is the half of verification a machine cannot do, made
# checkable: seven named lines, pass/fail each, three rounds, and no fingerprint for
# a failing build. Losing any line silently returns craft mode to shipping blind —
# the machine reports green on dead scroll and overflow while the page still opens
# on an empty dark field with a headline clipped mid-word. The seven line names are
# quoted verbatim by commands/wp-demo-verify.md, so renaming one here breaks that
# command's score card without any file failing to parse.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

v=skills/wp-demo-craft/references/verify.md
[ -f "$v" ] || fail "$v is missing"

for line in 'First paint complete' 'One peak' 'Squint test' 'Contrast, read from the frame' \
            'Mobile headline' 'Adjacent feelings' 'Name-swap'; do
  grep -Fq "$line" "$v" || fail "verify.md rubric is missing the line: $line"
done

grep -Fq 'three rounds' "$v" || fail "verify.md does not cap the loop at three rounds"
grep -Fq 'demo/VERIFY.md' "$v" || fail "verify.md does not write the score card to demo/VERIFY.md"
grep -Eqi 'no fingerprint|does not record a fingerprint' "$v" \
  || fail "verify.md lets a failing build record a fingerprint"
grep -Eq 'impeccable@[0-9]+ detect' "$v" || fail "verify.md does not run a version-pinned impeccable detect"
grep -Fq 'slop' "$v" || fail "verify.md does not fail the round on a slop finding"
if grep -Fq 'P0' "$v"; then fail "verify.md still says P0, a severity impeccable never emits"; fi
grep -Eqi 'only the (screenshots|sheets)' "$v" \
  || fail "verify.md does not restrict the evaluator to the sheets"
grep -Fq '4.5:1' "$v" || fail "verify.md does not state the measured contrast floor"
grep -Fq 'three lines' "$v" || fail "verify.md does not cap the mobile headline at three lines"

# The count where it is actually acted on. commands/wp-demo.md Step 7 dispatches the
# critique as a subagent and hands it "the N rubric lines" — that sentence is the only
# thing on the /wp-demo path telling the evaluator how many lines to grade, and no other
# check reads that file for the rubric. It said "six" for a release after the seventh
# line landed, so Name-swap was never graded there. Assert the number, and refuse any
# other count word rather than only the one that was wrong.
c=commands/wp-demo.md
[ -f "$c" ] || fail "$c is missing"
grep -Fq 'the seven rubric lines' "$c" \
  || fail "$c does not hand the evaluator all seven rubric lines"
grep -Eqi 'the (one|two|three|four|five|six|eight|nine|ten) rubric lines' "$c" \
  && fail "$c states a rubric line count other than seven"

echo PASS
