#!/usr/bin/env bash
# /wp-init must make the demo conversion part of the flow, decide the skip on the
# same evidence rule /wp-yolo Step 2.6 states, and /wp-finalize must validate the
# tailwind convention before delivery.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

# Command files wrap at ~90 columns, and any ordinary edit re-flows the paragraph
# around it. Every prose match below therefore runs against a newline-flattened
# copy; a line-anchored `grep -F` would false-fail on the next re-wrap.
#
# Two joins beyond the newline, both for re-wraps that have already false-failed a
# gate on this branch:
#   - ` \ ` is a markdown hard break left at the end of a re-wrapped line;
#   - a break taken at a HYPHEN (`plain-\nCSS`) flattens to `plain- CSS`, which no
#     literal for `plain-CSS evidence` would match. Re-joining a hyphen that is
#     preceded by a letter cannot touch a list marker (` - `, space before).
flat() { printf '%s' "$1" | tr '\n' ' ' | sed 's/ \\ / /g; s/  */ /g; s/\([A-Za-z]\)- /\1-/g'; }

# `bullet` (below) matches RAW lines, so the hyphen re-join `flat` does cannot help
# it: a bullet whose bold LABEL is split as `**Plain-` / `CSS evidence` becomes
# invisible and the check reports the bullet as missing. Re-join those breaks in
# the raw text first, before anything reads a line. A line ending in a letter and a
# hyphen is a wrap artefact; merging it into the next line keeps the first line's
# indent, so bullet nesting is untouched.
dehyphen() {
  printf '%s\n' "$1" | awk '
    { if (buf != "") { sub(/^[[:space:]]+/, ""); $0 = buf $0; buf = "" } }
    /[A-Za-z]-$/ { buf = $0; next }
    { print }
    END { if (buf != "") print buf }
  '
}

test -f commands/wp-init.md     || fail "commands/wp-init.md missing"
. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; wp_init=$EXPANDED
test -f commands/wp-finalize.md || fail "commands/wp-finalize.md missing"
. tests/checks/lib/expand-command.sh; expand_command commands/wp-finalize.md; wp_finalize=$EXPANDED

init=$(flat "$(cat "$wp_init")")
fin=$(flat "$(cat "$wp_finalize")")

# ---------------------------------------------------------------------------
# Region. The conversion instruction lives in Step D4 and nowhere else, and a
# file-wide grep for a command NAME is satisfied by any passing prose mention of
# it — that exact hollow gate has been found twice on this branch. Scope to the
# step, and prove the range closed: if the terminator heading is renamed, awk runs
# to EOF and every "scoped" assertion below silently degrades to a file-wide one.
# The anchors deliberately match only `**Step D4` / `**Step D5`, so re-titling
# either step keeps working.
# ---------------------------------------------------------------------------
d4_raw=$(awk '/^\*\*Step D4/,/^\*\*Step D5/' "$wp_init")
[ -n "$d4_raw" ] || fail "wp-init.md has no '**Step D4' block — the tailwind demo-conversion instruction lives there"
printf '%s\n' "$d4_raw" | tail -1 | grep -q '^\*\*Step D5' \
  || fail "wp-init.md's Step D4 region is not terminated by its '**Step D5' heading — every assertion scoped to it would silently become file-wide"
d4_raw=$(dehyphen "$d4_raw")
d4=$(flat "$d4_raw")

# ---------------------------------------------------------------------------
# The @theme injection target. The upstream merge carried TWO D4 bullets whose
# condition is identical (`If $TEMPLATE is tailwind`) and whose targets
# differ: the stale one maps colours onto `assets/css/src/style.css`, a file
# the Tailwind starter does not ship (its compiled entry point is
# tailwindcss/main.css). An agent obeying it writes to nothing and the site
# ships the default palette. The duplicate is the defect, so the count is the
# assertion: exactly one such bullet, and the survivor names the entry point
# and never the stale path. The backticked path needle accepts the ceiling
# that a hard mid-path re-wrap would break it — careful authors wrap at word
# boundaries, and flat() rejoins those.
# ---------------------------------------------------------------------------
n_theme_bullets=$(printf '%s\n' "$d4_raw" | grep -cE '^[[:space:]]*- If `\$TEMPLATE` is `tailwind`:' || true)
[ "$n_theme_bullets" -eq 1 ] \
  || fail "Step D4 has $n_theme_bullets bullets conditioned on \`\$TEMPLATE is tailwind\` for the @theme injection — exactly one may exist. The merge carried a duplicate whose target, assets/css/src/style.css, the Tailwind starter does not ship, so an agent handed two targets obeys both or neither and the palette never lands"
