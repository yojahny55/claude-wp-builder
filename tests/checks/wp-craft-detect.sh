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

echo PASS
