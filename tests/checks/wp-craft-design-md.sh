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

# A malformed --container-max (`wide`, empty) used to unset padding-inline to 0
# at every viewport, because var() substitutes a bad value rather than falling
# back. @property makes it fall back to initial-value instead. Anchored on the
# opening brace, not the bare token+name pair, which a typo'd property name
# (--container-maxx) would also satisfy while leaving the real bug unfixed.
w=commands/wp-demo.md
r=bin/composition-preview.mjs
# Grep a CSS-comment-stripped copy of the command: the rule it carries lives in
# a fenced css block, so a dead `/* @property ... */` instruction satisfies a
# raw grep while instructing the build to emit nothing.
ws="$(perl -0pe 's{/\*.*?\*/}{}gs' "$w")"
grep -Eq '@property --container-max[[:space:]]*\{' <<<"$ws" \
  || fail "$w does not emit @property for --container-max outside a comment, so a malformed value still unsets padding-inline"
grep -Fq 'syntax: "<length>"' <<<"$ws" \
  || fail "$w's @property rule does not constrain --container-max to a length"
# `inherits` is not decoration. A registered property with inherits:false is not
# inherited by descendants, so :root's WELL-FORMED --container-max stops reaching
# the sections that read it and every one of them falls back to initial-value.
# Measured at 1920 with a valid 1440px token: inherits:true -> 240px padding,
# inherits:false -> 320px. That breaks the working case, not just the malformed
# one, which is strictly worse than the bug this rule was added to fix.
grep -Eq '@property --container-max[[:space:]]*\{[^}]*inherits: true' <<<"$(tr '\n' ' ' <<<"$ws")" \
  || fail "$w's @property rule does not set inherits: true, so a well-formed --container-max at :root never reaches the sections that read it"
# Step 6 writes one file per page, and the instruction beside the rule was
# singular ("in the same <style>"), which a builder can satisfy by emitting it on
# index.html alone — every interior page then keeps the unguarded token and the
# original bug. The sentence has to say every page out loud.
grep -Fq 'on every page this step writes' <<<"$ws" \
  || fail "$w does not tell the build to emit the @property rule on every page, so an interior page keeps the unguarded --container-max"
# ...and the theme the client actually receives. /wp-section copies thirteen
# `calc((100% - var(--container-max, 1280px)) / 2)` gutter rules into it, so a
# Step D4 that writes the craft tokens without --container-max and without its
# registration reproduces the same padding-inline: 0 one layer down, in the
# artifact that ships. Measured at 1920 on that rule: `wide` and empty both give
# 0px without the rule and 312px with it. Comment-stripped for the same reason
# as $w: the rule lives in a fenced css block.
i4=commands/wp-init.md
i4s="$(perl -0pe 's{/\*.*?\*/}{}gs' "$i4")"
grep -Eq '@property --container-max[[:space:]]*\{' <<<"$i4s" \
  || fail "$i4 Step D4 does not emit @property for --container-max, so a malformed token unsets padding-inline in the delivered theme"
grep -Fq 'syntax: "<length>"' <<<"$i4s" \
  || fail "$i4's @property rule does not constrain --container-max to a length"
grep -Eq '@property --container-max[[:space:]]*\{[^}]*inherits: true' <<<"$(tr '\n' ' ' <<<"$i4s")" \
  || fail "$i4's @property rule does not set inherits: true, so a well-formed --container-max never reaches the theme's sections"
# The registration alone is only half: with no --container-max in @theme every
# section falls back to initial-value and the demo's content width is lost. The
# token has to be written too, and named in the craft token list Step D4 writes.
# And where it goes: `@theme` in Tailwind v4 takes plain variable declarations,
# so an @property rule written inside it is not a registration — the token stays
# unregistered and the malformed-value case is back, silently.
grep -Fq 'at the top level of' <<<"$i4s" \
  || fail "$i4 does not say the @property rule goes at the top level of main.css; inside @theme it registers nothing"
grep -Fq -- '`--space-gutter`, `--container-max`' <<<"$i4s" \
  || fail "$i4 Step D4 does not write --container-max into the @theme block, so the theme loses the demo's content width"

tr '\n' ' ' < "$r" | grep -Eq '@property --container-max[[:space:]]*\{[^}]*inherits: true' \
  || fail "$r's @property rule does not set inherits: true, so a well-formed --container-max never reaches the preview's sections"
grep -Eq '@property --container-max[[:space:]]*\{' "$r" \
  || fail "$r does not emit @property, so previews and client demos differ"
# The source grep above only proves the text exists somewhere in the file. It
# is equally satisfied by the rule sitting at the --tokens call site (e.g.
# concatenated onto `process.stdout.write(...)`) as by it living inside
# rootBlock()'s own returned string — but only the second one reaches the
# embedded preview page, which calls rootBlock(t) directly and never goes
# through that call site. Extract the function body by its own brace range
# and require the rule inside it, so a rule sitting just outside — right
# above the function, or spliced into the --tokens branch — fails here even
# though the whole-file grep above stays green.
body="$(awk '/^function rootBlock\(t\) \{/,/^}/' "$r")"
[ -n "$body" ] || fail "$r's rootBlock(t) function is missing or unmatched, so the @property placement cannot be checked"
grep -Eq '@property --container-max[[:space:]]*\{' <<<"$body" \
  || fail "$r emits @property outside rootBlock()'s function body, so the embedded preview page (which calls rootBlock(t) directly) does not carry it even though --tokens might"
# And the runtime proof: --tokens prints exactly what rootBlock() returns, the
# same string the embedded preview page uses, so its output has to carry the
# rule too — this is what the file's own comment on --tokens promises.
tokens="$(node "$r" --tokens)" \
  || fail "$r --tokens does not run, so the @property placement cannot be asserted"
grep -Eq '@property --container-max[[:space:]]*\{' <<<"$tokens" \
  || fail "$r --tokens output does not carry @property --container-max, so the rule is not inside rootBlock()'s returned string"
# Permanent zero-occurrence control: this ceiling is fixed, so its old wording
# must never reappear in CLAUDE.md. Stays green forever unless the ceiling
# entry is reverted while the code fix (and the greps above) stay in place.
grep -Fq 'only guards an absent token, not a malformed one' CLAUDE.md \
  && fail "CLAUDE.md still records the old container-max ceiling as unfixed"

echo PASS
