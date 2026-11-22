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
for d in docs/commands.md docs/workflows.md skills/wp-finalize-run/SKILL.md; do
  [ "$(tr '\n' ' ' < "$d" | grep -Ec 'runtime checks[^.]{0,60}when `.wp-create.json` exists')" = 0 ] || err "$d still conditions finalize runtime checks on the manifest"
  [ "$(tr '\n' ' ' < "$d" | grep -Fc 'without `.wp-create.json` or a demo')" = 0 ] || err "$d still says finalize runs without a manifest"
done
! grep -Fq 'Check 7: WP-CLI Runtime Validation (when' "$fin" || err "$fin makes Check 7 conditional on the manifest"

cr=commands/wp-create.md
ref=skills/wp-create-run/references/overwrite.md
grep -Fq '**Order when both exist:** 2b wins, and Adopt Mode never applies' "$cr" || err "$cr has no 2a/2b order rule"
grep -Fq 'and there is no `.wp-create.json`, enter **Adopt Mode**' "$cr" || err "$cr 2a still enters Adopt Mode with a manifest present"
ow=$(grep -F -- '- **Overwrite:**' "$cr" || true)
for t in 'never Adopt Mode' 'no yes, no 4.2 and no 4.4'; do
  hasp "$ow" "$t" || err "$cr Overwrite does not say: $t"
done
grep -Fq 'references/overwrite.md` now and follow it first' "$cr" || err "$cr 4.2 does not send Overwrite to its reference"
grep -Fq '`core download --force`' "$cr" || err "$cr Overwrite does not use core download --force"
grep -Fq 'db reset --yes' "$cr" || err "$cr 4.4 does not reset the database on Overwrite"
[ -r "$ref" ] || err "$ref is missing"
body=$(cat "$ref" 2>/dev/null || true)
for t in 'mkdir -p ~/wp-create-backups' 'db export -' 'to the host' 'Unknown database' 'start them' 'Any other failure: stop' \
  'naming only what this environment will really replace' 'Without an explicit yes, stop' 'db reset --yes' 'never Adopt Mode' 'core download --force'; do
  hasp "$body" "$t" || err "$ref does not say: $t"
done
# export and confirmation come before the replace step
e=$(grep -n 'Export, to the host' "$ref" | sed -n 1p | cut -d: -f1); c=$(grep -n '\*\*Confirm' "$ref" | sed -n 1p | cut -d: -f1); r=$(grep -n '\*\*Replace' "$ref" | sed -n 1p | cut -d: -f1)
[ -n "$e" ] && [ -n "$c" ] && [ -n "$r" ] && [ "$e" -lt "$c" ] && [ "$c" -lt "$r" ] || err "$ref does not order export, confirm, replace"

sd=commands/wp-seed.md
pol=$(sed -n 's/^\*\*Exit `3` policy:\*\* `\([a-z-]*\)`.*/\1/p' "$sd" | sed -n 1p)
[ -n "$pol" ] || err "$sd has no Exit 3 policy line"
grep -Fq "apply the \`$pol\` policy" "$sd" || err "$sd fallback does not cite its own policy ($pol)"
! grep -Fq 'the same way `/wp-debug` does' "$sd" || err "$sd still borrows /wp-debug's fallback"

[ "$fail" = 0 ] && echo PASS || exit 1