printf '%s' "$d4" | grep -qF 'tailwindcss/main.css' \
  || fail "Step D4's @theme injection never names assets/css/src/tailwindcss/main.css — mapping colours into any other file ships the default palette"
if printf '%s' "$d4" | grep -qF 'style.css'; then
  fail "Step D4 still names style.css as an @theme target — the Tailwind starter's compiled entry point is tailwindcss/main.css, and a colour mapping written to a file that does not exist is a silent no-op"
fi

# ---------------------------------------------------------------------------
# Run, don't suggest.
# ---------------------------------------------------------------------------
# The old wording must be gone. A positive alone is not enough: both sentences can
# coexist, leaving the operator told to suggest AND to run.
if printf '%s' "$init" | grep -qiF 'Also suggest running `/wp-tailwindify`'; then
  fail "wp-init still tells the operator to merely suggest /wp-tailwindify"
fi
printf '%s' "$d4" | grep -qiF 'run `/wp-tailwindify`' \
  || fail "wp-init's Step D4 does not tell the operator to RUN /wp-tailwindify"

# ---------------------------------------------------------------------------
# The detect RULE. Step D4 used to read:
#
#     Skip only if the demo has no `<style>` block and no static `style="`
#     attribute (already Tailwind-native)
#
# which treats the absence of ONE CSS delivery mechanism as proof of
# Tailwind-nativeness. A plain-CSS demo that keeps its rules in an external
# stylesheet has neither marker — and that is the shape of every demo fixture in
# this repo — so under that rule /wp-init converts nothing, ever, and reports
# success. `tests/checks/wp-yolo-tailwind.sh` bans the same sentence from
# commands/wp-yolo.md and commands/wp-tailwindify.md; nothing gated wp-init.md,
# which is how it survived here.
#
# The assertions below gate the SHAPE of the replacement rule, mirroring the ones
# that guard Step 2.6: plain-CSS evidence must include a linked stylesheet and must
# resolve to "convert"; Tailwind evidence must be defined POSITIVELY, by utility
# classes; the skip must require both halves. Each is scoped to its own bullet, so
# a clause moved between bullets fails rather than passing.
# ---------------------------------------------------------------------------

# `bullet <raw-region> <label>` prints the ONE markdown list item of <raw-region>
# whose bullet line contains <label> — that line, its wrapped continuation lines
# and any nested sub-bullets, and nothing else — and exits 1 when no bullet
# carries the label. Copied from tests/checks/wp-yolo-tailwind.sh, where the long
# form of this comment lives, along with the two false-fails that shaped it: an
# item ends where markdown says it ends (next item at its own level, blank line,
# or a dedent), never at a neighbouring bullet's wording, so renaming or
# reordering a sibling cannot move it.
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

# Closure proof for each extracted bullet. `bullet` cannot run past the list by
# construction, but that is a claim to hold in place, not to trust. Structural on
# purpose — it says nothing about wording, so an ordinary cross-reference to a
# neighbouring bullet cannot fire it.
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
    || fail "Step D4's \"$self\" bullet is not closed — it swallowed $sib sibling bullet(s) at its own indent. Every assertion scoped to this bullet is then satisfiable from a neighbouring one, which is how a clause moved between bullets stops being caught."
  [ "$num" -eq 0 ] \
    || fail "Step D4's \"$self\" bullet is not closed — it ran on past the end of the bullet list into a numbered list ($num numbered item(s) inside it)."
  return 0
}

# `sentences <flat-text> <needle>` prints one line per occurrence of <needle>: the
# sentence it sits in, bounded by ". " on either side and capped at 240 characters
# each way. `undirected <flat-text> <needle> <lowercase-ERE>` prints every such
# sentence in which the ERE matches at a position NOT governed by a negation in
# the same clause — silence means the text is clean. Both are copied from
# tests/checks/wp-yolo-tailwind.sh; the reason they exist is that a bare grep for
# "skip" inside this bullet exits 1 on "Never skip the page because the only CSS
# it carries arrives through a link", which is this gate's own contract written
# into the file it guards. A gate that fails on work strengthening the contract it
# defends gets muted.
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

