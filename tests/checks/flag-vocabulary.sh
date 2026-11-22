#!/usr/bin/env bash
# The flag vocabulary reference must exist, be named from SKILL.md, define the four flags,
# and document every command/flag pair a command mentions anywhere in its text: in the
# argument hint, in an argument table, or in the body (a flag of a tool the command calls
# counts, and is listed as such).
set -euo pipefail
cd "$(dirname "$0")/../.."
ref=skills/wp-contributing/references/flag-vocabulary.md
[ -r "$ref" ] || { echo "FAIL: $ref missing"; exit 1; }
grep >/dev/null -c 'references/flag-vocabulary.md' skills/wp-contributing/SKILL.md || { echo "FAIL: SKILL.md does not name $ref"; exit 1; }
for f in '`--yes`' '`--force`' '`--dry-run`' '`--resume`' '`--force-adopted`'; do
  grep >/dev/null -cF "$f" "$ref" || { echo "FAIL: $ref does not define $f"; exit 1; }
done
# The pair must be documented, not just the command: some entry of the reference (a table
# row, or a bullet with its continuation lines) names both `/<command>` and that flag.
# Naming the command for another flag does not cover a new one.
entries=$(awk '
  /^\|/ || /^- / || /^$/ { if (e != "") print e; e = "" }
  /^$/ { next }
  { e = (e == "" ? $0 : e " " $0) }
  END { if (e != "") print e }' "$ref")
for c in commands/*.md; do
  n=$(basename "$c" .md)
  for fl in yes force dry-run resume; do
    grep >/dev/null -cE -- "--$fl([^-a-z]|\$)" "$c" || continue
    hits=$(grep -E -- "/$n([^-a-z0-9]|\$)" <<<"$entries" | grep -cE -- "--$fl([^-a-z]|\$)" || true)
    [ "$hits" -gt 0 ] || { echo "FAIL: /$n mentions --$fl but no entry of $ref names /$n with --$fl"; exit 1; }
  done
done
echo PASS
