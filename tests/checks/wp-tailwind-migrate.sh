#!/usr/bin/env bash
# The migration command must be safe by construction: a git baseline and a
# before/after visual comparison bracket the conversion, neither the baseline
# screenshots nor the pristine CSS can be destroyed by the migration, the agents
# it dispatches are told the one thing their own Inputs table gets wrong about a
# migration — that the markup they receive is not converted yet — and they are
# kept away from the convention check, which cannot pass until Step 5 has run.
#
# Two structural rules the gates below encode, learned the hard way: a step that must
# RUN something is asserted inside its ```bash fence, because prose saying it is not run
# satisfies any flat-text match; and every widening keeps its inversion, because a gate
# that rejects correct prose is the more common defect here, not the more careful one.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-tailwind-migrate.md; f=$EXPANDED

[ -f "$f" ] || { echo "FAIL: $f missing"; exit 1; }

# Sentences wrap across lines at ~90 columns, and a line-anchored grep silently
# loses an assertion the moment someone re-wraps a paragraph. Flatten once and
# match against that. Region-scoped assertions get their own flattened copy so
# the scoping is not thrown away along with the newlines.
#
# The second sed drops shell line-continuations: after `tr`, a `cmd arg \<NL>
#   arg2` becomes `cmd arg \ arg2`, and the stray backslash splits every literal
# that spans it. Proven necessary — wrapping the Step 0 and Step 6 `mv` lines at
# the continuation false-failed both screenshot-write assertions before this.
flat() { tr '\n' ' ' | sed -e 's/  */ /g' -e 's/ \\ / /g' -e 's/  */ /g'; }
flatf=$(flat < "$f")

# A gate that says a command "must actually be RUN" cannot be satisfied by a sentence
# saying it is not run. bash() keeps only the lines inside ```bash fences, so the
# invocation gates below match code and nothing else. Proven necessary: unbackticked
# prose ("Skip the compile for now; in a later release npm run tailwindbuild will do
# it.") satisfied both run-gates before this existed.
bashonly() { awk '/^```bash/{inb=1;next} /^```/{inb=0;next} inb'; }

# Every gate below uses an explicit `if`. At the top level of a `set -e` script
# `grep -q X || { echo …; exit 1; }` is safe but `grep -q X && { … }` is not —
# it does not abort, and execution walks on to PASS. Do not depend on which.

# --- Structural references, asserted as paths rather than bare tokens. --------
# (A bare 'wp-tailwind' is satisfied by this command's own name — see A11.)
# A1 is deletion-proven only: there is no inversion of "points at the skill"
# short of pointing somewhere else, which the literal path already rejects.
if ! printf '%s' "$flatf" | grep -Fq 'skills/wp-tailwind-system/SKILL.md'; then
  echo "FAIL: does not send the agent to the Tailwind convention skill"; exit 1
fi

# --- Step 0 region. A clean-tree gate satisfied from the Report block is no gate.
s0=$(awk '/^## Step 0/,/^## Step 1/' "$f")
# Defence in depth only — the closure proof below already fails on an empty region.
[ -n "$s0" ] || { echo "FAIL: no Step 0 section"; exit 1; }
if ! printf '%s\n' "$s0" | tail -1 | grep -q '^## Step 1'; then
  echo "FAIL: the Step 0 region is not terminated by a '## Step 1' heading — its assertions would silently become file-wide"; exit 1
fi
s0flat=$(printf '%s\n' "$s0" | flat)

# The repo gate itself. Without it the command runs against a directory git knows
# nothing about and the "baseline commit" silently lands in some parent repo.
if ! printf '%s' "$s0flat" | grep -Fq 'git rev-parse --is-inside-work-tree'; then
  echo "FAIL: Step 0 does not verify the theme is inside a git work tree"; exit 1
fi

# Clean-tree gate, asserted WITH its polarity. The three shapes below are the only
# correct ones — `-z` guarding with `||`, `-n` guarding with `&&`, and the explicit
# `if [ -n … ]` this repo keeps rewriting into (bin/tailwind-native-check.sh:17).
# Both inversions (`-n … ||` and `if [ -z … ]`) are rejected. Verified against all
# correct shapes incl. the wrap-at-`\` form flat() normalises. `[`, `[[` and `test`
# are the same builtin spelled three ways, so the bracket is alternated and its
# closing half optional — narrowing to `[ … ]` false-failed the plain `test -z` form.
# `--porcelain` takes flags: `--untracked-files=all` is the SAME gate, made stricter,
# and pinning the closing paren straight after `--porcelain` false-failed it.
if ! printf '%s' "$s0flat" | grep -Eq '(\[\[?|test) -z "\$\(git status --porcelain[^)]*\)"( \]\]?)? *\|\||(\[\[?|test) -n "\$\(git status --porcelain[^)]*\)"( \]\]?)? *&&|if (\[\[?|test) -n "\$\(git status --porcelain[^)]*\)"( \]\]?)? *;? *then'; then
  echo "FAIL: Step 0 does not abort on a dirty tree — it must fail when 'git status --porcelain' is NON-empty, and an inverted test would migrate over uncommitted work"; exit 1
fi

# The baseline commit. The header comment above claims a git baseline BRACKETS the
# conversion, and without this line nothing does: the clean-tree gate proves the tree
# was clean, but only a commit gives `git diff`/`git revert` a point to return to when
# the migration goes wrong. Asserted inside the fence, since a sentence promising a
# baseline is not one. `[^|;&]*` keeps the flags in one command, so `--allow-empty`
# cannot be borrowed from a neighbouring `git` invocation.
s0bash=$(printf '%s\n' "$s0" | bashonly)
if ! printf '%s\n' "$s0bash" | grep -Eq 'git commit[^|;&]*--allow-empty'; then
  echo "FAIL: Step 0 does not create the empty baseline commit — with nothing committed there is no point to revert the migration to"; exit 1
