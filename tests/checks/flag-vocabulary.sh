#!/usr/bin/env bash
# The flag vocabulary reference must exist, be named from SKILL.md, define the four flags,
# and list every command that carries one of them in an argument table or hint.
set -euo pipefail
cd "$(dirname "$0")/../.."
ref=skills/wp-contributing/references/flag-vocabulary.md
[ -r "$ref" ] || { echo "FAIL: $ref missing"; exit 1; }
grep >/dev/null -c 'references/flag-vocabulary.md' skills/wp-contributing/SKILL.md || { echo "FAIL: SKILL.md does not name $ref"; exit 1; }
for f in '`--yes`' '`--force`' '`--dry-run`' '`--resume`' '`--force-adopted`'; do
  grep >/dev/null -cF "$f" "$ref" || { echo "FAIL: $ref does not define $f"; exit 1; }
done
# Every command whose argument-hint carries one of the four flags is named in the reference.
for c in commands/*.md; do
  n=$(basename "$c" .md)
  if sed -n 's/^argument-hint: //p' "$c" | grep >/dev/null -cE -- '--(yes|force|dry-run|resume)([^-a-z]|$)'; then
    grep >/dev/null -cF "/$n" "$ref" || { echo "FAIL: /$n takes a vocabulary flag but $ref never names it"; exit 1; }
  fi
done
echo PASS
