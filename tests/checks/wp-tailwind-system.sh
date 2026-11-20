#!/usr/bin/env bash
# The wp-tailwind-system skill must carry the full decision ladder and the
# prohibition list, so agents cannot fall back to the BEM/custom-property path.
#
# Round 2. All four prohibitions were gated by a bare presence grep for their
# SUBJECT ('assets/css/styles.css', 'BEM', ':root', 'new director'). An assertion
# shaped like that fires when the text is DELETED and never when it is REVERSED:
# a Forbidden list rewritten so that `assets/css/styles.css` is "the shared
# output surface for every template" and a `:root` block is fine "whenever
# `@theme` is inconvenient" still printed PASS, because both subjects are still
# named. A prohibition is a direction, not a word. Each of the four is now read
# out of its OWN list item and has to state the ban.
#
# The scoping/flattening helpers are lifted from tests/checks/wp-yolo-tailwind.sh
# and tests/checks/wp-init-tailwind.sh rather than reinvented; the long rationale
# for each lives there. Only `bullet_about` is new, and only because this file has
# to pick the item a subject BELONGS to: ':root' appears in two Forbidden items —
# the one that bans it, and the BEM item that names it in passing — and "the first
# item that mentions it" is a coin toss that a list reorder flips.
#
# Round 2 also closes a false-fail. The second decision-ladder rung was gated by
# the literal `2 pages`, so `2+ pages` — the very form this skill's own "Repeated"
# paragraph uses — exited 1 with "skill missing decision-ladder element '2 pages'".
# The threshold is a claim about a number, so it now accepts the forms a careful
# author writes for it (`≥2`, `2+`, `two or more`, `at least 2`) and still rejects
# an unrelated one (`≥7 pages`, `3+ pages`).
set -euo pipefail
f=skills/wp-tailwind-system/SKILL.md

fail() { echo "FAIL: $1"; exit 1; }

test -f "$f" || fail "$f missing"

# ---------------------------------------------------------------------------
# Text preparation. Every assertion below reads the FLATTENED file, never raw
# lines: prose here is wrapped at ~80 columns and a re-wrap that lands inside an
# asserted phrase is an ordinary, correct edit. `dehyphen` runs first, so a break
# at a hyphen (`BEM-with-custom-` / `properties`) rejoins before anything looks
# for a word.
# ---------------------------------------------------------------------------
dehyphen() {
  printf '%s\n' "$1" | awk '
    { if (buf != "") { sub(/^[[:space:]]+/, ""); $0 = buf $0; buf = "" } }
    /[A-Za-z]-$/ { buf = $0; next }
    { print }
    END { if (buf != "") print buf }
  '
}
flat() { printf '%s' "$1" | tr '\n' ' ' | sed 's/  */ /g'; }

# `bullets <raw-text>` prints one flattened line per TOP-LEVEL markdown list item:
# the bullet line plus its wrapped continuation lines and nested sub-bullets, and
# nothing else. A list item ends where markdown says it ends — at the next item at
# its own level, at the blank line that closes the list, or at the first line
# dedented out of it — so renaming a neighbour or reordering the list cannot move
# it. That property is the point: an assertion scoped to one item's own text is
# DIRECTED, because a clause moved into a different item leaves the scope.
bullets() {
  printf '%s\n' "$1" | awk '
  {
    line = $0
    m = match(line, /[^[:space:]]/)
    ind = (m ? m - 1 : -1)                      # -1 = blank or whitespace-only
  }
  ind < 0 { if (buf != "") { print buf; buf = "" } next }
  line ~ /^[[:space:]]*- / {
    if (ind == 0) { if (buf != "") print buf; buf = line; next }
    if (buf != "") { buf = buf " " line; next }
    next
  }
  { if (buf != "" && ind > 0) { buf = buf " " line; next }
    if (buf != "") { print buf; buf = "" } }
  END { if (buf != "") print buf }
  ' | sed 's/  */ /g'
}

