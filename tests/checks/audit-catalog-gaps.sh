#!/usr/bin/env bash
# Catalog gaps that forced auditors to invent ids: CLS, INP, Content-Security-Policy,
# and a soft-404 check that probes more than one path shape on more than one host.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }
need() { grep -qF -- "$2" "$1" || fail "$1 lacks: $2"; }

perf=agents/wp-audit-performance.md
sec=agents/wp-audit-security.md
geo=agents/wp-audit-geo.md
std=skills/wp-audit-geo-standards/SKILL.md

grep -qE '^\| PERF-068 \|' "$perf" || fail "PERF-068 (CLS) not tabulated"
grep -qE '^\| PERF-069 \|' "$perf" || fail "PERF-069 (INP) not tabulated"
need "$perf" "layout-shift"
need "$perf" "hadRecentInput"
need "$perf" "interactionId"
need "$perf" "UNMEASURED"

grep -qE '^\| SEC-044 \|' "$sec" || fail "SEC-044 (CSP) not tabulated"
need "$sec" "content-security-policy"
need "$sec" "production only"
need "$sec" "needs the public URL"

need "$geo" "Procedure — soft-404 shapes"
for t in "made-up top-level" "nested path" "near-prefix" "redirect_guess_404_permalink" ".php" ".html" "apex" "www" "apex-to-"; do
  grep -qi -- "$t" <(sed -n '/Procedure — soft-404 shapes/,/Procedure — rendered-head/p' "$geo") \
    || grep -qi -- "${t#made-up }" <(sed -n '/Procedure — soft-404 shapes/,/Procedure — rendered-head/p' "$geo") \
    || fail "$geo soft-404 procedure lacks: $t"
done
need "$geo" "one passing shape does not pass"
need "$std" "redirect_guess_404_permalink"

# archive bases are read, never assumed
need skills/wp-audit-seo-standards/SKILL.md "category_base"
need skills/wp-audit-seo-standards/SKILL.md "tag_base"
if grep -rn 'example.com/category/"' skills agents >/dev/null 2>&1; then
  fail "a hardcoded /category/ URL is back"
fi

echo PASS
