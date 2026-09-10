#!/usr/bin/env bash
# The domain table's page_pattern and considerations feed the brief as stated
# constraints — never a mapping onto this project's own section roles, which the
# catalogue's free-text patterns have no correspondence to. It is vendored from
# an MIT catalogue, so the licence travels with it, and it carries ONLY the shape
# columns: which page pattern a category wants and what it must consider. The
# colour and typography columns of that catalogue are deliberately absent — it
# maps 192 product types onto 50 primary colours and pairs Playfair Display with
# Inter, which would fight the fingerprint gate and the type floor. A future
# contributor who re-imports the whole thing reintroduces exactly the sameness
# this plugin exists to refuse, so the refusal is asserted here.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=skills/wp-demo-craft/references/domains

[ -f "$d/LICENSE" ] || fail "$d/LICENSE is missing; the table is vendored and its licence travels with it"
grep -Fqi 'MIT' "$d/LICENSE" || fail "$d/LICENSE is not the MIT text"
[ -f "$d/domains.csv" ] || fail "$d/domains.csv is missing"
[ -f "$d/README.md" ] || fail "$d/README.md is missing"

head -1 "$d/domains.csv" | grep -Fq 'domain,keywords,page_pattern,considerations,confidence' \
  || fail "$d/domains.csv header is not: domain,keywords,page_pattern,considerations,confidence"

n=$(tail -n +2 "$d/domains.csv" | wc -l)
[ "$n" -ge 185 ] || fail "expected at least 185 domain rows, found $n"

# Every row must carry keywords, or it can never match anything. The keywords
# field is a quoted CSV field that itself contains commas, so a naive
# comma-split (awk -F',') lands inside the quotes and never sees an empty
# field — use a real CSV parser.
python3 -c "
import csv,sys
bad=[i for i,r in enumerate(csv.DictReader(open('$d/domains.csv')),2) if not (r.get('keywords') or '').strip()]
sys.exit('rows with no keywords: '+str(bad[:5]) if bad else 0)
" || fail "$d/domains.csv has a row with no keywords, which can never match"

# The refusal, stated and asserted. The bare words 'colour' and 'typography'
# each appear more than once in the README (the heading, the recap), so a
# whole-word grep survives deleting the one sentence that actually carries the
# reasoning and leaves the check green with the reasoning gone. Anchor on the
# reasoning clause itself, which appears exactly once.
grep -Fq '192 product types onto 50 distinct primary colours' "$d/README.md" \
  || fail "$d/README.md does not carry the colour-table refusal reasoning (the 192-onto-50 ratio)"
grep -Fq 'pairs Playfair Display with Inter' "$d/README.md" \
  || fail "$d/README.md does not carry the typography-refusal reasoning (the named Playfair/Inter pairing)"
grep -Fq 'nextlevelbuilder/ui-ux-pro-max-skill' "$d/README.md" || fail "$d/README.md does not name the source"
grep -Eq '^(No,)?Primary,|On Primary|Heading Font' "$d/domains.csv" \
  && fail "$d/domains.csv carries colour or typography columns; only shape columns are vendored"
# The header guard above only catches a literal column reimport. Nothing stops
# colour or type data folded into considerations prose instead — the same
# technique the importer already uses for the style recommendation — so guard
# the whole file against a hex literal, which colour data would need to carry.
grep -Eq '#[0-9A-Fa-f]{6}' "$d/domains.csv" \
  && fail "$d/domains.csv carries a hex colour literal; colour must not enter through prose either"
# A hex literal is only one shape colour data takes, and not the one the upstream
# catalogue uses: its style-recommendation column is prose ("Primary colour: deep
# blue"), and bin/domains-import.sh:70-72 already folds that column into
# `considerations`. So fold one sentence and the hex guard above never fires. Grep a
# colour-name and font-name vocabulary over the considerations column itself.
# `inter` needs more than a word boundary: the one live hit in the current CSV is
# "Inter-page linking" in the Wiki row, so the font pattern excludes a following
# hyphen. Anything this rejects wrongly belongs in page_pattern or nowhere.
python3 -c "
import csv,re,sys
colours=r'black|white|red|orange|yellow|green|blue|purple|violet|pink|brown|gr[ae]y|teal|cyan|magenta|indigo|amber|navy|gold|silver|beige|cream|crimson|turquoise|lavender|maroon|olive|coral'
fonts=r'inter(?!-)|playfair|roboto|montserrat|lato|open sans|poppins|raleway|oswald|merriweather|nunito|source sans|helvetica|georgia|garamond|futura|manrope|dm sans|space grotesk|work sans|rubik|karla|lora|mulish|quicksand'
bad=[]
for i,r in enumerate(csv.DictReader(open('$d/domains.csv')),2):
    for kind,pat in (('colour',colours),('font',fonts)):
        m=re.search(r'\b(?:'+pat+r')\b', r.get('considerations') or '', re.I)
        if m: bad.append('row %d (%s): %s name %r' % (i, r['domain'], kind, m.group(0)))
sys.exit('; '.join(bad[:5]) if bad else 0)
" || fail "$d/domains.csv folds a colour or font name into considerations; only shape data is vendored"

