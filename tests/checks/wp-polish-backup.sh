#!/usr/bin/env bash
# /wp-polish's pre-polish backup. Two independent defects lived in the same four
# lines of commands/wp-polish.md, and fixing either one alone leaves the other:
#
#   1. LOCATION. The backup was a SIBLING of the demo pages (demo/original.html,
#      demo/original-<filename>). /wp-seed maps every demo/*.html to a WordPress
#      Page named after the file, so the backup seeds a phantom page out of
#      pre-polish markup. Not within one /wp-yolo run — Step 5 seeds (item 1)
#      before it polishes (item 4) — but on the NEXT seed: a second /wp-yolo over
#      the same demo folder, or a standalone /wp-polish followed by /wp-seed.
#   2. LIFETIME. "(overwrites if exists)" meant run two copied the already-
#      polished page over the only unpolished copy. Silent, irreversible data
#      loss on an ordinary repeat invocation, and documented rather than
#      accidental, so no reader of the file would flag it.
#
# Two more, found after that fix shipped:
#
#   3. IDENTITY. Fixing (2) alone made the never-overwrite rule preserve a backup
#      of the WRONG document. Step 1 used to copy an input from outside demo/ over
#      demo/index.html BEFORE Step 2 ran, so /wp-polish figma-v1.html then
#      /wp-polish figma-v2.html both arrive as demo/index.html: run two finds
#      demo/.prepolish/index.html already there, keeps it under (2), and the report
#      calls figma-v1's markup "the page as it stood before the first polish" of
#      figma-v2. The copy is now named after the SOURCE document, so the rule fires
#      only on a re-polish of the same document, and Step 1 copies nothing at all —
#      Step 6 writes the destination anyway, so the early copy bought nothing and
#      falsified Step 2's "before touching anything".
#   4. PROPAGATION. /wp-init runs /wp-polish and then writes the backup path into
#      the generated project's .claude/CLAUDE.md — the file every agent in a user's
#      project reads first. README.md and commands/wp-init.md were still promising
#      demo/original.html long after /wp-polish stopped writing it, because this
#      check was scoped to commands/wp-polish.md alone. The sweep below covers
#      commands/, agents/ and README.md.
#
# Assertion style, from the defects this branch has already shipped:
#   - flatten before matching; command files here wrap at ~90 columns, so a
#     line-anchored grep dies on the next re-wrap.
#   - assert PATHS, not words: "original" appears in ordinary prose in this same
#     file ("preserve the original design intent"), so grep -q 'original' gates
#     nothing.
#   - assert DIRECTION: a bare mention of demo/.prepolish/ survives an edit that
#     re-points the actual copy back at a sibling of demo/*.html.
#   - and do not fail on CORRECT prose. Every widening below was written against a
#     realistic, correct edit this check used to reject; a gate that reddens on
#     ordinary authoring gets muted, and then it protects nothing.
set -euo pipefail

f=commands/wp-polish.md
fail() { echo "FAIL: $1"; exit 1; }
test -f "$f" || fail "$f missing"

flatten() { tr '\n' ' ' | sed 's/  */ /g'; }
flat=$(flatten < "$f")

# Print every sentence containing a fixed-string needle, one per output line, so
# a two-part assertion cannot be satisfied by halves drawn from two unrelated
# sentences. Needle is compared with index(), never as a regex.
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

# Markdown headings are dropped, not flattened in, wherever a region feeds
# sentences(). sentences() splits on ". " and an ATX heading carries no full
# stop, so a heading glues itself onto the sentence beneath it: with the heading
# left in, `## Step 2: Preserve Original` handed assertion 1 its save verb and
# the body underneath was free to promise nothing at all. Each heading becomes a
# bare "." — a sentence boundary with no words of its own.
drop_headings() { sed 's/^#\+ .*/./'; }

