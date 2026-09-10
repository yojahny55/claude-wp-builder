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
# The other half of the split, and the one that costs more when it is wrong:
# drive() is required to publish --motion-p for the SCRUB devices, so a stalled
# section carrying one with nothing samplable is an engine that never ran, not a
# device the harness cannot read. Routing that to advisory shipped a broken page
# green — the exact file://-blocked-module failure this branch exists to fix.
grep -Fq 'frame.samplable === 0 && !b.scrub' "$v" \
  || fail "$v routes a scrubbed section with nothing samplable to advisory, so a page whose motion engine never ran exits 0"
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
# Anchored on the call site and its consequence, never on the identifier: the
# whole two-point block was once deleted with the function left defined, and a
# `grep -Fq revealState` stayed green while dead-scroll-for-reveal ceased to
# exist. The second sample proves the block is called twice; the -A1 pair proves
# the comparison still pushes a finding when the two samples match.
grep -Fq 'const after = await page.evaluate(revealState, b.idx);' "$v" \
  || fail "$v does not take the second reveal sample, so the two-point check cannot run and a sparse walk reports dead scroll on a section that reveals"
grep -A1 -F 'if (after === before)' "$v" | grep -Fq "kind: 'dead-scroll'" \
  || fail "$v does not report dead-scroll when both reveal samples match, so a reveal that never fires walks clean"
# The predicate itself. Comparing computed opacity/transform let a decorative
# @keyframes on the reveal's own children counterfeit a live reveal; only a
# ViewTimeline-driven animation is the device's contract. `none` is what keeps an
# unwired reveal from returning '' and being skipped by the `before !== ''` guard.
grep -Fq 'a.timeline instanceof ViewTimeline' "$v" \
  || fail "$v judges reveal by computed style, so ambient motion on the same children spoofs a section with no reveal wired at all"
grep -Fq "out.push('none')" "$v" \
  || fail "$v returns an empty reveal state for a child with no scroll-driven animation, so an unwired reveal is skipped instead of reported"
# The block's own guard, pinned by polarity AND by what it gates. Inverting one
# character (`!b.scrub` → `b.scrub`) or wrapping the condition in `false &&`
# leaves both assertions above matching — the two samples are still adjacent and
# intact — while reveal detection disappears entirely and deadreveal/falsealive
# drop to exit 0. Anchoring the first sample under the exact condition is what
# makes either edit fail here by name.
grep -A3 -F 'if (!b.scrub && !reduced && belowFold >= 0) {' "$v" \
  | grep -Fq 'const before = await page.evaluate(revealState, b.idx);' \
  || fail "$v does not gate the two-point reveal check on exactly '!b.scrub && !reduced && belowFold >= 0' with the first sample inside it, so inverting or disabling that guard silently switches reveal detection off"
# The GSAP fallback path. motion.js drives reveal with rAF tweens when the
# browser has no view(), and those are invisible to getAnimations(), so the
# predicate must return the unjudged sentinel there rather than read none|none
# and call a working section dead.
grep -Fq "CSS.supports('animation-timeline', 'view()')" "$v" \
  || fail "$v judges reveal on a browser with no view(), where motion.js drives it in GSAP and getAnimations() sees nothing, so a working section is reported dead"
grep -Fq "animation-timeline', 'view()" skills/wp-demo-craft/references/verify.md \
  || fail "skills/wp-demo-craft/references/verify.md does not record that reveal is unjudged without view() support, so the limit reads as a bug"
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
  # The artifact has to be self-describing, or every consumer carries its own
  # copy of the kind list and that copy goes stale when a kind joins ADVISORY.
  grep -Fq '"advisory": true' "$f" \
    || fail "$f does not document the advisory flag on findings.json rows, so a consumer has to match on the kind instead"
  grep -Fq 'page-wide judgments, printed per section' "$f" \
    || fail "$f still reads as if unobserved/no-engine were per-section facts; both counters come from a document-wide query"
done
grep -Fq 'f.advisory = true' "$v" \
  || fail "$v writes findings.json without the advisory flag, so the label exists only on stdout"
# The command contradicted itself: an exit-code line that predates the advisory
# split, three lines from the line that documents it.
if grep -Fq '`0` no machine findings, `1` findings printed' commands/wp-demo-verify.md; then
  fail "commands/wp-demo-verify.md still documents the pre-advisory exit codes, contradicting its own advisory-only-run line"
fi
grep -Fq 'Fold every **blocking** finding' commands/wp-yolo.md \
  || fail "commands/wp-yolo.md folds every finding into the fix list, advisory ones included, so the split it consumes does not reach the one command that acts on it"
grep -Fq 'parallax' skills/wp-demo-craft/references/verify.md \
  || fail "skills/wp-demo-craft/references/verify.md does not record that parallax is left unjudged, so the limit reads as a bug"

echo PASS