[ -x bin/domains-import.sh ] || fail "bin/domains-import.sh is missing or not executable"

[ -f "$d/SOURCE.txt" ] || fail "$d/SOURCE.txt is missing; the imported commit must be recorded, not just a version claim"
grep -Eq '^Commit: [0-9a-f]{7,40}$' "$d/SOURCE.txt" \
  || fail "$d/SOURCE.txt does not name the imported commit"

# Both craft entry points must actually use the table: read it, record the
# match, gate the threshold, tie-break it, define the non-English and
# unclassified fallbacks, and — the whole point of the table — never let it
# decide colour or type. /wp-yolo never calls /wp-demo (same reason the browser
# gate above is checked in both files, not just one), so it must run the same
# classification itself, in the same terms.
for f in commands/wp-demo.md commands/wp-yolo.md; do
  grep -Fq 'references/domains/domains.csv' "$f" || fail "$f does not read the domain table"
  grep -Fq '"domain"' "$f" || fail "$f does not record the domain in the manifest"
  grep -Fq 'two distinct keyword' "$f" || fail "$f does not state the two-keyword threshold"
  grep -Fq 'unclassified' "$f" || fail "$f does not define the unclassified outcome"
  grep -Eqi 'never (touch|decide|choose) (the )?tokens|never touches tokens' "$f" \
    || fail "$f does not forbid the classifier from touching tokens"
  grep -Eqi 'highest hit count' "$f" \
    || fail "$f does not tie-break multiple domains clearing the threshold by hit count"
  grep -Eqi 'exact tie' "$f" || fail "$f does not say what happens on an exact tie for the top count"
  grep -Eqi 'english-only' "$f" || fail "$f does not say the keyword lists are English-only"
  grep -Fq 'with that reason stated' "$f" \
    || fail "$f falls through to unclassified for non-English docs without stating why"
  grep -Eqi 'name the domain directly' "$f" \
    || fail "$f does not let the operator name the domain directly when matching can't"
done

# page_pattern cannot constrain section roles — the catalogue's 77 free-text
# patterns (things like "Bento Grid Showcase") have no correspondence to this
# project's fixed roles, and building that mapping would be mostly arbitrary.
# The real binding lives in the composition plan (sub-step 5): every row must
# cite the brief constraint or domain signal that justified it, or say there
# isn't one — that is what is verified here, not a pattern-to-role mapping.
c=commands/wp-demo.md
grep -Fq 'page_pattern' "$c" || fail "$c does not fold the domain's page_pattern into the brief as a constraint"
# 'no domain signal' contains 'domain signal' as a substring, so anchoring the
# positive-case assertion on the short form would make it pass off the fallback
# phrase alone and never fail on its own — anchor on the longer phrase instead.
grep -Fq 'domain signal that justified' "$c" || fail "$c's composition plan does not require a domain signal (or brief constraint) per row"
grep -Fq 'no domain signal' "$c" || fail "$c does not define the no-domain-signal fallback for a row the domain does not touch"

# /wp-yolo's craft branch never runs its own composition-plan procedure — it
# delegates to skills/wp-demo-craft/SKILL.md's order of work (step 3), so the
# domain-signal column has to live there too, or the classification stays
# inert on the path a one-shot builder most likely uses.
k=skills/wp-demo-craft/SKILL.md
grep -Fq 'domain signal that justified' "$k" \
  || fail "$k's composition-plan step does not require a domain signal (or brief constraint) per row"
grep -Fq 'no domain signal' "$k" \
  || fail "$k does not define the no-domain-signal fallback for a row the domain does not touch"

# SKILL.md cites references/compositions.md as the source of the role table, so a
# builder following that pointer writes the plan from the row printed THERE. It
# carried the pre-classifier five-column row for a release, which is a plan written
# with the classification unread — the exact failure the rest of this file prevents.
# The literal row is asserted as well as the prose: the prose alone would survive a
# revert of the row to five columns.
r=skills/wp-demo-craft/references/compositions.md
grep -Fq 'section | role | composition | why | motion cost | domain signal' "$r" \
  || fail "$r's composition-plan row is not the six-column form ending in domain signal"
grep -Fq 'domain signal that justified' "$r" \
  || fail "$r does not require a domain signal (or brief constraint) per row"
grep -Fq 'no domain signal' "$r" \
  || fail "$r does not define the no-domain-signal fallback for a row the domain does not touch"

# The manifest is the shared source of truth: a domain already recorded must be read,
# not re-derived, the same rule /wp-yolo already applies four lines above to
# `demo mode` — and the one commands/wp-demo.md itself promises when it says the
# recorded domain is what "/wp-yolo reads ... rather than re-deriving it". The rule
# has to hold on BOTH entry points or it is not a property of the manifest: with it
# only in /wp-yolo, a second /wp-demo run silently overwrote an operator's
# "name the domain directly" override with the match it had already been rejected for.
for y in commands/wp-yolo.md commands/wp-demo.md; do
  grep -Fq 'already has `"domain"`' "$y" \
    || fail "$y does not check for an already-recorded domain before classifying"
  grep -Fq 'do not re-classify' "$y" \
    || fail "$y does not skip re-classification once the domain is already recorded"
done

echo PASS
