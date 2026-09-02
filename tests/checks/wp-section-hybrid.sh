#!/usr/bin/env bash
# /wp-section --hybrid: /wp-init, /wp-cinematic-init and docs/cinematic-mode.md all send the
# user to this flag, so commands/wp-section.md must actually define it — and define it as the
# trailing-flex overlay the cinematic starter's front-page.php renders, not a standalone group.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=commands/wp-section.md
fail() { echo "FAIL: $*"; exit 1; }

grep -Fq -- '--hybrid' "$f" || fail "$f does not parse --hybrid"
grep -Fq 'trailing_sections' "$f" || fail "$f does not append to the trailing_sections flex field"
grep -Fq 'fields/trailing-sections.php' "$f" || fail "$f does not name fields/trailing-sections.php"
grep -Fq 'get_sub_field' "$f" || fail "$f does not tell the template to read row values with get_sub_field()"
grep -Fq 'assets/css/cinematic.css' "$f" || fail "$f does not route hybrid CSS to assets/css/cinematic.css"
grep -Eq 'Skip (this step|Step 6).*--hybrid|--hybrid.*skip' "$f" || fail "$f does not skip the page-template injection under --hybrid"
grep -Eqi 'only valid on a cinematic project' "$f" || fail "$f does not refuse --hybrid on non-cinematic projects"

# the loop the flag relies on must still exist in the starter
grep -Fq "have_rows('trailing_sections')" starter-theme/__cinematic__/front-page.php \
  || fail "cinematic front-page.php lost its trailing_sections loop"

# every place that advertises the flag must keep doing so
for g in commands/wp-init.md commands/wp-cinematic-init.md docs/cinematic-mode.md; do
  grep -Fq -- '--hybrid' "$g" || fail "$g no longer mentions --hybrid"
done

echo PASS
