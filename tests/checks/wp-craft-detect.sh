#!/usr/bin/env bash
# Impeccable's detector is the deterministic half of the loop: 61 rules, no
# model, exit codes a build can act on. It is an external package this repo
# does not install, vendor or configure, so a missing binary, an offline
# machine or a rate-limited registry must never look like a clean scan — this
# pins the major-version guard (impeccable@1 404s; @4 is the real latest) and
# the distinct "could not run" message that keep that failure mode from
# passing as zero findings. It also pins the real finding shape: the tool has
# no P0 severity, only a category (slop/quality) and an advisory flag, and a
# nonzero exit does not by itself mean findings — exit 2 means findings, exit
# 1 means a target could not be scanned. If the command stops naming any of
# this, the refuse list that used to live in taste.md is enforced nowhere.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-demo-verify.md
d=commands/wp-demo.md

grep -Eq 'impeccable@4' "$c" || fail "$c does not pin the detector to the real major version (4, not the nonexistent 1)"
grep -Fq -- '--json' "$c" || fail "$c does not ask the detector for JSON"
grep -Fq 'impeccable.json' "$c" || fail "$c does not save detector findings under .verify"
grep -Fq 'slop' "$c" || fail "$c does not gate on the real 'slop' category"
# The advisory tier is documented by the tool but was never reproduced against
# this library, so the command must state it conditionally rather than as
# observed fact. Anchored to the conditional, not to the bare word: 'advisory'
# alone stays green if the hedge is deleted and the tier reasserted as certain.
grep -Fq 'if the tool emits an advisory tier' "$c" \
  || fail "$c states the advisory tier as observed fact instead of conditionally"
if grep -Fq 'P0' "$c"; then fail "$c still says P0, a severity impeccable never emits"; fi
grep -Fq 'demo/VERIFY.md' "$c" || fail "$c does not write the score card"
grep -Eqi 'external (package|dependency)' "$c" || fail "$c does not say the detector is an external dependency this repo does not vendor"
grep -Eqi 'could not run|could not be performed' "$c" || fail "$c does not fail loudly, and distinctly from zero findings, when the detector cannot run at all"
for line in 'First paint complete' 'One peak' 'Squint test' 'Contrast, read from the frame' 'Mobile headline' 'Adjacent feelings' 'Name-swap'; do
  grep -Fq "$line" "$c" || fail "$c rubric is missing: $line"
done
grep -Fq 'feel check' "$c" || fail "$c dropped the feel check that the old Step 4 required"
grep -Fq 'impeccable detect' "$d" || fail "$d does not run the detector inside the craft loop"

# The three kinds must be distinguishable in the walker itself, not just named in
# prose. `reveal` publishing nothing samplable is why dead-scroll fired on every
# library-built section; conflating that with real dead scroll is the defect.
v=bin/demo-verify.mjs
grep -Fq "kind: 'unobserved'" "$v" \
  || fail "$v does not emit an unobserved finding, so an unreadable section is still reported as dead"
grep -Fq "kind: 'no-engine'" "$v" \
  || fail "$v does not emit a no-engine finding, so a page with no devices still walks clean"
grep -Fq "data-motion') === 'reveal'" "$v" \
  || fail "$v does not sample the reveal device, so every reveal-only section reports dead scroll"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'unobserved' "$f" || fail "$f does not document the unobserved finding"
  grep -Fq 'no-engine' "$f" || fail "$f does not document the no-engine finding"
done

# A stall walk asks "did the signature change across N samples", which is the
# right question for a scrubbed device and the wrong shape for reveal: reveal is
# a one-shot entry transition a few pixels long, so a sparse walk catches it by
# luck and a miss is the false dead-scroll this whole finding exists to avoid.
# Reveal is judged by two samples instead, and the walk's own dead-scroll push
# must stay behind the scrubbed branch or the false positive comes straight back.
grep -Fq "const SCRUB = ['pin', 'pan', 'kinetic', 'wipe', 'drift']" "$v" \
  || fail "$v does not tell a scrubbed section from an entry-driven one, so both take the same sampling window"
grep -Fq 'revealState' "$v" \
  || fail "$v does not judge reveal by a two-point sample, so a sparse walk reports dead scroll on a section that reveals"
grep -Fq '} else if (b.scrub) {' "$v" \
  || fail "$v pushes dead-scroll from the walk for an entry-driven section, which is the false positive the two-point sample replaces"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'below the fold and fully entered' "$f" \
    || fail "$f does not document that a section with no scrubbed device is judged by two samples, not by the walk"
done

# Advisory has to mean advisory in the exit code, not only in prose: a round that
# fails on what the harness could not see is the false positive under another
# name. The split lives in one named set so a new advisory kind joins a list.
grep -Fq "const ADVISORY = new Set(['unobserved'])" "$v" \
  || fail "$v does not name its advisory kinds in one place, so the blocking rule is re-derived at the exit"
grep -Fq 'exitCode = blocking === 0 ? 0 : 1' "$v" \
  || fail "$v exits on the total finding count, so an advisory-only run still fails the round"
grep -Fq "' [advisory]'" "$v" \
  || fail "$v does not label advisory findings in the printed line, so a reader cannot see why a run with findings exited 0"
grep -Fq 'nothing blocking, ' "$v" \
  || fail "$v does not distinguish an advisory-only run from a run with nothing to report"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'advisory-only run exits 0' "$f" \
    || fail "$f does not document that an advisory-only run exits 0"
done
grep -Fq 'parallax' skills/wp-demo-craft/references/verify.md \
  || fail "skills/wp-demo-craft/references/verify.md does not record that parallax is left unjudged, so the limit reads as a bug"

echo PASS
