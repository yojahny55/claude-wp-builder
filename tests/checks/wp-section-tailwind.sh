#!/usr/bin/env bash
# /wp-section must route its CSS agent by template. On tailwind it dispatches
# wp-tailwind in author mode; on basic it keeps wp-css unchanged.
set -euo pipefail
f=commands/wp-section.md

# Flattened once, up front, and reused by every assertion that matches a phrase a
# correct re-wrap can split across two physical lines — including a break AT A
# HYPHEN, which has false-failed gates on this branch before. `wp- ?tailwind`
# absorbs the space such a break leaves behind after flattening.
flatf=$(tr '\n' ' ' < "$f" | sed 's/  */ /g')

# Backticked, exactly as tests/checks/wp-commands-tailwind.sh does it, so this
# cannot be satisfied by the `wp-tailwind-system` skill reference the assertion
# further down separately mandates. The bare 'wp-tailwind' needle it replaces was a
# decoration that could never fail on its own: rewriting every `wp-tailwind` in the
# command to `wp-css` — `perl -0pi -e 's/wp-tailwind(?!-system)/wp-css/g'`, 22 lines —
# left `wp-tailwind-system` behind and still PASSed, so the whole tailwind routing
# could be reverted with this gate green.
printf '%s' "$flatf" | grep -qE '`wp- ?tailwind`' \
  || { echo "FAIL: wp-section never names the \`wp-tailwind\` agent"; exit 1; }
grep -Eqi 'template.{0,40}tailwind|tailwind.{0,40}template' "$f" \
  || { echo "FAIL: wp-section does not read the project template"; exit 1; }

# The author MODE token, in a form ordinary prose cannot supply. The bare 'author'
# needle these two assertions replace was satisfied by wording that predates this
# branch entirely — `re-authoring`, `authoring path` — so stripping every mode token
# from the file left it green. That is not cosmetic: agents/wp-tailwind.md selects
# Section Authoring Mode on a `Mode: **author**` line and on nothing else, and
# without that line the agent falls into Demo Conversion Mode and tries to write
# `<output-path>.tmp` instead of a section. (It used to gate on a bare `author`
# token appearing anywhere in the prompt — which the conversion dispatch's own
# input path supplies whenever a demo page is named `author.html`.)
#
# Two assertions, because the token has to do two different jobs here:
#   1. the routing statements must BIND the agent to the mode, and bind it
#      directed — it is `wp-tailwind` that runs in author mode, not something else;
#   2. the dispatch prompt itself must carry the mode line the agent reads.
# `\*{0,2}` so `**author**`, `*author*` and a plain `author` all satisfy (1).
printf '%s' "$flatf" | grep -qE '`wp- ?tailwind` in \*{0,2}author\*{0,2} mode' \
  || { echo "FAIL: wp-section never binds \`wp-tailwind\` to author mode (wanted the directed clause \"\`wp-tailwind\` in author mode\") — a bare 'author' anywhere in the file is prose, not a dispatch mode"; exit 1; }

# BLOCKQUOTE LINES ONLY. Only a `>` line is text the dispatching command actually
# hands to the agent; a heading or a paragraph is commentary the agent never sees.
# This scoping is the assertion's whole point: the gate it protects used to be a
# bare `author` needle over the whole file, which pre-existing prose
# ("re-authoring", "authoring path") satisfied on its own, so every mode token
# could be stripped from the dispatch and the suite stayed green. Restricting the
# scan to quoted lines makes prose — including this file's own headings, its
# routing table and the sentence introducing the line — unable to satisfy it.
#
# Emphasis markers are still stripped and the quoted text is still flattened, so
# `> Mode: **author**`, `> **Mode:** author` and `> Mode: _author_` all satisfy it:
# the reformat a careful author would make must not turn this gate red.
#
# `|| true` is load-bearing, exactly as tests/checks/wp-tailwind-migrate.sh:531
# documents for the same idiom: under `set -euo pipefail` a zero-match `grep` inside a
# command substitution aborts the script outright, so a wp-section.md with no
# blockquote at all exited 1 printing NOTHING — no FAIL line, no diagnosis. Let the
# assertion below report instead of the shell.
modef=$(grep -E '^[[:space:]]*>' "$f" | sed -e 's/^[[:space:]]*>//' -e 's/[*_]//g' | tr '\n' ' ' | sed 's/  */ /g' || true)
printf '%s' "$modef" | grep -qiE 'Mode: ?author' \
  || { echo "FAIL: no QUOTED line in wp-section carries a \`Mode: **author**\` mode line — agents/wp-tailwind.md selects Section Authoring Mode on that line and on nothing else, so a tailwind dispatch without it runs Demo Conversion Mode instead. Prose about author mode does not count: the agent only ever sees the blockquote"; exit 1; }