# Verbs that make a sentence a statement about where the backup is WRITTEN,
# rather than a passing mention of a path. Verbs only, plus the noun "backup"
# when a preposition makes it directional: a bare "backup" matched the plural in
# a migration note ("the retired sibling backups `demo/original.html` ... are no
# longer produced"), which is correct prose this check must not punish.
SAVE='sav(e|es|ed)|cop(y|ies|ied)|writ(e|es|ten)|preserv(e|es|ed)|back(s|ed)? up'
SAVE="$SAVE"'|backups? (at|in|into|to|as|named|lives|goes)'

# Copied verbatim from tests/checks/wp-init-tailwind.sh / wp-yolo-tailwind.sh.
# `undirected <flat-text> <needle> <lowercase-ERE>` prints every sentence holding
# the needle in which the ERE matches at a position NOT governed by a negation in
# the same clause; silence means the text is clean. Needed here because the fixed
# wp-polish.md states its own contract as a prohibition — "Do **not** copy the
# source over `demo/index.html` here" — and a raw grep for a copy verb near that
# path fails on the very sentence that closes the defect.
NEGATION="(^|[^a-zA-Z])(not|never|no|nor|cannot|neither)([^a-zA-Z]|\$)|n't"

undirected() { # <flat-text> <literal-needle> <lowercase-ERE>
  local text=$1 needle=$2 pat=$3 sent
  while IFS= read -r sent; do
    [ -n "$sent" ] || continue
    printf '%s' "$sent" | awk -v pat="$pat" -v neg="$NEGATION" '
    {
      low = tolower($0); s = low; off = 0
      while (match(s, pat)) {
        # RSTART/RLENGTH belong to THIS match and the clause loop below calls
        # match() again, which overwrites both. Copy before anything else matches.
        ms = RSTART; ml = RLENGTH
        if (ml < 1) break
        pre = substr(low, 1, off + ms - 1)
        cl = pre
        while (match(cl, /[,;:]|—/)) { cl = substr(cl, RSTART + RLENGTH) }
        if (cl !~ neg) { print $0; exit }
        off = off + ms + ml - 1
        s = substr(low, off + 1)
      }
    }'
  done <<< "$(sentences "$text" "$needle")"
  return 0
}

# ---------------------------------------------------------------------------
# A clause that names a retired sibling path is a LIVE PROMISE only if it tells
# the reader something is kept there now. Past-tense and cautionary prose about
# the same path is correct writing — this repo argues this gate's own case in
# exactly that register, in commands/wp-yolo.md and commands/wp-finalize.md —
# and failing it is how a gate gets muted.
#
# Markers come in two tiers, because one tier was demonstrably wrong in both
# directions. A STRONG marker — a past-tense verb, a modal, a word naming the
# defect — cannot occur in a live promise at all, so it exempts the whole
# SENTENCE, and it has to be read before the clause cut: "a sibling backup named
# `demo/original.html`, which /wp-seed would turn into a phantom page, is exactly
# the hazard this fix removed" loses both "would" and "hazard" to its commas.
#
# Bare NEGATION is the other direction. "Copy the source document — not the demo
# page — to `demo/original.html`" is a live promise whose "not" belongs to an
# aside about something else entirely, and reading negation across the whole
# sentence let exactly that defect through. Negation therefore exempts only the
# CLAUSE it sits in (clauses cut at `,` `;` `(` and the em-dash).
#
# The locative itself is read from the sentence, not the clause. Cutting it to
# the clause silently unhooks the verb from the path in the sentence above — the
# em-dash aside strands "Copy" three clauses away from `demo/original.html` — and
# a negative that cannot see the verb is not a negative. What the clause cut was
# protecting against, a sentence whose save verb belongs to a *different* path,
# is covered by the two exemptions: prose that mentions the retired path
# alongside the live one does it either to disown it ("..., not at
# `demo/original.html`") or to date it ("the old `demo/original.html`"). `:` is
# deliberately not a cut point — "The demo's original: demo/original.html" is a
# stale promise, and cutting there would strand the path in a clause of its own.
#
# "must" and "should" are deliberately in neither tier — "the backup must be
# written to demo/original.html" is a stale promise, and their negated forms are
# already covered by negation. Likewise bare "used": only "used to" is historical.
# ---------------------------------------------------------------------------
STRONG="(^|[^a-z])(never|avoids?|stops?|would|could|used to|no longer|formerly"
STRONG="$STRONG"'|previously|earlier|older|old|legacy|retired|deprecated|superseded'
STRONG="$STRONG"'|obsolete|stale|historical|history|was|were|wrote|renamed|replaced'
STRONG="$STRONG"'|hazard|phantom|mistake|instead|rather|until)([^a-z]|$)'
WEAK="(^|[^a-z])(not|no|nor|neither|none|cannot)([^a-z]|\$)|n't"

