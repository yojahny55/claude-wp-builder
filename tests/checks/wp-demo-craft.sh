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

# --- Grammars. The forbids are the point: a grammar that only says what it
#     likes is a preference, and a preference drifts back to the default shape.
for gname in 'layered landing' 'chaptered editorial' 'typographic poster' \
             'gallery' 'split stage' 'rhythmic cutlist'; do
  grep -Fqi "$gname" "$r/grammars.md" || fail "grammars.md is missing the grammar: $gname"
done
grep -Eqi 'forbid' "$r/grammars.md" || fail "grammars.md does not state what each grammar forbids"
grep -Eqi 'cinematic' "$r/grammars.md" \
  || fail "grammars.md does not route the video grammars to the cinematic path"

# --- The device kit and its attribute contract. -----------------------------
for d in reveal pin pan wipe kinetic parallax count drift; do
  grep -Fq "\`$d\`" "$r/devices.md" || fail "devices.md is missing the device: $d"
done
for a in data-motion data-motion-span data-motion-cue data-motion-rate \
         data-motion-stagger data-motion-count data-motion-dir data-motion-drift; do
  grep -Fq "$a" "$r/devices.md" || fail "devices.md does not document the attribute: $a"
done
grep -Fq -- '--motion-p' "$r/devices.md" || fail "devices.md does not publish --motion-p"
grep -Eqi 'scrub' "$r/devices.md" \
  || fail "devices.md does not say video scrub belongs to the cinematic path"
# The cue contract's three rules, each learned by shipping the bug.
grep -Eqi 'greet' "$r/devices.md" || fail "devices.md is missing the greet cue form for heroes"
grep -Eqi 'only the last' "$r/devices.md" \
  || fail "devices.md does not restrict the holding cue to the last section"
grep -Eqi 'plateau' "$r/devices.md" || fail "devices.md does not require a cue plateau"
grep -Eqi 'prefers-reduced-motion|reduced motion' "$r/devices.md" \
  || fail "devices.md does not state the reduced-motion behaviour"

# --- The fingerprint gate. --------------------------------------------------
grep -Fq '4 of the 6' "$r/fingerprint.md" || fail "fingerprint.md does not state the 4-of-6 rule"
grep -Fq 'FINGERPRINTS.md' "$r/fingerprint.md" || fail "fingerprint.md does not name the registry file"
grep -Fq '.wp-create.json' "$r/fingerprint.md" \
  || fail "fingerprint.md does not record the project's own row in the manifest"
grep -Eqi 'change the plan, not the log' "$r/fingerprint.md" \
  || fail "fingerprint.md does not forbid rewriting a row to fit a new build"
for axis in 'grammar' 'nav' 'hero' 'sequence' 'close' 'signature move'; do
  grep -Fqi "$axis" "$r/fingerprint.md" || fail "fingerprint.md is missing the axis: $axis"
done

# --- Verification is not optional and not automatic. ------------------------
grep -Fq '/wp-demo-verify' "$r/verify.md" || fail "verify.md does not name the verify command"
grep -Eqi 'dead scroll' "$r/verify.md" || fail "verify.md does not define dead scroll"
grep -Eqi 'contact sheet' "$r/verify.md" || fail "verify.md does not require reading the contact sheet"
grep -Eqi 'not a pass|is not a pass' "$r/verify.md" \
  || fail "verify.md does not state that a green machine run alone is not a pass"

echo PASS
