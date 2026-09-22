#!/usr/bin/env bash
# Contours that differ across engines. Verification ran Chromium only, and a build shipped
# outline buttons and ringed icon links drawn as a 1px `border` + `border-radius` on a
# transparent background: Firefox on Windows draws notched corners on exactly that, and Linux
# Firefox does not reproduce it, so no screenshot here could have caught it. Its search field
# showed Chromium's native clear "x" and nothing in Firefox. bin/css-contour-lint.mjs is the
# static guard; /wp-finalize and the practices audit run it; both CSS skills state the rules.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }

lint=bin/css-contour-lint.mjs
fx=tests/fixtures/css-contour-lint

set +e; out=$(node "$lint" "$fx/bad"); code=$?; set -e
[ "$code" -eq 1 ] || fail "$lint exited $code on $fx/bad, expected 1"
for want in 'style.css:2 [thin-border]' 'style.css:3 [thin-border]' 'style.css:4 [drop-shadow-ring]' \
    'style.css:5 [thin-border]' 'search.php:3 [thin-border]' 'search.php:2 [search-clear]' \
    'style.css:6 [thin-border]' 'style.css:7 [thin-border]' 'filter.php:3 [search-clear]'; do
  grep -Fq "$want" <<<"$out" || fail "$lint missed $want"
done
# style.css:6 has a nested `&:hover { }` block: a regex over innermost braces never read the
# rule that owns it. style.css:7 is white written as hsl(). style.css:8 hides the native
# clear button for `.filter__search` only, so filter.php:2 and the Tailwind-variant field on
# filter.php:4 are covered while filter.php:3 and search.php:2 are not.
[ "$(grep -c '^FAIL: .*\[' <<<"$out")" -eq 9 ] || fail "$lint reported something beyond the nine seeded defects:
$out"

set +e; out=$(node "$lint" "$fx/good"); code=$?; set -e
[ "$code" -eq 0 ] || fail "$lint flagged the corrected fixture (a card, a solid button, a transparent border, an inset shadow):
$out"

set +e; node "$lint" /nonexistent >/dev/null 2>&1; code=$?; set -e
[ "$code" -eq 2 ] || fail "$lint on a missing dir exited $code, expected 2"

# The starters themselves pass.
node "$lint" starter-theme/__tailwind__ starter-theme/__cinematic__ >/dev/null \
  || fail "a starter theme fails its own contour lint"

# Wired where the other static gates run, and documented in both CSS systems.
grep -Fq 'bin/css-contour-lint.mjs' commands/wp-finalize.md || fail "/wp-finalize does not run the contour lint"
grep -Fq 'css-contour-lint.mjs' agents/wp-audit-practices.md || fail "the practices audit does not run the contour lint"
for s in skills/wp-css-system/SKILL.md skills/wp-tailwind-system/SKILL.md; do
  grep -Fq 'inset 0 0 0 1px' "$s" || fail "$s does not state the inset box-shadow contour rule"
  grep -Fq -- '-webkit-search-cancel-button' "$s" || fail "$s does not say to hide the native search clear button"
  grep -Fq 'drop-shadow' "$s" || fail "$s does not warn about drop-shadow on a ring"
done

echo PASS
