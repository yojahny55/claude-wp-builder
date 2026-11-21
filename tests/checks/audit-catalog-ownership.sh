#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# The audit catalog keeps one owner per defect, one PHP floor, WCAG 2.2 AA coverage,
# no report files written inside the site, and never reuses a retired check id.

fail() { echo "FAIL: $1"; exit 1; }

A11Y=agents/wp-audit-a11y.md
SEC=agents/wp-audit-security.md
PERF=agents/wp-audit-performance.md
WP=agents/wp-audit-practices.md
SEO=agents/wp-audit-seo.md
STD=skills/wp-audit-standards/SKILL.md
CMD=commands/wp-audit.md

# Row text for a code: the whole table line, or empty.
row() { grep -m1 -E "^\| $2(@[0-9]+)? \|" "$1" || true; }
# First word of the severity column (second-last cell, before Auto-fix, or last cell).
sev() {
  local line=$1 cells
  IFS='|' read -ra cells <<<"$line"
  local n=${#cells[@]} i=$((${#cells[@]} - 1))
  # Trailing empty cell after the final pipe.
  [ -z "${cells[$i]// /}" ] && i=$((i - 1))
  local last=${cells[$i]}
  # Auto-fix columns are Yes/No; the severity is then the cell before it.
  case "${last// /}" in Yes|No) i=$((i - 1)); last=${cells[$i]};; esac
  last=${last# }
  echo "${last%% *}"
  : "$n"
}

# --- WCAG 2.2 AA ---
for f in "$A11Y" README.md; do
  if grep -q 'WCAG 2.1 AA' "$f"; then fail "$f still states WCAG 2.1 AA"; fi
done
for pair in 070:2.4.11 071:3.3.8 072:2.5.7 073:3.3.7 074:3.2.6; do
  id=A11Y-${pair%%:*}; crit=${pair##*:}
  r=$(row "$A11Y" "$id")
  [ -n "$r" ] || fail "$A11Y: $id is not a table row"
  case "$r" in *"$crit"*) ;; *) fail "$id does not name criterion $crit";; esac
done

# --- one PHP floor ---
r=$(row "$SEC" SEC-026)
[ -n "$r" ] || fail "$SEC: SEC-026 row missing"
case "$r" in *"8.2"*) ;; *) fail "SEC-026 must carry the 8.2 floor";; esac
for spec in "$PERF:PERF-040" "$WP:WP-042"; do
  r=$(row "${spec%%:*}" "${spec##*:}")
  [ -n "$r" ] || fail "${spec##*:} row missing"
  if grep -qE '[0-9]\.[0-9]' <<<"$r"; then fail "${spec##*:} must not carry a version number; SEC-026 owns it"; fi
done

# --- same defect, one owner ---
grep -q 'Same defect, one owner' "$STD" || fail "$STD lacks the Same defect, one owner table"
grep -q 'Same defect, one owner' "$CMD" || fail "$CMD does not mention the Same defect table"
file_of() {
  case "$1" in
    SEC-*) echo "$SEC";; PERF-*) echo "$PERF";; WP-*) echo "$WP";;
    SEO-*) echo "$SEO";; A11Y-*) echo "$A11Y";;
  esac
}
for pair in SEC-026:PERF-040 SEC-026:WP-042 SEC-022:PERF-029 SEC-008:WP-040 SEC-001:WP-001 \
            SEC-004:WP-031 WP-018:A11Y-063 A11Y-001:SEO-006; do
  o=${pair%%:*}; d=${pair##*:}
  grep -qE "^\| .*\b$o\b.* \| .*\b$d\b" "$STD" || fail "$STD: owner $o / duplicate $d not tabulated"
  ro=$(row "$(file_of "$o")" "$o"); rd=$(row "$(file_of "$d")" "$d")
  [ -n "$ro" ] || fail "owner row $o missing"
  [ -n "$rd" ] || fail "duplicate row $d missing"
  so=$(sev "$ro"); sd=$(sev "$rd")
  [ "$so" = "$sd" ] || fail "$o is $so but its duplicate $d is $sd"
done
grep -q 'SEO-031' "$STD" || fail "$STD must say SEO-031 is not a duplicate"

# --- no report files inside the site ---
for f in agents/*.md; do
  if grep -q 'audit-results/' "$f"; then fail "$f writes to audit-results/"; fi
  if grep -q 'audit/a11y-report.json' "$f"; then fail "$f writes audit/a11y-report.json"; fi
done

# --- retired ids are never reused ---
section=$(sed -n '/^#### Unused and retired ids/,/^### /p' "$STD")
[ -n "$section" ] || fail "$STD lacks the Unused and retired ids list"
count=0
while IFS= read -r line; do
  case "$line" in -*) ;; *) continue;; esac
  # Drop any prose after an em dash.
  line=${line%% —*}
  for tok in $(grep -oE '[A-Z0-9]+-[0-9]{3}(\.\.[0-9]{3})?' <<<"$line"); do
    prefix=${tok%%-*}; rest=${tok#*-}
    lo=${rest%%..*}; hi=${rest##*..}
    for ((n = 10#$lo; n <= 10#$hi; n++)); do
      id=$(printf '%s-%03d' "$prefix" "$n")
      count=$((count + 1))
      if grep -qE "^\| $id(@[0-9]+)? \|" agents/wp-audit-*.md; then
        fail "retired id $id is used by a catalog row"
      fi
    done
  done
done <<<"$section"
[ "$count" -ge 40 ] || fail "retired list parsed only $count ids; the list or the parser is broken"

echo PASS
