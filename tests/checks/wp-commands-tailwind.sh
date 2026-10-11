#!/usr/bin/env bash
# Every command that emits CSS must route by template, not hardcode wp-css.
set -euo pipefail
cd "$(dirname "$0")/../.."
# /wp-page and /wp-header keep long steps in skills/<command>-run/references/; read them as a run does.
. tests/checks/lib/expand-command.sh
expand_command commands/wp-page.md; page_md=$EXPANDED
expand_command commands/wp-header.md; wp_header=$EXPANDED
for f in "$page_md" "$wp_header" commands/wp-footer.md commands/wp-cpt.md; do
  # Backticked, so this cannot be satisfied by the `wp-tailwind-system` skill
  # reference line 9 separately mandates — a bare 'wp-tailwind' grep was a
  # decoration that could never fail on its own.
  grep -qF '`wp-tailwind`' "$f" \
    || { echo "FAIL: $f never names the \`wp-tailwind\` agent"; exit 1; }
  grep -Eqi 'template.{0,40}tailwind|tailwind.{0,40}template' "$f" \
    || { echo "FAIL: $f does not read the project template"; exit 1; }
  grep -q 'wp-tailwind-system' "$f" \
    || { echo "FAIL: $f does not point the agent at wp-tailwind-system"; exit 1; }

  # The author-mode line, and it must live on a BLOCKQUOTE line — the only text
  # these commands actually hand an agent. agents/wp-tailwind.md selects Section
  # Authoring Mode on a `Mode: **author**` line and on nothing else, so a routing
  # block that only *describes* author mode in prose dispatches an agent that
  # reads its prompt as a demo conversion and writes a `.tmp` nobody asked for.
  # It used to gate on a bare `author` token instead, which an ordinary input
  # path (`demo/author.html`) supplies by accident — that is the defect this
  # assertion's other half, in tests/checks/wp-tailwind-agent.sh, closes.
  #
  # File-wide over quoted lines rather than scoped to one dispatch site on
  # purpose: in these four commands ONE quoted prompt serves both agents (wp-css
  # on `basic`, wp-tailwind on `tailwind`), so the mode line cannot sit inside
  # that shared block — it would tell wp-css it is in author mode. It sits in the
  # `### CSS agent routing` block as the line the `tailwind` dispatch prepends.
  # Prose, headings and the routing table cannot satisfy this; only a `>` line can.
  #
  # `|| true` is load-bearing, exactly as tests/checks/wp-tailwind-migrate.sh:531
  # documents for the same idiom: under `set -euo pipefail` a zero-match `grep`
  # inside a command substitution aborts the whole script, so a file with no
  # blockquote at all exited 1 with NO message — the operator saw a silent
  # non-zero and none of the diagnosis below. Let the assertion do the talking.
  qmode=$(grep -E '^[[:space:]]*>' "$f" | sed -e 's/^[[:space:]]*>//' -e 's/[*_]//g' | tr '\n' ' ' | sed 's/  */ /g' || true)
  printf '%s' "$qmode" | grep -qiE 'Mode: ?author' \
    || { echo "FAIL: $f has no QUOTED \`Mode: **author**\` line for its tailwind dispatch to hand the agent — agents/wp-tailwind.md selects Section Authoring Mode on that line and on nothing else, so without it the dispatched wp-tailwind runs Demo Conversion Mode. Describing author mode in prose does not count: the agent only ever sees the blockquote"; exit 1; }

  # ---------------------------------------------------------------------------
  # The tailwind dispatch needs a PROMPT BODY, not just a route to an agent.
  # All four files carried the `(routed — … dispatch \`wp-tailwind\` in author mode
  # instead)` marker and were then followed by the wp-css prompt — "Add blog CSS to
  # `assets/css/styles.css`…", the one file the tailwind path must never write. The
  # only quoted prompt below the routing block was the banned one, so an agent
  # following the marker had nothing to hand wp-tailwind but the basic branch's
  # instructions. Assert the body exists IN THE BLOCKQUOTE, since that is the only
  # text a dispatched agent ever sees, and assert it by the things that make it a
  # usable prompt rather than by any one sentence.
  # ---------------------------------------------------------------------------
  qflat=$(grep -E '^[[:space:]]*>' "$f" | sed -e 's/^[[:space:]]*>//' -e 's/[*]//g' | tr '\n' ' ' | sed 's/  */ /g' || true)

  printf '%s' "$qflat" | grep -qF 'wp-tailwind-system' \
    || { echo "FAIL: $f never sends the agent to the wp-tailwind-system skill from inside a QUOTED prompt — the skill owns the decision ladder and the prohibition list, and prose above the dispatch is not text the dispatched agent receives"; exit 1; }

  # The prohibition, quoted. `grep -F 'assets/css/styles.css'` over the blockquotes
  # would be satisfied by the basic branch's own prompt, which names that file as its
  # TARGET — so match the forbidding clause instead.
  printf '%s' "$qflat" | grep -Eqi "(never|do not|don'?t|must not)[ a-z]{0,12}write[^.]{0,20}\`?assets/css/styles\.css" \
    || { echo "FAIL: $f has no quoted prompt forbidding \`assets/css/styles.css\` — the tailwind dispatch's own prompt body must say it, because the only other quoted prompt in the file NAMES that path as its output target and an agent handed it writes the file the Tailwind starter never enqueues"; exit 1; }

  # The five inputs agents/wp-tailwind.md's Inputs table declares. wp-header.md and
  # wp-footer.md supplied NONE of them and instead named a target (`layouts/header.css`)
  # the table had no input for; wp-page.md and wp-cpt.md supplied two of five. Each is
  # asserted separately so the failure names the missing one.
  printf '%s' "$qflat" | grep -qF -- '--block' \
    || { echo "FAIL: $f's quoted tailwind prompt does not supply \`--block <name>\` — without it the agent has no unique name to scope an \`@apply\` class under, and parallel section agents collide on a selector"; exit 1; }
  printf '%s' "$qflat" | grep -Eq -- '--page|--layout' \
    || { echo "FAIL: $f's quoted tailwind prompt supplies neither \`--page <slug>\` nor \`--layout <name>\` — those are the two spellings of the LOCAL @apply target input, and with neither the agent can only promote to utilities/site.css"; exit 1; }
  printf '%s' "$qflat" | grep -qiF 'theme path' \
    || { echo "FAIL: $f's quoted tailwind prompt does not supply the theme path — the agent has no theme root to write its CSS into"; exit 1; }
  printf '%s' "$qflat" | grep -qiE 'function prefix|prefix:' \
    || { echo "FAIL: $f's quoted tailwind prompt does not supply the project function prefix — the markup it edits calls prefix_ functions it would otherwise have to guess"; exit 1; }

  # ---------------------------------------------------------------------------
  # File ownership. `wp-template` writes the PHP on BOTH paths — it is the only agent
  # carrying the ACF, escaping and i18n contract (grep agents/wp-tailwind.md for
  # `prefix_get_field`, `esc_html`, `esc_url`, `@package`: zero hits). So `wp-tailwind`
  # must run AFTER it, never beside it: dispatched in parallel the two write the same
  # path, last writer wins, and if wp-tailwind wins the section ships with no ACF
  # wiring and no escaping — which /wp-finalize then reports as a bilingual failure.
  # Backticks and emphasis are stripped so the relation can be matched as prose.
  # ---------------------------------------------------------------------------
  nof=$(tr '\n' ' ' < "$f" | sed -e 's/[`*]//g' -e 's/  */ /g')
  printf '%s' "$nof" | grep -Eqi "wp[ -]{1,2}template[^.]{0,40}\b(owns|owned|belongs to|is the only agent that (may )?(writes?|creates?))" \
    || { echo "FAIL: $f never states that wp-template OWNS the .php files it generates — with ownership unstated the tailwind dispatch reads as a second author of the same file"; exit 1; }
  printf '%s' "$nof" | grep -Eqi "wp[ -]{1,2}tailwind[^.]{0,60}\bafter\b[^.]{0,90}(never|not)[ a-z]{0,12}(beside|in parallel|simultaneous)" \
    || { echo "FAIL: $f does not say wp-tailwind runs AFTER wp-template and never beside it — a parallel dispatch races two agents on one file with opposite class systems, and the loser's ACF wiring and escaping vanish with no error anywhere"; exit 1; }
