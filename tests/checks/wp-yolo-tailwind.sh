#!/usr/bin/env bash
# /wp-yolo reads Template: in step 1 but historically dropped it. It must now
# convert the demo IN PLACE (with a backup) in Step 2.6 and route every
# downstream dispatch by template.
#
# Round 2 rewrite. The previous version of this file still printed PASS under
# four mutations that invert its meaning:
#   1. re-pointing downstream back at the ORIGINAL, unconverted demo,
#   2. flipping the skip gate to "skip when template == tailwind",
#   3. flipping the routing notes so `basic` gets the Tailwind agent,
#   4. moving both routing notes out of Step 4 to the top of the file.
# The cause was the same each time: assertions that only proved a *word* was
# present somewhere in the file, never that a *claim* pointed the right way in
# the right place. Every assertion below is anchored on the direction of the
# claim and scoped to the region that has to carry it.
#
# Round 3. Four assertions in the round-2 file still gated nothing:
#   - the backup guard matched its own inversion ("only if ... already exists"),
#   - the --css assertion gated the phrase "the converted demo page" and so
#     survived re-pointing --css at the unconverted backup,
#   - the s26/s55 awk ranges had no closure proof, so renaming a heading
#     silently reopened them to EOF,
#   - and two ERE patterns matched the markdown arrow with a bare `.`, which
#     made the whole file FAIL under LC_ALL=C.
# Direction and literal paths from here on; grep -F wherever a fixed string will
# do, so the byte/character distinction cannot come back.
set -euo pipefail
f=commands/wp-yolo.md
t=commands/wp-tailwindify.md
# agents/wp-tailwind.md is here for exactly one assertion, and it is not a
# digression: Step 2.6's skip rule is "utilities and no project stylesheet", and
# that rule only terminates because the CONVERSION removes the project
# stylesheet link. If the agent keeps the link, every converted page keeps
# plain-CSS evidence and re-converts on every later run.
a=agents/wp-tailwind.md

fail() { echo "FAIL: $1"; exit 1; }

test -f "$f" || fail "$f missing"
test -f "$t" || fail "$t missing"
test -f "$a" || fail "$a missing"

# ---------------------------------------------------------------------------
# Regions. A file-wide grep is what let mutation 4 pass: the routing notes
# belong to the two section-walk sites inside Step 4, and Step 4 ends at
# "## Step 4.5: Font carry" — not at end of file, or the scoping is fiction.
# ---------------------------------------------------------------------------
s26=$(awk '/^## Step 2\.6/,/^## Step 3:/' "$f")
s3=$(awk '/^## Step 3:/,/^## Step 4:/' "$f")
s4=$(awk '/^## Step 4:/,/^## Step 4\.5/' "$f")
s55=$(awk '/^## Step 5\.5/,/^## Step 6:/' "$f")
[ -n "$s26" ] || fail "wp-yolo has no top-level Step 2.6 demo-conversion phase"
[ -n "$s3" ]  || fail "wp-yolo has no Step 3 checkpoint region delimited by Step 4"
[ -n "$s4" ]  || fail "wp-yolo has no Step 4 build region delimited by Step 4.5"
[ -n "$s55" ] || fail "wp-yolo has no Step 5.5 demo-parity-gate region"
# If a terminator heading is ever renamed, awk's range runs to EOF and every
# "scoped" assertion below silently degrades back to a file-wide grep. That is
# not hypothetical: with s26 open to EOF, its assertions become satisfiable from
# Step 5.5, which also mentions the backup path and "item 3". Prove every range
# actually closed on the heading it claims to close on.
printf '%s\n' "$s26" | tail -1 | grep -q '^## Step 3:' \
  || fail "the Step 2.6 region is not terminated by a '## Step 3:' heading — the Step 2.6 assertions would silently become file-wide and be satisfiable from Step 5.5"
printf '%s\n' "$s3" | tail -1 | grep -q '^## Step 4:' \
  || fail "the Step 3 region is not terminated by a '## Step 4:' heading — the abort-wording assertions would silently become file-wide"
printf '%s\n' "$s4" | tail -1 | grep -q '^## Step 4\.5' \
  || fail "the Step 4 region is not terminated by a '## Step 4.5' heading — the section-walk assertions would silently become file-wide"
printf '%s\n' "$s55" | tail -1 | grep -q '^## Step 6:' \
  || fail "the Step 5.5 region is not terminated by a '## Step 6:' heading — the Step 5.5 assertions would silently become file-wide"

# Blockquote notes and list bullets wrap across lines, so a single sentence is
# not greppable line-by-line. Flatten each region to one line first.
# Strip only the leading blockquote marker (line-wise) — a global s/>//g would
# also eat the `>` in `demo/.original/<slug>.html` and in `<style>`.
flat() { printf '%s' "$1" | sed 's/^[[:space:]]*>[[:space:]]\?//' | tr '\n' ' ' | sed 's/  */ /g'; }

# `bullet <raw-region> <label>` prints the ONE markdown list item of <raw-region>
# whose bullet line contains <label> — that line, its wrapped continuation lines
# and any nested sub-bullets, and nothing else — and exits 1 when no bullet
# carries the label.
#
# Scoping an assertion to one bullet's own text is what makes it DIRECTED: a
# clause moved from the plain-CSS bullet into the Tailwind-evidence bullet, which
# is exactly the inversion of this rule, leaves the scope and fails, where a
# region-wide grep for the same clause would not notice. That property is the
# reason this helper exists and it is unchanged.
#
# What changed is where a bullet is judged to END. The previous helper ran from
# one bullet's label to the NEXT bullet's label and, when that terminator was
# absent, silently ran on to the end of the region — the same defect the four awk
# ranges above carry an explicit closure proof against, in a helper that had
# none. Two ordinary correct edits tripped it, both exiting 1 with a diagnosis
# that was the opposite of what the file said:
#   - renaming item 2's label ("2. **Back up, per page.**" → "2. **Preserve the
#     original, per page.**") took away the Ambiguous bullet's terminator, so
#     that bullet swallowed item 4's "skip it forever" and the check reported
#     "Step 2.6 skips on ambiguous input";
#   - reordering the last two bullets (Ambiguous before Skip-only), which is
#     semantically identical, took away the Skip-only bullet's terminator and
#     produced the same false message.
# A list item does not need a sibling to know where it ends. Markdown says where:
# at the next item at its own level, at the blank line that closes the list, or at
# the first line dedented out of it. None of those is a neighbouring bullet's
# wording, so neither edit above can move it.
bullet() { # <raw-region> <label>
  printf '%s\n' "$1" | awk -v lab="$2" '
  {
    line = $0
    m = match(line, /[^[:space:]]/)
    ind = (m ? m - 1 : -1)                      # -1 = blank or whitespace-only
  }
  ind < 0 { grab = 0; next }                    # blank line closes the item
  line ~ /^[[:space:]]*- / {
    if (grab && ind > bind) { print line; next }   # nested sub-bullet: content
    if (index(line, lab) > 0) {                    # this is our item
      grab = 1; found = 1; bind = ind; print line; next
    }
    grab = 0; next                                 # a sibling bullet ends it
  }
  grab && ind > bind { print line; next }       # wrapped continuation line
  { grab = 0 }                                  # anything dedented ends it
  END { if (!found) exit 1 }
  '
}