# live_promise flattens with PARAGRAPH BREAKS PRESERVED as sentence boundaries, which
# plain flatten() does not. sentences() splits on ". " only, so a block that ends without
# one — a code fence, a table, an HTML footer — glues itself onto the next paragraph and
# lends it every word it contains. That is an exemption channel, not a cosmetic detail:
# a live promise appended after README's footer inherited `star-history` from a link, the
# `history` in it matched STRONG, and the promise was waved through. Blank lines become a
# lone `.`, so the window starts where the paragraph does.
paraflatten() { sed 's/^[[:space:]]*$/./' | tr '\n' ' ' | sed 's/  */ /g'; }

live_promise() { # <file> <literal-needle> <locative-ERE> -> first offending sentence
  local file=$1 needle=$2 loc=$3 text sent cl
  text=$(paraflatten < "$file")
  while IFS= read -r sent; do
    [ -n "$sent" ] || continue
    if printf '%s' "$sent" | grep -Eqi "$STRONG"; then continue; fi
    # the clause the path actually sits in, for the negation test only
    cl=$(printf '%s' "$sent" | sed 's/[,;(]/\n/g; s/—/\n/g' | grep -F "$needle") || true
    if printf '%s' "$cl" | grep -Eqi "$WEAK"; then continue; fi
    # decided on the sentence, reported as the clause: a flattened code block can
    # run 240 characters without a full stop and the whole window is unreadable.
    if printf '%s' "$sent" | grep -Eqi "$loc"; then printf '%s\n' "$cl" | head -1; return 0; fi
  done <<< "$(sentences "$text" "$needle")"
  return 0
}

# ---------------------------------------------------------------------------
# Region. A backup rule stated *after* the step that overwrites the demo page is
# not a backup rule, so the two assertions below are scoped to everything before
# the first heading about writing the output. The region deliberately degrades to
# the whole file if no such heading exists: a check that FAILS when someone
# renames Step 6 protects nothing, it just gets muted. Anchoring on a step
# *number* would be worse still — renumbering the steps is an ordinary correct
# edit.
#
# The marker is loose but no longer blind. It used to be `tolower($0) ~
# /write|output/`, which also matched an EARLIER heading — "## Step 1: Resolve
# Input and Output Paths", "## Step 2: ... Never Overwrite It" — and collapsed
# the region onto the front matter, hard-failing assertions 1 and 2 without them
# ever running. So: the write verb is word-boundaried ("Overwrite" and
# "Rewriting" are not "write"), a heading that also names an INPUT is not the
# output step, a NEGATED heading is not it either, and a heading about the BACKUP
# ("Write the Pre-Polish Copy") is not the step that overwrites the demo page.
# ---------------------------------------------------------------------------
WRITE_HEAD='(^|[^a-z])(writ(e|es|ing)|outputs?)([^a-z]|$)'
WRITE_SKIP='(^|[^a-z])(input|not|never|no)([^a-z]|$)|backup|pre-?polish|preserv|copy|source|original'