# Kept deliberately small: every token here reverses the claim it sits in front
# of. "instead of"/"rather than" are NOT in it — they reverse a choice of object,
# not a claim.
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

# The three bullet labels are frozen exact strings, deliberately: they are the
# rule's own structure — the three cases it decides between — and each FAIL
# message names the bullet it wants back, so a rename that is genuinely intended
# tells the author exactly what to update.
plain_raw=$(bullet "$d4_raw" '**Plain-CSS evidence') \
  || fail "Step D4's conversion rule has no \"Plain-CSS evidence\" bullet — it must enumerate what counts as evidence of plain CSS, or it is back to testing for the absence of a <style> block"
tw_raw=$(bullet "$d4_raw" '**Tailwind evidence') \
  || fail "Step D4's conversion rule has no \"Tailwind evidence\" bullet — a skip needs positive evidence of Tailwind-nativeness to rest on"
skip_raw=$(bullet "$d4_raw" '**Skip only') \
  || fail "Step D4's conversion rule has no \"Skip only ...\" bullet stating the condition under which a demo is left unconverted"
plain_ev=$(flat "$plain_raw")
tw_ev=$(flat "$tw_raw")
skip_ev=$(flat "$skip_raw")
bullet_closed '**Plain-CSS evidence' "$plain_raw"
bullet_closed '**Tailwind evidence'  "$tw_raw"
bullet_closed '**Skip only'          "$skip_raw"

# The other half of the closure proof: three disjoint bullets share no line, so an
# overrun that keeps printing a neighbour's continuation lines without ever
# printing its marker shows up here.
dup=$(printf '%s\n%s\n%s\n' "$plain_raw" "$tw_raw" "$skip_raw" \
      | grep -v '^[[:space:]]*$' | sort | uniq -d)
[ -z "$dup" ] \
  || fail "Step D4's three detect bullets are not disjoint — the same line appears in more than one of them, so a bullet ran past its own end: $(printf '%s' "$dup" | head -1)"

# 1. A linked stylesheet is plain-CSS evidence. This is the whole defect: without
#    it, every demo fixture in tests/fixtures/ (no <style>, no style=, rules in
#    assets/styles.css) classifies as already Tailwind-native and /wp-init
#    converts nothing.
#    The literal stops at the closing quote, not at the tag's `>`: writing the tag
#    the way a real page carries it — `<link rel="stylesheet" href="assets/styles.css">`
#    — is strictly an improvement, and gating the `>` form exits 1 on it.
printf '%s' "$plain_ev" | grep -qF '<link rel="stylesheet"' \
  || fail 'Step D4 does not count a `<link rel="stylesheet">` as plain-CSS evidence. A demo that keeps its rules in an external stylesheet has no <style> block and no style=" attribute, so under a rule that only tests for those it is silently declared already Tailwind-native and never converted — which is the original defect this branch exists to fix.'
# ...and the bullet has to resolve to CONVERT. Naming the evidence and then
# skipping on it would satisfy the assertion above and change nothing.
# Read from the whole bullet, label included: here the label IS the decision
# ("any one of these means convert"), so inverting it to "means skip" fails this
# assertion, and inverting the body instead is caught by the directional check
# below. Same split /wp-yolo Step 2.6's gate uses.
printf '%s' "$plain_ev" | grep -qiF 'convert' \
  || fail "Step D4's plain-CSS evidence bullet never says what plain-CSS evidence means for the demo: it means convert"
plain_skip=$(undirected "$plain_ev" 'skip' 'means skip|(^|[^a-z])skip (it|the demo|the page|that page|them)([^a-z]|$)')
plain_skip="$plain_skip$(undirected "$plain_ev" 'means it is' 'means it is (already )?tailwind')"
if [ -n "$plain_skip" ]; then
  fail "Step D4's plain-CSS evidence bullet directs a SKIP — plain-CSS evidence is the reason to convert, not the reason to skip: $plain_skip"
fi
# The carve-out has to come with it, or a Google Fonts link alone re-converts an
# already-Tailwind demo on every run and the step stops being idempotent.
printf '%s' "$plain_ev" | grep -qF 'fonts.googleapis.com' \
  || fail "Step D4's plain-CSS evidence bullet does not exempt Google Fonts — a webfont <link> is not project CSS, and counting it makes every converted demo convert again forever"