# `bullet_about <raw-text> <literal-label>` prints the ONE list item the label
# belongs to: of the items containing it, the one where it appears EARLIEST in the
# item's own text. A prohibition names its subject at the head of the item ("A
# `:root { --… }` block."); an item that merely refers to another rule's subject
# does so mid-sentence ("`var(--x)` from `:root`"). Exits 1 when no item carries
# the label.
#
# The alternative — demanding the label be unique across the list — would fail on
# a correct edit, since cross-referencing another rule's subject is normal prose
# and is exactly the wording this skill ships with today.
bullet_about() { # <raw-text> <literal-label>
  awk -v lab="$2" '
    { i = index($0, lab) }
    i > 0 { if (best == 0 || i < best) { best = i; line = $0 } }
    END { if (best == 0) exit 1; print line }
  ' < <(bullets "$1")
}

# `sentences <flat-text> <needle>` prints one line per occurrence of <needle>: the
# sentence it sits in, bounded by ". " on either side and capped at 240 characters
# each way so a stretch without sentence punctuation cannot pull in the file.
sentences() {
  printf '%s' "$1" | awk -v needle="$2" '
  {
    s = $0; nl = length(needle); pos = 1
    while ((i = index(substr(s, pos), needle)) > 0) {
      abs = pos + i - 1
      lo = (abs > 240) ? abs - 240 : 1
      pre = substr(s, lo, abs - lo)
      p = 0
      while ((j = index(substr(pre, p + 1), ". ")) > 0) p = p + j + 1
      start = lo + p
      post = substr(s, abs + nl, 240)
      k = index(post, ". ")
      print substr(s, start, (abs + nl - start) + ((k > 0) ? k : length(post)))
      pos = abs + nl
    }
  }'
}

raw=$(dehyphen "$(cat "$f")")
flatf=$(flat "$raw")

# ---------------------------------------------------------------------------
# Decision ladder. These are positive statements, so presence is the right shape
# — but file-wide and flattened, because scoping them to a `## Decision ladder`
# heading would turn renaming that heading into a failure, and a heading rename
# is a correct edit.
# ---------------------------------------------------------------------------
for rung in 'utility classes in the markup' 'utilities/site\.css' 'components/<slug>\.css' '@keyframes'; do
  printf '%s' "$flatf" | grep >/dev/null -Ec "$rung" \
    || fail "skill missing decision-ladder element '$rung'"
done

# Rung 2's threshold: a utility group seen on two or more pages is promoted to
# utilities/site.css. The old needle was the literal `2 pages`, and this skill's
# own "Repeated" paragraph already writes the same number as `2+`, so the check
# rejected the file's own house style. Written as a closed alternation of the
# forms that mean two-or-more, each pinned behind a non-digit so `12+ pages` and
# `12 or more pages` cannot satisfy it, and no other number can.
TWO_PAGES='(^|[^0-9])(≥ ?2|2\+|2 or more|two or more|at least (2|two))[a-z ]{0,14}pages'
printf '%s' "$flatf" | grep >/dev/null -Eci "$TWO_PAGES" \
  || fail "skill missing the decision-ladder threshold that sends a repeated utility group to utilities/site.css — the group has to be seen on two or more pages. Accepted forms: '≥2 pages', '2+ pages', '2 or more pages', 'two or more pages', 'at least 2 pages'."

# Rungs 2 and 3 also have to exist as RUNGS. Both of their destinations are named
# a second time in the file-layout code fence — `utilities/site.css utility groups
# repeated across ≥2 pages` and `components/<slug>.css one per page/template` —
# and the file-wide greps above are satisfied by those lines alone. Verified:
# deleting rung 2 outright ("2. **Same utility group on ≥2 pages** → semantic
# class in `utilities/site.css` …") still printed PASS. A ladder rung is what
# tells an agent WHEN to promote a utility group; the fence only says where the
# file sits.
#
# Scoped to a list ITEM rather than to the `## Decision ladder` heading, because a
# heading rename is a correct edit. Ordered markers are normalised to `- ` first
# so `bullets` can flatten them, which also means renumbering the ladder or
# rewriting it as a bulleted list keeps passing; a fence line is not a list item
# and cannot satisfy either assertion.
items=$(bullets "$(printf '%s\n' "$raw" | sed -E 's/^([0-9]+)\. /- /')")

