#!/usr/bin/env bash
# Seeded-defects corpus (tests/fixtures/seeded-defects): a theme and plugin with deliberate
# defects and expected-findings.json naming the audit check that must fire for each. Without
# this, nothing says whether an edit to an audit agent stopped it seeing a defect it used to
# catch, and the "expected" list can rot away from the fixture it describes.
#
# Offline half (always runs): the JSON has the right shape, every code is in the catalog of
# the audit that owns its domain, every defect is still in its file, and every file's
# SEEDED marker names the same code.
# Comparison half: every expected code must appear as a FAIL. Always runs against the
# committed recorded-findings.json (plus a negative case with one finding removed); when
# SEEDED_FINDINGS points at the findings JSON of a real /wp-audit run it compares that too.
# The real-run comparison is NOT exercised in CI, which has no audit run to compare.
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

# ...without its SEEDED markers: the HTML and CSS comments are served, and an audit that reads
# "SEEDED A11Y-007" in the page source is handed the answer. Run the same strip provision.sh
# runs on a scratch copy: no marker survives, every defect does, the PHP still parses, and a
# marker written inline (which the line rule cannot remove) fails the copy.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cp -R "$fx/theme" "$fx/plugin" "$scratch/"
bash tests/fixtures/wp/provision.sh --strip-seeded "$scratch" >/dev/null 2>&1 || fail "provision.sh --strip-seeded failed on the corpus"
if left=$(grep -rlE 'SEEDED [A-Z0-9]+-[0-9]+' "$scratch"); then fail "SEEDED markers survive the copy: $left"; fi
while IFS=$'\t' read -r code file pattern; do
  grep -Fq -- "$pattern" "$scratch/$file" || fail "$code: stripping the markers removed the defect itself from $file"
done < <(jq -r '.defects[] | [.check,.file,.pattern] | @tsv' "$exp")
if command -v php >/dev/null; then
  while IFS= read -r p; do php -l "$p" >/dev/null || fail "php -l failed after stripping: $p"; done < <(find "$scratch" -name '*.php')
fi
# Three markers the line rule must refuse rather than delete: one after code, one before code
# (deleting that line would delete the defect), one opening a block comment that runs on.
for bad in '<?php echo 1; // SEEDED SEC-999: inline' '/* SEEDED A11Y-999: x */ a:focus{outline:0}' $'/* SEEDED PERF-999: runs\n   on */'; do
  rm -f "$scratch/theme/inline.css"
  printf '%s\n' "$bad" > "$scratch/theme/inline.css"
  if bash tests/fixtures/wp/provision.sh --strip-seeded "$scratch" >/dev/null 2>&1; then
    fail "provision.sh --strip-seeded accepted a marker it cannot remove whole: $bad"
  fi
done
rm -rf "$scratch"

# The comparison itself, as a function so the same logic runs against the recorded audit
# (always) and against a real run (SEEDED_FINDINGS). Prints the missed codes, empty when none.
missed_codes() {
  local fired c missed=""
  # A check id may carry a revision (SEC-036@2, see CLAUDE.md); the expected codes are bare ids.
  # A code folded under another FAIL's also_affects (the renderer's root-cause fold) fired too:
  # the report counts it as present, so the comparison does. Under a non-FAIL row it did not.
  fired=$(jq -r '[.findings[] | select(.status == "FAIL") | .check, ((.also_affects // [])[] | if type == "object" then .check else . end)] | map(select(type == "string")) | unique[]' "$1" | sed 's/@.*//')
  for c in $listed; do grep -Fxq "$c" <<<"$fired" || missed="$missed $c"; done
  printf '%s' "$missed"
}

# Recorded half (always runs): a committed findings file standing for a correct audit, so the
# comparison logic is exercised in CI. Then a negative case: the same file with one finding
# removed must be reported as missing that defect.
rec=$fx/recorded-findings.json
[ -f "$rec" ] || fail "$rec is missing"
m=$(missed_codes "$rec")
[ -z "$m" ] || fail "the recorded audit misses seeded defects:$m (re-record it or fix the corpus)"
first=$(printf '%s\n' "$listed" | sed -n 1p)
neg=$(mktemp)
trap 'rm -rf "$scratch"; rm -f "$neg" "$neg.fold"' EXIT
drop='.findings |= map(select((.check | sub("@.*"; "")) != $c) | if .also_affects then .also_affects |= map(select(((if type == "object" then .check else . end) | sub("@.*"; "")) != $c)) else . end)'
jq --arg c "$first" "$drop" "$rec" > "$neg"
m=$(missed_codes "$neg")
[ "$m" = " $first" ] || fail "negative case: dropping $first from the recorded audit should miss exactly it, got '$m'"

# also_affects: the dropped code folded under another FAIL counts as fired; folded under a
# PASS row it does not.
host=$(jq -r --arg c "$first" '[.findings[] | select(.status == "FAIL" and ((.check | sub("@.*"; "")) != $c))][0].check' "$neg")
jq --arg c "$first" --arg h "$host" '.findings |= map(if .check == $h then .also_affects = ((.also_affects // []) + [{check: $c, resource: "site"}]) else . end)' "$neg" > "$neg.fold"
m=$(missed_codes "$neg.fold")
[ -z "$m" ] || fail "also_affects: $first folded under $host should count as fired, got missed '$m'"
jq --arg c "$first" '.findings += [{check: "WP-000", status: "PASS", also_affects: [{check: $c, resource: "site"}]}]' "$neg" > "$neg.fold"
m=$(missed_codes "$neg.fold")
[ "$m" = " $first" ] || fail "also_affects under a PASS row must not count as fired, got '$m'"

if [ -n "${SEEDED_FINDINGS:-}" ]; then
  [ -f "$SEEDED_FINDINGS" ] || fail "SEEDED_FINDINGS=$SEEDED_FINDINGS does not exist"
  m=$(missed_codes "$SEEDED_FINDINGS")
  [ -z "$m" ] || fail "the audit missed seeded defects:$m"
  echo "compared against $SEEDED_FINDINGS: all $n fired"
else
  echo "compared against the recorded audit ($rec): all $n fired; set SEEDED_FINDINGS to also compare a real run"
fi
echo PASS
