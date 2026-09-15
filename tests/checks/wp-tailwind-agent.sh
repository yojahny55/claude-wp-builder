#!/usr/bin/env bash
# wp-tailwind must do double duty: demo conversion AND section authoring
# (the wp-css replacement on the tailwind path).
set -euo pipefail
f=agents/wp-tailwind.md

# Sentences wrap across lines, and a line-anchored grep silently loses an
# assertion the moment someone re-wraps a paragraph. Flatten once and match
# against that.
flatf=$(tr '\n' ' ' < "$f" | sed 's/  */ /g')

# `[^.]{0,N}` is this file's idiom for "these two things are in the same sentence".
# It has false-failed twice: a filename's extension dot ends the window early
# (`components/<slug>.css when the group is local to one page` is ONE sentence and
# three `[^.]` runs), and the most ordinary correct edit of all — splitting a long
# sentence in two — puts the two halves either side of a full stop. `gap N`
# therefore tolerates at most ONE dot inside the window: enough for a path, or for
# the adjacent sentence, and not enough to wander a paragraph away.
gap() { printf '[^.]{0,%d}(\\.[^.]{0,%d})?' "$1" "$1"; }

grep -q 'Section Authoring Mode' "$f" \
  || { echo "FAIL: wp-tailwind has no Section Authoring Mode"; exit 1; }

# The skill deference, the cross-page promotion rule and the prohibition list were
# all gated by bare file-wide presence greps, which the inversions they exist to
# catch survive intact ("Do not read the SKILL … override it wherever they
# disagree" names the skill twice; "always write `utilities/site.css`" names the
# path; `### Never` renamed to `### Always` leaves both prohibition needles where
# they were). They are asserted further down instead, scoped to the region that
# owns them and matched on the RELATION rather than on the token.

# Conversion mode writes a TEMPORARY path and stops. `/wp-tailwindify` Step 3
# hands the agent `<output-path>.tmp` and keeps the verification and the move
# for itself (Step 4 runs after the agent returns, so the agent could not
# condition the move on it even if it wanted to). This file used to say "Write
# the converted HTML to the output path provided", which contradicted that and
# reinstated the destructive in-place write.
printf '%s' "$flatf" | grep -qF 'Write the converted HTML to `<output-path>.tmp`' \
  || { echo "FAIL: wp-tailwind does not write the conversion to \`<output-path>.tmp\`"; exit 1; }
printf '%s' "$flatf" | grep -qF 'never to `<output-path>` itself' \
  || { echo "FAIL: wp-tailwind does not forbid writing \`<output-path>\` itself"; exit 1; }
# The wording is "the verification that gates the move is not yours to run", not
# "you do not verify your own conversion". The latter contradicted this file's
# own Quality Checks section, which tells the agent to verify delimiters and
# `<style>` blocks before writing — a direct contradiction inside the file the
# actor split was about. A self-check before the `.tmp` write is fine and wanted;
# what the agent must not own is the GATE.
printf '%s' "$flatf" | grep -qF 'Then stop: you do not move, rename or delete `<output-path>`, and the verification that gates the move is not yours to run' \
  || { echo "FAIL: wp-tailwind does not stop after the temporary write — the move, and the verification that gates it, belong to /wp-tailwindify Step 4"; exit 1; }
printf '%s' "$flatf" | grep -qF 'that is a self-check, not the gate' \
  || { echo "FAIL: wp-tailwind does not separate its own Quality Checks self-check from /wp-tailwindify Step 4's gate — without that, Step 5 and the Quality Checks section contradict each other"; exit 1; }
printf '%s' "$flatf" | grep -qF 'Write the converted HTML to the output path provided' \
  && { echo "FAIL: wp-tailwind writes straight to the output path — that is the truncating in-place write the .tmp contract exists to prevent"; exit 1; }

# ---------------------------------------------------------------------------
# The mode gate. It must key on the whole `Mode: **author**` LINE a dispatcher
# emits, never on a bare `author` token appearing anywhere in the prompt: the
# demo-conversion dispatch hands this agent an input FILE PATH, so a demo page
# named `demo/author.html` (or `authors.html` — ordinary pages on a blog site)
# put the bare token in the prompt, flipped the agent into Section Authoring Mode
# and the page was then silently never converted. The old gate here asserted the
# bare-token rule verbatim, so it locked the defect in.
#
# Directed, bullet by bullet, rather than by presence: swapping the two bullets
# (absence of the line selects authoring, presence selects conversion) names both
# modes and both mode lines, so any mere-presence test passes the inversion. For
# each bullet, the CONDITION is the text before the mode name it selects; that
# condition must carry the mode line, and must be negated for exactly one of the
# two modes. Scanning only the condition is deliberate: the authoring bullet's
# tail legitimately says "the demo-conversion pipeline below does not apply", and
# a bullet-wide negation scan would read that "not" as an inverted condition.
# ---------------------------------------------------------------------------
mode_region=$(awk '/^## Mode Selection/,/^# WP Tailwind/' "$f")
if ! printf '%s\n' "$mode_region" | tail -1 | grep -q '^# WP Tailwind'; then
  echo "FAIL: the Mode Selection region is not terminated by the '# WP Tailwind' heading — its assertions would silently become file-wide"; exit 1
