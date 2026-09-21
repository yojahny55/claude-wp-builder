#!/usr/bin/env bash
# The structure axis: the half of scroll-craft this plugin did not port.
#
# Every constraint file came over -- taste floor, refuse list, feeling curve, device
# kit -- and the three systems that make two builds differ from each other did not.
# The result was a skill that could only produce its own floor, and the report that
# followed was "all the pages are almost the same thing". These assertions exist so a
# future trim cannot quietly repeat that: a skill made only of prohibitions produces
# the prohibition.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

R=skills/wp-demo-craft/references
S=skills/wp-demo-craft/SKILL.md
D=commands/wp-demo.md

for f in uniqueness hero-depth worlds; do
  [ -f "$R/$f.md" ] || fail "$R/$f.md is missing -- it is one of the three generative references, and without it the skill is floors only"
  # Unreachable prose is the same as absent prose. SKILL.md is the only entry point.
  grep -Fq "$f.md" "$S" \
    || fail "$S never names $f.md, so nothing reads it -- shipped, green, and does nothing"
done

# --- the signature move -----------------------------------------------------------
# The single cheapest defence against the template trap, because it is unique by
# definition. It has to be recorded BEFORE the build: a move described afterwards is
# reliably a library device wearing a project-specific class name.
grep -Fq 'signature move' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md does not define the signature move"
grep -Fq 'cannot tell it apart from something the library already does' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md states what a signature move is without stating the test that rejects one"
grep -Fq 'A move described after the build' "$D" \
  || fail "$D does not require the signature move to be recorded before building, which is what makes it a decision rather than a label"

# --- the within-build axis --------------------------------------------------------
# scroll-craft built one page per project, so its only sameness axis was build against
# build. A multi-page demo has a second axis, and it is the one that was reported.
grep -Fq 'superset' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md does not state the within-build rule (no page's sequence a superset of another's)"
grep -Fq 'superset' "$D" \
  || fail "$D does not make the composition plan answer the within-build rule, so the rule has no step that applies it"

# --- the fingerprint gate compares structure again ---------------------------------
# v2 kept only the palette, on the reasoning that the composition library chooses
# structure per role. A library with one good answer per role gives every build the
# same answer, which is the thing structural fingerprinting catches.
grep -Fq '4 of the 7' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md does not state the 4-of-7 gate"
grep -Fq 'Section-sequence shape' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md's dimension table has lost the structural axes, which is the v2 regression this file exists to prevent"
grep -Fq '4 of the 7' "$R/fingerprint.md" \
  || fail "$R/fingerprint.md still gates on palette alone"
grep -Fq 'count as **no match**' "$R/fingerprint.md" \
  || fail "$R/fingerprint.md does not say how a v2 row (palette only) is compared on the structural axes it never recorded"

# --- aesthetic range --------------------------------------------------------------
# Premium-minimal as an unexamined default is how a shelf of dark pages with one
# accent each happens.
for fam in Brutalist Maximalist Playful Retro Dense Editorial Premium-minimal; do
  grep -Fq "$fam" "$R/uniqueness.md" \
    || fail "$R/uniqueness.md's aesthetic range is missing the $fam family"
done
grep -Fq 'aesthetic family' "$D" \
  || fail "$D never asks which aesthetic family, so the range exists in prose and nothing selects from it"
grep -Fq 'the interview was decorative' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md does not say what it means when the brief and the build disagree on family"

# --- hero depth -------------------------------------------------------------------
grep -Fq 'not a polish pass' "$R/hero-depth.md" \
  || fail "$R/hero-depth.md does not state that layering is the baseline"
grep -Fq 'one image do not meet this rule' "$R/hero-depth.md" \
  || fail "$R/hero-depth.md does not reject stacked planes moving at one rate, which is the flat hero it exists to prevent"
# The overflow lesson came from a real 390px walk and belongs where heroes are built.
grep -Fq 'overflow-x: clip' "$R/hero-depth.md" \
  || fail "$R/hero-depth.md does not carry the wrapper-scale overflow backstop"
grep -Fq 'makes the root a scroll container' "$R/hero-depth.md" \
  || fail "$R/hero-depth.md does not say why the backstop is clip and not hidden (hidden makes the root a scroll container and kills the sticky header)"

# --- worlds -----------------------------------------------------------------------
# The preamble is only worth anything reused verbatim; paraphrasing it is what makes
# eight assets look like eight prompts.
grep -Fq 'verbatim' "$R/worlds.md" \
  || fail "$R/worlds.md does not require the preamble to be reused verbatim"
grep -Fq 'verbatim' "$D" \
  || fail "$D does not carry the world preamble into the image prompts, so choosing a world changes nothing"
n=$(grep -cE '^### [1-8]\. ' "$R/worlds.md" || true)
[ "$n" -eq 8 ] || fail "$R/worlds.md carries $n world preambles, not 8"
grep -Fq 'where the empty space is' "$R/worlds.md" \
  || fail "$R/worlds.md does not require every shot prompt to name the empty space -- copy sits on these images"
grep -Fq 'banned as a default' "$R/worlds.md" \
  || fail "$R/worlds.md does not ban the clay-diorama look as a default, which is the AI-site house style"
# Every preamble has to carry its negative list, or the model drifts to rendered.
for w in 1 2 3 4 5 6 7 8; do
  blk=$(awk -v n="$w" 'BEGIN{p=0} index($0, "### " n ". ") == 1 {p=1;next} /^### /{p=0} p' "$R/worlds.md")
  printf '%s' "$blk" | grep -qiE 'not (3d|rendered|cgi)|no cgi|no render|not rendered|no 3d' \
    || fail "$R/worlds.md preamble $w has no negative list; without it the model drifts toward rendered-looking output"
done

# --- image prompt skeleton --------------------------------------------------------
# The skeleton every plate prompt follows, and which half the script composes.
# Adapted from MengTo/Skills design-first-ui-prompting (MIT): one accent only,
# and generate without text -- copy is set in HTML, so a plate carrying letters
# is a plate carrying misspelled letters.
[ -f "$R/image-prompt.md" ] || fail "$R/image-prompt.md is missing"
for t in 'SUBJECT' 'FORMAT' 'COLOUR' 'NEGATIVE' 'one accent' 'no text' 'image-gen.mjs' 'where the empty space is'; do
  grep -Fq "$t" "$R/image-prompt.md" || fail "$R/image-prompt.md lacks: $t"
done
grep -Fq 'image-prompt.md' "$R/worlds.md" \
  || fail "$R/worlds.md does not point at image-prompt.md, so a reader of worlds alone still pastes the preamble by hand"

echo PASS