grep -q 'wp-tailwind-system' "$f" \
  || { echo "FAIL: wp-section does not point the agent at wp-tailwind-system"; exit 1; }

# ---------------------------------------------------------------------------
# FILE OWNERSHIP — the worst defect this command ever shipped.
#
# `wp-template` and `wp-tailwind` were dispatched SIMULTANEOUSLY against the same
# `template-parts/section-<name>.php`, with opposite class systems: wp-template's
# prompt ordered BEM naming, wp-tailwind's Procedure said "Author the markup. Emit
# the template part with Tailwind utility classes." Last writer won,
# non-deterministically, and the loss was not symmetric —
#
#     $ grep -c 'prefix_get_field\|get_field\|esc_html\|esc_url\|ABSPATH\|@package' agents/wp-tailwind.md
#     0
#
# — so a wp-tailwind win shipped the section with no ACF wiring, no escaping and no
# i18n, which /wp-finalize then reports as a bilingual failure, while a wp-template
# win shipped BEM into a Tailwind theme and failed bin/tailwind-native-check.sh at
# delivery. /wp-yolo Step 5 runs this per section, so it hit every section of a
# demo.
#
# Four assertions hold the resolution: ONE owner named, the ordering that keeps the
# race from existing, the instruction that lets the owner emit utilities, and the
# per-template dispatch order. Backticks and emphasis are stripped so the relations
# can be matched as prose and a re-emphasis cannot turn any of them red.
# ---------------------------------------------------------------------------
nof=$(printf '%s' "$flatf" | sed -e 's/[`*]//g' -e 's/  */ /g')

printf '%s' "$nof" | grep -Eqi "wp[ -]{1,2}template[^.]{0,40}\b(owns|owned|belongs to)[^.]{0,60}template-parts/section|template-parts/section[^.]{0,80}(owned by|belongs to|written by)[^.]{0,20}wp[ -]{1,2}template" \
  || { echo "FAIL: wp-section never says wp-template OWNS template-parts/section-<name>.php — it is the only agent carrying the ACF, escaping and i18n contract (agents/wp-tailwind.md names none of prefix_get_field, esc_html, esc_url, @package or ABSPATH), so with ownership unstated the tailwind dispatch reads as a second author of the same file"; exit 1; }

printf '%s' "$nof" | grep -Eqi "wp[ -]{1,2}tailwind[^.]{0,60}\bafter\b[^.]{0,90}(never|not)[ a-z]{0,12}(beside|in parallel|simultaneous)" \
  || { echo "FAIL: wp-section does not say wp-tailwind runs AFTER wp-template and never beside it — that parallel dispatch against one file with two class systems is the defect, and 'prefer wp-tailwind' or 'route to wp-tailwind' does not close it"; exit 1; }

# The invariant, both halves. Either half alone is satisfied by a command that ships
# the other defect.
printf '%s' "$nof" | grep -Eqi "(no|never)[^.]{0,40}\bship[a-z]*\b[^.]{0,30}without[^.]{0,60}(acf|escap)" \
  || { echo "FAIL: wp-section does not state the invariant that no section may ship WITHOUT its ACF wiring and escaping — that is the half a wp-tailwind win destroys"; exit 1; }
