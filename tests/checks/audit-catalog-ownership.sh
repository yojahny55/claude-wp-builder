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
# Full severity cell, trimmed: the last cell, or the one before Auto-fix when that is Yes/No.
sev() {
  awk -F'|' '{
    n = NF - 1; c = $n; gsub(/^ +| +$/, "", c)
    if (c == "Yes" || c == "No") { n--; c = $n; gsub(/^ +| +$/, "", c) }
    print c
  }' <<<"$1"
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
# A rule that changes what it reports carries a revision, so old coverage is not read as new.
for id in SEC-026@2 PERF-040@2 WP-042@2 PERF-029@2 SEC-008@2; do
  f=$(case "$id" in SEC-*) echo "$SEC";; PERF-*) echo "$PERF";; WP-*) echo "$WP";; esac)
  grep -qE "^\| $id \|" "$f" || fail "$f: $id must be a table row at that revision"
done
r=$(row "$SEC" SEC-026)
[ -n "$r" ] || fail "$SEC: SEC-026 row missing"
case "$r" in *">= 8.2 "*) ;; *) fail "SEC-026 must carry the literal '>= 8.2' floor";; esac
for spec in "$PERF:PERF-040" "$WP:WP-042"; do
  r=$(row "${spec%%:*}" "${spec##*:}")
  [ -n "$r" ] || fail "${spec##*:} row missing"
  if grep -qE '[0-9]\.[0-9]' <<<"$r"; then fail "${spec##*:} must not carry a version number; SEC-026 owns it"; fi
done
# The duplicates point at SEC-026's floor, so the number must be readable without security.md.
grep -qE '^\| PHP version below the floor \(`>= 8\.2`' "$STD" || fail "$STD: the Same defect row must state the >= 8.2 floor"

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
  # Table row: column 2 is exactly the owner, column 3 contains the duplicate.
  ok=$(awk -F'|' -v o="$o" -v d="$d" '{
    c2 = $3; c3 = $4; gsub(/^ +| +$/, "", c2); sub(/@[0-9]+$/, "", c2)
    if (c2 == o && index(c3, d)) found = 1
  } END { print found + 0 }' "$STD")
  [ "$ok" = 1 ] || fail "$STD: no table row with owner $o and duplicate $d"
  # The merge is the renderer's root-cause fold: every row names the slug both sides emit.
  slug=$(awk -F'|' -v o="$o" '{ c2 = $3; gsub(/^ +| +$/, "", c2); sub(/@[0-9]+$/, "", c2)
    if (c2 == o) { c5 = $5; gsub(/^ +| +$/, "", c5); print c5; exit } }' "$STD")
  case "$slug" in '`'?*'`') ;; *) fail "$STD: row for $o names no root_cause slug";; esac
  ro=$(row "$(file_of "$o")" "$o"); rd=$(row "$(file_of "$d")" "$d")
  [ -n "$ro" ] || fail "owner row $o missing"
  [ -n "$rd" ] || fail "duplicate row $d missing"
  case "$rd" in *"duplicate of $o"[,\ \)]*) ;; *) fail "$d row must say 'duplicate of $o'";; esac
  case "$ro" in *"owner of "*"$d"*) ;; *) fail "$o row must say 'owner of' naming $d";; esac
  so=$(sev "$ro"); sd=$(sev "$rd")
  [ "$so" = "$sd" ] || fail "$o severity '$so' differs from duplicate $d '$sd'"
done
grep -q 'SEO-031' "$STD" || fail "$STD must say SEO-031 is not a duplicate"

# --- no report files inside the site ---
for f in agents/*.md; do
  if grep -qE '(^|[^-.a-zA-Z_])audit(-results)?/[^ `]*\.json' "$f"; then
    fail "$f names a report file under audit/ or audit-results/"
  fi
done
for f in "$A11Y" "$SEO" agents/wp-audit-geo.md; do
  grep -q 'Write no report file inside the site' "$f" || fail "$f must say: Write no report file inside the site"
done
grep -q 'folded finding is found, not resolved' skills/wp-audit-run/references/ledger.md \
  || fail "ledger.md must keep folded findings out of resolved"
grep -q 'after UX-058' "$STD" || fail "$STD: new UX ids must start after UX-058"

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
