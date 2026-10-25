#!/usr/bin/env bash
# Seeded-defects corpus (tests/fixtures/seeded-defects): a theme and plugin with deliberate
# defects and expected-findings.json naming the audit check that must fire for each. Without
# this, nothing says whether an edit to an audit agent stopped it seeing a defect it used to
# catch, and the "expected" list can rot away from the fixture it describes.
#
# Offline half (always runs): the JSON has the right shape, every code is in the catalog of
# the audit that owns its domain, every defect is still in its file, and every file's
# SEEDED marker names the same code.
# Comparison half (only when SEEDED_FINDINGS points at the findings JSON of a real
# /wp-audit run over the fixture): every expected code must appear as a FAIL. That half is
# NOT exercised in CI, which has no audit run to compare.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v jq >/dev/null || { echo "SKIP: jq not installed"; exit 0; }

fx=tests/fixtures/seeded-defects
exp=$fx/expected-findings.json
[ -f "$exp" ] || fail "$exp is missing"

jq -e '.version == 1 and (.defects | type == "array")' "$exp" >/dev/null || fail "$exp: needs version 1 and a defects array"
n=$(jq '.defects | length' "$exp")
[ "$n" -ge 8 ] && [ "$n" -le 12 ] || fail "corpus has $n defects, expected 8 to 12"
jq -e 'all(.defects[]; (.check|type=="string") and (.domain|type=="string") and (.file|type=="string") and (.pattern|type=="string") and (.pattern|length>0))' "$exp" >/dev/null \
  || fail "a defect lacks check, domain, file or pattern"
[ "$(jq '[.defects[].check] | unique | length' "$exp")" -eq "$n" ] || fail "a check code is listed twice"
for d in security accessibility seo performance best-practices; do
  jq -e --arg d "$d" '[.defects[].domain] | index($d) != null' "$exp" >/dev/null || fail "corpus has no defect in the $d domain"
done

while IFS=$'\t' read -r code domain file pattern; do
  case "$domain" in
    security) catalog=agents/wp-audit-security.md ;;
    accessibility) catalog=agents/wp-audit-a11y.md ;;
    seo) catalog=agents/wp-audit-seo.md ;;
    performance) catalog=agents/wp-audit-performance.md ;;
    best-practices) catalog=agents/wp-audit-practices.md ;;
    *) fail "$code: unknown domain $domain" ;;
  esac
  [ -f "$catalog" ] || fail "$code: catalog $catalog does not exist"
  grep -Fq "| $code |" "$catalog" || fail "$code is not a check in $catalog"
  [ -f "$fx/$file" ] || fail "$code: $fx/$file does not exist"
  grep -Fq -- "$pattern" "$fx/$file" || fail "$code: pattern not found in $file (defect fixed or reworded?): $pattern"
  grep -Fq "SEEDED $code" "$fx/$file" || fail "$code: $file has no 'SEEDED $code' marker"
done < <(jq -r '.defects[] | [.check,.domain,.file,.pattern] | @tsv' "$exp")

# No marker without an entry (scans every fixture source file, not just listed ones; the JSON and
# the README are excluded so prose about a marker is not read as one). An unlisted seeded defect
# would be invisible to the comparison. grep exits 1 on no match, so it is tolerated here and the
# diff below reports the empty side by name instead of the script dying silently.
listed=$(jq -r '.defects[].check' "$exp" | LC_ALL=C sort -u)
found=$( { grep -rhoE --exclude='*.json' --exclude='*.md' 'SEEDED [A-Z0-9]+-[0-9]+' "$fx" 2>/dev/null || true; } | awk '{print $2}' | LC_ALL=C sort -u)
if ! drift=$(diff <(printf '%s\n' "$listed") <(printf '%s\n' "$found")); then
  fail "SEEDED markers and expected-findings.json disagree (< only in expected-findings.json, > only in markers):
$drift"
fi

# The fixture must be valid PHP, or the audits see a parse error instead of the defects.
if command -v php >/dev/null; then
  while IFS= read -r p; do php -l "$p" >/dev/null || fail "php -l failed: $p"; done < <(find "$fx" -name '*.php')
fi

# provision.sh must still hand the corpus to a real WordPress.
[ -f tests/fixtures/wp/provision.sh ] || fail "tests/fixtures/wp/provision.sh does not exist"
grep -Fq 'WP_FIXTURE_SEEDED' tests/fixtures/wp/provision.sh || fail "provision.sh lost WP_FIXTURE_SEEDED"

if [ -n "${SEEDED_FINDINGS:-}" ]; then
  [ -f "$SEEDED_FINDINGS" ] || fail "SEEDED_FINDINGS=$SEEDED_FINDINGS does not exist"
  # A check id may carry a revision (SEC-036@2, see CLAUDE.md); the expected codes are bare ids.
  fired=$(jq -r '[.findings[] | select(.status == "FAIL") | .check] | unique[]' "$SEEDED_FINDINGS" | sed 's/@.*//')
  missed=""
  for c in $listed; do grep -Fxq "$c" <<<"$fired" || missed="$missed $c"; done
  [ -z "$missed" ] || fail "the audit missed seeded defects:$missed"
  echo "compared against $SEEDED_FINDINGS: all $n fired"
else
  echo "SKIP: SEEDED_FINDINGS not set, the comparison with a real audit run was NOT exercised"
fi
echo PASS
