#!/usr/bin/env bash
# Three more from the same delivery: a third party's default colour winning over
# an inherited one, CF7's own filter inserting line breaks nobody wrote, and one
# page's timeout destroying a whole directory's results.
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

m=starter-theme/__tailwind__/assets/css/src/tailwindcss/main.css
r=skills/wp-demo-craft/compositions/README.md
c=agents/wp-cf7.md
v=bin/demo-verify.mjs
for x in "$m" "$r" "$c" "$v"; do test -f "$x" || fail "$x missing"; done

# The typography plugin is loaded, so its colours must be bound to the theme's.
if grep -q '@plugin "@tailwindcss/typography"' "$m"; then
  grep -q -- '--tw-prose-body' "$m" || fail "typography is loaded but --tw-prose-body is not bound to a theme token"
  grep -q -- '--tw-prose-headings: var(--color-dark)' "$m" \
    || fail "prose headings do not follow the theme's ink token"
  grep -Eq -- '--tw-prose-body: var\(--color-' "$m" \
    || fail "prose body colour is not a theme token — a dark palette gets grey on near-black"
fi
grep -q 'reserved class name' "$r" || fail "compositions may still borrow the prose class name"

# CF7: wpautop turns the newline between a label and its tag into a <br>.
grep -q 'ONE line' "$c" || fail "wp-cf7 does not require one-line label rows"
grep -q 'wpautop' "$c" || fail "wp-cf7 never names wpautop as the cause"

# The walk must survive a page that does not.
grep -q "page-crashed" "$v" || fail "demo-verify has no per-page crash finding"
grep -q "One page's failure costs that page, never the walk" "$v" \
  || fail "demo-verify no longer isolates a page failure"
node --check "$v" || fail "$v does not parse"

echo PASS