fi

# One flattened window per bullet: the bullet line plus the continuation lines a
# ~90-column re-wrap pushed it onto. Ends at the next bullet or a blank line, so a
# neighbouring bullet can never satisfy the bullet under test.
mode_bullets=$(printf '%s\n' "$mode_region" | grep -c '^- ' || true)
[ "$mode_bullets" -eq 2 ] \
  || { echo "FAIL: the Mode Selection list has $mode_bullets top-level bullets, expected exactly 2 (one per mode) — a third branch, or a lost one, means the walk below is no longer reading the gate it thinks it is"; exit 1; }

seen_author=0
seen_convert=0
for b in $(printf '%s\n' "$mode_region" | grep -n '^- ' | cut -d: -f1); do
  win=$(printf '%s\n' "$mode_region" | awk -v s="$b" '
    NR < s { next }
    NR > s && (/^[[:space:]]*$/ || /^-[[:space:]]/) { exit }
    { print }
  ' | tr '\n' ' ' | sed 's/  */ /g')

  # Which mode does this bullet select, and what is its condition clause?
  mode=$(printf '%s' "$win" | grep -oE 'Section Authoring Mode|Demo Conversion Mode' | head -1 || true)
  [ -n "$mode" ] \
    || { echo "FAIL: a Mode Selection bullet names neither mode — every branch of the gate must say which mode it selects: $win"; exit 1; }
  cond=${win%%"$mode"*}

  printf '%s' "$cond" | grep -qF 'Mode: **author**' \
    || { echo "FAIL: the Mode Selection bullet for $mode does not test for a \`Mode: **author**\` line — the gate must key on the mode line a dispatcher emits, not on a bare \`author\` token an input path like \`demo/author.html\` also supplies: $win"; exit 1; }

  # The negation has to GOVERN THE MODE-LINE NOUN, not merely appear somewhere in the
  # condition. Scanning the whole condition marked a bullet "inverted" the moment any
  # `no|not|without` preceded the mode name — so adding the clarification this file's
  # own prose insists on ("a `Mode: **author**` line, not merely a bare `author`
  # token") turned the gate red while stating exactly what the gate exists to
  # enforce. A check that fails on the correct edit gets muted, and then it protects
  # nothing. So look only at the 40 characters immediately before the mode line:
  # "The prompt carries no `Mode: **author**` line" negates; "…carries a `Mode:
  # **author**` line, not merely a bare `author` token" does not.
  neg_window=$(printf '%s' "${cond%%"Mode: **author**"*}" | tail -c 40)
  if printf '%s' "$neg_window" | grep -qiE '\b(no|not|without|absent|lacks?|missing|omits?)\b'; then
    negated=1
  else
    negated=0
  fi

  case "$mode" in
    'Section Authoring Mode')
      seen_author=1
      [ "$negated" -eq 0 ] \
        || { echo "FAIL: Section Authoring Mode is selected by the ABSENCE of the \`Mode: **author**\` line — the gate is inverted, and every demo-conversion dispatch would land in authoring mode: $win"; exit 1; } ;;
    'Demo Conversion Mode')
      seen_convert=1
      [ "$negated" -eq 1 ] \
        || { echo "FAIL: Demo Conversion Mode is selected by the PRESENCE of the \`Mode: **author**\` line — the gate is inverted, and every /wp-section dispatch would land in conversion mode: $win"; exit 1; } ;;
  esac
done
[ "$seen_author" -eq 1 ] \
  || { echo "FAIL: the Mode Selection list has no bullet selecting Section Authoring Mode"; exit 1; }
[ "$seen_convert" -eq 1 ] \
  || { echo "FAIL: the Mode Selection list has no bullet selecting Demo Conversion Mode"; exit 1; }

# The hazard itself has to stay written down, or the next author re-keys the gate
# on the bare word and re-opens the defect. Naming the concrete filename is the
# point: `author` in an input PATH is what selects nothing.
#
# Ceiling, deliberate: this asserts the warning is PRESENT, not that it points the
# right way — a region that named `demo/author.html` while claiming it DOES select
# authoring mode would satisfy it. The direction is held by the bullet walk above,
# which is where the gate actually lives; this only stops the rationale being
# quietly dropped, which is how the bare-token rule got written in the first place.
printf '%s\n' "$mode_region" | tr '\n' ' ' | sed 's/  */ /g' | grep -qF 'author.html' \
  || { echo "FAIL: the Mode Selection region does not warn that a bare \`author\` inside an input path (\`demo/author.html\`) must not select the mode — that is the defect this gate exists to keep closed"; exit 1; }

