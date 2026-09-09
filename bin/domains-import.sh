#!/usr/bin/env bash
# Rebuild references/domains/domains.csv from the upstream MIT catalogue.
#
# Takes only the shape columns. Upstream's products.csv is nine columns; we keep
# Product Type, Keywords, Landing Page Pattern and Key Considerations, and fold
# the style recommendation into the considerations text because this plugin
# already owns style through its grammars and compositions. The colour and
# typography tables are not imported at all — see references/domains/README.md.
#
# Confidence comes from upstream's own data-provenance.json where a record
# exists for the row, and defaults to 0.5 where none does, so a weak match can
# be reported as weak rather than asserted.
set -euo pipefail
cd "$(dirname "$0")/.."
d=skills/wp-demo-craft/references/domains
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q --depth 1 https://github.com/nextlevelbuilder/ui-ux-pro-max-skill "$tmp/up"
src="$tmp/up/src/ui-ux-pro-max/data/products.csv"
prov="$tmp/up/src/ui-ux-pro-max/data/data-provenance.json"
[ -f "$src" ] || { echo "upstream products.csv not found; the catalogue moved" >&2; exit 1; }

mkdir -p "$d"
cp "$tmp/up/LICENSE" "$d/LICENSE"

# The clone above is unpinned (always `main`), so a version string in README.md
# would go stale the moment upstream tags a release. Record what was actually
# imported instead: the ref, the exact commit, and the date, so provenance is a
# fact recorded at import time rather than a claim that has to be kept in sync.
sha=$(git -C "$tmp/up" rev-parse HEAD)
ref=$(git -C "$tmp/up" symbolic-ref --short HEAD 2>/dev/null || echo HEAD)
cat > "$d/SOURCE.txt" <<EOF
Source: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
Ref: $ref
Commit: $sha
Imported: $(date -u +%Y-%m-%d)
EOF

python3 - "$src" "$prov" > "$d/domains.csv" <<'PY'
import csv, json, sys, re

src, prov = sys.argv[1], sys.argv[2]
conf = {}
try:
    for rec in json.load(open(prov)).get("records", []):
        eid = (rec.get("entityId") or "").lower()
        if eid:
            conf[eid] = rec.get("confidence", 0.5)
except Exception:
    pass

def slug(s):
    # Upstream's own entityIds spell "&" out as "-and-" (q-and-a-community-platform),
    # so a bare punctuation strip turns "&" into a hyphen instead and the lookup
    # misses — silently falling back to the 0.5 default, indistinguishable from a
    # genuine weak match. Normalise before stripping.
    s = re.sub(r"\s*&\s*", " and ", s.lower())
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")

out = csv.writer(sys.stdout, lineterminator="\n")
out.writerow(["domain", "keywords", "page_pattern", "considerations", "confidence"])
for row in csv.DictReader(open(src)):
    domain = (row.get("Product Type") or "").strip()
    kw = (row.get("Keywords") or "").strip()
    if not domain or not kw:
        continue
    pattern = (row.get("Landing Page Pattern") or "").strip()
    cons = (row.get("Key Considerations") or "").strip()
    style = (row.get("Primary Style Recommendation") or "").strip()
    if style:
        cons = (cons + " " if cons else "") + f"Style leaning: {style}."
    out.writerow([domain, kw, pattern, cons, conf.get(slug(domain), 0.5)])
PY

echo "wrote $d/domains.csv ($(($(wc -l < "$d/domains.csv") - 1)) rows)"