# Closure proof for each extracted bullet, in the shape of the awk-range proofs
# above. `bullet` cannot run past the list by construction, but that is a claim to
# hold in place, not to trust: it is the claim whose absence made the previous
# helper report "Step 2.6 skips on ambiguous input" over a renamed heading.
#
# The proof is structural, on the raw lines, and deliberately says nothing about
# wording: an overrun bullet contains a second list marker at its own indent, or a
# line from the numbered step list underneath. Keying it on a neighbour's LABEL
# instead would fire on an ordinary cross-reference ("unlike **Skip only**, ..."),
# which is the false-fail class this round exists to remove.
bullet_closed() { # <own-label> <raw-bullet-text>
  local self=$1 raw=$2 counts sib num
  counts=$(printf '%s\n' "$raw" | awk '
    { m = match($0, /[^[:space:]]/); ind = (m ? m - 1 : -1) }
    NR == 1 { bind = ind; next }
    ind == bind && /^[[:space:]]*- / { sib++ }
    /^[[:space:]]*[0-9]+\. / { num++ }
    END { print (sib + 0) " " (num + 0) }
  ')
  sib=${counts% *}; num=${counts#* }
  [ "$sib" -eq 0 ] \
    || fail "Step 2.6's \"$self\" bullet is not closed — it swallowed $sib sibling bullet(s) at its own indent. Every assertion scoped to this bullet is then satisfiable from a neighbouring one, which is how a clause moved between bullets stops being caught."
  [ "$num" -eq 0 ] \
    || fail "Step 2.6's \"$self\" bullet is not closed — it ran on past the end of the bullet list into the numbered step list ($num numbered item(s) inside it). The detect assertions would then be satisfiable from items 2-6, which is how renaming an unrelated step's label used to make this check report the opposite of what the file said."
  return 0
}

f26=$(flat "$s26")
f3=$(flat "$s3")
f4=$(flat "$s4")
f55=$(flat "$s55")

# ---------------------------------------------------------------------------
# Sentence windows.
#
# Round 4 shipped two heuristic negatives with no negation awareness, and both
# fire on the obvious correct edit: an explicit prohibition. "Never pass
# `demo/.original/<slug>.html` as the `--css` source" is this check's own
# contract written into the file it guards, and it exited 1 with "a --css source
# line ... resolves to demo/.original/" — which is not what the line says. A gate
# that fails on work that strengthens the contract it defends gets muted, and
# muting this file silences ~50 assertions. Treat that as exactly as serious as a
# hollow assertion.
#
# `sentences <flat-text> <needle>` prints one line per occurrence of <needle>:
# the sentence it sits in, bounded by ". " on either side and capped at 240
# characters each way so a stretch without sentence punctuation cannot pull in
# the whole region. The sentence is the right window: a wider one borrows the
# "never" from the sentence before and would suppress a genuine bypass sitting
# next to a correct prohibition.
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

# A plain negation. Kept deliberately small: every token here is a word that
# reverses the claim it sits in front of, so widening it later is how the gate
# goes hollow. "instead of"/"rather than" are NOT in it — they reverse a choice
# of object, not a claim, and the round-1 wording this file exists to ban
# ("... detects and skips instead of converting twice") contains one.
NEGATION="(^|[^a-zA-Z])(not|never|no|nor|cannot|neither)([^a-zA-Z]|\$)|n't"

# `undirected <flat-text> <literal-needle> <lowercase-ERE>` prints every sentence
# of <flat-text> that contains <literal-needle> and in which <lowercase-ERE>
# matches at a position NOT governed by a negation in front of it. Silence means
# the text is clean.
#
# Two negatives in this file — "the plain-CSS bullet directs a SKIP" and "Step 2.6
# skips on ambiguous input" — were raw greps with no negation awareness, in a file
# that documents this machinery a few lines above and already uses it in
# no_rerun_safe(). Both fire on the obvious strengthening edit:
#     Never skip the page because the only CSS it carries arrives through a link.
#     Never leave the file alone just because you are unsure.
# and both then report the exact opposite of what the sentence says. A gate that
# fails on work that strengthens the contract it defends gets muted, and muting
# this file silences ~50 assertions.
#
# The negation must PRECEDE the matched verb — that is what makes it govern the
# claim rather than merely share a sentence with it. Anywhere-in-sentence
# suppression is not equivalent and is not safe: it would excuse a wording that
# ends "... detects and skips instead of converting twice", which is also why
# `instead of`/`rather than` are kept out of $NEGATION.
#
# Sentence-bounded is not tight enough either, and this was proven, not guessed.
# The ambiguous bullet's own inversion reads "... a page you cannot classify with
# confidence: skip it." — a straight instruction to skip, which a sentence-wide
# window excuses because "cannot" appears earlier in the same sentence governing
# "classify". So the window is the CLAUSE: everything after the last `,` `;` `:`
# or em-dash before the match. "Never skip the page ..." keeps its negation;
# "... cannot classify with confidence: skip it" loses the one that was never
# about skipping.
#
# The ERE is matched against a lower-cased copy, so pass it in lower case; `\b` is
# deliberately absent because awk does not have it (in gawk `\b` is a backspace),
# so word edges are written as [^a-z] classes.
#
# The optional 4th argument adds alternatives to $NEGATION for THAT CALL ONLY.
# $NEGATION itself is shared by every negative in this file and by
# no_rerun_safe(), and it is not the place to put a token one call happens to
# need: "nothing" is a genuine negation in front of "reads the unconverted demo",
# but putting it in the shared pattern would also excuse "Nothing else is needed;
# a re-run is safe." — the exact claim no_rerun_safe() exists to catch, since that
# helper takes everything before the word "safe" as its window. Per-call, the
# extension is auditable at the call site; shared, it is invisible.
undirected() { # <flat-text> <literal-needle> <lowercase-ERE> [<extra-negation-ERE>]
  local text=$1 needle=$2 pat=$3 extra=${4:-} neg=$NEGATION sent
  if [ -n "$extra" ]; then neg="$neg|$extra"; fi
  while IFS= read -r sent; do
    [ -n "$sent" ] || continue
    printf '%s' "$sent" | awk -v pat="$pat" -v neg="$neg" '
    {
      low = tolower($0); s = low; off = 0
      while (match(s, pat)) {
        # RSTART/RLENGTH belong to THIS match and the clause loop below calls
        # match() again, which overwrites both — including on a failed match,
        # where gawk sets RSTART=0 and RLENGTH=-1. Reading them afterwards walked
        # the cursor BACKWARDS, so the second pass looked at a truncated prefix
        # ("nev"), found no negation in it and reported a prohibition as a
        # directive. Take a copy before anything else can match.
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

# "A re-run is safe" — banned in EVERY region that can carry it.
#
# Round 4 removed this claim from Step 3 and wrote a check message about it, but
# scoped the negative to $f3, so the same claim 50 lines earlier in Step 2.6
# ("This is also what makes a re-run safe") survived. An executing orchestrator
# reads Step 2.6 first, and it is the more specific statement about the
# conversion step, so the wrong one wins. The claim is false for the RUN: Step 2
# dispatches wp-normalize unconditionally and empties cssRules/fonts/backgrounds
# before Step 2.6 is reached a second time. It is true for the conversion STEP,
# which is why this is negation-aware rather than a ban on the word "safe" — the
# correct text has to be able to say "it does not make a re-run safe".
#
# The negation must sit BEFORE the word "safe" in the same sentence, i.e. it must
# actually govern the claim. Anything looser re-admits the original wording,
# whose trailing "instead of converting twice" would otherwise read as a
# negation.
no_rerun_safe() { # <region-label> <flattened-region>
  local label=$1 text=$2 sent claim
  while IFS= read -r sent; do
    [ -n "$sent" ] || continue
    printf '%s' "$sent" | grep -Eqi 're-?run|second [^ ]{0,14} ?pass|later run|resume' || continue
    claim=${sent%%safe*}
    if printf '%s' "$claim" | grep -Eqi "$NEGATION"; then
      continue
    fi
    fail "$label claims a re-run is safe. Only the conversion STEP is idempotent: by the time Step 2.6 runs again, Step 2 has re-dispatched wp-normalize unconditionally and emptied the manifest's cssRules/fonts/backgrounds, so the build degrades silently instead of failing. Say what is idempotent, and negate the rest: $sent"
  done <<< "$(sentences "$text" 'safe')"
}

# ---------------------------------------------------------------------------
# Step 2.6 — the conversion phase itself
# ---------------------------------------------------------------------------

# The gate must skip on `basic`, i.e. RUN on `tailwind`. Asserting the literal
# condition, not "some skip-ish word appears": the old `grep -q skip` was
# satisfied by the inverted gate and by 12 unrelated uses of the word.
printf '%s' "$f26" | grep -qF 'Skip this step entirely when `template == basic`' \
  || fail 'Step 2.6 does not gate on "Skip this step entirely when `template == basic`" — tailwind is the path that must convert'
if printf '%s' "$f26" | grep -qF 'Skip this step entirely when `template == tailwind`'; then
  fail "Step 2.6 skips itself on the tailwind path — that is the only path that needs conversion"
fi

printf '%s' "$f26" | grep -qF '/wp-tailwindify' \
  || fail "Step 2.6 does not run /wp-tailwindify on the tailwind path"

# Multi-page demos are wp-yolo's premise (item 6 walks every inner page), so
# the conversion cannot be a single hardcoded home-page run.
printf '%s' "$f26" | grep -qF '**every** page in the manifest' \
  || fail "Step 2.6 does not loop the conversion over every page in the manifest"

# In-place conversion contract: a backup under a fixed name, and an output path
# that is the demo page itself. Without the second half, nothing downstream
# reads the converted markup — the Task 7 defect.
#
# The backup lives in `demo/.original/`, NOT beside the page as
# `demo/<slug>.original.html`. `/wp-seed` (Step 5) maps every `demo/*.html` to a
# WP Page named after the file, so a sibling backup seeds a phantom page per
# demo page out of unconverted markup. A dot-prefixed subdirectory is outside
# `demo/*.html`, so it immunises every glob in the repo at once instead of
# needing an exclusion at each call site.
printf '%s' "$f26" | grep -qF 'demo/.original/<slug>.html' \
  || fail "Step 2.6 does not name the backup copy demo/.original/<slug>.html"
if printf '%s' "$f26" | grep -qF 'copy `demo/<slug>.html` to `demo/<slug>.original.html`'; then
  fail "Step 2.6 backs up to demo/<slug>.original.html — a sibling of demo/*.html, which /wp-seed turns into a phantom WP Page seeded from unconverted markup"
fi
printf '%s' "$f26" | grep -qF '/wp-tailwindify demo/<slug>.html --out demo/<slug>.html' \
  || fail "Step 2.6 does not convert in place — /wp-tailwindify's output path must be the demo page itself"

# The backup guard has to be asserted in its correct DIRECTION. The old pattern
# ('only if .{0,80}\.original\.html.{0,80}already exist') matched the inversion
# — "only if ... already exists" — just as happily, and under that inversion no
# backup is ever taken on the first run and the pristine original is overwritten
# with converted markup on every later one.
printf '%s' "$f26" | grep -qF 'only if `demo/.original/<slug>.html` does not already exist' \
  || fail 'Step 2.6 does not guard the backup with the literal "only if `demo/.original/<slug>.html` does not already exist"'
# Negative, directed, and scoped to GUARD sentences only. The previous version
# of this assertion required every "already exist" anywhere in Step 2.6 to carry
# a negation, which over-reached: an ordinary, correct sentence such as "If
# `demo/.original/` already exists from an earlier run, reuse it." made the check
# exit 1 with a message that was actively wrong about what had happened. A gate
# that fails spuriously gets muted, and muting this file silences ~40 assertions.
#
# What actually has to be directed is the guard: an "only if ... already exist"
# clause whose "already exist" is not immediately preceded by a negation is the
# inverted guard. Scanned per occurrence (not with one greedy regex) so a correct
# guard sitting next to an inverted one cannot mask it.
guard_bad=$(printf '%s' "$f26" | awk '
{
  s = $0
  while ((i = index(s, "already exist")) > 0) {
    start = (i > 80) ? i - 80 : 1
    pre = substr(s, start, i - start)
    if (pre ~ /only if/ && pre !~ /not[[:space:]]*$/) {
      print substr(s, start, i - start + 13)
      bad = 1
    }
    s = substr(s, i + 13)
  }
  exit bad ? 1 : 0
}') || fail "Step 2.6 has an \"only if ... already exist\" guard with no negation — the backup guard is inverted, so nothing is backed up on the first run and the pristine original is destroyed on every later one: $guard_bad"

# A truncated in-place write is otherwise unrecoverable: item 1's detect step
# reads the wreckage, finds no <style> block, calls the page already
# Tailwind-native and skips it forever. Verification must restore the backup
# over the demo page — in that direction, never the reverse.
printf '%s' "$f26" | grep -qF 'restore `demo/<slug>.html` from `demo/.original/<slug>.html`' \
  || fail "Step 2.6 does not restore the demo page from its backup when /wp-tailwindify's verification fails — a truncated page would be treated as already-converted forever"
if printf '%s' "$f26" | grep -qF 'restore `demo/.original/<slug>.html` from `demo/<slug>.html`'; then
  fail "Step 2.6's restore runs backwards — it overwrites the pristine backup with the failed conversion"
fi
printf '%s' "$f26" | grep -qiF 'report the page as unconverted' \
  || fail "Step 2.6 does not report a page whose conversion failed verification as unconverted"
# ...and the verification it reads has to include the third check (see $t's Step 4
# below). Without it a page that lost its stylesheet and gained invented utilities
# passes, is left at demo/<slug>.html, and is never restored from demo/.original/.
printf '%s' "$f26" | grep -qF 'no project-local stylesheet `<link>` remaining' \
  || fail "Step 2.6's verify item does not include /wp-tailwindify's third verification check — that no project-local stylesheet <link> remains on the converted page"

# The re-point item must say downstream reads the CONVERTED markup, and must
# name the readers it covers — items 3 and 4 (header/footer) were missed once
# already because the old wording scoped re-pointing to items 5 and 6 only.
printf '%s' "$f26" | grep -qF 'every later reader picks up Tailwind-native markup' \
  || fail "Step 2.6 does not state that every later reader picks up the converted markup"
# item 2 is /wp-cpt: it reads demo/index.html via --from-demo and runs at Step 4
# item 2, i.e. after Step 2.6. It is a CSS-emitting reader like the rest.
for item in 'item 2' 'item 3' 'item 4' 'item 5' 'item 6'; do
  printf '%s' "$f26" | grep -qF "$item" \
    || fail "Step 2.6's re-point item does not account for $item as a reader of the converted demo"
done
printf '%s' "$f26" | grep -Eq 'never[[:space:]]*a build source' \
  || fail "Step 2.6 does not state that the .original.html backup is never a build source"
# Negation-aware (see `undirected` above), for exactly the reason the two
# evidence negatives are. This was the last raw negative left in the file, and
# the obvious strengthening edit tripped it: "No downstream builder reads the
# unconverted demo." is this assertion's own contract written into the file it
# guards, and the grep exited 1 saying the file claimed the opposite of what that
# sentence says. Matched against a lower-cased copy so the old `-i` behaviour is
# unchanged, with `demo` as the sentence needle because every shape of the claim
# ends in that word.
f26l=$(printf '%s' "$f26" | tr 'A-Z' 'a-z')
reads_orig=$(undirected "$f26l" 'demo' 'read[s]?( from)?[^.]{0,40}(original|unconverted|plain-css) demo' \
                          '(^|[^a-z])(nothing|none)([^a-z]|$)')
if [ -n "$reads_orig" ]; then
  fail "Step 2.6 claims a later reader still reads the original/unconverted demo: $reads_orig"
fi

# The already-tailwind demo must be detected, not converted twice. Matched on
# the report string itself — an 'already tailwind|no <style>|skip' alternation
# hit the bare word "skip" 12 times in unrelated steps and so gated nothing.
printf '%s' "$f26" | grep -qF 'conversion skipped' \
  || fail "Step 2.6 has no skip path for an already-converted demo"

# ---------------------------------------------------------------------------
# The detect RULE itself. This is the one defect on this branch that was a
# design defect rather than a check defect: item 1 used to read
#
#     If it has no `<style>` block and no static `style="` attribute, it is
#     already Tailwind-native
#
# which treats the absence of ONE CSS delivery mechanism as proof of
# Tailwind-nativeness. A plain-CSS demo that keeps its rules in an external
# stylesheet has neither marker, and that is the shape of every demo fixture in
# this repo. The gate meant to prevent the branch's original bug reproduced it:
# every page was reported `demo already tailwind-native — conversion skipped`,
# nothing was converted, the section walk transcribed the manifest's plain-CSS
# cssRules, and the theme shipped with BEM CSS and no utility classes — while
# reporting success.
#
# So the assertions below gate the SHAPE of the replacement rule, not one
# sentence of it: plain-CSS evidence must include a linked stylesheet and must
# resolve to "convert"; the skip must require POSITIVE Tailwind evidence plus the
# absence of plain-CSS evidence; ambiguity must convert. Each is scoped to its own
# bullet, so moving a clause between bullets fails rather than passing.
# ---------------------------------------------------------------------------
#
# The four bullet labels below are frozen exact strings, deliberately. They are
# the rule's own structure — the four cases it decides between — and each FAIL
# message names the bullet it wants back, so a rename that is genuinely intended
# tells the author exactly what to update. Flattening cannot help here: a label is
# what identifies the bullet, so there is nothing to match it by if it is gone.
plain_raw=$(bullet "$s26" '**Plain-CSS evidence') \
  || fail "Step 2.6's detect step has no \"Plain-CSS evidence\" bullet — the rule must enumerate what counts as evidence of plain CSS, or it is back to testing for the absence of a <style> block"
tw_raw=$(bullet "$s26" '**Tailwind evidence') \
  || fail "Step 2.6's detect step has no \"Tailwind evidence\" bullet — a skip needs positive evidence of Tailwind-nativeness to rest on"
skip_raw=$(bullet "$s26" '**Skip only') \
  || fail "Step 2.6's detect step has no \"Skip only ...\" bullet stating the condition under which a page is left unconverted"
amb_raw=$(bullet "$s26" '**Ambiguous') \
  || fail "Step 2.6's detect step has no \"Ambiguous\" bullet — the tie has to be broken explicitly, and towards converting"
plain_ev=$(flat "$plain_raw")
tw_ev=$(flat "$tw_raw")
skip_ev=$(flat "$skip_raw")
amb_ev=$(flat "$amb_raw")
bullet_closed '**Plain-CSS evidence' "$plain_raw"
bullet_closed '**Tailwind evidence'  "$tw_raw"
bullet_closed '**Skip only'          "$skip_raw"
bullet_closed '**Ambiguous'          "$amb_raw"

# The other half of the closure proof, and the half that actually caught a broken
# `bullet`. Counting list markers alone is not enough: a helper that stops
# printing sibling MARKERS but keeps printing their continuation lines overruns
# without ever showing a second marker. Four disjoint bullets share no line; an
# overrun shows up immediately as a line appearing in two of them.
dup=$(printf '%s\n%s\n%s\n%s\n' "$plain_raw" "$tw_raw" "$skip_raw" "$amb_raw" \
      | grep -v '^[[:space:]]*$' | sort | uniq -d)
[ -z "$dup" ] \
  || fail "Step 2.6's four detect bullets are not disjoint — the same line appears in more than one of them, so a bullet ran past its own end and every assertion scoped to it is satisfiable from a neighbour: $(printf '%s' "$dup" | head -1)"

# A bullet's bold LABEL is not its instruction, and an assertion that a bullet
# resolves a certain way must not be satisfiable by the label alone. Proven, not
# assumed: inverting the ambiguous bullet's instruction to "... a page you cannot
# classify with confidence: skip it." left `\bconverts\b` matching its own label,
# "**Ambiguous input converts.**", so the decision assertion below still passed on
# a bullet that said the opposite. The label stays gated (bullet() finds the item
# by it); the decision is read from the body.
body() { printf '%s' "$1" | sed 's/^ *- *\*\*[^*]*\*\* *//'; }
amb_body=$(body "$amb_ev")
[ "$amb_body" != "$amb_ev" ] \
  || fail "Step 2.6's ambiguous-input bullet has no bold label to strip — the decision assertions below would be read from the label instead of from the instruction"

# 1. A linked stylesheet is plain-CSS evidence. This is the whole defect: without
#    it, every fixture in tests/fixtures/ (no <style>, no style=, rules in
#    assets/styles.css) classifies as already Tailwind-native.
#    The literal stops at the closing quote, not at the tag's `>`: writing the tag
#    the way a real page carries it — `<link rel="stylesheet" href="assets/styles.css">`
#    — is strictly an improvement and is what the rule is about, and the `>` form
#    exited 1 on it here, at the MUST-remove assertion and at $t's validate list.
printf '%s' "$plain_ev" | grep -qF '<link rel="stylesheet"' \
  || fail 'Step 2.6 does not count a `<link rel="stylesheet">` as plain-CSS evidence. A demo that keeps its rules in an external stylesheet has no <style> block and no style=" attribute, so under a rule that only tests for those it is silently declared already Tailwind-native and never converted — which is the original defect this branch exists to fix, reproduced at the gate meant to prevent it.'
# ...and the bullet has to resolve to CONVERT. Naming the evidence and then
# skipping on it would satisfy the assertion above and change nothing.
printf '%s' "$plain_ev" | grep -qiF 'convert' \
  || fail "Step 2.6's plain-CSS evidence bullet never says what plain-CSS evidence means for the page: it means convert"
# Negation-aware (see `undirected` above): "Never skip the page because the only
# CSS it carries arrives through a link." is a legitimate strengthening of this
# bullet and used to exit 1 here saying the bullet directed a skip.
plain_skip=$(undirected "$plain_ev" 'skip' 'means skip|(^|[^a-z])skip (it|the page|that page|them)([^a-z]|$)')
plain_skip="$plain_skip$(undirected "$plain_ev" 'means it is' 'means it is (already )?tailwind')"
if [ -n "$plain_skip" ]; then
  fail "Step 2.6's plain-CSS evidence bullet directs a SKIP — plain-CSS evidence is the reason to convert, not the reason to skip: $plain_skip"
fi

# 2. Tailwind evidence must be defined POSITIVELY, by utilities. Defining it as
#    "no <style> block" is the defect wearing the new rule's clothes.
printf '%s' "$tw_ev" | grep -qi 'utilit' \
  || fail "Step 2.6's Tailwind-evidence bullet does not define Tailwind-nativeness by the presence of utility classes — absence of inline CSS is not evidence of anything"
if printf '%s' "$tw_ev" | grep -qF 'no `<style>` block'; then
  fail "Step 2.6 defines Tailwind evidence as the ABSENCE of a <style> block. That is the original heuristic: a plain-CSS demo with an external stylesheet satisfies it and is skipped."
fi

# 3. The skip needs BOTH halves — positive Tailwind evidence AND no plain-CSS
#    evidence — and the skip ACTION has to sit in the same bullet as its
#    condition, so the two cannot drift apart.
printf '%s' "$skip_ev" | grep -qF 'Tailwind evidence' \
  || fail "Step 2.6's skip bullet does not require positive Tailwind evidence — a skip on anything less is a skip on ignorance"
printf '%s' "$skip_ev" | grep -qF 'no plain-CSS evidence' \
  || fail "Step 2.6's skip bullet does not require the ABSENCE of plain-CSS evidence — a page with both utilities and a project stylesheet must still be converted"
printf '%s' "$skip_ev" | grep -qF 'conversion skipped' \
  || fail "Step 2.6's skip condition and the skip it authorises are in different bullets — the report line \`demo already tailwind-native — conversion skipped\` must be emitted by the bullet that states the condition, or the two drift apart"

# 4. Ambiguity converts, and the tie is broken in that direction on purpose.
# A bare `grep -F convert` here would be subsumed by the bullet's own
# explanatory prose ("Converting a page that was already Tailwind-native costs
# ..."), which survives inverting the instruction. Require the verb in the
# DECISION position instead.
printf '%s' "$amb_body" | grep -Eqi '\bconverts\b|\bconvert (it|them|the page|that page)\b' \
  || fail "Step 2.6's ambiguous-input bullet does not resolve to convert"
# Negation-aware for the same reason: "Never leave the file alone just because you
# are unsure." says what this assertion wants and used to exit 1 saying the
# opposite.
amb_skip=$(undirected "$amb_ev" 'skip' '(^|[^a-z])skip (it|the page|that page|them)([^a-z]|$)')
amb_skip="$amb_skip$(undirected "$amb_ev" 'alone' 'leave (it|the file|the page) alone')"
if [ -n "$amb_skip" ]; then
  fail "Step 2.6 skips on ambiguous input. The two errors are not symmetrical: a redundant conversion costs one pass over markup already in the target form, a wrong skip voids the whole tailwind path and reports success while doing it: $amb_skip"
fi
# `conver` and not `convert`: "Bias the tie toward conversion" is the same claim
# and used to exit 1 here. Scoped to the ambiguous bullet, and the verb list is
# short: a region-wide version with `resolve` in it was silently satisfied by
# item 5's "all resolve to the converted file", so the inverted tie-break
# ("bias every tie towards skipping") still printed PASS. Subsumption, exactly
# the failure mode this file keeps re-learning.
printf '%s' "$amb_ev" | grep -Eqi '(bias|break|breaks) [^.]{0,40}conver|in doubt[^.]{0,24}conver' \
  || fail "Step 2.6's ambiguous-input bullet does not state which way to break a tie. It must break towards converting."

# 5. Literal backstop against the exact sentence this task removed. The bullet
#    assertions above already fail if the rule is replaced wholesale; this
#    catches the other shape of regression — the old sentence being ADDED BACK
#    alongside the new bullets, leaving the step self-contradictory with the
#    wrong half stated first.
if printf '%s' "$f26" | grep -qF 'no `<style>` block and no static `style="` attribute, it is already Tailwind-native'; then
  fail "Step 2.6's detect step carries the original heuristic again: absence of inline CSS is not proof of Tailwind-nativeness, and every demo fixture in this repo is the counter-example"
fi

# 6. Keep a plain-CSS-shaped demo in the repo. This is NOT a test of the rule and
#    must not be read as one: Step 2.6 opens `demo/<slug>.html`, the file
#    `wp-normalize` emits, and never opens tests/fixtures/** at all. All five
#    assertions below can hold while the rule above is arbitrarily wrong.
#    What they do buy is that the repo keeps at least one demo in the shape the
#    old heuristic mis-classified — no <style>, no style=", every rule in
#    assets/styles.css, BEM class names — so the case stays available to anyone
#    reading the rule or exercising the converter by hand. If the fixture drifts
#    to some other shape, that is worth knowing; it is not evidence about the rule.
fx=tests/fixtures/demo-acme/index.html
test -f "$fx" || fail "the plain-CSS worked example $fx is gone. Re-point this assertion at a demo fixture that still keeps its rules in an external stylesheet — without one, nothing here checks the rule against a real page."
if grep -q '<style' "$fx"; then
  fail "$fx now carries a <style> block, so it no longer exercises the case the old heuristic got wrong (external stylesheet, zero inline CSS). Re-point this assertion at a fixture that still does."
fi
if grep -q 'style="' "$fx"; then
  fail "$fx now carries a static style= attribute, so it no longer exercises the case the old heuristic got wrong (external stylesheet, zero inline CSS). Re-point this assertion at a fixture that still does."
fi
grep -q '<link rel="stylesheet"' "$fx" \
  || fail "$fx no longer links a project stylesheet, so the detect rule's plain-CSS evidence has no worked example in this repo"
grep -q 'site-header__' "$fx" \
  || fail "$fx no longer carries BEM class names, so it no longer demonstrates a page with plain-CSS evidence and no Tailwind evidence"

# 7. The premise the skip rests on, in the agent that has to make it true. The
#    skip terminates only because a converted page carries NO plain-CSS evidence;
#    if the conversion leaves the project stylesheet <link> in the head, every
#    converted page still has plain-CSS evidence and re-converts forever.
# The two lists, taken as the bullet block each heading owns: from the heading to
# the first line that is neither a bullet nor a bullet continuation. An awk range
# ending on `/^### /` looked tighter than it was — deleting the `###` that was
# supposed to close it just ran the range on to the NEXT `###` heading, so the
# closure proof printed PASS while the region silently grew. A block that ends at
# its own blank line cannot grow at all.
# `**MUST preserve:**` and `**MUST remove:**` stay frozen exact strings, for the
# same reason as the four detect-bullet labels: they are the contract's own
# anchors, nothing else identifies the two lists, and each FAIL message names the
# heading it wants. Re-wrapping cannot move them (they are short and stand alone
# on their line); only a deliberate rename can, and that is a change worth being
# told about.
#
# The continuation pattern used to be `  [^ ]` — exactly two spaces. A four-space
# continuation indent is valid Markdown and is what a re-wrap of a nested item
# produces; under it the block silently stopped at the first such line and the
# assertion below still printed PASS over the truncated remainder. Any indent now
# counts as a continuation, and the block is required to have ended where it
# claims to: on the blank line that closes the list, not on prose.
bullets() { # <file> <heading-line>
  awk -v h="$2" '
    $0 == h { inb = 1; next }
    inb && /^[[:space:]]*$/ { exit 0 }
    inb && /^(- |[[:space:]]+[^[:space:]])/ { print; next }
    inb { exit 3 }
  ' "$1"
}
rc=0; mustkeep=$(bullets "$a" '**MUST preserve:**') || rc=$?
[ "$rc" -ne 3 ] || fail "$a's MUST preserve list does not end at a blank line — the block ran into prose, so the assertions scoped to it are satisfiable from outside the list"
[ "$rc" -eq 0 ] || fail "$a's MUST preserve list could not be read (bullets exited $rc)"
rc=0; mustrm=$(bullets "$a" '**MUST remove:**') || rc=$?
[ "$rc" -ne 3 ] || fail "$a's MUST remove list does not end at a blank line — the block ran into prose, so the assertions scoped to it are satisfiable from outside the list"
[ "$rc" -eq 0 ] || fail "$a's MUST remove list could not be read (bullets exited $rc)"
[ -n "$mustrm" ] || fail "$a has no '**MUST remove:**' bullet list for the conversion to be held to"
[ -n "$mustkeep" ] || fail "$a has no '**MUST preserve:**' bullet list"
if printf '%s\n' "$mustrm" | grep -q '^#'; then
  fail "$a's MUST remove block swallowed a heading — the assertion below would be satisfiable from outside the list"
fi
printf '%s' "$(flat "$mustrm")" | grep -qF '<link rel="stylesheet"' \
  || fail "$a's MUST remove list does not remove the demo's own project stylesheet <link>. /wp-yolo Step 2.6 skips a page only when it has Tailwind evidence and no plain-CSS evidence, and a linked project stylesheet IS plain-CSS evidence — so a conversion that leaves the link behind makes every converted page re-convert on every later run, and leaves a page that is not actually Tailwind-native."
if printf '%s' "$(flat "$mustkeep")" | grep -qF '<link rel="stylesheet"'; then
  fail "$a preserves the project stylesheet <link> through conversion — the converted page then still carries plain-CSS evidence and is not Tailwind-native. Google Fonts and Tailwind CDN links are the ones that stay."
fi

# 8. ...and the agent has to READ what it is told to delete. The MUST-remove
#    bullet above was added without touching the agent's Input, which listed only
#    inline `<style>` blocks and class patterns, or the dispatch context, which
#    hands over three things: input path, output path, project CLAUDE.md. Nothing
#    opened the linked file. The agent is not sourceless — `wp-normalize` inlines
#    the rules it can match to a section — but the rules that match NO section
#    (`:root` custom properties, resets, `body`, `@font-face`, global `@media`)
#    are not inlined and are reachable only through the link, so dropping the link
#    without reading it silently deletes the demo's design tokens and font
#    loading. That is a regression on the previous behaviour, where the link
#    stayed and the page still rendered.
sIn=$(awk '/^## Input/,/^### Step 2: Map Colors/' "$a")
[ -n "$sIn" ] || fail "$a has no '## Input' region delimited by '### Step 2: Map Colors'"
printf '%s\n' "$sIn" | tail -1 | grep -q '^### Step 2: Map Colors' \
  || fail "$a's Input/Step 1 region is not terminated by its '### Step 2: Map Colors' heading — the source-reading assertions would silently become file-wide and be satisfiable from the MUST-remove list they exist to license"
fIn=$(flat "$sIn")
printf '%s' "$fIn" | grep -qF '<link rel="stylesheet"' \
  || fail "$a's Input/Step 1 never mentions the project stylesheet <link>. Step 4 tells the agent to delete it; if Step 1 never opens it, the rules that live only there — :root custom properties, resets, @font-face, global @media — are deleted with it and nothing replaces them."
printf '%s' "$fIn" | grep -qF 'conversion source exactly like a `<style>` block' \
  || fail "$a's Input/Step 1 does not tell the agent that a linked stylesheet's rules are conversion source exactly like a \`<style>\` block's. Naming the file is not enough — it has to be read AS SOURCE, or the conversion covers only the rules wp-normalize happened to inline."
printf '%s' "$fIn" | grep -qF 'licensed only once you have accounted for its rules' \
  || fail "$a's Input/Step 1 does not tie the MUST-remove licence to having accounted for the linked rules. Removal is only safe after the rules are absorbed; as an unconditional instruction it is a delete."

# ...and that skip path must not be sold as making the RUN safe. See
# no_rerun_safe above: this is the claim round 4 deleted from Step 3 and left
# standing here, where an orchestrator reads it first.
no_rerun_safe "Step 2.6's detect/skip item" "$f26"

# ---------------------------------------------------------------------------
# Step 3 — the abort wording (the other half of the Step 2.6 contract)
#
# Step 3 sits past the s26 terminator, so no Step 2.6 assertion reaches it and
# this text was ungated. It used to claim "re-running is safe because Step 2.6's
# detect step skips a page that is already Tailwind-native", which is false:
# Step 2 dispatches wp-normalize unconditionally with no manifest guard, so a
# later run re-derives cssRules/fonts/backgrounds from the now Tailwind-native
# markup that no longer carries them and quietly empties what Step 4.5's font
# carry and /wp-finalize Layer 1 read. That is a degraded build, not a failing
# one, which is exactly the kind of claim a check has to hold in place.
# ---------------------------------------------------------------------------
printf '%s' "$f3" | grep -qF 'A later `/wp-yolo` run is **not** a resume' \
  || fail "Step 3's abort branch does not state that a later /wp-yolo run is not a resume"
printf '%s' "$f3" | grep -qF 'dispatches `wp-normalize` over the demo folder unconditionally' \
  || fail "Step 3's abort branch does not name the unconditional wp-normalize dispatch that makes a naive re-run degrade the manifest"
printf '%s' "$f3" | grep -qF 'restore `demo/<slug>.html` from `demo/.original/<slug>.html` for every page first' \
  || fail "Step 3's abort branch does not tell the operator to restore the plain-CSS originals before a fresh run"
no_rerun_safe "Step 3's abort branch" "$f3"
if printf '%s' "$f3" | grep -qF 'restore `demo/.original/<slug>.html` from `demo/<slug>.html`'; then
  fail "Step 3's abort branch restores backwards — it would overwrite the pristine originals with the converted pages"
fi

# The abort branch used to end with: "To continue the aborted build instead,
# re-run with `--yolo` only if `demo/.yolo-manifest.json` is still the one Step
# 2.6 ran against and has not been regenerated since."
#
# `--yolo` is defined at Step 1 as "no checkpoint at all". It skips STEP 3 only —
# Step 2 still dispatches wp-normalize and still writes
# demo/.yolo-manifest.json — so that advice IS the unconditional-normalize path
# the paragraph directly above it calls unsafe, and it destroys its own gating
# condition in the act of being followed: normalize regenerates the manifest the
# operator was told to check. There is no resume entrypoint in this command, and
# the file has to say so rather than invent one.
printf '%s' "$f3" | grep -qF 'There is no resume entrypoint in this command' \
  || fail "Step 3's abort branch does not state plainly that /wp-yolo has no resume entrypoint — without that sentence the operator is left to invent one, and the only flag on offer (--yolo) re-runs wp-normalize and regenerates the manifest"
printf '%s' "$f3" | grep -qF 'Step 2 still dispatches `wp-normalize` and still overwrites `demo/.yolo-manifest.json`' \
  || fail "Step 3's abort branch does not say what --yolo actually skips: it suppresses this checkpoint and nothing else, while Step 2 still dispatches wp-normalize and still overwrites demo/.yolo-manifest.json"

# The offer itself, matched by direction. The window runs from a continue/resume
# verb forward to a backticked `--yolo` and may not cross a backtick, so a
# disclaimer that carries its negation between the two ("There is no resume
# entrypoint in this command — not `--yolo`, ...") stays green while the offer
# above does not.
offers=$(printf '%s' "$f3" | grep -oEi '(^|[^a-zA-Z])(continue|continuing|resume|resuming|carry on|pick up)([^a-zA-Z])[^`]{0,80}`--yolo`' || true)
while IFS= read -r offer; do
  [ -n "$offer" ] || continue
  if printf '%s' "$offer" | grep -Eqi "$NEGATION"; then
    continue
  fi
  fail "Step 3's abort branch offers \`--yolo\` as a way to continue or resume the aborted build. It is not one: --yolo skips Step 3 only, Step 2 still dispatches wp-normalize and still regenerates demo/.yolo-manifest.json, so following the advice destroys the condition the advice is gated on. Tell the operator to restore from demo/.original/ and run fresh: $offer"
done <<< "$offers"

# ---------------------------------------------------------------------------
# Step 4 — the two section-walk dispatch sites
# ---------------------------------------------------------------------------

# Backticks, because a bare \b is satisfied by "wp-tailwind-system" (the `-`
# is a word boundary) and would survive deleting every agent reference.
grep -qF '`wp-tailwind`' "$f" \
  || fail "wp-yolo never names the wp-tailwind agent"

# The routing note must land on BOTH section-walk sites (home + inner pages),
# and must land INSIDE Step 4 — hoisting both notes to the top of the file used
# to satisfy the old file-wide count.
n=$(printf '%s\n' "$s4" | grep -c 'Template routing' || true)
[ "$n" -ge 2 ] || fail "found $n 'Template routing' note(s) inside Step 4, expected 2 (home sections + inner pages)"

# Direction, not adjacency: the sentence that hands `tailwind` (never `basic`)
# to the wp-tailwind agent must appear at both sites.
d=$(printf '%s' "$f4" | grep -oF 'is `tailwind`, `/wp-section` dispatches `wp-tailwind` in author mode instead of `wp-css`' | wc -l || true)
[ "$d" -ge 2 ] || fail "found $d correctly-directed routing sentence(s) in Step 4, expected 2 — tailwind must be the value that gets the wp-tailwind agent"
if printf '%s' "$f4" | grep -qF 'is `basic`, `/wp-section` dispatches `wp-tailwind`'; then
  fail "a Step 4 routing note hands the Tailwind agent to template=basic"
fi

# /wp-section takes no template argument — it reads Template: itself
# (commands/wp-section.md, "CSS agent routing"). The old wording told the
# orchestrator to "pass the project's Template: value", which invents a flag
# that does nothing.
p=$(printf '%s' "$f4" | grep -oF 'reads `Template:` from `.claude/CLAUDE.md` itself' | wc -l || true)
[ "$p" -ge 2 ] || fail "found $p note(s) saying /wp-section reads Template: itself, expected 2"
if printf '%s' "$f4" | grep -qiF "Pass the project's \`Template:\` value"; then
  fail "a Step 4 routing note still tells the caller to pass a Template: value /wp-section does not accept"
fi

# --css source is template-dependent: the manifest cssRules were captured from
# the plain-CSS original in Step 2, so they are stale on the tailwind path.
#
# These assertions used grep -E with a bare `.` standing in for the markdown
# arrow. `.` is one character in a UTF-8 locale and one BYTE in C, where the
# 3-byte `→` never matched — so the whole check FAILed under LC_ALL=C, and a
# gate that fails spuriously in CI gets muted, silencing all 30-odd assertions
# in this file. Every pattern below is grep -F (byte-exact, locale-independent)
# or an ERE containing the literal arrow bytes.
printf '%s' "$f4" | grep -qF "\`basic\` → the section's verbatim demo \`cssRules\` from the manifest, which on this path is the source of truth" \
  || fail "Step 4 does not scope the manifest cssRules 'source of truth' claim to template=basic"

# The tailwind --css source must be asserted BY PATH at both section-walk sites.
# The old assertion gated the phrase "the converted demo page", which survived
# re-pointing the source at the unconverted backup and survived deleting the
# "never <backup>" clause outright — precisely the defect class this round
# exists to eliminate.
printf '%s' "$f4" | grep -qF '`tailwind` → the converted demo page itself, `demo/index.html`' \
  || fail "Step 4's home section walk does not point the tailwind --css source at the literal path demo/index.html"
printf '%s' "$f4" | grep -qF "on \`tailwind\`, this page's converted demo file \`demo/<slug>.html\`" \
  || fail "Step 4's inner-page section walk does not point the tailwind --css source at the literal path demo/<slug>.html"
printf '%s' "$f4" | grep -qF 'never the backup at `demo/.original/<slug>.html`' \
  || fail "Step 4 does not exclude the demo/.original/ backup as a --css source"
printf '%s' "$f4" | grep -qF 'stale on this path' \
  || fail "Step 4 does not state that the manifest cssRules are stale on the tailwind path"

# File-wide negative: nowhere in wp-yolo may a --css source resolve to the
# backup. Every legitimate mention of `demo/.original/` is a backup/restore
# operation inside Step 2.6 or an explicit prohibition, so the backup path must
# never sit where a source is being designated — directly after a `→`, or
# directly after the words "converted demo".
#
# Two of the three original alternatives used `[^.]` as their filler, which is a
# period-free run — and `demo/.original/` is full of periods, so the windows
# could never actually reach the path they were meant to catch. Appending "In
# practice pass `demo/.original/index.html` here" bypassed all three. The filler
# is now `.`, and a fourth alternative catches the path being handed to a reader
# by verb. That last one uses `[^\`]` as its filler so the window cannot reach
# back across an intervening backticked path (which is what keeps the legitimate
# "copy `demo/<slug>.html` to `demo/.original/<slug>.html`" and "restore
# `demo/<slug>.html` from `demo/.original/<slug>.html`" phrasings green), and
# \b-anchors each verb so "because"/"caused" do not count as "use".
#
# Round 5. That verb-keyed alternative had no negation awareness, while the
# comment above it promises that "an explicit prohibition" is a legitimate
# mention. Six realistic correct edits — every one of them STRENGTHENING the
# contract this negative defends — exited 1 with a message that was false about
# what the line said:
#     Never pass `demo/.original/<slug>.html` as the `--css` source.
#     Do not use `demo/.original/<slug>.html` for anything but a restore.
#     Step 2.6 uses `demo/.original/` only as the restore source.
#     No builder ever reads `demo/.original/<slug>.html`.
#     The backup is never used as a source; `demo/.original/<slug>.html` is reference only.
#     To inspect the plain-CSS markup by hand, read `demo/.original/<slug>.html`.
# The file survived only because its one existing prohibition happens to put the
# path BEFORE the verb.
#
# So the designation test now runs per sentence (see `sentences` above) and a
# sentence is skipped when it carries a negation or a not-a-source qualifier.
# `only as/only the/only for`, `by hand`, `manually` and `reference only` are in
# the qualifier list because they mark the mention as a restore source or a human
# read, which is what the last four examples above are. `instead of`/`rather
# than` are deliberately absent — they reverse an object, not a claim.
#
# The verb list also gains the phrasings a re-point would actually use. "On a
# failed conversion, point it at `demo/.original/<slug>.html` instead." and "Set
# it to the pristine copy in `demo/.original/<slug>.html`." both passed the
# round-4 list, and both are the bypass this negative exists to catch.
#
# A heuristic negative cannot be exhaustive and is not meant to be; the positive
# assertions above (which name demo/index.html and demo/<slug>.html by path at
# both section-walk sites) are what actually pin the contract. What this must not
# do is fire on the correct edit.
fall=$(flat "$(cat "$f")")
src_pat='→ `?demo/\.original/'
src_pat="$src_pat"'|converted demo.{0,30}`demo/\.original/'
src_pat="$src_pat"'|--css.{0,60}`demo/\.original/'
src_pat="$src_pat"'|\b(pass|passes|passed|passing|point|points|pointed|pointing|re-?point[a-z]*|set|sets|setting|use|uses|used|using|read|reads|reading|transcribe[a-z]*|source)\b[^`]{0,40}`demo/\.original/'
not_a_source="$NEGATION"'|only (as|the|for) |by hand|manually|reference only'
while IFS= read -r sent; do
  [ -n "$sent" ] || continue
  # -i: a designation verb at the head of a sentence is capitalised ("Set it to
  # the pristine copy in `demo/.original/<slug>.html`"), and the round-4 pattern
  # was case-sensitive, so exactly the sentence-initial re-point slipped through.
  printf '%s' "$sent" | grep -Eqi "$src_pat" || continue
  if printf '%s' "$sent" | grep -Eqi "$not_a_source"; then
    continue
  fi
  fail "a --css source line in $f resolves to demo/.original/ — the unconverted backup, which is exactly the re-point this check exists to catch: $sent"
done <<< "$(sentences "$fall" 'demo/.original/')"

# ---------------------------------------------------------------------------
# Step 5.5 — the parity-gate auto-fix must not re-inject plain CSS
# ---------------------------------------------------------------------------
# The template branch has to be asserted in its DIRECTION, the way Step 2.6's
# backup and restore contracts are. The three assertions that used to stand here
# were presence-only, and presence is not direction: swapping the two words in
# the blockquote's branch lines — `basic` told to emit Tailwind utilities,
# `tailwind` told to write a literal CSS declaration into the theme CSS — left
# all three satisfied and printed PASS, with the file then instructing the
# tailwind path to re-inject exactly the plain CSS Step 5.5 exists to keep out.
printf '%s' "$f55" | grep -qF 'On `basic`, a repair is a literal CSS declaration' \
  || fail 'Step 5.5 does not bind the literal-CSS repair to `basic`: its template blockquote must say "On `basic`, a repair is a literal CSS declaration"'
printf '%s' "$f55" | grep -qF 'On `tailwind`, a repair is expressed as **Tailwind utility classes' \
  || fail 'Step 5.5 does not bind the tailwind repair to Tailwind utility classes: its template blockquote must say "On `tailwind`, a repair is expressed as **Tailwind utility classes"'
# ...and each inversion banned by name, because the correct pair of lines can be
# left in place while the wrong pair is added underneath it. A prohibition is
# unaffected: negating either claim ("a repair is never a literal CSS
# declaration") breaks the literal these two look for.
if printf '%s' "$f55" | grep -qF 'On `tailwind`, a repair is a literal CSS declaration'; then
  fail "Step 5.5 tells the tailwind path that a repair is a literal CSS declaration written into the theme CSS — that re-injects the plain CSS this template exists to remove, which is the whole reason Step 5.5 branches"
fi
if printf '%s' "$f55" | grep -qF 'On `basic`, a repair is expressed as **Tailwind utility classes'; then
  fail "Step 5.5 tells the basic path to repair with Tailwind utility classes — the basic theme has no Tailwind build, so the repair is inert and the parity finding never clears"
fi
printf '%s' "$f55" | grep -qF 'skills/wp-tailwind-system/SKILL.md' \
  || fail "Step 5.5's auto-fix has no tailwind branch citing the wp-tailwind-system decision ladder"
# `-E` with an optional space after the hyphen rather than `-F`: re-wrapping the
# blockquote so the break falls at this hyphen is an ordinary correct edit, and
# `flat` rejoins the halves with a space, so the fixed string exited 1 on it.
# Nothing else about the assertion changes.
printf '%s' "$f55" | grep -Eqi 'step 2\.6- ?converted' \
  || fail "Step 5.5's tailwind repair does not read from the Step 2.6-converted demo"
printf '%s' "$f55" | grep -qiF 'never write a raw css declaration into a theme css file on the tailwind path' \
  || fail "Step 5.5 does not forbid writing a raw CSS declaration into theme CSS on the tailwind path"

# ---------------------------------------------------------------------------
# /wp-tailwindify must accept the output path Step 2.6 passes it
# ---------------------------------------------------------------------------
grep -qF -- '--out <output-path>' "$t" \
  || fail "$t does not document an --out <output-path> argument"
grep -qF -- 'argument-hint: "[path/to/demo.html] [--out <output-path>]"' "$t" \
  || fail "$t's argument-hint does not advertise --out"
grep -qF 'index-tailwind.html' "$t" \
  || fail "$t lost its default output path (<demo-dir>/index-tailwind.html) — standalone use must be unchanged"
grep -qiF 'in-place' "$t" \
  || fail "$t does not document that --out may name the input file (in-place conversion)"
grep -qF 'demo/.original/<slug>.html' "$t" \
  || fail "$t still describes /wp-yolo Step 2.6's backup as a sibling of demo/*.html rather than demo/.original/<slug>.html"

# ---------------------------------------------------------------------------
# $t restates the detect heuristic twice — once in its own Step 2 validate list,
# once in the truncated-write hazard under Step 3 — and both restatements were
# the defective one ("no <style> blocks or inline styles → it may already be
# Tailwind-native"). Two documents disagreeing about the rule is how the rule
# gets applied wrongly, so both have to agree with Step 2.6.
# ---------------------------------------------------------------------------
# Round 6: these three regions anchor on the step NUMBER, not the step TITLE.
# They used to open on the full heading ('## Step 2: Read and Validate'), so
# renaming a heading in $t reddened the gate over an ordinary correct edit —
# proven with
#   sed -E 's/^(## Step [0-9]+):.*/\1: Renamed heading/' commands/wp-tailwindify.md
# → "FAIL: commands/wp-tailwindify.md has no Step 2 read/validate region delimited
# by '## Step 3:'". The same edit on $f, wp-polish.md and wp-tailwind-migrate.md is
# harmless, because every region there already anchors on the number. The `tail -1`
# closure proofs are unchanged: they are what stops a range running to EOF and
# turning a scoped assertion back into a file-wide grep.
s2t=$(awk '/^## Step 2:/,/^## Step 3:/' "$t")
[ -n "$s2t" ] || fail "$t has no Step 2 read/validate region delimited by '## Step 3:'"
printf '%s\n' "$s2t" | tail -1 | grep -q '^## Step 3:' \
  || fail "$t's Step 2 region is not terminated by its '## Step 3:' heading — the validate assertions would silently become file-wide"
f2t=$(flat "$s2t")
printf '%s' "$f2t" | grep -qF '<link rel="stylesheet"' \
  || fail "$t's Step 2 validate list does not count a linked stylesheet as CSS to convert — it must agree with /wp-yolo Step 2.6, where a project-local <link rel=\"stylesheet\"> is plain-CSS evidence"
printf '%s' "$f2t" | grep -qi 'positive evidence' \
  || fail "$t's Step 2 validate list does not require positive evidence before calling a demo already Tailwind-native"
if printf '%s' "$f2t" | grep -qF 'Does it contain `<style>` blocks or inline styles? (If not, it may already be Tailwind-native'; then
  fail "$t's Step 2 validate list is back to the original heuristic — absence of inline CSS is not proof of Tailwind-nativeness"
fi

# An in-place write that is interrupted destroys the demo page with no recovery
# path, and prose ("must not emit a partial file") is not a mechanism. Require
# temp-then-move, gated on the Step 4 verification.
ft=$(flat "$(cat "$t")")

# Every claim in $t that CLASSIFIES a page as Tailwind-native has to key on the
# positive rule, not on a missing <style> block. Forgiving on purpose (any of
# utilities / stylesheet / evidence satisfies it), because this scans sentences
# the author has not written yet.
#
# The needle used to be the exact bigram `already Tailwind-native`, and that made
# the whole loop hollow: reverting $t's hazard clause to the defective
# absence-based wording with the two words swapped — "finds no `<style>` block,
# declares the page Tailwind-native already and skips it on every later run" —
# iterated zero times and printed PASS. So did `already be Tailwind-native`, the
# phrasing of the bullet this task removed, and so did any lowercase variant.
# The needle is now `tailwind-native` alone, matched against a lower-cased copy of
# the file so capitalisation cannot evade it.
#
# Widening the needle that far sweeps in sentences that merely name the output
# format ("Convert a standard HTML/CSS demo file into Tailwind-native HTML"),
# which assert nothing about any particular page and must stay green. The loop
# therefore looks only at sentences that make a JUDGEMENT — already / declare /
# decide / treat / consider / deem / assume / judge / call — which is what every
# form of the defect has in common and what a format statement never has.
ftl=$(printf '%s' "$ft" | tr 'A-Z' 'a-z')
while IFS= read -r sent; do
  [ -n "$sent" ] || continue
  printf '%s' "$sent" | grep -Eq 'alread|declar|decid|treat|consider|deem|assume|judg|call(s|ed)? (it|the page|the demo)' || continue
  if printf '%s' "$sent" | grep -Eq 'utilit|stylesheet|evidence'; then
    continue
  fi
  fail "$t decides Tailwind-nativeness without naming the evidence it rests on. Absence of a <style> block is not evidence: a plain-CSS demo with an external stylesheet has none either, which is what made Step 2.6 skip the conversion on every page. Say what the page must positively carry: $sent"
done <<< "$(sentences "$ftl" 'tailwind-native')"
printf '%s' "$ft" | grep -qF 'writes the converted HTML to a temporary path (`<output-path>.tmp`)' \
  || fail "$t does not require the agent to write to a temporary path (\`<output-path>.tmp\`) instead of the output path"
printf '%s' "$ft" | grep -qF "moves it over the output path **only after** Step 4's verification passes" \
  || fail "$t does not require the temporary file to be moved over the output path only after Step 4's verification passes"
printf '%s' "$ft" | grep -qF 'If verification fails, discard the temporary file and leave the output path exactly as it was' \
  || fail "$t does not discard the temporary file and leave the output path untouched when verification fails"
# Direction: moving first and verifying after is the truncating write itself.
if printf '%s' "$ft" | grep -Eq "moves it over the output path (\*\*)?(before|regardless of|and then|first)"; then
  fail "$t moves the temporary file into place before Step 4's verification — that is the destructive in-place write the temp path exists to prevent"
fi
printf '%s' "$ft" | grep -qF 'Only if 2, 3, 4 and 5 all hold' \
  || fail "$t's Step 4 does not make the move conditional on structure checks and the rendering gate"

# ---------------------------------------------------------------------------
# The conversion is licensed to DELETE the demo's project stylesheet <link>, and
# nothing verified that it went. Step 4 checked delimiters and the absence of
# <style> blocks only — so a page that lost its stylesheet and gained invented
# utilities passed verification, was moved over demo/<slug>.html by /wp-yolo Step
# 2.6, and was never restored from demo/.original/. The same omission is what
# makes the skip rule non-terminating in the other direction: a converted page
# that KEEPS the link carries plain-CSS evidence and re-converts on every run.
# ---------------------------------------------------------------------------
s4t=$(awk '/^## Step 4:/,/^## Step 5:/' "$t")
[ -n "$s4t" ] || fail "$t has no Step 4 verify-output region delimited by '## Step 5:'"
printf '%s\n' "$s4t" | tail -1 | grep -q '^## Step 5:' \
  || fail "$t's Step 4 region is not terminated by a '## Step 5:' heading — the verification-list assertions would silently become file-wide"
f4t=$(flat "$s4t")
printf '%s' "$f4t" | grep -qF 'Verify no project-local stylesheet `<link>` remains' \
  || fail "$t's Step 4 does not verify that the project stylesheet <link> is gone from the converted page. The agent is required to delete it, so nothing else can catch a conversion that deleted it without absorbing its rules — and a conversion that left it behind produces a page /wp-yolo Step 2.6 correctly judges not Tailwind-native, which it then re-converts forever."

# Step 4 item 4's FAILURE branch, gated in its own direction. Flipping "discard
# it, leave the output path untouched" to "move it anyway and report a partial
# success" reinstates exactly the destructive write the temp path exists to
# prevent, and used to leave the suite green.
printf '%s' "$ft" | grep -qF 'discard it, leave the output path untouched, and report the conversion as failed — never a partial success' \
  || fail "$t's Step 4 item 4 does not discard the temporary file, leave the output path untouched and report a failed conversion when verification fails"
if printf '%s' "$ft" | grep -Eq 'move (it|the temporary file) (anyway|regardless|and report)|partial success is|report (it |the conversion )?as a partial success'; then
  fail "$t's Step 4 item 4 moves the unverified temporary file into place and/or reports a partial success — a failed verification must leave the output path exactly as it was"
fi

# ---------------------------------------------------------------------------
# The temp-path contract must live in the DISPATCH CONTEXT the agent is handed,
# not only in the prose underneath it.
#
# The bullets are what the orchestrator actually passes to `wp-tailwind`. While
# they read "Output file path: the resolved output path from Step 1" and nothing
# in them named `<output-path>.tmp`, the agent's instruction was a plain direct
# write — and `agents/wp-tailwind.md` Step 5 agreed with the bullets, not with
# the paragraph. Rewriting the bullet to "write straight to this path,
# overwriting whatever is there" left the suite green.
#
# There was an actor mismatch too: the paragraph told the AGENT to move the temp
# file "only after Step 4's verification passes", but Step 4 runs in the command
# after the agent has returned, so the agent has nothing to condition on. The
# agent writes `<output-path>.tmp` and stops; the command verifies and moves.
# ---------------------------------------------------------------------------
s3t=$(awk '/^## Step 3:/,/^## Step 4:/' "$t")
[ -n "$s3t" ] || fail "$t has no Step 3 dispatch region delimited by '## Step 4:'"
printf '%s\n' "$s3t" | tail -1 | grep -q '^## Step 4:' \
  || fail "$t's Step 3 dispatch region is not terminated by its '## Step 4:' heading — the dispatch-context assertions would silently become file-wide"
f3t=$(flat "$s3t")

printf '%s' "$f3t" | grep -qF '**What the agent writes: `<output-path>.tmp`, never `<output-path>` itself.**' \
  || fail "$t's Step 3 dispatch context does not tell the agent, in the bullets it hands over, to write \`<output-path>.tmp\` and never \`<output-path>\` itself"
printf '%s' "$f3t" | grep -qF 'The agent writes `<output-path>.tmp` and stops there. It does not move, rename or delete `<output-path>`' \
  || fail "$t's Step 3 dispatch context does not stop the agent after the temporary write — the move belongs to the command, which is the only actor that can condition it on Step 4"
printf '%s' "$f3t" | grep -qF "this command owns Step 4's verification and owns the move" \
  || fail "$t's Step 3 dispatch context does not give Step 4's verification and the move to the command"
printf '%s' "$f3t" | grep -qF '**This command**, not the agent, moves it over the output path' \
  || fail "$t names the agent, not the command, as the actor that moves the temporary file — Step 4 runs after the agent returns, so the agent cannot condition on it"

# The stale sentence that contradicted all of the above.
#
# Negation-aware (see `undirected`), which it was not: this was the one negative
# in the file that did not route through the helper, and it survived only by the
# inflection accident that the paragraph above happens to read "never
# overwrites". Two ordinary correct edits exited 1 with a message that was the
# opposite of what the file said — adding "The temp path is the mechanism that
# stops the agent from overwriting its own input.", and a pure reword of the
# existing sentence to "Under it there is no risk of the agent overwriting its
# own input".
#
# What is banned is the AFFIRMATIVE claim, so the pattern asks for the actor to be
# the one doing it: a finite "overwrites its own input", or "overwriting" with the
# actor directly in front of it. A preventive framing puts a preposition between
# the two ("stops the agent FROM overwriting"), so it never matches; a negated one
# ("no risk of the agent overwriting ...") matches and is then governed by the
# negation in its own clause. Both stay green without widening $NEGATION, which
# every other negative in this file depends on.
own_input=$(undirected "$ftl" 'its own input' '(^|[^a-z])overwrites its own input|(^|[^a-z])(agent|command|conversion|it|this|that)( is| was| will be| would be)? overwriting its own input')
if [ -n "$own_input" ]; then
  fail "$t still tells the agent it is overwriting its own input — false under temp-then-move, and it reinstates the direct-write reading: $own_input"
fi
# Direction: no instruction in the dispatch context may name the output path as
# the thing the agent writes.
if printf '%s' "$f3t" | grep -Eq 'writes? (straight|directly) to|overwriting whatever is there|writes? (the converted HTML |it )?to `<output-path>`([^.]|$)'; then
  fail "$t's Step 3 dispatch context tells the agent to write the output path directly — it must write \`<output-path>.tmp\` and stop"
fi
# Every write instruction in the dispatch context that names <output-path> must
# name the .tmp form.
if printf '%s' "$f3t" | grep -oE 'writes?[^.`]{0,20}`<output-path>[^`]*`' | grep -qv '<output-path>\.tmp'; then
  fail "$t's Step 3 dispatch context has a write instruction that names \`<output-path>\` rather than \`<output-path>.tmp\`"
fi

# ===========================================================================
# Round 6 — what a REHEARSAL of Step 2.6 found.
#
# The eight assertions below are not code review. An agent executed Step 2.6
# against a three-page demo with a real 82-line stylesheet (`:root` tokens,
# `@media`, `@font-face`, `background url()`, an `::after` gradient, hover/focus,
# a transition), compiled the result with Tailwind 4.1.5 and diffed COMPUTED
# STYLES in a browser at six widths. Each assertion pins a defect that run
# measured.
#
# The skill file is read HERE, not only in tests/checks/wp-tailwind-system.sh,
# and the split is deliberate: that check owns the decision ladder, the file
# layout and the prohibition list — the authoring contract. What is gated below
# is the CONVERSION contract, which spans two files by construction. The agent's
# Demo Conversion Mode (agents/wp-tailwind.md Steps 1-5) does not read the skill
# at all — only its Section Authoring Mode does — so the conversion-time facts
# have to reach it through $t's dispatch context, and the dispatch context and
# the skill section it points at are one claim in two places.
# ===========================================================================
k=skills/wp-tailwind-system/SKILL.md
test -f "$k" || fail "$k missing"
fk=$(flat "$(cat "$k")")
fkl=$(printf '%s' "$fk" | tr 'A-Z' 'a-z')

# ---------------------------------------------------------------------------
# G1 — the converted demo renders UNSTYLED, and Step 5 used to send the user to
# a browser to look at it. Conversion removes every <style> block (Step 4 item 3)
# and every project stylesheet <link> (item 4) and adds nothing: the rehearsal's
# converted index.html <head> was meta, meta, title. The command must say so.
# ---------------------------------------------------------------------------
s5t=$(awk '/^## Step 5:/,0' "$t")
[ -n "$s5t" ] || fail "$t has no Step 5 region"
f5t=$(flat "$s5t")
f5tl=$(printf '%s' "$f5t" | tr 'A-Z' 'a-z')
# Scoped to the REPORT BLOCK, not to the region: the region also carries the
# rationale paragraph explaining why no runtime stylesheet is emitted, which uses
# the word "unstyled" twice — so a region-wide grep stayed green with the whole
# statement deleted from the text the user actually sees. Proven, not assumed.
rep5=$(printf '%s\n' "$s5t" | awk '/^```/{n++; next} n==1')
[ -n "$rep5" ] || fail "$t's Step 5 has no fenced report block"
printf '%s' "$rep5" | grep -qi 'unstyled' \
  || fail "$t's Step 5 report does not tell the user the converted demo renders UNSTYLED. Conversion strips the demo's <style> blocks and its stylesheet <link> and adds no replacement, so the page has no CSS at all until the theme's Tailwind build compiles it — and a report that omits that reads as a failed conversion."
# ...and it must not send them to a browser to look at it. Negation-aware: the
# file's own way of stating the rule is "Do not tell the user to open it in a
# browser", which a bare grep would have failed on — the exact false-fail class
# this file has been bitten by five times.
browser=$(undirected "$f5tl" 'browser' '(review|open|inspect|preview|view)[a-z]* ?(the |it |this |that )?[a-z ]{0,30}in (a|the|your) browser')
if [ -n "$browser" ]; then
  fail "$t's Step 5 still tells the user to view the converted demo in a browser. It renders unstyled; the review is a diff of the markup against the original: $browser"
fi

# ---------------------------------------------------------------------------
# G6 — `mv` is aliased to `mv -i` in an interactive shell. In the rehearsal the
# first move PROMPTED and moved nothing, leaving three unconverted pages and
# three orphan .tmp files while the loop reported success for every one of them.
# ---------------------------------------------------------------------------
printf '%s' "$f4t" | grep -qF '\mv -f' \
  || fail "$t's Step 4 does not specify \`\\mv -f\` for the move. A bare \`mv\` hits the interactive \`mv -i\` alias, prompts, moves nothing and still exits 0 — the demo folder then reports three converted pages that were never touched."
printf '%s' "$f4t" | grep -Eqi 'post-condition' \
  || fail "$t's Step 4 gives the move no post-condition. A no-op move must not be able to read as a success."
printf '%s' "$f4t" | grep -Eqi '\.tmp[^.]{0,60}(no longer exists|is gone|does not exist)' \
  || fail "$t's Step 4 post-condition does not require the temporary file to be GONE after the move — that is the one observation that separates a real move from a prompt nobody answered."
# `still[^.]{0,24}` rather than `still (on disk|...)`: "should the .tmp still be
# present on disk" is an ordinary rewrite of "if the .tmp is still on disk", and
# the tighter form exited 1 on it. The consequence half is what the assertion is
# actually about, and it is unchanged.
printf '%s' "$f4t" | grep -Eqi 'still[^.]{0,24}(on disk|there|present|exist)[^.]{0,120}(did not happen|failed|not converted)' \
  || fail "$t's Step 4 does not say what a surviving .tmp means: the move did not happen and the page is a failure, not a conversion."

# ---------------------------------------------------------------------------
# G7 — the restore branch was dead code presented as the main defence.
# /wp-tailwindify never moves an unverified file, so on a failure demo/<slug>.html
# IS the pristine original and restoring the backup over it is a no-op. Keeping
# the branch is fine; presenting a no-op as the safety net is not, because it
# hides that the real guarantee lives in the temp-then-move mechanism.
# ---------------------------------------------------------------------------
printf '%s' "$f26" | grep -Eqi 'nothing to restore' \
  || fail "Step 2.6 still presents the restore as the recovery path for a failed conversion. /wp-tailwindify moves the temporary file only after its own verification passes, so a failed page never reaches demo/<slug>.html: normally there is nothing to restore, and the step has to say so or the mechanism that actually protects the page goes undocumented."
printf '%s' "$f26" | grep -Eqi 'belt[- ]and[- ]braces' \
  || fail "Step 2.6 does not mark the restore as the belt-and-braces check it is — see the 'nothing to restore' assertion above."
printf '%s' "$f26" | grep -Eqi 'compare `demo/<slug>\.html`' \
  || fail "Step 2.6's restore is unconditional. It must be conditioned on the invariant it backs up: compare demo/<slug>.html with the backup after a reported failure, restore only when they differ (something outside the contract wrote that path)."
printf '%s' "$f26" | grep -Eqi 'identical' \
  || fail "Step 2.6 does not say what an identical comparison means — the contract held, report the page unconverted and touch nothing."

# ---------------------------------------------------------------------------
# G2 — Step 4.5's font carry had no template branch, and its instruction
# ("enqueue the resulting stylesheet, or add to the theme's existing fonts
# partial") describes a theme that does not exist on the tailwind path: a
# Tailwind theme has no fonts partial and enqueues exactly one stylesheet, the
# compiled main.css. A second enqueue is the plain-CSS regression this whole
# branch exists to remove.
# ---------------------------------------------------------------------------
s45=$(awk '/^## Step 4\.5/,/^## Step 5:/' "$f")
[ -n "$s45" ] || fail "wp-yolo has no Step 4.5 font-carry region"
printf '%s\n' "$s45" | tail -1 | grep -q '^## Step 5:' \
  || fail "the Step 4.5 region is not terminated by a '## Step 5:' heading — the font-carry assertions would silently become file-wide"
f45=$(flat "$s45")

b45_tw=$(bullet "$s45" '`tailwind` →') \
  || fail "Step 4.5 has no \`tailwind\` branch. Without one the font carry enqueues a second stylesheet into a theme whose only enqueue is the compiled assets/css/dist/main.css."
b45_ba=$(bullet "$s45" '`basic` →') \
  || fail "Step 4.5 has no \`basic\` branch — the original enqueue behaviour has to survive the split."
fb_tw=$(flat "$b45_tw")
fb_ba=$(flat "$b45_ba")
printf '%s' "$fb_tw" | grep -qF 'base/fonts.css' \
  || fail "Step 4.5's \`tailwind\` branch does not route the @font-face rule to assets/css/src/tailwindcss/base/fonts.css — the skill's file layout gives \`base\` the resets-and-font-face role, and it is the only sanctioned home for the rule on this path: [$fb_tw]"
printf '%s' "$fb_tw" | grep -Eqi 'enqueue nothing|exactly one enqueue|no second enqueue|only enqueue' \
  || fail "Step 4.5's \`tailwind\` branch does not forbid a second enqueue. /wp-tailwind-migrate Step 5 says leave exactly one enqueue; a fonts stylesheet beside assets/css/dist/main.css is the regression this template exists to remove: [$fb_tw]"
printf '%s' "$fb_ba" | grep -Eqi 'enqueue' \
  || fail "Step 4.5's \`basic\` branch no longer enqueues the font stylesheet — the basic theme has no Tailwind build, so nothing else would load the @font-face rule: [$fb_ba]"
if printf '%s' "$fb_ba" | grep -qF 'base/fonts.css'; then
  fail "Step 4.5's \`basic\` branch writes into the Tailwind source tree. The two branches are swapped: [$fb_ba]"
fi

# The rehearsal's demo declared src: url("assets/fonts/marcellus.woff2") and
# shipped no such file. Real demos do this constantly and the step had no branch
# for it — and a re-emitted @font-face pointing at a missing file fails silently
# under font-display: swap, so the theme renders the fallback stack with nothing
# logged to say why.
printf '%s' "$f45" | grep -Eqi 'not found in the demo folder|genuinely absent|not there|is missing' \
  || fail "Step 4.5 has no branch for a @font-face whose woff2 is not in the demo folder. The rehearsal demo declares assets/fonts/marcellus.woff2 and does not ship it; without a branch the step copies nothing and carries on."
# Widened after a proven false-fail: "never re-emit" and "leave that family's rule
# out altogether" are ordinary rewrites of "do **not** re-emit" / "skip that
# family", and the first form of this needle exited 1 on both. The bold markers
# survive `flat`, hence the optional asterisks.
printf '%s' "$f45" | grep -Eqi '(not|never)\*{0,2},? ?re-emit|(skip|omit) (that|the) family|leave (that|the) family[^.]{0,40}out' \
  || fail "Step 4.5's missing-source branch does not stop the @font-face rule being re-emitted anyway. A rule pointing at a file the theme does not have fails silently — with font-display: swap the page renders the fallback stack and nothing anywhere says why."
printf '%s' "$f45" | grep -Eqi 'review list' \
  || fail "Step 4.5's missing-source branch does not surface the missing font to the operator. A silent fallback is exactly what the Review list exists for."

# Step 5.5's prohibition ("Never write a raw CSS declaration into a theme CSS
# file on the tailwind path", gated above) and its own missing-font repair
# ("re-emit the @font-face rule") contradicted each other four lines apart.
# @font-face is a raw declaration block with no utility and no @apply form — it
# is rung 4 of the ladder — so it has to be carved out by name, and the carve-out
# has to stay closed at one.
printf '%s' "$f55" | grep -qF '@font-face' \
  || fail "Step 5.5 orders a raw @font-face re-emission four lines under a blanket ban on raw CSS declarations, and never reconciles them. Carve @font-face out by name."
# Both needles accept the synonyms a careful author reaches for. "@font-face is
# the single exception" is the same claim as "the one carve-out", and the
# carve-out-only form exited 1 on it — the false-fail class this file exists to
# stay clear of. The direction is still gated: a widened licence has to say
# something, and the raw-CSS permission scan below catches what these two do not.
printf '%s' "$f55" | grep -Eqi 'carve[- ]?out|(one|single|sole|only) exception' \
  || fail "Step 5.5 does not mark @font-face as a carve-out from the raw-CSS prohibition — see the assertion above."
printf '%s' "$f55" | grep -qF 'base/fonts.css' \
  || fail "Step 5.5's @font-face carve-out does not say where the rule goes on the tailwind path: assets/css/src/tailwindcss/base/fonts.css, the same place Step 4.5 puts it."
printf '%s' "$f55" | grep -Eqi 'the only one|only carve[- ]?out|no other (repair|rule|exception)|nothing else may|and only (that|this) one' \
  || fail "Step 5.5's carve-out is open-ended. One exception with a reason is a carve-out; an exception with no boundary is the prohibition repealed."
# ...and nothing else in Step 5.5 may license raw CSS. A sentence that permits it
# without naming @font-face reopens the door the carve-out just closed.
# Keyed on the bare word "raw", not on the bigram "raw CSS": the licence this
# scan exists to catch was written as "a raw DECLARATION is acceptable on this
# path too" and slipped straight through the bigram form. Lower-cased so a
# sentence-initial capital cannot evade it.
# ...and negation-aware, through the same helper every other negative here uses.
# The file's own boundary sentence is "No other repair on this path may write raw
# CSS", which a bare permission grep read as a permission and reddened the gate on
# — the file saying exactly what this scan wants it to say.
f55l=$(printf '%s' "$f55" | tr 'A-Z' 'a-z')
raw_ok=$(undirected "$f55l" 'raw ' '(is|are|stays|remains) (fine|ok|okay|acceptable|allowed|permitted|permissible)|may (be written|write)|you may write|feel free to write')
if [ -n "$raw_ok" ]; then
  fail "Step 5.5 permits raw CSS on the tailwind path in a sentence that is not the @font-face carve-out: $raw_ok"
fi

# ---------------------------------------------------------------------------
# G3 — Preflight. Measured on the rehearsal, every regression below came from a
# CORRECTLY translated rule: <button> Arial/13.33px → system-ui/16px/25.6px,
# <img> inline/max-width:none → block/100% (service card 197.9 → 190.7px), <p>
# UA margin 14.4px → 0 (footer column 71.04 → 56.8px), the logo <a> underline
# gone, page height 1130.21 → 1108.78px. An agent converting declaration by
# declaration is right at every step and wrong at the end, and no document in
# this plugin mentioned Preflight at all.
#
# Both halves are gated: the dispatch context (the only thing the agent's Demo
# Conversion Mode actually reads) and the skill section it points at.
# ---------------------------------------------------------------------------
printf '%s' "$fkl" | grep -qF 'preflight' \
  || fail "$k never mentions Preflight. Compiled Tailwind replaces the browser's default stylesheet, so a theme whose every declaration was translated correctly still does not render like the demo."
for pf in 'max-width:100%' 'display:block' 'underline' 'button'; do
  printf '%s' "$fkl" | grep -qiF "$pf" \
    || fail "$k's Preflight material does not name '$pf'. The measured moves are the whole content: <button> font, <img> display and max-width, <p>/heading margins, and the bare <a> underline."
done
printf '%s' "$fkl" | grep -Eqi 're-add|add (it|them) back|restore (it|the value)' \
  || fail "$k says Preflight changes the baseline but never says what to do about it: re-add the UA value the demo relied on as a utility ON the element."
printf '%s' "$f3t" | grep -qi 'preflight' \
  || fail "$t's Step 3 dispatch context never warns the conversion agent about Preflight. agents/wp-tailwind.md reads the wp-tailwind-system skill only in Section Authoring Mode, so Demo Conversion Mode learns this from the dispatch context or not at all."
# Naming Preflight is not enough, and this was proven: replacing the whole bullet
# with "- **Notes.**" left the word alive in the cross-reference that follows it
# ("see the SKILL, § Preflight") and the presence grep stayed green with the
# warning gone. The dispatch context has to carry what Preflight MOVES, because
# Demo Conversion Mode reads no skill unless it is told to.
for pf in 'max-width:100%' 'underline' 'display:block'; do
  printf '%s' "$f3t" | grep -qiF "$pf" \
    || fail "$t's Step 3 dispatch context names Preflight but not what it moves ('$pf'). The measured list is <button> font, <img> display and max-width, <p>/heading margins and the bare <a> underline."
done
printf '%s' "$f3t" | grep -qF 'skills/wp-tailwind-system/SKILL.md' \
  || fail "$t's Step 3 dispatch context does not point the conversion agent at the wp-tailwind-system skill, which is where the measured Preflight list and the v4 rules live."
# Direction. Negation-aware, because the correct text says Preflight is NOT the
# browser's default stylesheet and that a faithful conversion does NOT render the
# same — both of which a bare grep would read as the inversion.
pfclaim=$(undirected "$ftl" 'preflight' '(identical|unchanged|no (change|effect|difference)|leaves? the (ua |browser )?(baseline|defaults?) (alone|intact|as they are)|preserves? the (ua|browser))')
if [ -n "$pfclaim" ]; then
  fail "$t claims Preflight leaves the UA baseline alone. It does not, and the difference is measurable: $pfclaim"
fi

# ---------------------------------------------------------------------------
# G4 — bare element selectors had no home in any document, and the rehearsal got
# one wrong: it reasoned that `a { color: var(--color-brand) }` was dead because
# every <a> carried a class, and the computed diff proved otherwise — the logo
# <a> came out rgb(28,28,28) instead of rgb(11,107,90). The rule and its test
# both have to be written down.
# ---------------------------------------------------------------------------
printf '%s' "$fkl" | grep -Eqi 'bare (element )?selector' \
  || fail "$k says nothing about bare element selectors (a {}, h1,h2,h3 {}, body {}, *,*::before,*::after {}). They carry real declarations and have no class to convert, so an agent with no rule either drops them or invents one."
printf '%s' "$fkl" | grep -Eqi 'distribut' \
  || fail "$k does not give the default answer for a bare selector: distribute its declarations, as utilities, onto every element the selector actually reaches."
printf '%s' "$fkl" | grep -Eqi 'dead only (when|if)' \
  || fail "$k does not state the deadness test as a CONDITION. 'Every <a> has a class' is the reasoning that dropped the brand link colour in the rehearsal; the rule is that a bare selector is dead only when every element it matches already carries a class setting the same property."
printf '%s' "$fkl" | grep -Eqi 'check the elements, not the stylesheet|read (each|every) `?class`? attribute|enumerate the matches' \
  || fail "$k does not say HOW to test a bare selector for deadness — the check is over the elements in the markup, not over the stylesheet."
printf '%s' "$f3t" | grep -Eqi 'bare (element )?selector' \
  || fail "$t's Step 3 dispatch context does not tell the conversion agent what to do with a bare element selector, and its Demo Conversion Mode reads no skill."
printf '%s' "$f3t" | grep -Eqi 'dead only (when|if)' \
  || fail "$t's Step 3 dispatch context gives no deadness test for a bare element selector — see the $k assertion above for what the missing test cost."

# ---------------------------------------------------------------------------
# G5 — Tailwind v4 specifics no document named. package.json pins ^4.1.5 and the
# palette is OKLCH: v4's gray-300 is #d1d5dc where the rehearsal demo declared
# #d1d5db, while gray-200 is exact — so "no match → use Tailwind's built-in
# colour scale" is right sometimes and off-by-one others with no way to tell.
# ---------------------------------------------------------------------------
printf '%s' "$fkl" | grep -Eqi '(^|[^a-z0-9])v4([^a-z0-9]|$)|tailwind 4|\^?4\.1' \
  || fail "$k never names the Tailwind version. v3 and v4 disagree on utility names and on palette values, and the starter installs ^4.1."
printf '%s' "$fkl" | grep -qF 'bg-linear-to-r' \
  || fail "$k does not name the v4 gradient utility \`bg-linear-to-r\`. A v3-trained agent writes \`bg-gradient-to-r\`, which compiles to nothing in v4."
printf '%s' "$fkl" | grep -qF 'oklch' \
  || fail "$k does not say the built-in palette is OKLCH — that is why v4's gray-300 (#d1d5dc) is not the #d1d5db a demo declared."
printf '%s' "$fkl" | grep -qF 'oklab' \
  || fail "$k does not say gradients interpolate in OKLab. A converted linear-gradient compiles to oklab() stops with a different midpoint than the demo's sRGB ramp; an agent that does not know this chases the difference with extra stops."
printf '%s' "$fkl" | grep -Eqi 'exact match or arbitrary|byte for byte' \
  || fail "$k gives no tolerance rule for a colour that is close to a scale value but not equal to it. The rule has to be decidable: exact match or arbitrary value."
printf '%s' "$f3t" | grep -qF 'bg-linear-to-r' \
  || fail "$t's Step 3 dispatch context does not name the v4 gradient utility for the conversion agent."
printf '%s' "$f3t" | grep -Eqi 'exact match or arbitrary|byte for byte' \
  || fail "$t's Step 3 dispatch context gives the conversion agent no colour tolerance rule, so \"no match → use the built-in scale\" silently shifts the demo's declared value."
# A v3 name may be MENTIONED, never recommended: every sentence naming it has to
# mark it as v3 or reject it. A negative-only scan — zero iterations means the
# name is absent, which is also fine.
while IFS= read -r sent; do
  [ -n "$sent" ] || continue
  if printf '%s' "$sent" | grep -Eqi 'v3|not |never|instead of|rather than'; then continue; fi
  fail "$k names \`bg-gradient-to-r\` without marking it as the v3 form: $sent"
done <<< "$(sentences "$fkl" 'bg-gradient-to-r')"

# ---------------------------------------------------------------------------
# The merged axes. Step 1 must REFUSE the cinematic template (upstream's third
# axis, init-only everywhere else), and Step 5 item 1 must hand the seed's
# language shape to the i18n strategy instead of stating the suffix model
# unconditionally. Both files were auto-merged and nobody read them whole.
# ---------------------------------------------------------------------------
s1=$(awk '/^## Step 1/,/^## Step 2:/' "$f")
s5=$(awk '/^## Step 5:/,/^## Step 5\.5/' "$f")
[ -n "$s1" ] || fail "wp-yolo has no Step 1 region delimited by Step 2"
[ -n "$s5" ] || fail "wp-yolo has no Step 5 region delimited by Step 5.5"
printf '%s\n' "$s1" | tail -1 | grep -q '^## Step 2:' \
  || fail "the Step 1 region is not terminated by a '## Step 2:' heading — the cinematic-refusal assertions would silently become file-wide"
printf '%s\n' "$s5" | tail -1 | grep -q '^## Step 5\.5' \
  || fail "the Step 5 region is not terminated by a '## Step 5.5' heading — the seed assertions would silently become file-wide"
f1=$(flat "$s1"); f5=$(flat "$s5")

# Cinematic must be named AND refused — a mention is not a stop. Falling
# through drives the section walk on a reel project and wp-css writes
# assets/css/styles.css into a theme that has its own cinematic.css.
printf '%s' "$f1" | grep -qF '`Template:` is `cinematic`' \
  || fail "Step 1 never names the cinematic template — a reel project runs the section walk and wp-css writes assets/css/styles.css into a theme that has its own cinematic.css"
printf '%s' "$f1" | grep -qF 'exit without dispatching anything' \
  || fail "Step 1 names cinematic but never refuses it — a mention is not a stop, and falling through drives the section walk on a reel project"

# The seed's language shape is the strategy's, not the suffix model's. Stating
# 'primary language only' unconditionally told a polylang run to skip the
# counterpart pages /wp-seed exists to build on that strategy.
printf '%s' "$f5" | grep -qF 'under `suffix` it fills the primary language' \
  || fail "Step 5 item 1 does not scope primary-language seeding to the suffix strategy — the sentence is the suffix model's and a polylang run reading it skips the counterpart pages its strategy requires"
printf '%s' "$f5" | grep -qF 'under `polylang` it builds a counterpart page per language' \
  || fail "Step 5 item 1 never says what /wp-seed does under polylang — seeding without the counterpart pages leaves every secondary language empty and /wp-polylang to rebuild them from nothing"

echo PASS
