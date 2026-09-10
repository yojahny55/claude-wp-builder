#!/usr/bin/env bash
# The catalogue is the craft skill's positive vocabulary: real tokens from real
# sites. It travels with its licence, is indexed so a build can find a nearest
# match without reading dozens of files, and ships one neutral file the
# composition previews render against so the previews show the compositions,
# not a brand. Only 64 of the upstream repo's 74 domains are vendored: the
# other ten carry no YAML front matter (pure prose, pre-dating the front-matter
# convention) and so cannot supply the parseable colours/typography this
# catalogue depends on — that omission is deliberate, not a botched copy.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=skills/wp-demo-craft/references/design-md

[ -f "$d/LICENSE" ] || fail "$d/LICENSE is missing; the catalogue is MIT and the licence travels"
grep -Fqi 'MIT' "$d/LICENSE" || fail "$d/LICENSE is not the MIT text"
[ -f "$d/INDEX.md" ] || fail "$d/INDEX.md is missing"
n=$(find "$d" -mindepth 2 -name DESIGN.md | wc -l)
[ "$n" -ge 60 ] || fail "expected at least 60 vendored DESIGN.md files, found $n"
# Every entry is indexed, every index row exists.
for f in "$d"/*/DESIGN.md; do
  dom=$(basename "$(dirname "$f")")
  grep -Fq "| $dom |" "$d/INDEX.md" || fail "INDEX.md is missing the row for $dom"
  awk 'NR==1 && /^---$/ { f = 1 } END { exit !f }' "$f" || fail "$f has no front matter"
done
grep -Eq '^\| domain \| industry \| tone \| display \| accent \|' "$d/INDEX.md" \
  || fail "INDEX.md header row is not: domain, industry, tone, display, accent"

# The neutral preview reference defines the token vocabulary compositions use.
p="$d/_preview.md"
[ -f "$p" ] || fail "$p is missing"
for t in canvas surface ink ink-soft accent accent-ink hairline; do
  grep -Eq "^  $t: " "$p" || fail "$p does not define the token: $t"
done
grep -Eq '^  display:' "$p" || fail "$p does not define the display face"
grep -Eq '^  text:' "$p" || fail "$p does not define the text face"
# The content width joined the vocabulary in the same pass that made every
# composition constrain against it. Asserted as a front-matter key, because that
# is what composition-preview.mjs reads; the prose token list below it is not.
# As a LENGTH, not merely as a present key: the value is interpolated straight
# into the preview :root and anything that is not a length makes every
# composition's calc() invalid at computed-value time, which unsets padding-inline
# rather than degrading it.
grep -Eq '^  container: "[0-9.]+(px|rem|em)"$' "$p" \
  || fail "$p does not define the content width as a length, so every composition padding-inline is invalid at computed-value time"

# The handoff: a DESIGN.md the demo was built from is worth nothing if /wp-init
# scrapes the demo's :root instead of reading it, or leaves it behind in demo/.
i=commands/wp-init.md
y=commands/wp-yolo.md
grep -Fq 'demo/DESIGN.md' "$i" || fail "$i does not read demo/DESIGN.md"
grep -Eqi 'before .*:root|first.*:root|instead of .*:root' "$i" || fail "$i does not prefer DESIGN.md over the :root scrape"
grep -Fq 'DESIGN.md' "$y" || fail "$y does not carry the DESIGN.md contract into the whole-site build"
grep -Fq 'browser' CLAUDE.md || fail "CLAUDE.md does not state the craft browser prerequisite"
grep -Fq 'demo/DESIGN.md' CLAUDE.md || fail "CLAUDE.md does not document the DESIGN.md handoff"

# The token seam. The compositions' CSS names a vocabulary the starter's :root
# has never defined, so a craft demo carried into the theme by name alone would
# reference undefined properties and render unstyled. /wp-init has to write the
# craft vocabulary AND alias the starter's own tokens onto it, or one of the two
# stylesheets goes dead — and the mapping has to be recorded where the next
# agent can read it rather than guess.
for t in --color-canvas --color-surface --color-ink-soft --color-accent-ink --color-hairline --font-display --font-text; do
  grep -Fq -- "$t" "$i" || fail "$i does not write the craft token $t into the theme"
done
# Assert the alias ROWS, not the token names. Every starter token name already
# appears in Step D4's pre-existing extraction table, so grepping for the bare
# name passes on text that predates the alias table entirely — a green check
# whose message names a behaviour it cannot detect. The row is what is new.
while IFS='=' read -r starter craft; do
  grep -Fq -- "| \`$starter\` | \`var(--$craft)\` |" "$i" \
    || fail "$i does not alias the starter token $starter onto var(--$craft)"
done <<'ALIASES'
--color-primary=color-accent
--color-secondary=color-ink
--color-dark=color-ink
--color-light=color-canvas
--color-gray=color-ink-soft
--font-primary=font-display
--font-secondary=font-text
ALIASES
# Anchored to the alias-table row including the no-alias marker: the bare fragment
# '| `--color-accent` |' is also satisfied by Step D4's pre-existing extraction
# table (the 'Accent/CTA color' row), which predates the alias table entirely and
# would leave this green even with the whole alias table deleted.
grep -Fq -- '| `--color-accent` | *(no alias)*' "$i" \
  || fail "$i does not state that --color-accent is the one shared name and needs no alias"
# Bare 'alias' is satisfied by two pre-existing lines about basic/tailwind, so
# pin the rule that keeps the mapping right instead of the word.
grep -Eqi 'by role, never by lightness' "$i" || fail "$i does not state that the aliases map by role, not by lightness"
grep -Eqi 'alias table' "$i" || fail "$i does not require the alias table in the theme's copied DESIGN.md"

# Craft demos never go through /wp-tailwindify. They already carry BEM classes
# and a :root, which is exactly the plain-CSS evidence the converter triggers on,
# and wp-tailwind maps colours to the nearest utility — which would replace the
# compositions' custom-property references with hardcoded classes and delete the
# token indirection the alias table exists to preserve.
grep -Fq 'wp-tailwindify' "$i" || fail "$i no longer mentions /wp-tailwindify"
grep -Fq 'When `demo mode` is craft, skip `/wp-tailwindify` entirely' "$i" \
  || fail "$i does not skip /wp-tailwindify on a craft demo"
grep -Fq 'Otherwise, **run `/wp-tailwindify`**' "$i" \
  || fail "$i still runs /wp-tailwindify unconditionally"
grep -Fq 'Skip it entirely when `demo mode` is **craft**' "$y" \
  || fail "$y does not skip the Step 2.6 demo conversion on a craft demo"

echo PASS