pre=$(awk -v wh="$WRITE_HEAD" -v ws="$WRITE_SKIP" '
  /^#+ /{ h = tolower($0)
          if ($0 ~ /^## / && h ~ wh && h !~ ws) exit
          print "."; next }
  { print }' "$f" | flatten)
[ -n "$pre" ] || fail "$f is empty before its write-output step"

# ---------------------------------------------------------------------------
# 1. LOCATION, stated directionally: the command must say the copy is written INTO
#    demo/.prepolish/, a dot-prefixed directory that shell globbing, Python's
#    glob, ripgrep and fd all skip, so /wp-seed's demo/*.html enumeration cannot
#    see it. The save verb has to come from the BODY — see drop_headings above.
# ---------------------------------------------------------------------------
sentences "$pre" 'demo/.prepolish/' | grep -Eqi "$SAVE" \
  || fail "The command never says, before the step that overwrites the page, that the pre-polish copy is written to demo/.prepolish/ — a backup beside the demo pages becomes a phantom WP Page on the next /wp-seed"

# ...and nowhere may the file direct that copy at a sibling of demo/*.html.
# Word-level greps are useless here, so this is scoped to clauses that both name
# such a path and carry a save verb, with past-tense and cautionary sentences
# exempt: a migration note ("earlier builds wrote that copy to
# `demo/original.html`") and a warning ("do not write the backup to
# `demo/original.html`") are correct prose and used to fail here.
for needle in 'demo/original' '.original.html'; do
  off=$(live_promise "$f" "$needle" "$SAVE")
  if [ -n "$off" ]; then
    fail "$f still writes a backup to a sibling of demo/*.html, which /wp-seed turns into a phantom Page seeded from pre-polish markup: $off"
  fi
done

# ---------------------------------------------------------------------------
# 2. LIFETIME: the write must be conditional. Relocating the backup without this
#    still destroys the original on run two — the second polish copies the
#    already-polished page over it.
#
#    The conditional has to bind the backup COPY, not the directory it sits in.
#    "Create `demo/.prepolish/` only if it does not already exist" satisfied a
#    grep keyed on the path while the line under it promised "Overwrite whatever
#    copy is already there" — the exact loss this assertion exists to stop. So a
#    sentence whose only reference is the bare DIRECTORY and whose verb creates
#    it is dropped before the conditional is looked for; a sentence that also
#    names a file *under* the directory is kept, because one sentence can
#    legitimately do both jobs.
#
#    Ceiling: the conditional sentence must name the path. "Write that copy only
#    if it does not already exist", with the path only in the line above, does
#    not satisfy this — deliberately, because that is also how the directory
#    reading crept in.
# ---------------------------------------------------------------------------
DIRCREATE='(creat(e|es|ing)|mak(e|es|ing)|mkdir)[^.]{0,40}demo/[.]prepolish/'
FILEPATH='demo/[.]prepolish/[a-z<]'
lifetime=$(sentences "$pre" 'demo/.prepolish/' \
  | awk -v dc="$DIRCREATE" -v fp="$FILEPATH" '
    { low = tolower($0); if (low ~ dc && low !~ fp) next; print }')

# "only when" is an ordinary synonym of "only if" and used to fail here.
COND='only (if|when) .{0,120}(do|does|has|have|is|are)( not|n.t) (already )?(exist|there|present)'
COND="$COND"'|unless .{0,120}(already )?(exists|exist|is there|is present)'
COND="$COND"'|only (if|when) .{0,120}(is|are) (absent|missing)'
COND="$COND"'|(never|do not|does not|must not|no run) (overwrit|replac|clobber)(e|es|ing)'

printf '%s\n' "$lifetime" | grep -Eqi "$COND" \
  || fail "The command does not make the backup write conditional, before the step that overwrites the page, on demo/.prepolish/<source-filename> not already existing — a second /wp-polish copies the already-polished page over the only unpolished copy. A conditional about creating the DIRECTORY does not count; the rule has to bind the copy"

# ...and nothing may promise the opposite. "(overwrites if exists)" was only one
# spelling of it: "Overwrite whatever copy is already there" says the same thing
# and walked straight past a grep for that exact phrase. Negation-aware, so the
# rule itself — "never overwrite the stored copy" — stays green.
OVERWRITE='overwrit(e|es|ing|ten)[^.]{0,60}(cop(y|ies)|backup|demo/[.]prepolish|unpolished|pre-polish|original)'
OVERWRITE="$OVERWRITE"'|(cop(y|ies)|backup|original)[^.]{0,40}(is|are|gets?|will be) overwritten'
OVERWRITE="$OVERWRITE"'|overwrit(e|es) if( it)? exists'
# needle 'verwrit', not 'overwrit': sentences() compares with index(), which is
# case-sensitive, and the promise this catches starts the sentence — "Overwrite
# whatever copy is already there" never contains a lowercase "overwrit".
ow=$(undirected "$flat" 'verwrit' "$OVERWRITE")
[ -z "$ow" ] \
  || fail "$f documents the backup as overwriting an existing copy — that is silent, irreversible loss of the original on an ordinary re-run: $ow"

# ---------------------------------------------------------------------------
# 3. The printed report must name the real backup path, and must not label a
#    demo-sibling path as the original.
#
#    The region ends at the fence that closes the report's code block, not at the
#    report's last LINE. Hard-coding "Next: Run" as the terminator meant renaming
#    that one line ("Next step: run /wp-init ...") killed the range and reddened
#    the check for a rename that changes nothing this gate cares about.
# ---------------------------------------------------------------------------
grep -qF '=== Demo Polished ===' "$f" || fail "$f prints no '=== Demo Polished ===' report block"
rep=$(awk '/^=== Demo Polished ===/{ inr = 1; next }
           inr && /^```/ { print "__FENCE__"; exit }
           inr { print }' "$f")
printf '%s' "$rep" | grep -qF '__FENCE__' \
  || fail "the '=== Demo Polished ===' report block never closed on its code fence; the awk range ran to EOF and the assertions below would degrade to file-wide greps"
# The `|| true` is load-bearing — same shape and same reason as the one on `qmode`
# in tests/checks/wp-tailwind-migrate.sh. A report block holding nothing but its
# closing fence leaves `__FENCE__` as the only line; `grep -Fv` then matches nothing
# and exits 1, and under `set -euo pipefail` that aborts the whole script from
# inside the command substitution — rc=1 with NO output at all, and the "report
# block is empty" FAIL on the next line is unreachable dead code. Proven by
# emptying the `=== Demo Polished ===` block.
rep=$(printf '%s\n' "$rep" | { grep -Fv '__FENCE__' || true; })
[ -n "$rep" ] || fail "$f's '=== Demo Polished ===' report block is empty"
printf '%s' "$rep" | grep -qF 'demo/.prepolish/' \
  || fail "the printed report does not name the backup at demo/.prepolish/ — it points the user at a path the command no longer writes"
if printf '%s' "$rep" | grep -Eq '^Original:.*demo/[A-Za-z]'; then
  fail "the report labels a sibling of demo/*.html 'Original:' — that file is both a phantom-page hazard and, after a re-run, not the original at all"
fi

# ---------------------------------------------------------------------------
# 4. demo/.prepolish/ and demo/.original/ are two different artifacts with
#    confusingly similar names: /wp-yolo Step 2.6 keeps the pre-CONVERSION
#    plain-CSS page in demo/.original/, this command keeps the pre-POLISH page
#    (already converted, on the tailwind path) in demo/.prepolish/. Restoring
#    the wrong one silently un-converts a page, so one block must hold both
#    paths and TELL THEM APART.
#
#    "Hold both paths" alone was hollow: a paragraph saying the two directories
#    "are interchangeable" — the exact opposite of the distinction — passed. So
#    the block must also name what each one holds (conversion vs polish), carry a
#    contrast, and not assert the two are the same. The equivalence patterns are
#    positive forms only, which makes them self-negating: "are not the same" and
#    "are never interchangeable" do not match "are the same" / "are
#    interchangeable" in the first place.
#
#    Blocks are paragraphs, except that a blank line is not a block break when it
#    sits inside a bulleted list, or between a list and its lead-in line. This
#    repo writes two-way distinctions as a loose bullet list, and paragraph mode
#    put every bullet in a block of its own so no block held both paths. The
#    lead-in is folded in with them because that is where "Two backup directories,
#    one letter apart" lives.
# ---------------------------------------------------------------------------
merge_lists() {
  awk '
    { l[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (l[i] ~ /^[ \t]*$/) {
          p = ""; for (j = i - 1; j >= 1; j--) if (l[j] !~ /^[ \t]*$/) { p = l[j]; break }
          n = ""; for (j = i + 1; j <= NR; j++) if (l[j] !~ /^[ \t]*$/) { n = l[j]; break }
          if (n ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]/ && p != "" \
              && p !~ /^[ \t]*(#|```)/) continue
        }
        print l[i]
      }
    }' "$1"
}

