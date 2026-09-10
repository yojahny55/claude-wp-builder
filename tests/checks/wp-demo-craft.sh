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

# --- The two spine rules that survive v2. Variety was the product in v1 and it
#     produced a split-stage credit-repair site with a seam nobody asked for.
grep -Eqi 'real content only' "$s" || fail "$s does not require real content only"
grep -Eqi 'one peak' "$s" || fail "$s does not require one peak"
grep -Eqi 'four device families' "$s" && fail "$s still requires four device families (removed in v2)"
grep -Eqi 'never the same device' "$s" && fail "$s still forbids repeating a device (removed in v2)"
grep -Fq 'compositions/README.md' "$s" || fail "$s does not send the build to the composition role table"
grep -Fq 'DESIGN.md' "$s" || fail "$s does not name demo/DESIGN.md"
grep -Eqi 'browser' "$s" || fail "$s does not state the browser prerequisite"

# --- The refuse list split: the generic tells went to the detector, the rules
#     that are this plugin's own stayed in taste.md as part of the positive floor.
grep -Fq '## The refuse list' "$r/taste.md" && fail "taste.md still carries the refuse list as a separate section"
grep -Fq 'impeccable' "$r/verify.md" || fail "verify.md does not run the impeccable detector"
grep -Eqi 'purple|violet' "$r/taste.md" || fail "taste.md does not refuse the AI-purple palette"

# --- Measured floor, not vibes. A floor with no numbers is a preference. -----
grep -Fq '45' "$r/taste.md" || fail "taste.md does not state the 45-75ch measure floor"
grep -Fq '4.5:1' "$r/taste.md" || fail "taste.md does not state the contrast floor"
grep -Fq '300ms' "$r/taste.md" || fail "taste.md does not cap UI transition duration"
grep -Eqi 'transform and opacity|transform.*opacity only' "$r/taste.md" \
  || fail "taste.md does not restrict continuous animation to transform/opacity"
# --- The three hero limits the client build broke. They are authoring-time copy
#     limits, so no render check can catch their loss; they vanished once already
#     when the refuse list was removed.
grep -Fq 'at most two lines at' "$r/taste.md" || fail "taste.md lost the hero headline two-line limit"
grep -Fq 'three at 390' "$r/taste.md" || fail "taste.md lost the 390px three-line allowance the rubric grades"
grep -Fq '25 words' "$r/taste.md" || fail "taste.md lost the hero subtext word limit"
grep -Fq 'four text elements' "$r/taste.md" || fail "taste.md lost the hero text-element limit"

# --- The emotion axis. -------------------------------------------------------
grep -Eqi 'one engineered peak' "$r/feel.md" || fail "feel.md does not require one engineered peak"
grep -Fqi "it's the site where" "$r/feel.md" || fail "feel.md is missing the tell-someone sentence"
grep -Eqi 'adjacent' "$r/feel.md" || fail "feel.md does not flag adjacent same-feeling sections as filler"
grep -Eqi 'cold|before looking|do not reread' "$r/feel.md" \
  || fail "feel.md does not require the feel check to be run cold"

# --- Grammars. The forbids are the point: a grammar that only says what it
#     likes is a preference, and a preference drifts back to the default shape.
for gname in 'layered landing' 'chaptered editorial' 'typographic poster' 'gallery'; do
  grep -Fqi "$gname" "$r/grammars.md" || fail "grammars.md is missing the grammar: $gname"
done
grep -Fq '## Retired' "$r/grammars.md" || fail "grammars.md does not retire split stage and rhythmic cutlist"
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

# --- The budget replaces variety. -------------------------------------------
grep -Fq 'data-motion-peak' "$r/devices.md" || fail "devices.md does not define data-motion-peak"
# The numbers, not a substring of them: a bare '2.0' passes on a version string
# while the cap silently becomes 4.0.
grep -Fq 'span 2.0' "$r/devices.md" || fail "devices.md does not cap pin span at 2.0"
grep -Fq 'span 3.0' "$r/devices.md" || fail "devices.md does not allow the peak up to span 3.0"
grep -Eqi 'interior pages? (get|have) no pin|never pin' "$r/devices.md" \
  || fail "devices.md does not forbid pins on interior pages"