fi

# `node_modules/` has to be ignored, not committed. Step 2 runs `npm install`, which
# leaves an untracked tree; the clean-tree gate above runs again on EVERY --page pass,
# so an un-ignored node_modules/ aborts the next pass on the previous pass's own
# dependencies, and the only escape the command would otherwise offer is committing it.
if ! printf '%s' "$s0flat" | grep -Eq 'node_modules/?[^.]{0,90}\.gitignore|\.gitignore[^.]{0,90}node_modules/?'; then
  echo "FAIL: Step 0 does not add node_modules/ to the theme's .gitignore — Step 2's npm install then dirties the tree and the next --page pass aborts on its own dependency directory"; exit 1
fi

# THE screenshot-collision assertion. /wp-responsive-check Method B writes fixed
# filenames (responsive-375.png … responsive-1440.png) into the cwd, so a second
# run overwrites the first. If Step 0 does not move the golden out of the way,
# Step 6 destroys the very baseline it is meant to compare against.
# Assert the WRITE, not a path mention: 'responsive-*.png <dest>' is the argument
# order of the mv that relocates the shots. A bare '.tailwind-migrate/before/' is
# satisfied by prose that merely names the directory.
# Not -F: `mv responsive-*.png ".tailwind-migrate/before/$slug/"` is the same write with
# the destination quoted — which is the CORRECT shell habit — and the fixed-string form
# rejected it. The optional quote is allowed here and in the three sibling gates below,
# so quoting can never flip a gate's verdict in either direction.
if ! printf '%s' "$s0flat" | grep -Eq 'responsive-\*\.png "?\.tailwind-migrate/before/'; then
  echo "FAIL: Step 0 does not move the golden screenshots into .tailwind-migrate/before/<slug>/ — the Step 6 re-run overwrites responsive-*.png and the baseline is lost"; exit 1
fi

# Direction: before/ is written in Step 0, after/ in Step 6, never the reverse.
# Forbid the WRITE, not the mention — Step 0 may legitimately explain what Step 6
# does with after/, and a blanket negative on the path would fail that correct prose.
if printf '%s' "$s0flat" | grep -Eq 'responsive-\*\.png "?\.tailwind-migrate/after/'; then
  echo "FAIL: Step 0 writes the after/ directory — the baseline and the comparison are the same files"; exit 1
fi

# Method A (Playwright MCP) is tried FIRST and names its own files, so the fixed
# responsive-<w>.png names exist only under Method B. A command that assumes the
# glob silently produces an empty golden and migrates anyway.
if ! printf '%s' "$s0flat" | grep -Eqi 'method b[^.]{0,90}(fixed filenames|responsive-375)'; then
  echo "FAIL: Step 0 does not say that only /wp-responsive-check's Method B writes the fixed responsive-<width>.png names"; exit 1
fi
if ! printf '%s' "$s0flat" | grep -Eqi '(do not|never) assume the glob|glob may match nothing|may be no [^ ]{0,2}responsive-\*'; then
  echo "FAIL: Step 0 assumes 'responsive-*.png' is in the cwd — under Method A it is not, and the golden ends up empty"; exit 1
fi

# Five widths, five files, or there is no golden. Polarity asserted: the guard must
# abort when the count is NOT five. `-eq 5 ] &&` (abort when it IS five) is rejected.
if ! printf '%s' "$s0flat" | grep -Eq '[-]eq 5 \] *\|\||[-]ne 5 \] *;? *then'; then
  echo "FAIL: Step 0 does not abort when fewer than five golden screenshots land for a page"; exit 1
fi

# The human-facing half of the same rule: a missing golden stops the run, it does
# not downgrade it to a best-effort migration.
if ! printf '%s' "$s0flat" | grep -Eqi 'stop and report[^.]{0,80}(five files|golden)|do not proceed without the golden'; then
  echo "FAIL: Step 0 does not stop the run when the golden is unobtainable — a migration with no baseline cannot be verified"; exit 1
fi

# --- Step 1 region: the audit. Step 4 hands the agents the CSS rules this step
# enumerates, so an empty Step 1 leaves every dispatch with markup and nothing to
# translate it from. Nothing gated this region before: the whole body could be deleted
# and the suite stayed green.
s1=$(awk '/^## Step 1/,/^## Step 2/' "$f")
[ -n "$s1" ] || { echo "FAIL: no Step 1 section"; exit 1; }
if ! printf '%s\n' "$s1" | tail -1 | grep -q '^## Step 2'; then
  echo "FAIL: the Step 1 region is not terminated by a '## Step 2' heading — its assertions would silently become file-wide"; exit 1
fi
s1flat=$(printf '%s\n' "$s1" | flat)

# Step 5 deletes enqueue calls; it can only delete what Step 1 found.
if ! printf '%s' "$s1flat" | grep -Fq 'wp_enqueue_style'; then
  echo "FAIL: Step 1 does not inventory the wp_enqueue_style calls — Step 5 removes enqueues it was never told about"; exit 1
fi
# Dead rules are the escape hatch Step 5's deletion gate depends on ("a rule that was
# dead in Step 1's audit is accounted for by being reported as dead"). Wide alternation
# and either word order: this is a claim, not a fixed wording.
if ! printf '%s' "$s1flat" | grep -Eqi 'dead[^.]{0,40}(rule|css|selector|markup|declaration)|(rule|css|selector|declaration)[a-z]*[^.]{0,40}dead'; then
  echo "FAIL: Step 1 does not identify the dead CSS rules — Step 5's deletion gate treats 'reported as dead' as accounted for, so nothing would ever qualify"; exit 1