blocks=$(merge_lists "$f" \
  | awk -v RS='' '/demo\/\.prepolish\//&&/demo\/\.original\//{ gsub(/\n/, " "); print }')
[ -n "$blocks" ] \
  || fail "no single paragraph or list in $f holds both demo/.prepolish/ and demo/.original/ — two artifacts one letter apart, and restoring the wrong one un-converts the page"

EQUIV='(are|is|were|was) (interchangeable|equivalent|identical|the same)'
EQUIV="$EQUIV"'|either (one|directory|copy|file) (will do|works|is fine)'
EQUIV="$EQUIV"'|treat (them|the two) as (one|the same)'
CONTRAST='(^|[^a-z])(is not|are not|whereas|while|rather than|instead of|differ|different|two|apart|each)([^a-z]|$)'

told_apart=$(printf '%s\n' "$blocks" \
  | grep -Ei 'conver(t|ts|ted|sion)' | grep -Ei 'polish' \
  | grep -Ei "$CONTRAST" | grep -Eiv "$EQUIV") || true
[ -n "$told_apart" ] \
  || fail "no block in $f tells demo/.prepolish/ (pre-POLISH) apart from demo/.original/ (pre-CONVERSION) — naming both paths in one breath is not the same as distinguishing them, and restoring the wrong one un-converts the page"