# --- Heroes are reveal, never kinetic. The split masks every word until a scroll
#     trigger fires, which is what clipped the client's headline. A cue does not
#     fix it: drive() reads cues only for pin|pan|kinetic|wipe|drift, so a cue on
#     a reveal section is inert.
grep -Eqi 'never on a hero headline' "$r/devices.md" \
  || fail "devices.md does not ban the kinetic split on hero headlines"
grep -Eqi 'inert|does nothing|no effect' "$r/devices.md" \
  || fail "devices.md does not say a cue outside a scrubbed section is inert"

# --- The fingerprint gate, reduced to palette and type. ---------------------
grep -Fq '4 of the 6' "$r/fingerprint.md" && fail "fingerprint.md still states the 4-of-6 structure rule (removed in v2)"
grep -Fq 'FINGERPRINTS.md' "$r/fingerprint.md" || fail "fingerprint.md does not name the registry file"
grep -Fq '| client | display | text | accent | canvas | date |' "$r/fingerprint.md" \
  || fail "fingerprint.md does not define the v2 row format"
grep -Fq '15 degrees' "$r/fingerprint.md" || fail "fingerprint.md does not state the 15-degree hue tolerance"
grep -Fq '.wp-create.json' "$r/fingerprint.md" \
  || fail "fingerprint.md does not record the project's own row in the manifest"
grep -Eqi 'change the plan, not the log' "$r/fingerprint.md" \
  || fail "fingerprint.md does not forbid rewriting a row to fit a new build"

# --- New references: the catalogue and the composition library. -------------
[ -f "$r/design-md.md" ] || fail "$r/design-md.md is missing"
[ -f "$r/compositions.md" ] || fail "$r/compositions.md is missing"
grep -Fq 'designlang' "$r/design-md.md" || fail "design-md.md does not name designlang"
grep -Fq 'INDEX.md' "$r/design-md.md" || fail "design-md.md does not send the build to the catalogue index"
grep -Eqi 'never (a )?copy|not a copy source|vocabulary' "$r/design-md.md" \
  || fail "design-md.md does not forbid copying a catalogue entry"
grep -Fq 'landing.gallery' "$r/compositions.md" || fail "compositions.md does not name the free Landing Gallery MCP"
grep -Eqi 'one.line reason' "$r/compositions.md" || fail "compositions.md does not require a reason to deviate"

# --- Verification is not optional and not automatic. ------------------------
grep -Fq '/wp-demo-verify' "$r/verify.md" || fail "verify.md does not name the verify command"
grep -Eqi 'dead scroll' "$r/verify.md" || fail "verify.md does not define dead scroll"
grep -Eqi 'contact sheet' "$r/verify.md" || fail "verify.md does not require reading the contact sheet"
grep -Eqi 'not a pass|is not a pass' "$r/verify.md" \
  || fail "verify.md does not state that a green machine run alone is not a pass"

# --- The floor gained a seventh rubric line and two authoring notes. --------
grep -Fq 'oklch' "$r/design-md.md" || fail "design-md.md does not derive token scales in oklch"
grep -Eqi 'trend roundup|becoming the next default|next default' "$r/taste.md" \
  || fail "taste.md does not warn that today's anti-slop moves become tomorrow's default"

# Three client complaints, one contract each. A real logo on disk was never wired
# in because docs/ reached a craft build only through the mode decision; and craft
# inherited Step 4's placeholder-logo and placeholder-image clauses, which is how
# "HERO PHOTOGRAPH PENDING" shipped as a hero and still passed First paint complete.
grep -Fq 'Assets on disk' commands/wp-demo.md \
  || fail "commands/wp-demo.md does not inventory the assets under docs/, so a real logo is never wired in"
grep -Fq 'placeholder-content clauses' commands/wp-demo.md \
  || fail "commands/wp-demo.md still inherits Step 4's placeholder logo and placeholder image clauses"
# And the clause it replaced is gone. Without this, writing the new phrase anywhere
# in the file satisfies the assertion above while the exemption line still reads
# "single-file, no-CDN and :root token clauses" and craft still inherits both.
grep -Fq 'no-CDN and `:root` token clauses' commands/wp-demo.md \
  && fail "commands/wp-demo.md still carries the old exemption line, so craft inherits the placeholder clauses whatever else the file says"
grep -Fq -- '- A placeholder image, a placeholder logo' skills/wp-demo-craft/SKILL.md \
  || fail "SKILL.md does not blocklist placeholder imagery, which spine rule 1 does not cover"

echo PASS