printf '%s' "$plain_ev" | grep -qF 'cdn.tailwindcss.com' \
  || fail "Step D4's plain-CSS evidence bullet does not exempt the Tailwind CDN — a demo linking it is the Tailwind-native case, not the plain-CSS one"
printf '%s' "$plain_ev" | grep -Eqi 'exempt|not plain-CSS evidence|do(es)? not count|never count' \
  || fail "Step D4's plain-CSS evidence bullet names the font/CDN hosts but never says they are exempt — the carve-out has to state that a <link> to them is NOT plain-CSS evidence"

# 2. Tailwind evidence must be defined POSITIVELY, by utilities. Defining it as
#    "no <style> block" is the defect wearing the new rule's clothes.
printf '%s' "$tw_ev" | grep -qi 'utilit' \
  || fail "Step D4's Tailwind-evidence bullet does not define Tailwind-nativeness by the presence of utility classes — absence of inline CSS is not evidence of anything"
if printf '%s' "$tw_ev" | grep -qF 'no `<style>` block'; then
  fail "Step D4 defines Tailwind evidence as the ABSENCE of a <style> block. That is the original heuristic: a plain-CSS demo with an external stylesheet satisfies it and is skipped."
fi

# 3. The skip needs BOTH halves — positive Tailwind evidence AND no plain-CSS
#    evidence — and the skip ACTION has to sit in the same bullet as its condition.
printf '%s' "$skip_ev" | grep -qF 'Tailwind evidence' \
  || fail "Step D4's skip bullet does not require positive Tailwind evidence — a skip on anything less is a skip on ignorance"
printf '%s' "$skip_ev" | grep -qF 'no plain-CSS evidence' \
  || fail "Step D4's skip bullet does not require the ABSENCE of plain-CSS evidence — a demo with both utilities and a project stylesheet must still be converted"
printf '%s' "$skip_ev" | grep -qiF 'conversion skipped' \
  || fail "Step D4's skip condition and the skip it authorises are in different bullets — the report line \`demo already tailwind-native — conversion skipped\` must be emitted by the bullet that states the condition, or the two drift apart"
# ...and the operator still has to say which way it went. That predates this rule
# and survives it.
printf '%s' "$d4" | grep -qiF 'which case applied' \
  || fail "Step D4 no longer requires the operator to say which case applied"

# 4. Literal backstop against the exact sentences this rule replaced — wp-init's
#    own form first, then the /wp-yolo form that tests/checks/wp-yolo-tailwind.sh
#    bans from the other two files, because a copy-paste from either is how it
#    comes back. The bullet assertions above already fail if the rule is replaced
#    wholesale; these catch the other shape of regression — the old sentence being
#    ADDED BACK alongside the new bullets, leaving the step self-contradictory
#    with the wrong half stated first.
if printf '%s' "$d4" | grep -qF 'Skip only if the demo has no `<style>` block and no static `style="` attribute'; then
  fail "Step D4 carries the original heuristic again: absence of inline CSS is not proof of Tailwind-nativeness, and every demo fixture in this repo is the counter-example"
fi
if printf '%s' "$d4" | grep -qF 'no `<style>` block and no static `style="` attribute, it is already Tailwind-native'; then
  fail "Step D4 carries /wp-yolo's original heuristic, which wp-yolo-tailwind.sh already bans from the two other files that state this rule"
fi

# ---------------------------------------------------------------------------
# /wp-finalize
# ---------------------------------------------------------------------------
printf '%s' "$fin" | grep -qF 'bin/tailwind-native-check.sh' \
  || fail "wp-finalize does not run the tailwind-native check"

# The gate must be scoped to the tailwind template — an unconditional run would fail
# every basic project on a missing main.css.
printf '%s' "$fin" | grep -qF 'Skip when `Template:` is `basic`' \
  || fail "wp-finalize's tailwind check is not gated on the template"