# ---------------------------------------------------------------------------
# 5. IDENTITY (defect 3 in the header). The copy must be named after the SOURCE
#    document, not after the demo page the polished output lands in. Keyed on the
#    destination, assertion 2's never-overwrite rule preserves the wrong file the
#    moment a second, different source document is polished into demo/index.html.
#    Two halves. Wording first proved too soft to assert on: requiring the word
#    "source" in a save-sentence naming the path was satisfied by Step 2's own
#    intro line ("Save a copy of the source document under demo/.prepolish/") and
#    by the conditional in item 3, so re-keying the copy on the demo page passed.
#    What is actually load-bearing is the PLACEHOLDER — the token that says which
#    filename the copy takes — and the contrast that explains it.
#
#    5a. Every demo/.prepolish/<...> placeholder in the file must be source-derived.
#        <filename> is the pre-fix spelling and means "the demo page's name", which
#        is the whole defect; <input-...> is allowed because it is the same claim in
#        the other common word.
# ---------------------------------------------------------------------------
ph_bad=$(printf '%s' "$flat" | grep -oE 'demo/\.prepolish/<[^>]*>' | grep -Evi '<(source|input)' | head -1) || true
if [ -n "$ph_bad" ]; then
  fail "$f names the pre-polish copy after the demo page it is written to ($ph_bad), not after the source document. /wp-polish figma-v1.html then /wp-polish figma-v2.html both land at demo/index.html, so both key on demo/.prepolish/index.html: run two keeps run one's copy under the never-overwrite rule above and Step 7 presents figma-v1's markup as the pre-polish version of figma-v2 — a preserved original of a document nobody asked about"
fi
printf '%s' "$flat" | grep -Eq 'demo/\.prepolish/<(source|input)[^>]*>' \
  || fail "$f never spells out which filename the pre-polish copy takes. It has to be the source document's own, or two different documents polished into demo/index.html collide on one backup name"