# Straight revert tripwire, file-wide: the old rule's own wording, in a form the
# new one cannot produce (the new gate quotes \`Mode: **author**\`, never a lone
# \`author\`, after "literal token").
if printf '%s' "$flatf" | grep -qE 'literal token .author.'; then
  echo "FAIL: wp-tailwind still keys a mode on the literal token \`author\` — an input path such as \`demo/author.html\` supplies that token, which is the silent wrong-mode defect"; exit 1
fi

# ---------------------------------------------------------------------------
# Section Authoring Mode region. Scoped, because Demo Conversion Mode's own prose
# talks at length about converting declarations into utilities and would satisfy
# the assertions below from the wrong half of the file. `## Quality Checks` closes
# the region — proved, because a renamed terminator runs awk's range to EOF and
# silently turns each scoped assertion back into a file-wide grep. That proof also
# covers the empty-region case: `tail -1` of nothing matches nothing, so a
# separate `[ -n … ]` here would be dead code.
# ---------------------------------------------------------------------------
sa=$(awk '/^## Section Authoring Mode/,/^## Quality Checks/' "$f")
if ! printf '%s\n' "$sa" | tail -1 | grep -q '^## Quality Checks'; then
  echo "FAIL: the Section Authoring Mode region is not terminated by a '## Quality Checks' heading — its assertions would silently become file-wide"; exit 1