# Step 4b: Layer 3 must compare the converted demo against the pristine original,
# because on the tailwind path the demo URL now serves the converted page and a
# conversion error appears on BOTH sides of the old comparison.
# Anchor on the ASCII substring, not on the heading's em-dash — a bare `.` does not
# match a multibyte char under LC_ALL=C.
# The closure proof must read the CAPTURED REGION, not the file. `grep -q '^## Step
# 4:' commands/wp-finalize.md` proved only that the heading exists SOMEWHERE, which
# says nothing about whether this awk range ever reached it — and a range whose
# terminator never matches runs to EOF, turning both needles below into file-wide
# greps. Proven latent by moving the Layer 3 subsection to sit directly after
# `## Step 4:`, stripping its two needles from it, and leaving them in a sentence at
# end of file: the old form printed PASS. So the awk now prints a sentinel at the
# point it stopped, and the sentinel — not the heading — is what proves the range
# closed on its terminator rather than on EOF.
# The `|| true` on the strip is load-bearing: a region holding nothing but the
# sentinel makes `grep -Fv` match nothing and exit 1, which under `set -euo pipefail`
# kills the script from inside the command substitution — rc=1 and no FAIL printed.
l3raw=$(awk '/Layer 3 \(measured visual parity/{f=1;next} f&&/^## Step 4:/{print "__END__"; exit} f' "$wp_finalize")
# Emptiness first, so a DELETED subsection reports itself as deleted rather than as
# an unterminated range — both exit 1, but only one of them names the mutation.
[ -n "$l3raw" ] || fail "no Layer 3 section in wp-finalize.md"
printf '%s' "$l3raw" | grep -qF '__END__' \
  || fail "the Layer 3 region is not terminated by a '## Step 4:' heading — the awk range ran to EOF and its assertions would silently degrade to file-wide greps"
l3=$(flat "$(printf '%s\n' "$l3raw" | { grep -Fv '__END__' || true; })")
[ -n "$l3" ] || fail "the Layer 3 section holds nothing but its terminator"
printf '%s' "$l3" | grep -qF 'demo/.original/' \
  || fail "Layer 3 never reads demo/.original/ — on the tailwind path it compares the converted demo against a build made from that same converted demo, so a conversion defect cancels out"
printf '%s' "$l3" | grep -qF 'conversion defect' \
  || fail "Layer 3 does not distinguish a conversion defect from a build defect"

# ---------------------------------------------------------------------------
# Check 3 must branch on Template:. It read assets/css/styles.css and demanded
# @media at fixed pixel breakpoints, a file the Tailwind convention check FAILS
# delivery for existing and a mechanism the SKILL forbids — one run, two
# checks, opposite demands, and a correct Tailwind theme always reported a
# spurious failure. Scope to the Check 3 region and prove the range closed.
# ---------------------------------------------------------------------------
c3raw=$(awk '/^### Check 3/,/^### Check 4/' "$wp_finalize")
[ -n "$c3raw" ] || fail "wp-finalize has no Check 3 region"
printf '%s\n' "$c3raw" | tail -1 | grep -q '^### Check 4' \
  || fail "the Check 3 region is not terminated by a '### Check 4' heading — its assertions would silently become file-wide"
c3=$(flat "$c3raw")
printf '%s' "$c3" | grep -qF 'If `Template:` is `basic`' \
  || fail "Check 3 never branches on the template — it reads assets/css/styles.css and demands @media, which the Tailwind convention check in the same command fails delivery for existing"
printf '%s' "$c3" | grep -qF 'If `Template:` is `tailwind`' \
  || fail "Check 3 has a basic branch but no tailwind branch — on tailwind the check still reads a file that must not exist"
printf '%s' "$c3" | grep -qF 'responsive prefixes' \
  || fail "Check 3's tailwind branch never points at the Tailwind responsive-prefix equivalent — with no @media allowed, the branch must name what it checks instead"
printf '%s' "$c3" | grep -qF 'at least 3 of the four' \
  || fail "Check 3's basic branch no longer says 'at least 3 of the four' breakpoints — the old text promised 3 of 5 while listing 4"

# The Tailwind convention gate must skip EVERY non-tailwind template, not just
# basic: a cinematic project has its own assets/css/cinematic.css and would
# fall through 'skip basic, run tailwind' into a gate written for the other
# tree.
printf '%s' "$fin" | grep -qF 'anything other than `tailwind`' \
  || fail "the Tailwind convention check only skips basic — a cinematic project falls through and runs the tailwind gate against assets/css/cinematic.css"

echo PASS