printf '%s\n' "$items" | grep -F 'utilities/site.css' | grep >/dev/null -Eci "$TWO_PAGES" \
  || fail "no decision-ladder rung sends a utility group seen on two or more pages to \`utilities/site.css\`. The file-layout code fence names that path too, so a file-wide grep passes with the rung deleted — and a deleted rung is the whole promotion rule gone."

printf '%s\n' "$items" | grep >/dev/null -Fc 'components/<slug>.css' \
  || fail "no decision-ladder rung sends a group repeated within a single page to \`components/<slug>.css\`. As with rung 2, the code fence names the path, so only a rung proves the ladder still has its third step."

# ---------------------------------------------------------------------------
# Prohibitions. Directed, and read out of the list item that owns each subject.
# ---------------------------------------------------------------------------
BAN='never (write|create|author|emit|generate|produce|touch|use)|(do|does) not (write|create|author|emit|use)|(must|may) not be (written|created|used)|(is|are) not (written|created|used)|forbidden|banned|off[- ]limits'

# 1. assets/css/styles.css is the OTHER template's output surface. Naming it is
#    not enough — the reversal that started this round kept the name and called it
#    "the shared output surface for every template".
b_styles=$(bullet_about "$raw" 'assets/css/styles.css') \
  || fail "no Forbidden list item is about \`assets/css/styles.css\` — that file is the template=basic output surface and a Tailwind theme must never write it"
printf '%s' "$b_styles" | grep >/dev/null -Eci '(^|[^a-z])basic([^a-z]|$)' \
  || fail "the \`assets/css/styles.css\` item does not say the file belongs to the \`basic\` template: [$b_styles]"
printf '%s' "$b_styles" | grep >/dev/null -Eci "$BAN" \
  || fail "the \`assets/css/styles.css\` item names the file but never bans writing it. A Forbidden entry that only names its subject reads as documentation of an output surface, which is the opposite of the rule: [$b_styles]"

# 2. BEM-with-custom-properties belongs to wp-css-system, and to nothing here.
b_bem=$(bullet_about "$raw" 'BEM') \
  || fail "no Forbidden list item is about BEM-with-custom-properties authoring — that is wp-css-system's model, and it is what a Tailwind theme falls back to when this skill goes quiet"
printf '%s' "$b_bem" | grep >/dev/null -Fc 'wp-css-system' \
  || fail "the BEM item does not hand BEM-with-custom-properties authoring back to \`wp-css-system\`: [$b_bem]"
printf '%s' "$b_bem" | grep >/dev/null -Eci "$BAN|not (this|ours|for this)|instead|rather than|belongs to|'s job" \
  || fail "the BEM item never says BEM-with-custom-properties authoring is not this skill's job. Named without a direction, it reads as a sanctioned second option: [$b_bem]"

# 3. Tokens are declared in @theme, never in :root. ':root' appears in two items —
#    this one and the BEM item's parenthetical — which is why the item is picked by
#    `bullet_about` rather than by "first mention".
b_root=$(bullet_about "$raw" ':root') \
  || fail "no Forbidden list item is about a \`:root\` custom-property block"
printf '%s' "$b_root" | grep >/dev/null -Fc '@theme' \
  || fail "the \`:root\` item does not redirect tokens to the \`@theme\` block: [$b_root]"
printf '%s' "$b_root" | grep >/dev/null -Eci '(belong|live|go|are declared|are defined|are set) in|never (re)?declare|(^|[^a-z])only (in|ever)' \
  || fail "the \`:root\` item names \`:root\` but never states where tokens go instead. \"A \`:root\` block is fine whenever \`@theme\` is inconvenient\" satisfies a check that only looks for the two words: [$b_root]"
if printf '%s' "$b_root" | grep >/dev/null -Eci '(is|are|stays|remains) (fine|ok|okay|acceptable|allowed|permitted|permissible)|may be used|is the fallback'; then
  fail "the \`:root\` item permits a \`:root\` block. Tokens live in \`@theme\`; a second declaration site is how a Tailwind theme grows a custom-property system it was never meant to have: [$b_root]"
fi