# 5b. ...and the file must say so against the alternative, because a reader who
#     only sees "<source-filename>" cannot tell it apart from the demo page's name
#     in the ordinary case, where the two are the same file.
sentences "$pre" 'demo page' | grep -Ei 'rather than|instead of|(^|[^a-z])not([^a-z]|$)' | grep -Eqi 'sourc|input' \
  || fail "$f no longer contrasts naming the copy after the source document with naming it after the demo page it is written to. In the ordinary in-place polish those are the same file and the distinction reads as pedantry; it is the whole fix for an input from outside demo/"

# ---------------------------------------------------------------------------
# 6. ...and nothing may put the source at demo/index.html before that copy is
#    taken. Step 1 used to do exactly that, which is both how two documents came
#    to share one backup name and why Step 2's "before touching anything" was
#    false on that branch. Two halves, because either alone is hollow: the
#    prohibition must be PRESENT (a deletion leaves nothing warning the next
#    author off it) and no sentence may state it as an INSTRUCTION.
#
#    The preposition must sit immediately in front of the path, not merely
#    somewhere in the sentence: "move on to Step 2" is ordinary prose and an
#    unanchored (to|over|into|onto) makes it a failure.
#
#    Sentences that name the write step are exempt from the negative half:
#    "Step 6 copies the polished markup to demo/index.html" is a true description
#    of the step that legitimately writes that path, not an instruction to do it
#    early. The exempt label is read out of the write heading itself rather than
#    hard-coded, so renumbering the steps cannot turn the exemption off, and the
#    exemption is skipped entirely when there is no such heading — grep -v on an
#    empty pattern would drop every line and mute the assertion.
# ---------------------------------------------------------------------------
PRECOPY='(cop(y|ies|ied)|mov(e|es|ed)).*(to|over|into|onto) .?demo/index[.]html'
sentences "$pre" 'demo/index.html' | grep -Eqi "$PRECOPY" \
  || fail "$f no longer warns against copying the source over demo/index.html before the pre-polish copy is taken. That copy is what gave two different source documents one backup name, and what made Step 2's promise to run 'before touching anything' false for every input from outside demo/"

