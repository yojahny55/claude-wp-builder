#!/usr/bin/env bash
# Prose contracts of three commands:
#  - /wp-finalize: the example report must add up (PASS/FAIL/SKIP lines match the Result line,
#    one issue per FAIL), list the parity layers, and not promise a run without a manifest,
#    because exit 3 of the manifest gate is the `stop` policy.
#  - /wp-create: when wp-config.php and .wp-create.json both exist, the order is explicit, and
#    Overwrite exports the database and asks for confirmation before core download / db create.
#  - /wp-seed: names its own exit-3 policy, not "the way /wp-debug does".
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
has() { [ "$(printf '%s\n' "$1" | grep -Fxc -- "$2")" -gt 0 ]; }
hasp() { [ "$(printf '%s\n' "$1" | grep -Fc -- "$2")" -gt 0 ]; }
err() { echo "FAIL: $*"; fail=1; }

fin=commands/wp-finalize.md
rep=$(awk '/^=== WP Finalize Report ===/{on=1} on&&/^```/{exit} on' "$fin")
[ -n "$rep" ] || err "$fin has no example report"
p=$(printf '%s\n' "$rep" | grep -c '^\[PASS\]' || true)
f=$(printf '%s\n' "$rep" | grep -c '^\[FAIL\]' || true)
s=$(printf '%s\n' "$rep" | grep -c '^\[SKIP\]' || true)
issues=$(printf '%s\n' "$rep" | grep -c '^[0-9]\+\. ' || true)
want="Result: $p/$((p + f)) checks passed — $f failed, $s skipped"
has "$rep" "$want" || err "$fin example counts $p PASS, $f FAIL, $s SKIP but its Result line is not: $want"
[ "$issues" = "$f" ] || err "$fin example lists $issues issues for $f FAIL"
for l in 'Layer 1' 'Layer 2' 'Layer 3'; do
  hasp "$rep" "Demo-parity $l" || err "$fin example omits the parity $l gate"
done
grep -Fq '**Exit `3` policy:** `stop`' "$fin" || err "$fin does not name the stop policy for exit 3"
! grep -Eq 'without \.wp-create\.json|if there is also no \.wp-create\.json|Skipped if \.wp-create\.json' "$fin" \
  || err "$fin still describes a run without .wp-create.json"
! grep -Fq 'Check 7: WP-CLI Runtime Validation (when' "$fin" || err "$fin makes Check 7 conditional on the manifest"

cr=commands/wp-create.md
grep -Fq '**Order when both exist:** 2b wins' "$cr" || err "$cr has no 2a/2b order rule"
ow=$(grep -F -- '- **Overwrite:**' "$cr" || true)
for t in 'db export' 'never under the WordPress root' 'confirm' 'database and core' 'no 4.2'; do
  hasp "$ow" "$t" || err "$cr Overwrite does not say: $t"
done

sd=commands/wp-seed.md
grep -Fq 'apply the `bare-wp-fallback` policy' "$sd" || err "$sd does not name its own policy in the fallback"
! grep -Fq 'the same way `/wp-debug` does' "$sd" || err "$sd still borrows /wp-debug's fallback"

[ "$fail" = 0 ] && echo PASS || exit 1