printf '%s' "$nof" | grep -Eqi "(no|never)[^.]{0,40}\bship[a-z]*\b[^.]{0,30}(on |with )?BEM[^.]{0,80}tailwind" \
  || { echo "FAIL: wp-section does not state the invariant that no section may ship on BEM class names in a Tailwind theme — that is the half a wp-template win destroys, and bin/tailwind-native-check.sh rule 6 catches it only at delivery"; exit 1; }

# The dispatch ORDER, per template. The command used to say "Launch all three agents
# simultaneously" flat, with no template condition at all.
printf '%s' "$nof" | grep -Eqi "(wait|only after)[^.]{0,60}(agent 2|wp[ -]{1,2}template)[^.]{0,60}(before|then)[^.]{0,60}(agent 3|wp[ -]{1,2}tailwind)" \
  || { echo "FAIL: wp-section's tailwind branch does not wait for Agent 2 (wp-template) to return before dispatching Agent 3 (wp-tailwind) — without that wait the two agents write template-parts/section-<name>.php concurrently and the winner is undefined"; exit 1; }

# wp-template can only KEEP the utilities if its own prompt says so, and the prompt
# is the blockquote — prose above it is commentary the agent never receives. Both
# halves: the positive instruction, and the prohibition on the BEM names its Rule 7
# would otherwise apply (agents/wp-template.md item 7 orders BEM unconditionally).
printf '%s' "$modef" | grep -Eqi '(keep|keeps|carry|carries|preserve|preserves|retain|retains)[^.]{0,20}the tailwind utility classes' \
  || { echo "FAIL: no QUOTED line in wp-section tells wp-template to KEEP the Tailwind utility classes already on the section HTML — agents/wp-template.md Rule 7 orders BEM naming unconditionally, so without this instruction in the prompt the owner of the file emits BEM into a Tailwind theme"; exit 1; }
printf '%s' "$modef" | grep -Eqi "(never|do not|don'?t|must not)[ a-z]{0,16}(replace|rename|convert|swap)[^.]{0,40}BEM" \
  || { echo "FAIL: no QUOTED line in wp-section forbids replacing those utilities with BEM names — 'keep the utilities' and 'also use BEM' are not mutually exclusive to an agent reading both, and agents/wp-template.md tells it to use BEM"; exit 1; }

# The basic path must survive untouched.
grep -q 'assets/css/styles.css' "$f" \
  || { echo "FAIL: wp-section lost the basic path's styles.css target"; exit 1; }

# The transcription overlay needs its tailwind variant.
awk '/TRANSCRIPTION MODE OVERLAY/,/^---$/' "$f" | grep -q 'tailwind' \
  || { echo "FAIL: transcription overlay has no tailwind branch"; exit 1; }

# ---------------------------------------------------------------------------
# The per-template definition of `--css` in Step 1 is the canonical statement of
# this contract — `commands/wp-yolo.md` Step 4 and its check both defer to it
# ("per the transcription overlay below"). It was ungated: swapping the two
# bullets, so `basic` got the converted Tailwind demo and `tailwind` got the
# verbatim CSS "SOURCE OF TRUTH", left 0 of 26 checks failing. That swap is a
# straight inversion of the contract this branch exists to establish, so bind
# each template to its own source by name and reject the other direction.
#
# grep -F throughout: the bullets contain a literal `→` (3 bytes in UTF-8) and a
# bare `.` in an ERE does not match it under LC_ALL=C.
#
# ...but grep -F on the FILE was line-anchored, and these two bullets are the
# longest lines in the repo (183 and 299 characters, in a file that otherwise
# wraps at ~90). Re-wrapping either of them at any sane column without changing a
# single word exited 1, and so did a re-word that preserved the direction exactly
# ("demo CSS — the SOURCE OF TRUTH" for "demo CSS, and the SOURCE OF TRUTH").
# That is a gate that fails on the obvious next correct edit, which is how gates
# get muted. So match against `$flatf` — the whole file folded to one line at the
# top of this script, the same remedy tests/checks/wp-tailwind-agent.sh uses — and
# match the bullet's opening clause rather than the whole sentence.
# ---------------------------------------------------------------------------

