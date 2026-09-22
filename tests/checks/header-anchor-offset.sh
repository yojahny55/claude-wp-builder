#!/usr/bin/env bash
# Anchors under a sticky header: on a real build every "#section" link scrolled its heading
# behind the sticky bar, because nothing set scroll-padding-top. The tailwind starter ties it
# to the header's live height (desktop and mobile differ), and the cinematic starter to its
# fixed .nav's measured height.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

css=starter-theme/__tailwind__/assets/css/src/tailwindcss/base/reset.css
js=starter-theme/__tailwind__/assets/js/src/index.js
grep -Fq 'scroll-padding-top: calc(var(--header-offset, 0px) + 1.25rem);' "$css" \
  || fail "$css does not pad anchors by the header height"
grep -Fq "setProperty('--header-offset'" "$js" || fail "$js never writes --header-offset"
grep -Fq "getElementById('masthead')" "$js" || fail "$js does not measure #masthead"
grep -Fq "position === 'sticky' || style.position === 'fixed'" "$js" \
  || fail "$js pads anchors for a header that scrolls away"
# Pinned below the admin bar (.admin-bar #masthead { top: 32px }), the header ends at top + height.
grep -Fq 'top + header.getBoundingClientRect().height' "$js" \
  || fail "$js ignores the pinned header's top (admin bar)"
grep -Fq 'new ResizeObserver(update)' "$js" || fail "$js does not re-measure when the header resizes (mobile vs desktop)"
grep -Fq 'id="masthead"' starter-theme/__tailwind__/header.php || fail "the starter header lost id=masthead"

cin=starter-theme/__cinematic__/assets/css/cinematic.css
grep -Fq 'scroll-padding-top:calc(var(--nav-h) + 20px)' "$cin" || fail "$cin does not pad anchors under the fixed nav"
[ "$(grep -c -- '--nav-h:' "$cin")" -ge 2 ] || fail "$cin has no separate mobile --nav-h"
# The CSS values are a fallback: a logo or a longer menu changes the bar's height, so the
# engine measures the rendered .nav and keeps --nav-h in step.
eng=starter-theme/__cinematic__/assets/js/cinematic-engine.js
grep -Fq "setProperty('--nav-h'" "$eng" || fail "$eng does not keep --nav-h equal to the rendered nav"
grep -Fq 'new ResizeObserver(setNavH)' "$eng" || fail "$eng does not re-measure the nav when it resizes"

grep -Fq 'scroll-padding-top' commands/wp-header.md || fail "/wp-header does not carry the anchor offset contract"

echo PASS