fi
# …and the inventory is reported before anything is changed, or it is not a gate.
if ! printf '%s' "$s1flat" | grep -Eqi 'report[^.]{0,60}(before|prior to)[^.]{0,25}step 2|(before|prior to)[^.]{0,25}step 2[^.]{0,60}report'; then
  echo "FAIL: Step 1 does not report the inventory to the user before Step 2 starts changing the theme"; exit 1
fi

# --- Step 2 region: the Tailwind tree's sanctioned directory set. -------------
s2=$(awk '/^## Step 2/,/^## Step 3/' "$f")
# Defence in depth only — the closure proof below already fails on an empty region.
[ -n "$s2" ] || { echo "FAIL: no Step 2 section"; exit 1; }
if ! printf '%s\n' "$s2" | tail -1 | grep -q '^## Step 3'; then
  echo "FAIL: the Step 2 region is not terminated by a '## Step 3' heading — its assertions would silently become file-wide"; exit 1
fi
s2flat=$(printf '%s\n' "$s2" | flat)

# bin/tailwind-native-check.sh:26-31 errors on any directory under
# assets/css/src/tailwindcss/ that is not one of exactly these four. Assert the
# SET, positively — the enumeration Step 2 installs is the thing that has to stay
# closed, and a bare "does the word 'four' appear" gate false-fails the moment an
# author drops the numeral. Extract the names Step 2 actually lists and compare.
#
# NOT anchored on a `director(y|ies)[^.]*` clause any more. That anchor had two
# proven false-fails: any '.' between the word and the list truncated the clause to
# nothing and the gate reported an EMPTY set (`the four directories that
# `bin/tailwind-native-check.sh` rule 2 sanctions: `base`, …` — the `.sh` ends it),
# and brace notation (`{base,components,layouts,utilities}`) left `{base` and
# `utilities}` failing the name pattern, so it reported a WRONG set of two.
#
# Instead: walk the backticked spans of the region in order, split each on commas,
# braces and spaces, and grow a RUN of bare lowercase names. Anything that is not a
# bare name — a path, `@import "tailwindcss"`, `package.json` — ends the run, so the
# runs are exactly the lists an author writes. Take the first run that names two or
# more of the four sanctioned directories, and compare it whole: a fifth name lands
# in the same run and fails the comparison, a renamed one fails it too, and deleting
# the list leaves no qualifying run at all. Trailing slashes are stripped — `base/`
# is the same sanctioned name as `base`. `|| true` because `pipefail` turns an empty
# grep into a silent `set -e` abort that exits 1 without ever printing FAIL.
s2dirs=$(printf '%s' "$s2flat" | { grep -oE '`[^`]+`' || true; } | tr -d '`' \
  | tr ',{}' '   ' | tr ' ' '\n' | awk '
      function done_run() { if (!pr && n >= 2 && hits >= 2) { printf "%s", run; pr=1 } n=0; hits=0; run="" }
      { t=$0; sub(/\/+$/, "", t) }
      t == "" { next }
      t ~ /^[a-z][a-z0-9_-]*$/ {
        run = run t " "; n++
        if (t=="base" || t=="components" || t=="layouts" || t=="utilities") hits++
        next
      }
      { done_run() }
      END { done_run() }
    ')
# Compared as a SET, not as a sequence: rule 2 sanctions four names, it does not
# sanction an order, and Step 2 creates all four in one `mkdir`. Listing them
# `utilities components base layouts` is the same instruction and the sequence
# comparison rejected it — the same false-fail class as the two above. Sorting
# costs the gate nothing: a fifth name still lands in the sorted run and a renamed
# one still misses, so both inversions below stay red. The unsorted run is what the
# message prints, because that is what the author actually wrote.
s2set=$(printf '%s' "$s2dirs" | tr ' ' '\n' | { grep -v '^$' || true; } | sort | tr '\n' ' ')
if [ "$s2set" != "base components layouts utilities " ]; then
  echo "FAIL: Step 2 sanctions the directory set [${s2dirs}] under assets/css/src/tailwindcss/ — it must be exactly 'base components layouts utilities', which is the set bin/tailwind-native-check.sh rule 2 enforces"; exit 1
fi

# …and the sentence that keeps the set closed. Without it Step 2 can go on listing
# four names while the next sentence invites a fifth, and the extraction above
# still passes. Wide alternation: this is a claim, not a fixed wording.
if ! printf '%s' "$s2flat" | grep -Eqi "(set|list) is closed|(never|do not|don'?t|must not|may not|cannot) (add|create)[^.]{0,30}(fifth|another|other|additional|extra|more)|errors on any other (name|director)|no (fifth|other|additional|further) (director|name)"; then
  echo "FAIL: Step 2 does not say the four-directory set is closed — bin/tailwind-native-check.sh rule 2 errors on any other name under assets/css/src/tailwindcss/, so a fifth directory breaks the build for every template"; exit 1
fi

# Step 3 writes the extracted tokens into main.css's `@theme` block, and Step 2 is the
# only step that creates main.css. Without this, Step 2 installs a main.css holding
# nothing but `@import "tailwindcss"` and Step 3 writes into a block that is not there.
if ! printf '%s' "$s2flat" | grep -Eq '@theme'; then
  echo "FAIL: Step 2 does not put an @theme block in main.css — Step 3 has nowhere to write the tokens it extracts, and a token declared outside @theme compiles to nothing"; exit 1
fi

# --- Step 3 region: the tokens. Nothing gated this region before either — the whole
# body could be deleted and the suite stayed green, leaving Step 2's @theme block empty
# and Step 4's "prefer the Step 3 tokens" instruction pointing at nothing.
s3=$(awk '/^## Step 3/,/^## Step 4/' "$f")
[ -n "$s3" ] || { echo "FAIL: no Step 3 section"; exit 1; }
if ! printf '%s\n' "$s3" | tail -1 | grep -q '^## Step 4'; then
  echo "FAIL: the Step 3 region is not terminated by a '## Step 4' heading — its assertions would silently become file-wide"; exit 1
fi
s3flat=$(printf '%s\n' "$s3" | flat)

if ! printf '%s' "$s3flat" | grep -Eqi '(mine|extract|harvest|collect|read|inventory)[a-z]*[^.]{0,60}(old|existing|current|plain)[- ]?css'; then
  echo "FAIL: Step 3 does not mine the old CSS for its tokens — the @theme block Step 2 created stays empty and every converted template falls back to Tailwind's built-in scales"; exit 1
fi
if ! printf '%s' "$s3flat" | grep -Eq '@theme'; then
  echo "FAIL: Step 3 does not write the extracted tokens into the @theme block"; exit 1
fi
if ! printf '%s' "$s3flat" | grep -Fq 'main.css'; then
  echo "FAIL: Step 3 does not say which file the @theme block lives in — the tokens have to land in assets/css/src/tailwindcss/main.css or nothing compiles them"; exit 1
fi

# --- Step 4 region: which agent, in which mode, told what about its input. ----
s4=$(awk '/^## Step 4/,/^## Step 5/' "$f")
# Defence in depth only — the closure proof below already fails on an empty region.
[ -n "$s4" ] || { echo "FAIL: no Step 4 section"; exit 1; }
if ! printf '%s\n' "$s4" | tail -1 | grep -q '^## Step 5'; then
  echo "FAIL: the Step 4 region is not terminated by a '## Step 5' heading — its assertions would silently become file-wide"; exit 1
fi
s4flat=$(printf '%s\n' "$s4" | flat)

# A11. Subsumption guard: 'wp-tailwind' alone is satisfied by 'wp-tailwind-migrate'
# (this command's own name) and by 'wp-tailwind-system'; '[^-]' rejects both. And a
# lone standalone mention proves nothing about the mode, so the agent name and the
# mode must co-occur — in either order, since a rewrite may lead with either, and
# with either case, since a sentence may open on the mode.
# NOT `-i`: a case-insensitive match lets the neighbouring "Author mode's Inputs
# table…" sentence satisfy a dispatch line that dropped the mode. `[^.]` keeps the
# co-occurrence inside one sentence, which is what closes that hole. The initials of
# BOTH words are alternated rather than lower-cased wholesale: "**Author Mode**" is the
# same dispatch in title case and the `[Mm]`-less form rejected it, while a wholesale
# `-i` would still let the neighbouring sentence through.
if ! printf '%s' "$s4flat" | grep -Eq 'wp-tailwind[^-][^.]{0,80}[Aa]uthor[ -][Mm]ode|[Aa]uthor[ -][Mm]ode[^.]{0,80}wp-tailwind[^-]'; then
  echo "FAIL: Step 4 does not dispatch the wp-tailwind agent in author mode"; exit 1
fi

# A12. THE agent-contract assertion. agents/wp-tailwind.md's author-mode Inputs
# table declares `section HTML` to be "already Tailwind-native (the pipeline
# converts the demo before the section walk)". A migration has no converted demo,
# and author mode's gate ("conversion steps below do not apply") locks the agent
# out of the only procedure that turns declarations into utilities. If the dispatch
# does not contradict that table out loud, the agent applies the @apply ladder to
# markup nobody converted and the migration ships BEM classes with a Tailwind build
# bolted on — the exact defect this branch exists to remove.
# The separators are classes, not single characters: `**plain-CSS**, not converted`
# puts emphasis markers between `CSS` and the comma, and a wrap at the hyphen becomes
# `plain- CSS` once flat() collapses the newline. Both are the same sentence and the
# fixed-separator form rejected both.
if ! printf '%s' "$s4flat" | grep -Eqi 'plain[-* ]{1,4}css[*_]{0,3},?[ *_]{0,4}not[ *_]{1,4}(yet[ *_]{1,4})?converted'; then
  echo "FAIL: Step 4 does not tell the agent its input is plain CSS and not converted — author mode's Inputs table says the opposite, and nothing else in the chain does the declaration-to-utility translation"; exit 1
fi

# A12b. The agent cannot translate rules it was never handed. Step 1's audit is the
# only place those rules are enumerated, so the dispatch has to carry them across.
if ! printf '%s' "$s4flat" | grep -Eqi '(css|style)[- ]?(rules|declarations)[^.]{0,40}step 1|step 1[^.]{0,40}(css|style)[- ]?(rules|declarations)'; then
  echo "FAIL: Step 4 does not hand the agent the CSS rules from Step 1's audit — with markup alone there is nothing to translate"; exit 1
fi

# A12c/d/e. The translation procedure itself, which author mode's own gate locks the
# agent out of. This command is the only place it exists on the migration path, so
# each of the three rules is gated separately — deleting any one of them leaves the
# agent applying the @apply ladder to markup it never converted.
if ! printf '%s' "$s4flat" | grep -Eqi '(translat|convert|turn|map)[a-z]*[^.]{0,25}declaration[^.]{0,45}utilit'; then
  echo "FAIL: Step 4 does not tell the agent to translate each CSS declaration into the equivalent utility"; exit 1
fi
if ! printf '%s' "$s4flat" | grep -Eqi '@media[^.]{0,80}breakpoint (prefix|variant)|breakpoint (prefix|variant)[^.]{0,80}@media'; then
  echo "FAIL: Step 4 does not map @media queries onto Tailwind breakpoint prefixes — a re-written media query is not a Tailwind-native conversion"; exit 1
fi
# `@theme` and "tokens" in either order and at arm's length: "the tokens Step 3 wrote
# into `@theme` over Tailwind's built-in scale" is the same instruction and the earlier
# `@theme[^.]{0,3}tokens` form false-failed it. The preference direction is what carries
# the meaning, so that stays mandatory — the reversed sentence (built-in preferred over
# the tokens) still has nothing after `built-in` and is still rejected.
if ! printf '%s' "$s4flat" | grep -Eqi '(@theme[^.]{0,30}token|token[^.]{0,30}@theme)[^.]{0,60}(over|rather than|instead of|in preference to)[^.]{0,45}built[- ]?in'; then
  echo "FAIL: Step 4 does not prefer the Step 3 @theme tokens over Tailwind's built-in scales — the extracted design tokens would go unused"; exit 1
fi

# A12f. Author mode REQUIRES --block and --page; a dispatch missing them produces no
# section at all. Both must appear in the same sentence — '--page' alone is satisfied
# by this command's own unrelated --page flag, which the same region also discusses.
if ! printf '%s' "$s4flat" | grep -Eq '[-]-block[^.]{0,90}--page|[-]-page[^.]{0,90}--block'; then
  echo "FAIL: Step 4 does not pass author mode the --block and --page arguments it requires"; exit 1
fi

# …and the other two of the five. agents/wp-tailwind.md's Inputs table declares
# `section HTML`, `--page`, `--block`, `theme path` and `prefix`. The dispatch list
# enumerated only three: an agent with no theme path has no root to write its
# components/<slug>.css into, and one with no prefix emits unprefixed function calls
# into a theme whose helpers are all prefixed.
if ! printf '%s' "$s4flat" | grep -Eqi 'theme path[^.]{0,120}prefix|prefix[^.]{0,120}theme path'; then
  echo "FAIL: Step 4's dispatch list omits the theme path and/or the prefix — two of the five inputs author mode's Inputs table declares"; exit 1
fi

# A10b. utilities/site.css and main.css are the two files the WHOLE walk shares, and
# author mode tells each agent to create the first and edit the second in the same step
# (agents/wp-tailwind.md Procedure 4, a Write). Dispatched in parallel that is
# last-write-wins: the agent that finishes last erases every sibling's promotion and
# every sibling's @import. The dispatch prompt has to take both files off the agents.
if ! printf '%s' "$s4flat" | grep -Eqi "(do[ *_]{1,4}not|never|don'?t)[^.]{0,60}(creat|edit|writ|touch)[a-z]*[^.]{0,60}(main\.css|utilities/site\.css)"; then
  echo "FAIL: Step 4 lets the parallel agents create utilities/site.css and edit main.css — author mode writes both, so the last agent to finish erases the others' work"; exit 1
fi
# …and the single-writer step that replaces it. Both files must be written ONCE, by
# this command, after the walk — which is also the first moment the cross-page corpus
# author mode greps for actually exists.
if ! printf '%s' "$s4flat" | grep -Eqi 'utilities/site\.css[^.]{0,40}(once|one edit|single edit)|(once|one edit|single edit)[^.]{0,40}utilities/site\.css'; then
  echo "FAIL: nothing writes utilities/site.css exactly once after the parallel walk — cross-page promotion has no single writer"; exit 1
fi
if ! printf '%s' "$s4flat" | grep -Eqi 'main\.css[^.]{0,40}(once|one edit|single edit)|(once|one edit|single edit)[^.]{0,40}main\.css'; then
  echo "FAIL: nothing registers the @import lines in main.css in one edit after the parallel walk — concurrent agents each rewrite the same file"; exit 1
fi

# A13. `base components layouts utilities` are the only directories the Tailwind
# tree may ever hold — bin/tailwind-native-check.sh:26-31 errors on any other, and
# a parallel section agent inventing one breaks the build for every sibling. The
# prohibition has to reach the agents this command dispatches, so it lives in the
# dispatch step. Anchored on the negation AND on the path, in one sentence: a
# prohibition that does not name the Tailwind tree is satisfied by a rule about
# some other directory, and Step 2's set stays open. Bounded, not a blanket
# negative over directory names — an unbounded negative is the class that
# false-fails correct work on this branch.
if ! printf '%s' "$s4flat" | grep -Eqi '(never|no agent|no new|do not|does not|must not|may not)[^.]{0,60}director[a-z]*[^.]{0,60}assets/css/src/tailwindcss'; then
  echo "FAIL: Step 4 does not forbid the agents from creating a directory under assets/css/src/tailwindcss/ — only base, components, layouts and utilities may exist there"; exit 1
fi

# A14. agents/wp-tailwind.md tells Section Authoring Mode to run
# bin/tailwind-native-check.sh before reporting done. Step 4 dispatches those agents
# BEFORE Step 5 removes assets/css/styles.css, so rule 1 (:21) fails for every one of
# them and rule 6 (:52-56) fails until enough templates are converted. Every parallel
# agent would see FAIL on a correctly progressing migration. The dispatch prompt has
# to wave them off. Accepts the post-Task-13 phrasings too (naming the script or the
# check rather than the agent's heading), so this gate survives that refactor.
if ! printf '%s' "$s4flat" | grep -Eqi "(do not|never|don'?t)[^.]{0,40}(run|execute|perform)[^.]{0,60}(verify before reporting done|bin/tailwind-native-check\.sh|convention check)"; then
  echo "FAIL: Step 4 does not stop the dispatched agents running the convention check themselves — mid-walk it fails by construction (styles.css still present, <3 templates converted)"; exit 1
fi

# --- Step 5 region: removal is gated on accounting, and on --page scope. ------
s5=$(awk '/^## Step 5/,/^## Step 6/' "$f")
# Defence in depth only — the closure proof below already fails on an empty region.
[ -n "$s5" ] || { echo "FAIL: no Step 5 section"; exit 1; }
if ! printf '%s\n' "$s5" | tail -1 | grep -q '^## Step 6'; then
  echo "FAIL: the Step 5 region is not terminated by a '## Step 6' heading — its assertions would silently become file-wide"; exit 1
fi
s5flat=$(printf '%s\n' "$s5" | flat)

# Not `grep -F` on the whole clause: "Never delete a file until…" is the same rule
# and a `-F` match on "Do not delete…" rejects it. The verb of the subordinate clause
# is alternated for the same reason — "until its rules have been accounted for" is the
# same sentence and false-failed the `are`-only form.
# The noun takes adjectives: "Never delete a **CSS** file until…" and "…delete an old
# CSS file…" are the same rule, and the fixed "delete a file" form rejected both. The
# emphasis-tolerant separator does the same job for a bolded "**Never**".
if ! printf '%s' "$s5flat" | grep -Eqi '(do not|never|don'"'"'?t)[ *_]{1,4}delete an?[ *_A-Za-z-]{0,16}file until its rules (are|have been|were|get) accounted for'; then
  echo "FAIL: Step 5 does not gate deletion on Step 4's accounting"; exit 1
fi

# Under --page only one template is migrated; the rest are still styled by the old
# CSS. Deleting it, or dropping its enqueue, unstyles every template not touched.
# Not `grep -F` on the clause: "keep the file…" is the same rule. The two bounded
# gaps absorb the adverbs a careful author inserts — "leave BOTH the file and its
# enqueue in place", "…in place UNTOUCHED" — which the fixed-wording form false-failed.
# The verb is what carries the meaning, so `leave|keep` stays mandatory and the
# inversion ("delete the file and drop its enqueue") has neither.
if ! printf '%s' "$s5flat" | grep -Eqi '(leave|keep)[^.]{0,15}the file and its enqueue[^.]{0,12}(in place|alone|untouched|as[- ]is)'; then
  echo "FAIL: Step 5 removes the old CSS unconditionally — under --page that unstyles every template the run did not migrate"; exit 1
fi

# --- Step 6 region: build, convention check, visual comparison. ---------------
s6=$(awk '/^## Step 6/,/^## Report/' "$f")
# Defence in depth only — the closure proof below already fails on an empty region.
[ -n "$s6" ] || { echo "FAIL: no Step 6 section"; exit 1; }
if ! printf '%s\n' "$s6" | tail -1 | grep -q '^## Report'; then
  echo "FAIL: the Step 6 region is not terminated by a '## Report' heading — its assertions would silently become file-wide"; exit 1
fi
s6flat=$(printf '%s\n' "$s6" | flat)
s6bash=$(printf '%s\n' "$s6" | bashonly)
[ -n "$s6bash" ] || { echo "FAIL: Step 6 has no \`\`\`bash block — nothing in it is actually run"; exit 1; }

# Step 2 installs `tailwindwatch` and `tailwindbuild`, not `build`. The starter's
# own `build` chains `wp-scripts build` over assets/js/src/index.js, which a theme
# migrated off the plain-CSS path need not have — so `npm run build` here either
# reports a missing script or dies in the JS step and never compiles the CSS.
# Asserted as the RUN, not the string, and now inside the ```bash fence rather than
# merely unbackticked. The unbackticked form was hollow: the prose sentence "Skip the
# compile for now; in a later release npm run tailwindbuild will do it." satisfied it
# while nothing compiled. `--prefix <theme-path>` is accepted because it is the same
# invocation with the directory named instead of entered — rejecting it forced the
# command into the `cd … && npm …` shape that A5 proved broken.
if ! printf '%s\n' "$s6bash" | grep -Eq '^[[:space:]]*([^#]*&& *)?npm( +--prefix +[^ ]+)? +run +tailwindbuild'; then
  echo "FAIL: Step 6 does not run 'npm run tailwindbuild' inside a bash block — the only build script Step 2 installs, and prose about it is not a build"; exit 1
fi

# A5. Step 0 already did `cd <theme-path>`, and the working directory persists between
# bash calls, so a second one resolves the SAME relative argument against the theme and
# exits 1 — proven: ( cd site; cd wp-content/themes/acme; cd wp-content/themes/acme ).
# Chained with `&&` that failure swallows the build silently, Step 6 then "verifies" an
# unbuilt dist/main.css, and the convention check's rule 6 (gated on that file) never
# runs at all. Forbidden in the fence only: the prose above it must be free to SAY
# "do not `cd <theme-path>` again".
if printf '%s\n' "$s6bash" | grep -Eq 'cd +"?<theme-path>'; then
  echo "FAIL: Step 6 cd's to the relative <theme-path> again — Step 0 already did, cwd persists, so this cd fails and '&&' swallows the build"; exit 1
fi
# …and the hazard is stated, so the next author does not put the cd back.
if ! printf '%s' "$s6flat" | grep -Eqi "(do[ *_]{1,4}not|never|don'?t)[^.]{0,25}cd[^.]{0,45}(again|a second time)"; then
  echo "FAIL: Step 6 does not warn against a second 'cd <theme-path>' — Step 0's cd already moved there and the relative path resolves only once"; exit 1
fi

# The convention check must be RUN, not merely named. Scoped to Step 6 and asserted
# as an invocation: the script path followed by whitespace and a theme argument. The
# prose mention elsewhere writes it as `bin/tailwind-native-check.sh` with a closing
# backtick straight after `.sh`, so it cannot satisfy this.
# `-i` so a shell variable spelled `"$THEME_PATH"` reads as the theme argument it is;
# it does not weaken the gate, because the prose mentions all close the backtick
# straight after `.sh` and the ` +` here demands real whitespace before the argument.
# The `"?` is what lets the CORRECT shell idiom through: the path is rooted at
# `${CLAUDE_PLUGIN_ROOT}` and therefore quoted, which puts a closing double quote
# between `.sh` and the argument. Without it this gate rejected the quoted form and
# accepted only the unquoted one — a brittle assertion, not a contract.
# Scoped to Step 6's ```bash fences for the same reason as the build gate above: the
# flat-region form was satisfied by unbackticked prose saying the check is NOT run.
if ! printf '%s\n' "$s6bash" | grep -Eqi 'bin/tailwind-native-check\.sh"? +[^ `]*theme'; then
  echo "FAIL: Step 6 does not RUN bin/tailwind-native-check.sh against the theme path inside a bash block — naming the script in prose is not running it"; exit 1
fi

# …and it must be run by its PLUGIN path. Step 6 runs with the working directory
# inside the theme (the `npm run tailwindbuild` block `cd`s there), so a bare
# `bin/tailwind-native-check.sh` resolves to nothing and exits 127 — the delivery
# gate silently never runs. CLAUDE.md: plugin-relative paths in commands are always
# `${CLAUDE_PLUGIN_ROOT}/…`, never relative. The braces are optional here: they are
# the house style everywhere else in the repo, but `$CLAUDE_PLUGIN_ROOT/bin/…` is the
# same correct path and must not read as a regression.
if ! printf '%s\n' "$s6bash" | grep -Eq '\$\{?CLAUDE_PLUGIN_ROOT\}?/bin/tailwind-native-check\.sh'; then
  echo "FAIL: Step 6 does not root the convention check at \${CLAUDE_PLUGIN_ROOT} — a bare relative bin/ path cannot resolve from the theme directory this step cd's into"; exit 1
fi

# Two of that script's rules cannot hold part-way through a --page run. Without this,
# a correct --page pass reads as a failed migration and gets "fixed" into a broken one.
# The object takes a noun: "record both **failures** as expected" is the same sentence
# and the adjacent-words form rejected it.
if ! printf '%s' "$s6flat" | grep -Eqi '(record|treat|report)[ *_]{1,4}(both|them|these two|the two)[ *_A-Za-z-]{1,24}as expected'; then
  echo "FAIL: Step 6 does not record the two --page-inevitable check failures as expected — a correct --page pass would read as a failed migration"; exit 1
fi

# Step 6 legitimately NAMES both directories — it writes after/ and reads before/ —
# so a presence assertion cannot tell the two apart, and the catastrophic inversion
# (the re-shoot landing in before/, obliterating the golden) sails through one. The
# write is asserted by argument order, and writing into before/ is forbidden outright.
if ! printf '%s' "$s6flat" | grep -Eq 'responsive-\*\.png "?\.tailwind-migrate/after/'; then
  echo "FAIL: Step 6 does not capture the after-screenshots into .tailwind-migrate/after/<slug>/"; exit 1
fi
if printf '%s' "$s6flat" | grep -Eq 'responsive-\*\.png "?\.tailwind-migrate/before/'; then
  echo "FAIL: Step 6 writes the re-shot screenshots into .tailwind-migrate/before/ — that overwrites the Step 0 golden with the post-migration render, so the comparison compares a page against itself"; exit 1
fi
# A23, deletion-proven only: an inversion of "reads the golden" is "reads nothing",
# which is the deletion.
if ! printf '%s' "$s6flat" | grep -Fq '.tailwind-migrate/before/'; then
  echo "FAIL: Step 6 never reads the Step 0 golden, so it compares nothing"; exit 1
fi

# The comparison needs a stated mechanism. /wp-responsive-check ANALYZES one page for
# layout faults; it does not diff two images. Prose saying "compare" with no mechanism
# is the same defect as Task 7 fix round 2's untruncatable-write claim. Accept the
# synonyms a careful author would reach for — read/open/view, both/the two, and any of
# the words for the artifact — but keep "two things are opened" mandatory, so a bare
# "compare them" still fails.
# The quantifier takes emphasis and has synonyms: "Read **both** PNGs" puts markers
# between the verb and the quantifier, and "Read **each** PNG" is the same instruction
# with a different one. Both were rejected. What stays mandatory is that TWO artifacts
# are opened, so a bare "compare them" still fails.
if ! printf '%s' "$s6flat" | grep -Eqi '(read|open|view)[ *_]{1,4}(both|the two|each|all)[^.]{0,45}(pngs?|images?|screenshots?|captures?|files?)'; then
  echo "FAIL: Step 6 states no mechanism for the comparison — /wp-responsive-check does not diff two images"; exit 1
fi

# …and the comparison has to gate the success report, or it is advice rather than a
# step. Without this the command can pass its convention check, skip the visual read
# entirely, and report a migration that silently changed the design.
if ! printf '%s' "$s6flat" | grep -Eqi "(do not|never|don'?t) (report|declare|call)[^.]{0,60}(success|complete|done)[^.]{0,60}(without|until|unless)[^.]{0,60}compar"; then
  echo "FAIL: Step 6 does not forbid reporting the migration successful without the before/after comparison — 'the check passed' is a different claim"; exit 1
fi

# The author-mode dispatch must hand the agent the literal mode line. agents/wp-tailwind.md
# selects Section Authoring Mode on a `Mode: **author**` line and on nothing else — prose
# about "author mode" is commentary the agent never sees, and a bare `author` token is
# supplied by ordinary input paths such as `demo/author.html`. Blockquote lines only, with
# emphasis stripped, so `> **Mode:** author` also satisfies it.
# The `|| true` is load-bearing: grep exits 1 when a file has no `>` lines at all, and under
# `set -euo pipefail` that aborts the whole script inside a command substitution.
qmode=$(grep -E '^[[:space:]]*>' "$f" \
        | sed -e 's/^[[:space:]]*>//' -e 's/[*_]//g' | tr '\n' ' ' | sed 's/  */ /g' || true)
if ! printf '%s' "$qmode" | grep -qiE 'Mode: ?author'; then
  echo "FAIL: commands/wp-tailwind-migrate.md has no QUOTED \`Mode: **author**\` line for its Step 4 dispatch — agents/wp-tailwind.md selects Section Authoring Mode on that line and on nothing else, so the migration dispatch would run Demo Conversion Mode and convert a template nobody asked to convert"; exit 1
fi

# Step 4's per-agent contract restates the promotion rule, and a restatement that drops the
# threshold is worse than no restatement: an agent reading only this command promotes a group
# it saw twice in one section, which skills/wp-tailwind-system/SKILL.md keeps inline. The
# numbers are asserted, not the wording — "3+ times, or on 2+ distinct pages" is the rule, and
# any phrasing that carries both counts satisfies this.
#
# Reuses `$s4flat` from the Step 4 region above instead of re-deriving one. This line
# used to cut its own region with `sed -n '/^## Step 4 /,/^## Step 5/p'` — note the
# TRAILING SPACE, which the `awk '/^## Step 4/,/^## Step 5/'` at the top of that region
# does not have. Two anchors for one region is two answers to one question: rewriting
# the heading as `## Step 4: Convert…` (a colon instead of the em-dash, which changes
# nothing about the step) matched the awk and missed the sed, so this assertion read an
# EMPTY region and reported that Step 4 had lost the promotion threshold when it had
# not. Proven. The region above is already closure-proven — its last line is asserted
# to be the `## Step 5` heading — so reusing it also inherits that guarantee.
if ! printf '%s' "$s4flat" | grep -Eqi '3\+?[^.]{0,40}times?[^.]{0,60}2\+?[^.]{0,40}(distinct )?pages?'; then
  echo "FAIL: Step 4 restates the promotion rule without its threshold — SKILL.md promotes a group only at 3+ occurrences or across 2+ distinct pages, and a restatement that omits the counts tells the agent to promote a group it saw twice inside one section"; exit 1
fi

# ---------------------------------------------------------------------------
# Lessons from a run against a theme this command was never meant to touch.
# ---------------------------------------------------------------------------

# 1. Step 0 must gate on the Tailwind MAJOR, not assume it. Every later step writes the
# v4 layout (@import "tailwindcss", @theme, the four src dirs, dist/main.css) and Step 5
# deletes the old stylesheet. Pointed at a v3 theme — tailwind.config.js, a PostCSS build,
# style.css at the theme root carrying the Theme Name header — none of that exists, so the
# command silently restructures a theme nobody asked it to restructure and then removes the
# stylesheet the unmigrated templates still need. The gate has to READ the installed
# version and STOP, which is why this is asserted inside a bash fence and not in prose.
# Reuses the $s0 / $s0bash / $s0flat the Step 0 region above already derived, and the
# house `bashonly` helper — a second pair of anchors for one region is two answers to
# one question, which this file has already been bitten by once.
printf '%s' "$s0bash" | grep -q "tailwindcss/package.json" \
  || { echo "FAIL: Step 0 never reads the installed Tailwind version — it must resolve tailwindcss/package.json and stop when the major is not 4, or a v3 theme gets restructured around a layout it never had"; exit 1; }
printf '%s' "$s0bash" | grep -Eq 'exit 1' \
  || { echo "FAIL: Step 0's version check does not exit — reporting the wrong major and continuing is the failure this gate exists to prevent"; exit 1; }
s0flat=$(printf '%s' "$s0" | flat)
printf '%s' "$s0flat" | grep -q 'tailwind.config.js' \
  || { echo "FAIL: Step 0 does not name tailwind.config.js as the v3 artifact to look for"; exit 1; }

# 2. The pixel diff must carry its noise floor. `compare -metric AE` reads as the objective
# test this command wants and is not one: backdrop-filter, big gradients and transformed
# layers do not rasterise identically between runs. Measured — two consecutive captures of
# the SAME page differed by more than baseline-vs-migrated did, so the real comparison
# looked cleaner than the page compared against itself. Without the floor, the count is
# read as proof in whichever direction flatters the run.
if ! printf '%s' "$flatf" | grep -qi 'noise floor'; then
  echo "FAIL: Step 6 offers compare -metric AE without a noise floor — a differing-pixel count means nothing until the same page is captured twice and diffed against itself"; exit 1
fi
printf '%s' "$flatf" | grep -qi 'backdrop-filter' \
  || { echo "FAIL: Step 6 does not name backdrop-filter as the reason two captures of one page differ"; exit 1; }
printf '%s' "$flatf" | grep -Eqi 'same (unchanged )?page' \
  || { echo "FAIL: Step 6 does not tell the reader to capture the same page twice before trusting any before/after count"; exit 1; }

# 3. The verification contract must include ON-SCREEN ORDER. A rewrite that drops a
# flex-row-reverse mirrors a section left-to-right while every box keeps its size: page
# height, section heights, gaps and every element box stay byte-identical and a
# size-only contract reports a perfect match. It shipped that way once and only the
# screenshot read caught it.
printf '%s' "$flatf" | grep -Eqi 'flex-direction' \
  || { echo "FAIL: Step 6's numeric contract never mentions flex-direction — a dropped row-reverse changes no box and passes every size comparison"; exit 1; }
printf '%s' "$flatf" | grep -Eqi 'on-screen order|order of every row|element order' \
  || { echo "FAIL: Step 6's numeric contract does not require checking the on-screen order of reversible rows"; exit 1; }

echo PASS