# The `basic` bullet, from its own marker to whichever comes first: the `tailwind`
# marker, or the next top-level list item of any kind. Scoping the SOURCE OF TRUTH
# claim to this span is what keeps it directed: the claim has to sit in the `basic`
# bullet, and swapping the two bullets moves it out of the span (as well as tripping
# the inversions below).
#
# The span used to fall back to "everything after the `basic` marker" whenever the
# `tailwind` marker was not found AFTER it — so REORDERING THE TWO BULLETS, an
# ordinary edit, left the range with no terminator and it ran to EOF: 14347 of 16553
# characters, 87% of the file, and the check still PASSed, so nothing warned. An
# unclosed range makes every assertion below file-wide, which is the opposite of
# what this scoping is for. Bound it at the next list item too, and refuse (exit 2)
# rather than swallow the file when neither terminator is found.
awkrc=0
basic_css=$(printf '%s' "$flatf" | awk -v a='- `basic` → ' -v b='- `tailwind` → ' '
  {
    i = index($0, a)
    if (i == 0) exit 1
    s = substr($0, i + length(a))   # everything after the basic marker
    j = index(s, b)                 # the tailwind bullet
    k = index(s, " - ")             # the next top-level list item, whatever it is
    if (j > 0 && (k == 0 || j < k)) e = j; else e = k
    if (e == 0) exit 2              # unterminated: refuse, do not run to EOF
    print a substr(s, 1, e - 1)
  }') || awkrc=$?
case "$awkrc" in
  0) : ;;
  1) echo "FAIL: wp-section's --css definition has no \`basic\` bullet"; exit 1 ;;
  2) echo "FAIL: wp-section's \`basic\` --css bullet is not terminated — neither the \`tailwind\` bullet nor any following list item comes after it, so the span would have run to end of file and every assertion scoped to it would silently have become file-wide"; exit 1 ;;
  *) echo "FAIL: extracting wp-section's \`basic\` --css bullet failed (awk exit $awkrc)"; exit 1 ;;
esac

printf '%s' "$basic_css" | grep -qF -- "the section's **verbatim** demo CSS" \
  || { echo "FAIL: wp-section does not bind --css on \`basic\` to the section's **verbatim** demo CSS"; exit 1; }
printf '%s' "$basic_css" | grep -qF -- 'SOURCE OF TRUTH' \
  || { echo "FAIL: wp-section's \`basic\` --css bullet does not call the verbatim demo CSS the transcription's SOURCE OF TRUTH"; exit 1; }
printf '%s' "$flatf" | grep -qF -- '- `tailwind` → the converted demo page itself' \
  || { echo "FAIL: wp-section does not bind --css on \`tailwind\` to the converted demo page itself"; exit 1; }
# The tailwind --css source is the SOURCE OF TRUTH, exactly as the CSS blob is on
# `basic`. It once read "a geometry reference, not a source of verbatim declarations",
# and that sentence was read as licence to substitute an equivalent utility, collapse an
# element or drop a breakpoint variant — every drift it produced was toward LESS than the
# demo. The absence of raw declarations is a fact about the notation, never a weaker
# mandate, so assert both halves: the source-of-truth binding, and the explicit refusal
# of the substitution the old wording allowed.
printf '%s' "$flatf" | grep -qF 'SOURCE OF TRUTH for the transcription' \
  || { echo "FAIL: wp-section's \`tailwind\` --css bullet does not call the converted demo the transcription's SOURCE OF TRUTH — the same mandate \`basic\` gets"; exit 1; }
