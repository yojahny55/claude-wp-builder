#!/usr/bin/env bash
# The flag vocabulary reference must exist, be named from SKILL.md, define the four flags,
# and name every command that mentions one of them anywhere in its text: in the argument
# hint, in an argument table, or in the body (a flag of a tool the command calls counts, and
# is listed as such).
set -euo pipefail
cd "$(dirname "$0")/../.."
ref=skills/wp-contributing/references/flag-vocabulary.md
[ -r "$ref" ] || { echo "FAIL: $ref missing"; exit 1; }
grep >/dev/null -c 'references/flag-vocabulary.md' skills/wp-contributing/SKILL.md || { echo "FAIL: SKILL.md does not name $ref"; exit 1; }
for f in '`--yes`' '`--force`' '`--dry-run`' '`--resume`' '`--force-adopted`'; do
  grep >/dev/null -cF "$f" "$ref" || { echo "FAIL: $ref does not define $f"; exit 1; }
done
for c in commands/*.md; do
  n=$(basename "$c" .md)
  if grep >/dev/null -cE -- '--(yes|force|dry-run|resume)([^-a-z]|$)' "$c"; then
    grep >/dev/null -cF "/$n" "$ref" || { echo "FAIL: /$n mentions a vocabulary flag but $ref never names it"; exit 1; }
  fi
done
echo PASS