done

# EVERY file in the list above gets its dispatch sites walked, whatever its site
# count. The file-level greps are satisfied by a single routing block anywhere in
# the file, so they cannot tell a routed dispatch site from an unrouted one — the
# exact Task 5 failure mode.
#
# The walk used to cover only wp-page.md (a site per page type: blog, generic,
# legal, 404, search, embed, custom, ...) and wp-cpt.md (two: the
# archive/single/card CSS, and the teaser section injected into front-page.php),
# on the reasoning that those were the files with MULTIPLE sites and so the only
# ones a file-wide grep could under-cover. That reasoning was wrong, and
# wp-header.md and wp-footer.md proved it: with a single dispatch site each, they
# carried a correct "### CSS agent routing" block AND an unrouted "Dispatch the
# **wp-css** agent" step whose body still said to write BEM rules and `:root`
# custom properties into `assets/css/styles.css` — the surface the routing block
# forbids on `tailwind`. Appending a second, freshly unrouted dispatch block to
# wp-header.md left this check GREEN. One site is not "covered by the file-wide
# grep"; it is the case where the file-wide grep is most misleading, because the
# routing block that satisfies it sits inches above the site that ignores it.
#
# No loop hardcodes a site count — any of these files may grow more dispatch
# sites later and the walk adapts.
#
# The site pattern matches any dispatch line naming **wp-css**, not just lines
# that begin "Dispatch **wp-css** agent" — wp-cpt.md's teaser site dispatches
# three agents from one line ("Dispatch **wp-template** + **wp-acf** +
# **wp-css**"), and a pattern anchored on wp-css coming first would skip it.
walk_sites() {
  local page=$1 routing_line block_end sites site_num lineno rest flat
  local accounted mentions

  routing_line=$(grep -n -m1 '^### CSS agent routing$' "$page" | cut -d: -f1 || true)
  [ -n "$routing_line" ] || { echo "FAIL: $page has no \"### CSS agent routing\" block"; exit 1; }

  # The routing block runs from its heading to the next heading of the SAME OR
  # HIGHER level (or EOF). Its own prose quotes "Dispatch **wp-css** agent" while
  # describing the rule, so it is the one region where a **wp-css** mention is
  # legitimately not a dispatch site.
  #
  # The terminator used to be a bare /^#/, which ended the block on the first
  # `#`-leading line of any kind. Two ordinary, correct edits truncated the block
  # with it, and both orphaned the block's closing "This routing governs every
  # \"Dispatch **wp-css** agent\" step below..." sentence into the accounting
  # invariant below — which then failed with a wrong diagnosis ("usually a
  # hard-wrap") and an impossible remedy ("move it inside the routing block"; it
  # already was):
  #   1. a `#` comment inside a fenced code block, e.g. a worked example of
  #      `# .claude/CLAUDE.md` / `Template: tailwind`. `#`-leading lines inside
  #      fences are an established pattern in these files.
  #   2. a `#### sub-heading` inside the routing block, which is a child of the
  #      `###` heading and belongs to the block, not after it.
  # So: track fences and skip them, require a real ATX heading (`#`s followed by
  # a space), and only close on a heading whose level is <= the routing
  # heading's own.
  block_end=$(awk -v s="$routing_line" '
    NR == s { match($0, /^#+/); lvl = RLENGTH; next }
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    NR > s && !fence && /^#+[[:space:]]/ {
      match($0, /^#+/)
      if (RLENGTH <= lvl) { print NR; exit }
    }
  ' "$page")
  [ -n "$block_end" ] || block_end=$(( $(wc -l < "$page") + 1 ))

  # The leading character class admits an ordered-list marker as well as a bullet
  # one. It used to be `[[:space:]>*-]*`, with no digits, period or paren in it, so
  # renumbering a dispatch line into an ordered-list item ("1. Dispatch **wp-css**
  # agent…") dropped that site from the walk — and the accounting invariant below
  # then fired with a diagnosis that was simply false ("usually a hard-wrap that
  # split Dispatch from **wp-css**"; no wrap had occurred). Step renumbering is one
  # of this repo's most ordinary correct edits, so it must not move a site out of
  # the walk in the first place.
  sites=$(grep -nE '^[[:space:]>*+.)0-9-]*Dispatch .*\*\*wp-css\*\*' "$page" || true)
  # In a single-site file (wp-header.md, wp-footer.md) a hard-wrap between
  # "Dispatch" and "**wp-css**" empties this list outright, so the diagnosis has
  # to name that cause too — the accounting invariant below never gets to run.
  [ -n "$sites" ] || { echo "FAIL: $page: found no wp-css dispatch sites — either a hard-wrap split \"Dispatch\" from \"**wp-css**\" (keep them on one physical line) or the site pattern is stale"; exit 1; }

  # Accounting invariant. The site pattern needs "Dispatch" and "**wp-css**" on
  # the same PHYSICAL line, so an ordinary hard-wrap of an over-long dispatch
  # line silently deletes that site from the walk — every remaining site still
  # passes and the suite stays green while the re-wrapped one goes unrouted.
  # `[ -n "$sites" ]` above only fires when EVERY site vanishes. So instead of
  # trusting the pattern to find them all, require it to account for all of
  # them: every **wp-css** mention outside the routing block must be a line the
  # walk matched. A wrap that splits "Dispatch" from "**wp-css**" leaves the
  # **wp-css** half unaccounted and fails here.
  accounted=$(printf '%s\n' "$sites" | cut -d: -f1)
  mentions=$(grep -nF '**wp-css**' "$page" || true)
  while IFS=: read -r lineno rest; do
    [ -n "$lineno" ] || continue
    # inside the routing block: prose, not a dispatch site
    if [ "$lineno" -ge "$routing_line" ] && [ "$lineno" -lt "$block_end" ]; then
      continue
    fi
    printf '%s\n' "$accounted" | grep -qx "$lineno" \
      || { echo "FAIL: $page line $lineno mentions **wp-css** but the dispatch-site walk did not match it — usually a hard-wrap that split \"Dispatch\" from \"**wp-css**\", which deletes the site from the walk. Keep them on one line, or (if this is prose, not a dispatch) move it inside the \"### CSS agent routing\" block or drop the bold markers: $rest"; exit 1; }
  done <<< "$mentions"

  site_num=0
  while IFS=: read -r lineno rest; do
    site_num=$((site_num + 1))

    [ "$lineno" -gt "$routing_line" ] \
      || { echo "FAIL: $page dispatch site #$site_num (line $lineno) appears before the CSS agent routing block (line $routing_line)"; exit 1; }

    # Every site is an independent branch the routing block does not textually
    # touch — it must carry its own inline marker naming wp-tailwind, or a
    # revert to a bare "Dispatch wp-css agent" line here would silently fall
    # back to the basic-only path.
    #
    # Direction, not adjacency: the marker must hand wp-tailwind to `tailwind`.
    # A marker reading "on `basic`, dispatch `wp-tailwind`" names both tokens,
    # so any mere presence test would pass it while it routes the wrong way
    # round. Match the whole directed clause instead.
    #
    # Match the clause against the site line PLUS its continuation lines,
    # flattened — not against the site line alone. The marker runs ~129
    # characters in files whose prose wraps at ~90, so a perfectly correct
    # re-wrap can push its tail onto the next line; matching only the first line
    # false-failed on exactly that edit (a break after "above; on \`tailwind\`,",
    # which keeps "Dispatch" and "**wp-css**" together as the editing rule in
    # each command file demands). The window ends at the first blank line — every
    # dispatch site is followed by a blank line and then its blockquote — so it
    # can never swallow a neighbouring site.
    #
    # `wp- ?tailwind` tolerates a wrap landing on the hyphen itself: flattening
    # turns that break into "wp- tailwind", and a break at a hyphen has
    # false-failed a gate on this branch before.
    flat=$(awk -v s="$lineno" '
      NR < s { next }
      NR > s && /^[[:space:]]*$/ { exit }
      { print }
    ' "$page" | tr '\n' ' ' | sed 's/  */ /g')
    #
    # `(the )?` and `( agent)?` because the marker was a frozen nine-word phrase that
    # rejected the article+noun form these same files already use one line earlier for
    # the other agent ("Dispatch **the** wp-css **agent**"). Writing the marker the
    # same way — "on `tailwind`, dispatch the `wp-tailwind` agent in author mode
    # instead" — is a synonym a careful author reaches for, and it turned this gate
    # red. The DIRECTION is what the assertion is for, and both forms carry it.
    printf '%s\n' "$flat" \
      | grep -qE 'on `tailwind`, dispatch (the )?`wp- ?tailwind`( agent)? in author mode instead' \
      || { echo "FAIL: $page dispatch site #$site_num (line $lineno) does not route \`tailwind\` (and only \`tailwind\`) to wp-tailwind: $flat"; exit 1; }

    # Routing the site is not enough on its own: the site's own quoted prompt below
    # it is the `basic` branch's, and it names `assets/css/styles.css`. Without a
    # statement that the step does not run at all on `tailwind`, an agent that
    # followed the marker still has that prompt in front of it as the nearest
    # instructions. /wp-header and /wp-footer already solved this ("**This step is
    # the `basic` branch.** On `tailwind` it does not run at all…"); this requires it
    # at every site in every file.
    #
    # The window is the prose paragraph immediately above the site: scanning back at
    # most 12 lines, and RESETTING at any heading, fence, blockquote or rule, so the
    # previous site's prompt can never satisfy the site under test.
    pre=$(awk -v s="$lineno" '
      NR >= s { exit }
      NR < s - 12 { next }
      /^[[:space:]]*(>|#|---|```|~~~)/ { buf = ""; next }
      { buf = buf " " $0 }
      END { print buf }
    ' "$page" | sed 's/[`*]//g' | sed 's/  */ /g')
    printf '%s' "$pre" | grep -qiE '\bbasic\b[ a-z]{0,6}branch' \
      || { echo "FAIL: $page dispatch site #$site_num (line $lineno) is not marked as the \`basic\` branch — its quoted prompt names assets/css/styles.css, so a tailwind run that reaches it writes the one file the Tailwind starter never enqueues. Say so in the paragraph directly above the dispatch line, as commands/wp-header.md does"; exit 1; }
    printf '%s' "$pre" | grep -qiE "(does not|doesn'?t|never|must not|do not)[ a-z]{0,18}\bruns?\b[^.]{0,24}at all" \
      || { echo "FAIL: $page dispatch site #$site_num (line $lineno) is called the \`basic\` branch but never says it does not run at all on \`tailwind\` — \"prefer the other agent\" is not the same instruction, and the quoted prompt below the site is still the nearest thing to follow"; exit 1; }
  done <<< "$sites"
}

walk_sites "$page_md"
walk_sites commands/wp-cpt.md
walk_sites "$wp_header"
walk_sites commands/wp-footer.md

# The routing blocks cover `basic` and `tailwind`. `cinematic` is upstream's
# third template axis, present only in /wp-init, so a routing block that
# never mentions it lets a cinematic project fall through to the `basic`
# path — BEM CSS in a theme whose CSS is assets/css/cinematic.css. Assert
# the routing block states the cinematic case as NOT routed. Scoped to the
# block (heading to next `## Step` heading), so a passing mention elsewhere
# cannot satisfy it, and flattened so a re-wrap cannot break it.
hdr_route=$(awk '/^### CSS agent routing$/,/^## Step 5:/' "$wp_header" \
  | tr '\n' ' ' | sed 's/  */ /g' || true)
printf '%s' "$hdr_route" | grep -qiF 'cinematic' \
  || { echo "FAIL: wp-header's CSS agent routing block never names cinematic — an agent handed a cinematic project falls through to the basic path and writes BEM CSS into a theme that has its own cinematic.css"; exit 1; }
printf '%s' "$hdr_route" | grep -qiF 'not routed by this command' \
  || { echo "FAIL: wp-header's routing block names cinematic but never says it is not routed by this command — naming it while leaving the fall-through open routes the project to wp-css anyway"; exit 1; }

echo PASS
