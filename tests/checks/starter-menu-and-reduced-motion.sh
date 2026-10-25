#!/usr/bin/env bash
# Starter accessibility defects:
#   1. The mobile menu registered on DOMContentLoaded only, so a cache or "delay JS"
#      plugin that loads the bundle later left the button dead; it also had no Escape,
#      no aria-controls and no focus return.
#   2. navigation.php put role="menubar" on a plain list of links (a menubar promises
#      menuitems and arrow-key handling the markup does not have) and role="navigation"
#      on a <nav>.
#   3. Neither starter header had a skip link.
#   4. The cinematic starter's mobile <video autoplay loop> kept looping under
#      prefers-reduced-motion (WCAG 2.2.2): the reduced branch returned before touching it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

js=starter-theme/__tailwind__/assets/js/src/index.js
nav=starter-theme/__tailwind__/template-parts/header/navigation.php
eng=starter-theme/__cinematic__/assets/js/cinematic-engine.js
for f in "$js" "$nav" "$eng" starter-theme/__tailwind__/header.php starter-theme/__cinematic__/header.php; do
  [ -f "$f" ] || fail "$f is missing"
done

grep -Fq 'const initMobileMenu' "$js" || fail "mobile menu is not an init function"
grep -Fq "document.addEventListener('DOMContentLoaded', initMobileMenu)" "$js" \
  || fail "mobile menu has no DOMContentLoaded branch"
tr -d '\n' < "$js" | grep -Eq "if \(document\.readyState === 'loading'\) \{ *document\.addEventListener\('DOMContentLoaded', initMobileMenu\); *\} else \{ *initMobileMenu\(\); *\}" \
  || fail "mobile menu has no readyState guard joining DOMContentLoaded and the immediate call"
grep -Fq 'initMobileMenu();' "$js" || fail "mobile menu is never run when the DOM is already parsed"
grep -Fq "'Escape'" "$js" || fail "mobile menu has no Escape handler"
grep -Fq 'aria-controls' "$js" || fail "mobile menu toggle has no aria-controls"

! grep -Fq 'role="menubar"' "$nav" || fail "navigation.php still declares role=menubar"
! grep -Fq 'role="navigation"' "$nav" || fail "navigation.php still has the redundant role=navigation on <nav>"

grep -Fq 'class="skip-link screen-reader-text" href="#primary"' starter-theme/__tailwind__/header.php \
  || fail "tailwind header has no skip link to #primary"
grep -Fq 'class="skip-link screen-reader-text" href="#cinematic"' starter-theme/__cinematic__/header.php \
  || fail "cinematic header has no skip link to #cinematic"
grep -Fq 'id="primary"' starter-theme/__tailwind__/header.php \
  || fail "tailwind header has no #primary target for the skip link"
grep -Fq 'id="cinematic"' starter-theme/__cinematic__/front-page.php \
  || fail "cinematic template has no #cinematic target for the skip link"
grep -Fq '.skip-link.screen-reader-text' starter-theme/__cinematic__/assets/css/cinematic.css \
  || fail "cinematic skip link has no styles (it would render as visible text)"

# The reduced branch must reach the mobile clip before it returns.
reduced=$(awk '/if[[:space:]]*\([[:space:]]*reduced[[:space:]]*\)[[:space:]]*\{/{f=1; depth=0} f{for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="{")depth++; if(c=="}")depth--}; print; if(depth==0){exit}}' "$eng" \
  | sed -e 's://.*$::' -e '/\/\*/,/\*\//d')
[ -n "$reduced" ] || fail "could not extract the reduced-motion branch from $eng"
echo "$reduced" | grep -Eq "querySelectorAll\('\.scene__video-mobile'\)" || fail "reduced-motion branch does not touch .scene__video-mobile"
echo "$reduced" | grep -Eq '\.pause\(\)' || fail "reduced-motion branch does not pause the mobile clip"
echo "$reduced" | grep -Fq "removeAttribute('autoplay')" || fail "reduced-motion branch leaves autoplay on"
echo "$reduced" | grep -Fq "removeAttribute('loop')" || fail "reduced-motion branch leaves loop on"

if command -v node >/dev/null 2>&1; then
  node --input-type=module --check < "$js" || fail "$js does not parse as a module"
  node --check "$eng" || fail "$eng does not parse"
fi
echo PASS
