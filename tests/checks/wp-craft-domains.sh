#!/usr/bin/env bash
# The domain table decides which section roles a build may reach for. It is
# vendored from an MIT catalogue, so the licence travels with it, and it carries
# ONLY the shape columns: which page pattern a category wants and what it must
# consider. The colour and typography columns of that catalogue are deliberately
# absent — it maps 192 product types onto 50 primary colours and pairs Playfair
# Display with Inter, which would fight the fingerprint gate and the type floor.
# A future contributor who re-imports the whole thing reintroduces exactly the
# sameness this plugin exists to refuse, so the refusal is asserted here.
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
[ "$n" -ge 150 ] || fail "expected at least 150 domain rows, found $n"

# Every row must carry keywords, or it can never match anything. The keywords
# field is a quoted CSV field that itself contains commas, so a naive
# comma-split (awk -F',') lands inside the quotes and never sees an empty
# field — use a real CSV parser.
python3 -c "
import csv,sys
bad=[i for i,r in enumerate(csv.DictReader(open('$d/domains.csv')),2) if not (r.get('keywords') or '').strip()]
sys.exit('rows with no keywords: '+str(bad[:5]) if bad else 0)
" || fail "$d/domains.csv has a row with no keywords, which can never match"

# The refusal, stated and asserted.
grep -Fq 'colour' "$d/README.md" || fail "$d/README.md does not say the colour table was refused"
grep -Eqi 'font pairing|typography' "$d/README.md" || fail "$d/README.md does not say the font pairings were refused"
grep -Fq 'nextlevelbuilder/ui-ux-pro-max-skill' "$d/README.md" || fail "$d/README.md does not name the source"
grep -Eq '^(No,)?Primary,|On Primary|Heading Font' "$d/domains.csv" \
  && fail "$d/domains.csv carries colour or typography columns; only shape columns are vendored"

[ -x bin/domains-import.sh ] || fail "bin/domains-import.sh is missing or not executable"

echo PASS