# 4. The directory set under assets/css/src/tailwindcss/ is closed at four.
#    bin/tailwind-native-check.sh:28 errors on any other name, so a fifth breaks
#    the build for every template.
b_dir=$(bullet_about "$raw" 'assets/css/src/tailwindcss/') \
  || fail "no Forbidden list item is about the directories under \`assets/css/src/tailwindcss/\`"
printf '%s' "$b_dir" | grep >/dev/null -Eci "$BAN|no (fifth|other|further|additional)|other than|beyond the four" \
  || fail "the directory item names \`assets/css/src/tailwindcss/\` but never bans a directory outside the sanctioned set: [$b_dir]"
printf '%s' "$b_dir" | grep >/dev/null -Eci 'fifth|other than|beyond the four|not one of|outside the' \
  || fail "the directory item does not say WHICH directories are out of bounds. It has to ban a fifth name, not the four sanctioned ones — those may be created when the first rule that belongs there is written: [$b_dir]"

# The sanctioned SET itself, extracted positively and compared. This is the gate
# that stops the layouts/ carve-out below from opening the door to a fifth
# directory.
#
# NOT anchored on a `director(y|ies)[^.]*` clause any more. That anchor is the one
# tests/checks/wp-tailwind-migrate.sh already replaced, for two proven false-fails
# this file inherited when it borrowed the form: any '.' between the word and the
# list truncates the clause and the gate reports an EMPTY set, and brace notation
# (`{base,components,layouts,utilities}`) leaves `{base` and `utilities}` failing
# the bare-name pattern, so it reports a WRONG set of two.
#
# The run-walker ported from that file instead: walk the file's backticked spans in
# order, split each on commas, braces and spaces, and grow a RUN of bare lowercase
# names. Anything that is not a bare name — a path (`assets/css/src/tailwindcss/`,
# `utilities/site.css`), `@apply`, `template=basic` — ends the run, so the runs are
# exactly the lists an author writes. Take the first run that names two or more of
# the four sanctioned directories, and compare it whole: a fifth name lands in the
# same run and fails the comparison, a renamed one fails it too, and deleting the
# list leaves no qualifying run at all. Trailing slashes are stripped, so `base/`
# is the same sanctioned name as `base`. `|| true` because `pipefail` turns an empty
# grep into a silent `set -e` abort that exits 1 without ever printing FAIL.
# One difference from the migrate version, and it is required here: that one walks a
# single Step region, this one walks the WHOLE skill, so the PROSE BETWEEN two spans
# has to be able to end a run too. Feeding the walker only `grep -oE '`[^`]+`'` throws
# the gaps away, and the first thing it did on this file was glue the enumeration's
# `utilities` to the `layouts/` of the next PARAGRAPH ("`layouts/` in particular is
# absent until something writes into it") and report a five-token run. So the text is
# split into span lines (prefixed \001) and gap lines, and a gap is transparent only
# when it is list glue — commas, semicolons, whitespace, "and", "or". Anything else,
# including the ". Never create a fifth." that separates those two mentions, ends the
# run. Erring toward ending it is the safe direction: it can only shorten a run, and a
# run must still carry two of the four sanctioned names to be the enumeration at all.
# Triple-backtick FENCE markers are turned into gaps first, before the inline-code split
# runs, or the pairing consumes them and reads the file-layout fence's BODY as span text
# — which produced the nonsense run `shared components layouts header footer sidebar`
# from the fence's own right-hand column. The fence is gated by the stray-directory scan
# below, not by this enumeration.
dirs=$(printf '%s' "$flatf" | sed -e 's/```/\n/g' -e 's/`\([^`]*\)`/\n\x01\1\n/g' | awk '
      function done_run() { if (!pr && n >= 2 && hits >= 2) { printf "%s", run; pr=1 } n=0; hits=0; run="" }
      /^\001/ {
        line = substr($0, 2)
        gsub(/[,{}]/, " ", line)
        m = split(line, tok, /[ \t]+/)
        for (i = 1; i <= m; i++) {
          t = tok[i]; sub(/\/+$/, "", t)
          if (t == "") continue
          if (t ~ /^[a-z][a-z0-9_-]*$/) {
            run = run t " "; n++
            if (t=="base" || t=="components" || t=="layouts" || t=="utilities") hits++
          } else { done_run() }
        }
        next
      }
      { gap = $0; gsub(/[ \t,;]/, "", gap); if (gap != "" && gap != "and" && gap != "or") done_run() }
      END { done_run() }
    ')
# Compared as a SET, not as a sequence — the same reason wp-tailwind-migrate.sh sorts:
# rule 2 sanctions four NAMES, not an order, so listing them `utilities components base
# layouts` is the same instruction and must not read as a regression. Sorting costs the
# gate nothing: a fifth name still lands in the sorted run and a renamed one still
# misses. The message prints the UNSORTED run, because that is what the author wrote.
dirset=$(printf '%s' "$dirs" | tr ' ' '\n' | { grep -v '^$' || true; } | sort | tr '\n' ' ')
if [ "$dirset" != "base components layouts utilities " ]; then
  fail "the skill sanctions the directory set [${dirs}] under assets/css/src/tailwindcss/ — it must be exactly 'base components layouts utilities', which is the set bin/tailwind-native-check.sh rule 2 enforces"
fi

# The set gate above reads ONE clause — the four-name enumeration — and the
# Forbidden item reads only itself, so a fifth directory introduced ANYWHERE ELSE
# satisfied both. Verified before this gate existed: sanctioning `overrides/`
# inside the layouts/ carve-out sentence ("Any of the four — and `overrides/`,
# when a project needs it — may be created …") printed PASS, and so did adding
# `overrides/plugin.css` to the file-layout code fence. The carve-out is exactly
# the sentence that must not open the door to a fifth, so it is gated by name
# here rather than by trusting the enumeration to speak for the whole file.
#
# A CSS source directory reference is a bare lowercase name plus `/`, followed by
# nothing (`layouts/`) or by a single .css filename (`utilities/site.css`,
# `components/<slug>.css`). Everything is first split on non-path characters, one
# token per line, so the pattern anchors at both ends: that is what keeps
# `assets/css/styles.css` and `${CLAUDE_PLUGIN_ROOT}/bin/…` (multi-segment paths),
# `page/template` (prose) and `.claude/CLAUDE.md` (leading dot) out, and it is
# also why the scan cannot be defeated by two directory names sitting next to
# each other — an inline grep consumes the delimiter between them and misses the
# second. Read from the flattened text so a wrap between a name and its filename
# cannot hide one. LC_ALL=C safe: the class is byte-wise, so `≥` and `—` split
# into separators under either locale rather than joining tokens.
#
# `bin` is exempt: it is the PLUGIN's script directory, which the Verify section
# names twice — once in the fenced command and once in the prose warning about a
# bare relative `bin/…` path, whose ellipsis splits off and leaves a bare `bin/`.
# It is not a directory under assets/css/src/tailwindcss/, and the Verify path is
# gated on its own below.
# SCOPED to the two sections that speak for the CSS source tree — `## File layout`
# (its prose, its carve-out sentence and its layout fence) and `## Forbidden`. It used
# to read the WHOLE file, and a pattern that cannot tell a CSS-source directory from
# any other path reddened on two ordinary, correct additions:
#
#   "The build compiles `main.css` into `dist/main.css`; never hand-edit it."
#     -> FAIL: the skill names CSS source director(y|ies) [dist] …
#   "Read the converted page in `demo/` before authoring."
#     -> FAIL: … [demo] …
#
# Neither sentence is about the source tree, and a gate that fails on correct work
# gets muted. Both sections are still read whole, so the two controls that MUST keep
# failing still do: `overrides/` smuggled into the layouts/ carve-out sentence, and
# `overrides/plugin.css` added to the file-layout fence.
#
# Ceiling, stated because it is the cost of the narrowing: a `name/` token inside
# File layout or Forbidden is read as a directory of the CSS source tree, whatever it
# means — a sentence about `dist/` or `demo/` belongs in Tokens or Verify, not there —
# and a fifth directory sanctioned from some OTHER section escapes this scan. The
# declarative statements are covered regardless: the set enumeration above and the
# Forbidden item below both live in these two sections by construction.
#
# A section that runs to EOF is not proven closed here, deliberately: an unterminated
# range can only make this corpus BIGGER, which widens the scan rather than hollowing
# it, and `## Verify` legitimately ends at EOF today. What must be proven is that each
# section was FOUND — an empty corpus is a scan that asserts nothing.
section() { # section <heading text> — from the dehyphenated raw file on stdin
  awk -v pat="$1" '
    index($0, "## " pat) == 1 { f = 1; next }
    f && /^## / { exit }
    f { print }
  '
}
scope=$(printf '%s\n' "$raw" | section 'File layout'; printf '%s\n' "$raw" | section 'Forbidden')
printf '%s' "$scope" | grep >/dev/null -c '.' \
  || fail "neither a '## File layout' nor a '## Forbidden' section was found in $f — the stray-directory scan below would read an empty corpus and assert nothing"
stray=$(flat "$scope" \
  | sed 's|[^A-Za-z0-9_/.<>-]|\
|g' \
  | grep -E '^[a-z][a-z0-9_-]*/([a-z0-9_<>.-]+\.css)?$' \
  | sed 's|/.*$||' | sort -u \
  | grep -Ev '^(base|components|layouts|utilities|bin)$' | tr '\n' ' ' || true)
if [ -n "$stray" ]; then
  fail "the skill names CSS source director(y|ies) [${stray% }] under assets/css/src/tailwindcss/. The sanctioned set is closed at base, components, layouts and utilities — bin/tailwind-native-check.sh rule 2 errors on any other name, so a fifth breaks the build for every Tailwind theme. Naming one in File layout or Forbidden sanctions it, whether or not the four-name enumeration and the Forbidden list still say four."
fi

# ---------------------------------------------------------------------------
# The layouts/ carve-out.
#
# `git archive HEAD starter-theme/__tailwind__` ships base, components and
# utilities and NO layouts/: git cannot track a directory once the last file in
# it is gone, and this branch removed the comment-only stubs. Meanwhile the
# header and footer commands send their @apply rules to layouts/header.css and
# layouts/footer.css. Read against a flat "never create a new directory" with no
# carve-out, an agent has to choose between this file layout and the command that
# dispatched it. The skill has to say the sanctioned four MAY be created when
# absent — and, per the set gate above, still only those four.
# ---------------------------------------------------------------------------
printf '%s' "$flatf" | grep >/dev/null -Eci '(may|can|must) be created|create (it|them|one of the four|any of the four|the missing)|creating one of the four' \
  || fail "the skill never allows a sanctioned directory to be CREATED. layouts/ is not in the starter — git cannot track an empty directory — so an agent told only 'never create a new directory' cannot write layouts/header.css at all"
lay=$(sentences "$flatf" 'layouts/' || true)
printf '%s' "$lay" | grep >/dev/null -Eci 'absent|missing|does not exist|not (yet )?(there|present|shipped)|empty' \
  || fail "the skill treats layouts/ as a directory that is already there. It is not: git cannot track it while it is empty, so the skill has to say it can be missing and may be created: [$lay]"

# ---------------------------------------------------------------------------
# Tokens, empty files, and the Verify invocation.
# ---------------------------------------------------------------------------
printf '%s' "$flatf" | grep >/dev/null -Fc '@theme' \
  || fail "skill does not point tokens at the @theme block"

printf '%s' "$flatf" | grep >/dev/null -Eci 'at least one rule|never create an empty' \
  || fail "skill missing the no-empty-file rule"

# The Verify block must name the convention check AND root it at the plugin.
# Whoever follows this skill has the user's WordPress project as their working
# directory, so a bare `bin/…` exits 127 and the convention is never actually
# verified. Matched as a whitespace-stripped substring so re-indenting or
# re-fencing the block cannot false-fail it; tests/checks/tailwind-native.sh owns
# the repo-wide bare-path ban. The braces are optional:
# `$CLAUDE_PLUGIN_ROOT/bin/…` is the same correct path.
tr -d '[:space:]' < "$f" \
  | grep >/dev/null -Ec '\$\{?CLAUDE_PLUGIN_ROOT\}?/bin/tailwind-native-check\.sh' \
  || fail "skill does not point Verify at \${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh"

echo PASS
