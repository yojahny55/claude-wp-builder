#!/usr/bin/env bash
# The evaluator rubric is the half of verification a machine cannot do, made
# checkable: six named lines, pass/fail each, three rounds, and no fingerprint for
# a failing build. Losing any line silently returns craft mode to shipping blind —
# the machine reports green on dead scroll and overflow while the page still opens
# on an empty dark field with a headline clipped mid-word. The six line names are
# quoted verbatim by commands/wp-demo-verify.md, so renaming one here breaks that
# command's score card without any file failing to parse.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

v=skills/wp-demo-craft/references/verify.md
[ -f "$v" ] || fail "$v is missing"

for line in 'First paint complete' 'One peak' 'Squint test' 'Measured contrast' \
            'Mobile headline' 'Adjacent feelings'; do
  grep -Fq "$line" "$v" || fail "verify.md rubric is missing the line: $line"
done

grep -Fq 'three rounds' "$v" || fail "verify.md does not cap the loop at three rounds"
grep -Fq 'demo/VERIFY.md' "$v" || fail "verify.md does not write the score card to demo/VERIFY.md"
grep -Eqi 'no fingerprint|does not record a fingerprint' "$v" \
  || fail "verify.md lets a failing build record a fingerprint"
grep -Fq 'impeccable detect' "$v" || fail "verify.md does not run impeccable detect"
grep -Fq 'P0' "$v" || fail "verify.md does not fail the round on a P0"
grep -Eqi 'only the (screenshots|sheets)' "$v" \
  || fail "verify.md does not restrict the evaluator to the sheets"
grep -Fq '4.5:1' "$v" || fail "verify.md does not state the measured contrast floor"
grep -Fq 'three lines' "$v" || fail "verify.md does not cap the mobile headline at three lines"

echo PASS
