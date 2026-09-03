#!/usr/bin/env bash
# The craft skill is the plugin's design floor. Every assertion below pins a rule whose
# absence silently returns demo output to the generic AI look this skill exists to refuse:
# a check that only asserted "the file exists" would pass on an empty stub.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-demo-craft/SKILL.md
r=skills/wp-demo-craft/references

for f in "$s" "$r/taste.md" "$r/feel.md" "$r/grammars.md" "$r/devices.md" \
         "$r/fingerprint.md" "$r/verify.md"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- Frontmatter: skills inform, they never act. -----------------------------
awk 'NR<=8 && /^user-invocable: false/ { f = 1 } END { exit !f }' "$s" \
  || fail "$s does not declare user-invocable: false"
awk 'NR<=8 && /^name: wp-demo-craft/ { f = 1 } END { exit !f }' "$s" \
  || fail "$s frontmatter name is not wp-demo-craft"

# --- Attribution. The prose is ported; the licence travels with it. ----------
grep -Fq 'Adapted from nateherkai/scroll-craft (MIT)' "$s" \
  || fail "$s does not credit scroll-craft"

# --- The variety law. Without it every section becomes the same section. -----
grep -Eqi 'four device families' "$s" \
  || fail "$s does not require at least four device families"
grep -Eqi 'never the same device' "$s" \
  || fail "$s does not forbid the same device in adjacent sections"

# --- The refuse list. Each entry is a recognisable AI-page tell. -------------
for t in 'identical' '01 / 06' 'scroll cue' 'gradient text' 'em dash' \
         'invented statistic' 'cream' 'Inter'; do
  grep -Fqi "$t" "$r/taste.md" || fail "taste.md refuse list is missing: $t"
done
grep -Eqi 'purple|violet' "$r/taste.md" || fail "taste.md does not refuse the AI-purple palette"

# --- Measured floor, not vibes. A floor with no numbers is a preference. -----
grep -Fq '45' "$r/taste.md" || fail "taste.md does not state the 45-75ch measure floor"
grep -Fq '4.5:1' "$r/taste.md" || fail "taste.md does not state the contrast floor"
grep -Fq '300ms' "$r/taste.md" || fail "taste.md does not cap UI transition duration"
grep -Eqi 'transform and opacity|transform.*opacity only' "$r/taste.md" \
  || fail "taste.md does not restrict continuous animation to transform/opacity"

# --- The emotion axis. -------------------------------------------------------
grep -Eqi 'one engineered peak' "$r/feel.md" || fail "feel.md does not require one engineered peak"
grep -Fqi "it's the site where" "$r/feel.md" || fail "feel.md is missing the tell-someone sentence"
grep -Eqi 'adjacent' "$r/feel.md" || fail "feel.md does not flag adjacent same-feeling sections as filler"
grep -Eqi 'cold|before looking|do not reread' "$r/feel.md" \
  || fail "feel.md does not require the feel check to be run cold"

echo PASS