printf '%s' "$flatf" | grep -qF 'copy its exact utility classes and its exact element structure' \
  || { echo "FAIL: wp-section does not translate 'copy its exact declared values' into the tailwind notation (exact utility classes + exact element structure)"; exit 1; }
printf '%s' "$flatf" | grep -qF 'substitute an equivalent utility' \
  || { echo "FAIL: wp-section does not refuse substituting an equivalent utility on the tailwind path — the licence that let sections drift"; exit 1; }
if printf '%s' "$flatf" | grep -qF 'not** a source of verbatim declarations'; then
  echo "FAIL: wp-section has regressed to calling the tailwind --css source a geometry reference rather than the SOURCE OF TRUTH"; exit 1
fi
# Inversions, matched file-wide (on the flattened text) so an inverted duplicate
# added anywhere in the file is caught, not just the first bullet pair.
if printf '%s' "$flatf" | grep -qF '`basic` → the converted demo page'; then
  echo "FAIL: wp-section hands the converted Tailwind demo to template=basic — the contract is inverted"; exit 1
fi
if printf '%s' "$flatf" | grep -qF -- "\`tailwind\` → the section's **verbatim** demo CSS"; then
  echo "FAIL: wp-section hands the verbatim plain-CSS demo blob to template=tailwind as the SOURCE OF TRUTH — the contract is inverted"; exit 1
fi

# The CONTACT section's two-phase dispatch must route by template too — it must
# not hardcode wp-css as its Agent 3, and must point at the routing table instead.
#
# Closure and non-emptiness are both proved before anything is asserted about the
# block. Without them a compound of three ordinary edits — rewording the terminator
# sentence, re-titling the Agent 3 heading, and dropping the routing pointer — left
# `contact_block` EMPTY, and an empty string satisfies "does not contain the
# hardcoded heading" while `grep -qi` on it simply reported the missing pointer for
# the wrong reason. An empty region proves nothing; say so.
contact_start='### For CONTACT sections'
contact_end='^Wait for all Phase 1 agents to complete'
contact_block=$(awk -v s="$contact_start" 'index($0, s) { f = 1 } f' "$f" | awk -v e="$contact_end" '{ print } $0 ~ e { exit }')
[ -n "$contact_block" ] \
  || { echo "FAIL: wp-section has no \"$contact_start\" block — the two-phase contact dispatch is where wp-cf7's form IDs gate wp-template, and the assertions below would be scanning an empty string"; exit 1; }
printf '%s\n' "$contact_block" | tail -1 | grep -q "$contact_end" \
  || { echo "FAIL: the CONTACT block is not terminated by a \"Wait for all Phase 1 agents to complete\" line — the range ran to end of file, so the assertions below are file-wide and prove nothing about the contact dispatch"; exit 1; }

# Agent 3 must exist inside the block AND must not be hardcoded to wp-css. The old
# form of this test was `grep -q '^#### Agent 3: wp-css$'`, a frozen full-line needle
# that any re-title defeated — including a re-title back to an unrouted wp-css-only
# dispatch, as long as the wording differed by one character.
a3=$(printf '%s\n' "$contact_block" | grep -E '^#+[[:space:]]*Agent 3\b' || true)
[ -n "$a3" ] \
  || { echo "FAIL: the CONTACT block has no \"Agent 3\" heading — Agent 3 is the CSS/Tailwind slot, and a contact section with no such slot ships unstyled on both paths"; exit 1; }
if printf '%s' "$a3" | grep -qi 'wp-css' && ! printf '%s' "$a3" | grep -qiE 'wp-[ ]?tailwind|routed'; then
  echo "FAIL: the CONTACT block hardcodes wp-css as Agent 3 ($a3) — on a Tailwind project that writes assets/css/styles.css, which the Tailwind starter never enqueues. Route it by template like the non-contact block"; exit 1