wlab=$(awk -v wh="$WRITE_HEAD" -v ws="$WRITE_SKIP" '
  /^## /{ h = tolower($0)
          if (h ~ wh && h !~ ws) { sub(/^## /, ""); sub(/:.*/, ""); print; exit } }' "$f")
if [ -n "$wlab" ]; then
  precopy=$(undirected "$pre" 'demo/index.html' "$PRECOPY" | grep -Fiv "$wlab") || true
else
  precopy=$(undirected "$pre" 'demo/index.html' "$PRECOPY")
fi
[ -z "$precopy" ] \
  || fail "$f directs the source to be copied over demo/index.html before the pre-polish copy is taken. Step 6 writes that path anyway, so the early copy preserves nothing and destroys the page already there: $precopy"

# ---------------------------------------------------------------------------
# 7. The report must tie the backup to the document it is a copy of. The wording
#    it replaces — "the file at demo/.prepolish/<filename> is the page as it stood
#    before the **first** polish" — is exactly the mislabel: after a second source
#    document is polished, that file came from neither the page at Output: nor the
#    document just polished.
# ---------------------------------------------------------------------------
note=$(awk '/^=== Demo Polished ===/{ inr = 1 } inr { print }' "$f" | flatten)
[ -n "$note" ] || fail "$f prints no '=== Demo Polished ===' report block"
sentences "$note" 'demo/.prepolish/' | grep -Eqi 'a copy of|(came|come|comes) from|of nothing else' \
  || fail "the report section never says which document the file in demo/.prepolish/ is a copy of, so it is free to present one source document's unpolished markup as the pre-polish version of another"

# ---------------------------------------------------------------------------
# 8. PROPAGATION (defect 4 in the header). Nothing in commands/, agents/ or the
#    README may point a reader at the retired sibling path. /wp-init matters most:
#    it runs /wp-polish and writes the path into the generated project's
#    .claude/CLAUDE.md, the file every agent in a user's project reads first, so a
#    stale promise there outlives this repo entirely.
#
#    Same discrimination as assertion 1's negative, and via the same helper: only
#    a LIVE promise fails. The locative "original(s) at|in|to" is part of it
#    because commands/wp-init.md's summary line carried no verb at all — "Demo:
#    demo/index.html (original at demo/original.html)" — and a verb-only pattern
#    walks straight past it. Word-boundary-free "original" is deliberate:
#    "originally at" keeps its "ly" and does not match.
#
#    Needle set is 'demo/original' only, one narrower than assertion 1's. The
#    `<slug>.original.html` shape never propagated anywhere — the only places it
#    appears repo-wide are the two paragraphs explaining why NOT to write a backup
#    there. It stays asserted in assertion 1, where the scope is the one file that
#    could regress to it.
# ---------------------------------------------------------------------------
LOCATE="$SAVE"'|originals? (at|in|into|to)'
for g in commands/*.md agents/*.md README.md; do
  [ -f "$g" ] || continue
  stale=$(live_promise "$g" 'demo/original' "$LOCATE")
  if [ -n "$stale" ]; then
    fail "$g still tells the reader the pre-polish copy is kept at the retired sibling path. /wp-polish writes demo/.prepolish/<source-filename>; a demo/*.html sibling is the phantom-page hazard defect 1 removed, and the path does not exist to restore from: $stale"
  fi
done

# ---------------------------------------------------------------------------
# 9. ...and the two files that describe the backup to a user must still describe
#    it. A negative sweep alone is satisfied by deleting the sentence, which
#    leaves /wp-init's generated CLAUDE.md silent about where the unpolished copy
#    went — the same reader, no worse informed by a wrong path than by none.
#
#    Both regions degrade to the whole file when their anchor is renamed. A gate
#    that fails on a heading rename protects nothing; it gets muted.
# ---------------------------------------------------------------------------
rsec=$(awk '/^### /{ if (inr) exit; if (tolower($0) ~ /polish/) inr = 1 } inr { print }' README.md \
       | drop_headings | flatten)
[ -n "$rsec" ] || rsec=$(drop_headings < README.md | flatten)
sentences "$rsec" 'demo/.prepolish/' | grep -Eqi "$SAVE" \
  || fail "README.md's /wp-polish section does not say the unpolished copy is kept in demo/.prepolish/ — this is the only place a reader learns the polished page is recoverable at all"

. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; fi_=$EXPANDED
test -f "$fi_" || fail "$fi_ missing"

# 9a. the block /wp-init writes into the generated project's .claude/CLAUDE.md.
idemo=$(awk '/^## Demo$/{ inr = 1 } inr { print } inr && /^```$/ { exit }' "$fi_")
[ -n "$idemo" ] || idemo=$(cat "$fi_")
printf '%s' "$idemo" | grep -qF 'demo/.prepolish/' \
  || fail "the '## Demo' block $fi_ writes into the generated project's .claude/CLAUDE.md does not name demo/.prepolish/. That file is the first thing every agent in a user's project reads, so a wrong or missing backup path there is inherited by every later command"

# 9b. the terminal summary /wp-init prints for a demo-first project.
isum=$(awk '/^=== Project Initialized \(from existing demo\) ===/,/^Next step:/' "$fi_")
[ -n "$isum" ] || isum=$(cat "$fi_")
printf '%s' "$isum" | grep -qF 'Next step:' \
  || fail "$fi_'s demo-first summary block never closed on its 'Next step:' line; the awk range ran to EOF and the assertion below would degrade to a file-wide grep"
printf '%s' "$isum" | grep -qF 'demo/.prepolish/' \
  || fail "$fi_'s demo-first summary does not name demo/.prepolish/ — it is printed straight after /wp-init has run /wp-polish, and is where the user is told what to restore from"

echo PASS
