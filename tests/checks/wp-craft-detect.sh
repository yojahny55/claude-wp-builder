#!/usr/bin/env bash
# Impeccable's detector is the deterministic half of the loop: 61 rules, no
# model, exit codes a build can act on. It is an external package this repo
# does not install, vendor or configure, so a missing binary, an offline
# machine or a rate-limited registry must never look like a clean scan — this
# pins the major-version guard and the distinct "could not run" message that
# keep that failure mode from passing as zero findings. If the command stops
# naming any of this, the refuse list that used to live in taste.md is
# enforced nowhere.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-demo-verify.md
d=commands/wp-demo.md

grep -Eq 'impeccable@[0-9]+ detect' "$c" || fail "$c does not run a major-version-pinned impeccable detect"
grep -Fq -- '--json' "$c" || fail "$c does not ask the detector for JSON"
grep -Fq 'impeccable.json' "$c" || fail "$c does not save detector findings under .verify"
grep -Fq 'P0' "$c" || fail "$c does not fail on a P0"
grep -Fq 'demo/VERIFY.md' "$c" || fail "$c does not write the score card"
grep -Eqi 'external (package|dependency)' "$c" || fail "$c does not say the detector is an external dependency this repo does not vendor"
grep -Eqi 'could not run|could not be performed' "$c" || fail "$c does not fail loudly, and distinctly from zero findings, when the detector cannot run at all"
for line in 'First paint complete' 'One peak' 'Squint test' 'Measured contrast' 'Mobile headline' 'Adjacent feelings'; do
  grep -Fq "$line" "$c" || fail "$c rubric is missing: $line"
done
grep -Fq 'feel check' "$c" || fail "$c dropped the feel check that the old Step 4 required"
grep -Fq 'impeccable detect' "$d" || fail "$d does not run the detector inside the craft loop"

echo PASS