fi
printf '%s\n' "$contact_block" | grep -qi 'CSS agent routing' \
  || { echo "FAIL: CONTACT block's Agent 3 does not point at the CSS agent routing table"; exit 1; }

# ---------------------------------------------------------------------------
# The Step 7 report templates must not claim the tailwind path wrote the one file
# its own dispatch prompt forbids. Both summaries listed `assets/css/styles.css`
# unconditionally under "Files created/updated" while the tailwind dispatch prompt
# says "Never write `assets/css/styles.css`. Never emit a `<style>` block." — so on
# a Tailwind project /wp-section reported writing a file nothing wrote (and that the
# Tailwind starter never enqueues). commands/wp-header.md and commands/wp-footer.md
# closed the identical defect by marking the line `[basic only]` and pairing it with
# a `[tailwind only]` counterpart naming the real output surface; this walks EVERY
# such bullet, so a third summary added later is covered and so is a revert of
# either existing one.
#
# The bullet pattern is anchored on the report-list form (`  - assets/css/...`),
# which the file's prose mentions of the same path cannot take: the routing table's
# row starts with `|` and the two dispatch prompts' mentions start with `>`.
#
# Ceiling, deliberate: the counterpart only has to name a path under `components/`
# or `utilities/` — the two surfaces the tailwind dispatch prompt itself names for a
# section. It is not checked against the ladder.
# ---------------------------------------------------------------------------

