#!/usr/bin/env bash
# A craft build that fails verification must be unmistakable on disk and must
# stop every command that would build on it. Before v3.1 the only penalty was an
# unwritten fingerprint row — invisible to the client — so a build that failed
# five of seven rubric lines shipped with the shortfall as a footnote.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*" >&2; exit 1; }

d=commands/wp-demo.md
grep -Fq 'demo/FAILED.md' "$d" \
  || fail "$d never writes demo/FAILED.md, so a failed build is indistinguishable from a passing one"
grep -Fq 'is not a deliverable' "$d" \
  || fail "$d does not say a failed craft build is not a deliverable"

# Every command that builds on a demo must refuse a failed one.
for c in commands/wp-init.md commands/wp-section.md commands/wp-yolo.md; do
  grep -Fq 'demo/FAILED.md' "$c" \
    || fail "$c does not stop on demo/FAILED.md, so a theme can be built from an unverified demo"
done

# /wp-yolo carries its own copy of the craft verify loop (a craft /wp-yolo run
# never calls /wp-demo), so mentioning demo/FAILED.md on the consume side above
# is not enough — its own loop must produce the marker too, or a full-site
# build that fails its own three rounds still leaves nothing on disk.
grep -Fq 'write `demo/FAILED.md`' commands/wp-yolo.md \
  || fail "commands/wp-yolo.md's own craft loop does not write demo/FAILED.md, so a theme can still be built from a demo that failed /wp-yolo's own verify loop"

# The marker's inverse. Nothing else on disk deletes it, so a loop that does not
# clear it at its top makes the marker one-way: /wp-yolo writes it at Step 2.6 and
# then refuses itself at its own Step 0, and a build that failed, was fixed and
# then passed stays refused by three commands forever. Anchored on the literal
# command rather than on prose about clearing, because a rewording of the sentence
# must not be able to satisfy this while the deletion itself is gone — and required
# in both entry points, since a craft /wp-yolo run never calls /wp-demo.
for c in commands/wp-demo.md commands/wp-yolo.md skills/wp-demo-craft/references/verify.md; do
  grep -Fq 'rm -f demo/FAILED.md' "$c" \
    || fail "$c never clears demo/FAILED.md, so the marker is a one-way latch: a build that failed, was fixed and now passes stays refused, and /wp-yolo can never re-enter its own Step 0 gate"
done
# Clearing on success instead of at the top would leave the marker describing a
# past run whenever a later loop fails differently, so the deletion has to be the
# loop's first act.
grep -Fq 'Clear the marker before the first round' commands/wp-demo.md \
  || fail "commands/wp-demo.md does not clear demo/FAILED.md before the first round, so the marker can describe a run other than the last one"

v=commands/wp-demo-verify.md
grep -Fq '## Round N' "$v" \
  || fail "$v does not require a per-round heading, so rounds cannot be counted from disk"
grep -Fq 'Findings judged to be capture artefacts' "$v" \
  || fail "$v does not require dismissals to be written under a named heading with measurements"

echo PASS