fi
saflat=$(printf '%s\n' "$sa" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/ \\ / /g' -e 's/  */ /g')

# Authoring mode REPLACES wp-css on the tailwind path. Dispatching both writes the
# same section twice — once as BEM in styles.css, once as utilities — and the two
# fight. Both orders accepted, since a rewrite may lead with either the agent or
# the prohibition, and the negation must PRECEDE the verb so that a bare "dispatch
# both" cannot satisfy it. The comment used to CLAIM both orders and not deliver
# them: `both[^.]{0,60}wp-css` was too short for the agent-first reordering
# ("Never dispatch both agents for the same section: `wp-tailwind` is the
# `template=tailwind` replacement for `wp-css`."), and the leading `[^.]{0,90}`
# could not survive the semicolon being promoted to a full stop. `gap` fixes both.
if ! printf '%s' "$saflat" | grep -Eqi "wp[ -]{1,2}css$(gap 90)(never|do not|don'?t|must not)[^.]{0,30}(dispatch|run|use)[^.]{0,20}both|(never|do not|don'?t|must not)[^.]{0,30}(dispatch|run|use)$(gap 60)both$(gap 140)wp[ -]{1,2}css"; then
  echo "FAIL: Section Authoring Mode does not forbid dispatching wp-css and wp-tailwind for the same section — it is the wp-css REPLACEMENT on the tailwind path, and running both styles the section twice"; exit 1
fi

# --- Deference to the convention skill. -------------------------------------
# `grep -q 'wp-tailwind-system'` over the whole file was satisfied by the exact
# inversion it existed to prevent — "Do not read the SKILL … override it wherever
# they disagree" names the skill twice. Three assertions replace it: a positive
# read/follow directive naming the skill, a forbidding gate on the negated read,
# and the prohibition on restating or overriding what the skill owns. `[ -]{1,2}`
# throughout because a wrap breaking on a hyphen leaves `wp- tailwind-system`
# behind once the region is flattened. `(/SKILL\.md)?` because the skill is named
# by path and that path's own dot would otherwise close the sentence window.
skill='wp[ -]{1,2}tailwind[ -]{1,2}system(/SKILL\.md)?'
if ! printf '%s' "$saflat" | grep -Eqi "(read|follow|consult|obey|defer to)[^.]{0,70}$skill|$skill[^.]{0,70}(read|follow|consult|obey|defer)"; then
  echo "FAIL: Section Authoring Mode never directs the agent to READ the wp-tailwind-system skill — naming the skill is not deferring to it, and the ladder, file layout and prohibition list live only there"; exit 1
fi
if printf '%s' "$saflat" | grep -Eqi "(do not|does not|don'?t|never|must not|no need to)[ a-z]{0,24}(read|consult|follow|open)[^.]{0,70}$skill"; then
  echo "FAIL: Section Authoring Mode tells the agent NOT to read the wp-tailwind-system skill — that skill owns the decision ladder this mode is supposed to execute"; exit 1
fi
if ! printf '%s' "$saflat" | grep -Eqi '(\bnot\b|\bnever\b)[^.]{0,70}(restat|re-?state|overrid|overrul|contradict|supersed|duplicat)'; then
  echo "FAIL: Section Authoring Mode does not forbid restating or overriding what the wp-tailwind-system skill owns — an agent free to override the skill wherever they disagree is running a rival ladder"; exit 1
fi

# --- Cross-page promotion. ---------------------------------------------------
# `grep -Eqi 'grep|search'` file-wide plus a bare `utilities/site.css` presence
# grep was the weakest gate in this file: "No cross-page detection … always write
# `utilities/site.css`" satisfied both. What carries the meaning is the
# DISCRIMINATION — two or more pages promote to `utilities/site.css`, a single page
# stays in `components/<slug>.css` — so both halves are asserted, plus the search
# over the theme's other files that produces the count.
if ! printf '%s' "$saflat" | grep -Eqi '(grep|search|scan|look)[a-z]*[^.]{0,90}(other|existing|sibling|already|rest of)'; then
  echo "FAIL: Section Authoring Mode never tells the agent to search the theme's OTHER files for the same utility group — without that step the cross-page rule has nothing to count"; exit 1
fi
if ! printf '%s' "$saflat" | grep -Eqi "(two|2|multiple|more than one|second|several)[^.]{0,60}pages?[^.]{0,60}utilities/site\.css|utilities/site\.css$(gap 80)(two|2|multiple|more than one|second|several)[^.]{0,40}pages?"; then
  echo "FAIL: Section Authoring Mode does not tie \`utilities/site.css\` to the two-or-more-pages condition — a rule that always writes it, or never does, passes a bare mention of the path"; exit 1
fi
if ! printf '%s' "$saflat" | grep -Eqi "(one|a single|1)[^.]{0,20}page[^.]{0,60}components/|components/$(gap 60)(one|a single|1)[^.]{0,20}page"; then
  echo "FAIL: Section Authoring Mode does not keep the single-page case in \`components/<slug>.css\` — without that half, \"promote to utilities/site.css\" has nothing to be promoted FROM"; exit 1
fi

# --- The author-mode input contract. ----------------------------------------
# This mode has two callers with opposite inputs: /wp-yolo's section walk, which
# converts the demo in Step 2.6 and really does pass Tailwind-native markup, and
# /wp-tailwind-migrate Step 4, whose whole premise is a theme that was never
# converted. A contract naming only the first state sends the migration agent up
# the @apply ladder with plain BEM markup, and the theme ships plain-CSS semantics
# with a Tailwind build bolted on. Scoped to the `### Input state` sub-region: the
# mode intro states the same rule in passing, and a region-wide match would let
# that single sentence stand in for the whole branch.
is=$(printf '%s\n' "$sa" | awk '/^### Input state/,/^### Procedure/')
if ! printf '%s\n' "$is" | tail -1 | grep -q '^### Procedure'; then
  echo "FAIL: the '### Input state' sub-region is not terminated by a '### Procedure' heading — the input-contract assertions would silently widen to the whole mode"; exit 1
fi
isflat=$(printf '%s\n' "$is" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/ \\ / /g' -e 's/  */ /g')

# The unconverted state must be admitted, and tied to the caller that produces it
# by a verb of handing-over — "a migration hands you plain-CSS markup". Naming the
# two together is not enough: "no state ever reaches this mode unconverted, since
# migrations convert first" names both and asserts the opposite. All three orders
# a rewrite may produce are accepted. `[ -]{1,2}` because a wrap that breaks on the
# hyphen leaves "plain- CSS" behind once the region is flattened. `gap` rather than
# a bare `[^.]{0,140}` because the paragraph's most natural rewrite splits the
# state off from the caller — "**Plain-CSS** — the markup is a theme's existing BEM.
# A migration (`/wp-tailwind-migrate` Step 4) hands it to you …" — and a window that
# cannot cross one full stop rejects it. The `vb` requirement is what keeps the
# wider window honest: "no state ever reaches this mode unconverted, since
# migrations convert first" names both and still has no verb of handing-over.
st="(plain[ -]{1,2}css|unconverted|not (yet )?converted)"
vb="(hand|pass|give|send|suppl|provid|arriv|receiv)[a-z]*"
g140=$(gap 140); g70=$(gap 70)
if ! printf '%s' "$isflat" | grep -Eqi "${st}${g140}migrat[a-z]*${g70}${vb}|${st}${g140}${vb}${g70}migrat|migrat[a-z]*${g70}${vb}${g70}${st}"; then
  echo "FAIL: author mode's input contract does not admit plain-CSS markup from a migration — /wp-tailwind-migrate Step 4 has no converted demo to hand it, and a contract saying the input is always Tailwind-native makes that dispatch a no-op"; exit 1
fi

# …and admitting it is worthless unless the declaration-to-utility translation is
# switched back ON for it. Nothing else on the migration path performs it.
# The OPERATIVE instruction is the bullet "every declaration → the equivalent
# utility on the element (Step 3)", which states the mapping with an arrow and no
# verb at all; the verb-only needle this replaces was satisfied instead by an
# incidental sub-clause ("nothing else in it turns a declaration into a utility"),
# so rewording that clause failed the check while deleting the bullet passed it.
# Keying on the UNIVERSAL quantifier — every/each/all declarations — matches the
# obligation and not the aside, whether the mapping is written as an arrow, as
# "becomes", or as a verb ("translate every declaration into the equivalent
# utility"). `to`/`as` are deliberately NOT in the mapping alternation: both are
# common enough to appear in a sentence that says the opposite.
if ! printf '%s' "$isflat" | grep -Eqi '(every|each|all)[ a-z]{0,14}declarations?[^.]{0,60}(→|->|becomes?|into|maps? to)[^.]{0,60}utilit'; then
  echo "FAIL: author mode admits unconverted markup but never tells the agent to translate its declarations into utilities — the @apply ladder would land on BEM markup nobody converted"; exit 1
fi

# The other state must survive intact: /wp-yolo is this mode's main caller and its
# section walk genuinely does hand over converted markup.
if ! printf '%s' "$isflat" | grep -Eqi 'tailwind[ -]{1,2}native[^.]{0,110}section walk|section walk[^.]{0,110}tailwind[ -]{1,2}native'; then
  echo "FAIL: author mode no longer states that the section walk's markup arrives Tailwind-native — /wp-yolo Step 2.6 converts the demo first, and this mode must keep carrying those utilities across untranslated"; exit 1
fi

# --- The prohibition list. ---------------------------------------------------
# `### Never` was gated by two file-wide presence greps, so renaming the heading to
# `### Always` left both needles exactly where they were and turned the list into
# an instruction to write `assets/css/styles.css` — which the check then certified.
# The needles are scoped to a sub-region whose HEADING must itself express
# prohibition: `### Prohibited`, `### Do not`, `### Forbidden`, `### Never do this`
# are all fine, `### Always` is the defect. Every prohibition-headed `###` block in
# the mode is collected, so reordering or splitting the list is fine too, and the
# collector toggles rather than running to EOF — `sa` already ends at
# `## Quality Checks` and any heading at `##`/`###` closes the current block.
nev=$(printf '%s\n' "$sa" | awk '
  /^###[[:space:]]/ { inreg = (tolower($0) ~ /never|prohibit|forbidden|forbid|do not|don.t|must not/) ? 1 : 0; next }
  /^##[[:space:]]/  { inreg = 0; next }
  inreg { print }
')
if [ -z "$nev" ]; then
  echo "FAIL: Section Authoring Mode has no prohibition sub-section — wanted a '### Never'-style heading (never/prohibited/forbidden/do not/must not) with its list under it; a heading that does not say NO turns every rule beneath it into an instruction"; exit 1
fi
nevflat=$(printf '%s\n' "$nev" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/ \\ / /g' -e 's/  */ /g')

printf '%s' "$nevflat" | grep -qF 'assets/css/styles.css' \
  || { echo "FAIL: the prohibition list does not name \`assets/css/styles.css\` — that is the template=basic surface, and nothing else in author mode stops the agent writing it"; exit 1; }
printf '%s' "$nevflat" | grep -qF 'Create a file you do not fill' \
  || { echo "FAIL: the prohibition list has lost the no-empty-file rule (\`Create a file you do not fill\`) — a registered but empty .css file breaks the build for the next agent"; exit 1; }

# The directory bullet must carry its EXCEPTION. Written flat — "Create a directory
# under `assets/css/src/tailwindcss/`." — it forbade `layouts/`, which is one of the
# four names skills/wp-tailwind-system/SKILL.md sanctions and which /wp-header and
# /wp-footer both require as an @apply target. The starter ships only the sanctioned
# directories that already hold a file (git cannot track an empty one), so `layouts/`
# is absent from a fresh theme and an agent obeying the flat bullet could never
# create it. A fifth name is the thing forbidden.
printf '%s' "$nevflat" | grep -qE 'assets/css/src/tailwindcss/' \
  || { echo "FAIL: the prohibition list no longer names \`assets/css/src/tailwindcss/\` — the no-fifth-directory rule is gone"; exit 1; }
printf '%s' "$nevflat" | grep -Eqi 'tailwindcss/[^.]{0,90}(other than|except|besides|apart from)[^.]{0,120}layouts|layouts[^.]{0,120}(other than|except|besides|apart from)[^.]{0,90}tailwindcss/' \
  || { echo "FAIL: the directory prohibition has no exception for the four sanctioned names — written flat it forbids \`layouts/\`, which commands/wp-header.md and commands/wp-footer.md both target, so an agent obeying its own Never list can never write the file its dispatch demands. Say \"other than base, components, layouts and utilities\""; exit 1; }

# The template part is wp-template's file. agents/wp-tailwind.md names none of
# prefix_get_field, esc_html, esc_url, @package or ABSPATH, so an authoring pass here
# strips the section's ACF wiring, escaping and i18n — and /wp-section used to
# dispatch this agent IN PARALLEL with wp-template against that same path, last
# writer wins. Both halves: the prohibition on authoring, and the licence to edit it.
printf '%s' "$saflat" | grep -Eqi "(never|do not|don'?t|must not|not yours)[^.]{0,80}(create|author|rewrite|write)[^.]{0,60}template part|template part[^.]{0,60}(is )?not yours" \
  || { echo "FAIL: Section Authoring Mode does not forbid creating or rewriting the template part — that file belongs to wp-template, the only agent carrying the ACF, escaping and i18n contract, and a section authored here ships with none of it"; exit 1; }
printf '%s' "$saflat" | grep -Eqi 'edit[^.]{0,40}in place|in place[^.]{0,40}edit' \
  || { echo "FAIL: Section Authoring Mode never tells the agent to edit the template part IN PLACE — forbidding the rewrite without licensing the edit leaves the agent no way to rename a promoted class group at all"; exit 1; }

# --- Rung-aware class naming. -------------------------------------------------
# The Procedure sends a group used on 2+ distinct pages to `utilities/site.css`, and
# then demanded every class be named `<block>__<element>`. A group qualifies for that
# file BECAUSE it spans two or more blocks, so it cannot carry one block's name: the
# rule could not apply to the rung it governed. Assert the site-scoped form exists
# and is tied to utilities/site.css, and that the block-scoped form survives for the
# local rung.
printf '%s' "$saflat" | grep -Eqi 'utilities/site\.css[^.]{0,120}site__|site__[^.]{0,120}utilities/site\.css' \
  || { echo "FAIL: Section Authoring Mode gives cross-page promotions no site-scoped class name — a group promoted to utilities/site.css qualified precisely because it spans 2+ blocks, so naming it \`<block>__<element>\` is a name it cannot honestly carry and the next section agent collides with it"; exit 1; }
printf '%s' "$saflat" | grep -qF '<block>__<element>' \
  || { echo "FAIL: Section Authoring Mode lost the \`<block>__<element>\` name for the LOCAL rung — that is what stops parallel section agents colliding on a selector in components/<slug>.css"; exit 1; }

# --- The ladder is deferred during demo conversion. ---------------------------
# Rungs 2-4 name `utilities/site.css` and `components/<slug>.css`; Demo Conversion
# Mode writes one standalone HTML file and touches no CSS tree, and the conversion
# half of this file never references the SKILL. A rehearsal that actually executed a
# conversion found 16 qualifying groups and zero promotable ones — conversion is rung
# 1, unconditionally. Nothing said so, so an agent that read the SKILL mid-conversion
# would invent CSS files for a theme that does not exist yet. Scoped to the
# conversion half: the region from the converter heading to Section Authoring Mode.
conv=$(awk '/^# WP Tailwind — Demo CSS to Tailwind Converter/,/^## Section Authoring Mode/' "$f")
if ! printf '%s\n' "$conv" | tail -1 | grep -q '^## Section Authoring Mode'; then
  echo "FAIL: the Demo Conversion Mode region is not terminated by the '## Section Authoring Mode' heading — the assertion below would silently become file-wide and be satisfied by authoring mode's own ladder prose"; exit 1
fi
convflat=$(printf '%s\n' "$conv" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/ \\ / /g' -e 's/  */ /g')
if ! printf '%s' "$convflat" | grep -Eqi "ladder[^.]{0,90}(deferred|does not run|not run|never runs|no|deliberate)|rung 1[^.]{0,90}(everywhere|unconditional|deliberate|intentional)"; then
  echo "FAIL: Demo Conversion Mode never says the promotion ladder is deliberately deferred to the section walk — its rungs name CSS files that only exist inside a theme, conversion writes one standalone HTML file, so rung-1-everywhere is correct here and an agent reading the SKILL mid-conversion invents CSS files with nowhere to go"; exit 1
fi

# --- Agent frontmatter conventions. -------------------------------------------
# An agent is declared with `name:` + `tools:` (CLAUDE.md, "Authoring
# conventions"). `allowed-tools:` is the COMMAND key; on an agent file it is an
# unrecognized key, so the restriction is never applied and the agent runs with
# every tool. That is what shipped here: wp-tailwind was the only agent with no
# `name:` and the only one whose grant was written `allowed-tools:`, and the
# plugin's own agent registry listed it as "All tools" while every sibling listed
# an explicit set. Asserted across the whole directory so the next agent file
# cannot repeat it. Both keys are matched line-anchored and independently, so
# reordering the frontmatter keys is fine.
for a in agents/*.md; do
  grep -Eq '^name:[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*$' "$a" \
    || { echo "FAIL: $a has no 'name:' key in its frontmatter — an agent is declared with name + tools (CLAUDE.md, Authoring conventions)"; exit 1; }
  grep -Eq '^tools:' "$a" \
    || { echo "FAIL: $a declares no 'tools:' key — 'allowed-tools:' is the command key; on an agent it is ignored and the agent silently runs unrestricted"; exit 1; }
done

grep -Eq '^name:[[:space:]]*wp-tailwind[[:space:]]*$' "$f" \
  || { echo "FAIL: agents/wp-tailwind.md does not declare 'name: wp-tailwind' — the dispatching commands address this agent by that name"; exit 1; }

# --- The frontmatter and the instructions must agree about running things. ----
# Deliberately a CONSISTENCY gate, not one resolution of the defect: grant the
# agent Bash and a command block is fine; withhold it and the file must not tell
# the agent to run anything, because it cannot. The defect removed here was a
# `### Verify before reporting done` heading over a fenced
# `bin/tailwind-native-check.sh <theme-path>` beneath a tool grant with no Bash in
# it — a self-verification the agent could only skip or fake.
# Naming the script in prose is NOT running it, and this file legitimately explains
# who does run it, so only the invocation form is forbidden: a shell code fence, or
# an unbackticked script path followed by a real argument.
# `(allowed-)?tools:` so the extraction survives whichever key a future author
# reaches for; the convention gate above is what pins it to the correct one.
tools=$(awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm && /^---[[:space:]]*$/ {exit} fm && /^(allowed-)?tools:/' "$f")
if [ -z "$tools" ]; then
  echo "FAIL: agents/wp-tailwind.md has no tools line in its frontmatter — the tool grant this check compares the instructions against is missing"; exit 1
fi
case "$tools" in
  *Bash*) : ;;  # Bash granted — the agent may be told to run a script.
  *)
    if grep -Eq '^[[:space:]]*```(bash|sh|shell|console)' "$f"; then
      echo "FAIL: agents/wp-tailwind.md carries a shell command block but its tool grant has no Bash ($tools) — the agent can only skip that step or report a run it never made"; exit 1
    fi
    # Backticked spans are stripped OUTRIGHT before the test rather than excluded by a
    # `(^|[^`])` prefix. That prefix only exempted a backtick IMMEDIATELY before
    # `bin/`, so a perfectly ordinary backticked reference —
    # `` `${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh <theme-dir>` `` — matched
    # on the `/` in front of `bin` and read as a bare shell invocation.
    # tests/checks/tailwind-native.sh stays GREEN on that exact string, so the two
    # gates disagreed about the same text; naming a script inside backticks is prose,
    # which this file legitimately does when it explains who runs the check.
    nobt=$(printf '%s' "$flatf" | sed 's/`[^`]*`/ /g')
    if printf '%s' "$nobt" | grep -Eq '(bin|scripts)/[A-Za-z0-9._-]+\.sh +[<$"/A-Za-z]'; then
      echo "FAIL: agents/wp-tailwind.md invokes a script with an argument but its tool grant has no Bash ($tools) — either grant the tool or move the run to the dispatching command"; exit 1
    fi
    ;;
esac

# The settled decision, asserted after the consistency gate above so that gate is
# still exercised on a Bash-granted file rather than short-circuited by this one:
# wp-tailwind does not get Bash. It writes markup and CSS; the only script in its
# orbit is bin/tailwind-native-check.sh, and "The convention check is not yours to
# run" explains why running that mid-walk reads a FAIL off a correctly progressing
# build. Granting Bash here re-opens that door.
case "$tools" in
  *Bash*)
    echo "FAIL: agents/wp-tailwind.md grants Bash ($tools) — this agent authors markup and CSS only, and the one script it might reach for (bin/tailwind-native-check.sh) judges a FINISHED theme, so mid-walk it fails by construction; the dispatching command runs it"; exit 1 ;;
esac

# The breakpoint table shipped INVERTED: it mapped `max-width: 640px` to a bare `sm:`.
# A bare Tailwind prefix is MIN-width (`md:flex` compiles to `@media (width >= 48rem)`),
# and this repo's own CSS convention is mobile-first `min-width` queries — the direction
# the table never mentioned. An agent obeying it fires every responsive rule on the wrong
# side of every breakpoint, and the markup still compiles, so nothing downstream catches
# it. Assert the DIRECTION, not the wording: bare prefixes belong to min-width, and a
# max-width query must be spelled with the `max-` form.
bpflat=$(sed -n '/breakpoint prefix/,/^### /p' agents/wp-tailwind.md | tr '\n' ' ' | sed 's/  */ /g')
if [ -z "$bpflat" ]; then
  echo "FAIL: agents/wp-tailwind.md has no breakpoint-prefix region — the two assertions below would scan an empty string and assert nothing"; exit 1
fi
if ! printf '%s' "$bpflat" | grep -Eq 'min-width: ?[0-9]+px` → `(sm|md|lg|xl):'; then
  echo "FAIL: the breakpoint table never maps a min-width query to a bare prefix — a bare Tailwind prefix IS min-width, and mobile-first min-width queries are this repo's own CSS convention, so the common case is unmapped"; exit 1
fi
if printf '%s' "$bpflat" | grep -Eq 'max-width: ?[0-9.]+px` → `(sm|md|lg|xl):'; then
  echo "FAIL: the breakpoint table maps a max-width query to a BARE prefix — bare prefixes are min-width, so this inverts every responsive rule in the converted demo while still compiling"; exit 1
fi

# The colour-mapping step used to send the agent to `.claude/CLAUDE.md` for the theme's
# `@theme` values. That file names the location but carries no values (grep the template in
# commands/wp-init.md: zero hex literals), so the agent found nothing, fell through to
# "No match", and shipped the whole site on Tailwind's built-in palette instead of the
# project's tokens. The step must name the file the values actually live in.
if ! printf '%s' "$flatf" | grep -Eq 'assets/css/src/tailwindcss/main\.css[^.]{0,200}(@theme|colou?r)|@theme[^.]{0,200}assets/css/src/tailwindcss/main\.css'; then
  echo "FAIL: the colour-mapping step does not send the agent to <theme>/assets/css/src/tailwindcss/main.css for the @theme values — .claude/CLAUDE.md names that file but holds no colour values, so an agent reading only it falls through to Tailwind's built-in palette"; exit 1
fi

# Section Authoring Mode shipped with NO fidelity mandate at all. `wp-css` carried one
# ("the demo is the SOURCE OF TRUTH, not inspiration. Your job is to COPY, not
# re-author"), and that agent runs only on `basic` — so every tailwind project was built
# by agents that were never told to copy. The drift was always in the same direction:
# an "equivalent" utility instead of the declared one, a dropped breakpoint variant.
# Assert the mandate and the two substitutions that defeated it.
if ! printf '%s' "$flatf" | grep -qE '### Transcription Mode.*SOURCE OF TRUTH'; then
  echo "FAIL: agents/wp-tailwind.md does not call the demo the SOURCE OF TRUTH in Transcription Mode — the mandate agents/wp-css.md carries for \`basic\`, absent on the path that builds every tailwind project"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF 'character for character'; then
  echo "FAIL: agents/wp-tailwind.md does not require utilities carried across character for character — without it, an 'equivalent' utility is a silent geometry change"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF 'breakpoint variant survives'; then
  echo "FAIL: agents/wp-tailwind.md does not require every breakpoint variant to survive — a variant dropped as 'the default' only shows at that breakpoint, which is where these defects hid"; exit 1
fi

# Demo Conversion Mode dropped a whole reset rule because most of it was covered by
# preflight. "Preflight covers it" is a per-DECLARATION judgement and was applied to the
# rule. Two more couplings bit the same conversion: `text-*` carries a line-height that a
# declared font-size does not, and two overlapping `max-*` variants do not resolve in
# source order.
if ! printf '%s' "$flatf" | grep -qF 'DECLARATION BY DECLARATION'; then
  echo "FAIL: agents/wp-tailwind.md does not require a reset rule to be converted declaration by declaration — 'preflight covers it' applied to the whole rule is how \`cursor:pointer\` left every button on a site"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF 'cursor'; then
  echo "FAIL: agents/wp-tailwind.md never names \`cursor\` — it is the declaration preflight does not restore and the one that shipped broken"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF '@layer base'; then
  echo "FAIL: agents/wp-tailwind.md does not say the carried-over reset goes in @layer base — unlayered CSS outranks every utility, which is a second defect wearing the first one's fix"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF 'sets line-height too'; then
  echo "FAIL: agents/wp-tailwind.md does not warn that \`text-*\` sets line-height — a demo declaring 14px/20px and overriding only the size renders 24px once converted to text-base"; exit 1
fi
if ! printf '%s' "$flatf" | grep -qF 'do not resolve in source order'; then
  echo "FAIL: agents/wp-tailwind.md does not warn that two overlapping max-* variants do not resolve in source order — the literal, faithful conversion of a banded rule renders the wrong side"; exit 1
fi

echo PASS