# Flattened window of the report bullet starting at line $2 of file $1: the bullet
# line plus any continuation lines a re-wrap pushed it onto. The window stops at the
# next bullet, at a blank line and at the fence, so a marker on a NEIGHBOURING
# bullet can never satisfy the bullet under test.
bullet_window() {
  awk -v s="$2" '
    NR < s { next }
    NR > s && (/^[[:space:]]*$/ || /^[[:space:]]*-[[:space:]]/ || /^[[:space:]]*```/) { exit }
    { print }
  ' "$1" | tr '\n' ' ' | sed 's/  */ /g'
}

css_bullets=$(grep -nE '^[[:space:]]*-[[:space:]]*`?assets/css/styles\.css' "$f" || true)
[ -n "$css_bullets" ] || { echo "FAIL: no report bullet in wp-section lists assets/css/styles.css — the basic path must still report the file it writes (or a re-wrap split the bullet marker from the path)"; exit 1; }

while IFS=: read -r lineno rest; do
  [ -n "$lineno" ] || continue
  win=$(bullet_window "$f" "$lineno")

  if printf '%s' "$win" | grep -qF '[tailwind only]'; then
    echo "FAIL: wp-section line $lineno reports assets/css/styles.css as a [tailwind only] output, but the tailwind dispatch prompt forbids writing that file — the marker is inverted: $win"; exit 1
  fi
  printf '%s' "$win" | grep -qF '[basic only]' \
    || { echo "FAIL: wp-section line $lineno lists assets/css/styles.css in a report template with no [basic only] marker — on the tailwind path the command would report writing the file its own dispatch prompt forbids: $win"; exit 1; }

  # The same report must also name what the tailwind path DOES write. Scoped to the
  # whole enclosing fenced block, in both directions, so reordering the two bullets
  # cannot turn this red.
  fstart=$(awk -v s="$lineno" 'NR >= s { exit } /^[[:space:]]*```/ { n = NR } END { print n + 0 }' "$f")
  [ "$fstart" -gt 0 ] || fstart=1
  fend=$(awk -v s="$lineno" 'NR <= s { next } /^[[:space:]]*```/ { print NR; exit }' "$f")
  [ -n "$fend" ] || fend=$(wc -l < "$f")

  found=""
  for b in $(awk -v a="$fstart" -v z="$fend" 'NR >= a && NR <= z && /^[[:space:]]*-[[:space:]]/ { print NR }' "$f"); do
    w=$(bullet_window "$f" "$b")
    if printf '%s' "$w" | grep -qF '[tailwind only]' && printf '%s' "$w" | grep -qE '(components/|utilities/)'; then
      found=1
      break
    fi
  done
  [ -n "$found" ] || { echo "FAIL: the report template holding line $lineno has no [tailwind only] counterpart naming the Tailwind output surface (components/<page-slug>.css or utilities/site.css) — commands/wp-header.md and commands/wp-footer.md pair every [basic only] styles.css line with one"; exit 1; }
done <<< "$css_bullets"

# The one-line summary used to claim "Dispatches three agents in parallel", which
# is true only on `basic` — on `tailwind` wp-tailwind runs AFTER wp-template
# returns, the ownership rule asserted further up. The summary is the first thing
# a skimming agent reads, so it may not contradict the body. Any summary sentence
# claiming parallel dispatch must scope that claim to `basic`. Zero-run means the
# summary makes no parallel claim at all, which is fine: the body assertions carry
# the positive half.
summ=$(awk '/^# WP Section/,/^## Step 1:/' "$f" | tr '\n' ' ' | sed 's/  */ /g')
[ -n "$summ" ] || { echo "FAIL: wp-section has no header/summary region delimited by '## Step 1:' — the summary-governance scan would silently run over nothing"; exit 1; }
while IFS= read -r sent; do
  [ -n "$sent" ] || continue
  if printf '%s' "$sent" | grep -qi 'basic'; then continue; fi
  { echo "FAIL: wp-section's summary claims parallel agent dispatch without scoping it to basic — on tailwind wp-tailwind runs AFTER wp-template returns, and an unconditional parallel claim is the first thing a skimming agent obeys"; exit 1; }
done <<< "$(printf '%s' "$summ" | grep -oE '[^.]*parallel[^.]*' || true)"


# wp-template owns the element tree, and it had no fidelity mandate of its own: the
# teaser rule covered CPT cards and nothing covered ordinary sections. A header CTA
# whose demo carried two <span>s that swap at a breakpoint shipped as one span plus a
# guess, and the defect was invisible above md. Assert the rule where the agent that
# writes the markup will actually read it.
tflat=$(tr '\n' ' ' < agents/wp-template.md | sed 's/  */ /g')
if ! printf '%s' "$tflat" | grep -qF 'SOURCE OF TRUTH'; then
  echo "FAIL: agents/wp-template.md never calls the demo markup the SOURCE OF TRUTH — it authors the element tree for every section on both templates, with only the CPT-teaser rule to bind it"; exit 1
fi
if ! printf '%s' "$tflat" | grep -qF 'Every element the demo renders becomes an element here'; then
  echo "FAIL: agents/wp-template.md does not forbid collapsing the demo's elements — two siblings merged into one renders correctly at the breakpoint being looked at and wrongly at the other"; exit 1
fi
if ! printf '%s' "$tflat" | grep -qF 'Two labels in the demo need two fields'; then
  echo "FAIL: agents/wp-template.md does not require one ACF field per distinct string — one field and a shortened copy is how a demo's two breakpoint labels became one overflowing button"; exit 1
fi


# A repeated block is not one item drawn N times, and a list's order is not the query's
# default. Both were normalised away on a real build: six cards rendered with one icon
# type at one size where the demo mixed SVG art with glyphs at three sizes, and a section
# showing six of seven terms let \`get_terms()\` sort by name — which did not reorder the
# cards so much as choose which term never reached the front page.
if ! printf '%s' "$tflat" | grep -qF 'varies BETWEEN items is data'; then
  echo "FAIL: agents/wp-template.md does not say per-item variation inside a repeated block is data — normalising a grid to one variant looks right and makes every card wrong"; exit 1
fi
if ! printf '%s' "$tflat" | grep -qF "ORDER and COUNT"; then
  echo "FAIL: agents/wp-template.md does not bind a list's order and count to the demo — with a limit, the query's default ordering picks which item is never shown"; exit 1
fi

echo PASS
