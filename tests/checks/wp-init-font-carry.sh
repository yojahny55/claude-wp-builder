#!/usr/bin/env bash
set -euo pipefail
# The theme named fonts it never loaded, so every non-/wp-yolo build rendered in a
# fallback stack and nothing said why.
#
# Three defects, one cause. /wp-init Step D4 wrote the demo's font *names* into
# --font-primary / --font-secondary and no step ever carried a font file. The Tailwind
# starter shipped `--font-primary: "Inter"` with no @font-face and no Inter anywhere, so
# even a demo-less scaffold rendered in the system fallback. And functions.php preconnected
# to fonts.googleapis.com unconditionally while the theme never made a single request to
# it -- a dead hint on every page.
#
# The rule this asserts: a theme self-hosts every family it names, and names no family it
# has not carried.
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

init=commands/wp-init.md
yolo=commands/wp-yolo.md
starter=starter-theme/__tailwind__
main_css="$starter/assets/css/src/tailwindcss/main.css"
for f in "$init" "$yolo" "$main_css" "$starter/functions.php"; do
  test -f "$f" || fail "$f missing"
done

# 1. /wp-init actually carries font files, and says how to get woff2 out of Google Fonts.
grep -Fq 'Step 4.5: Font carry' "$init" \
  || fail "$init has no font-carry step -- D4 writes font names nothing loads"
grep -Fq 'fonts.gstatic.com' "$init" \
  || fail "$init's font carry never fetches the woff2 files Google serves from fonts.gstatic.com"
grep -Fq -- '-A "$UA"' "$init" \
  || fail "$init's font carry dropped the browser user-agent -- Google then serves legacy TTF and the theme ships it silently"

# 2. The theme makes no runtime request to Google. A preconnect to a host nothing calls
#    is the dead hint this removed; self-hosting is the whole point of step 1.
if grep -rq 'fonts\.googleapis\.com' "$starter"; then
  echo "FAIL: $starter still references fonts.googleapis.com, but the theme self-hosts its fonts"
  grep -rn 'fonts\.googleapis\.com' "$starter"
  exit 1
fi

# 3. The starter names no family it does not ship. Behavioral, not wording.
#    Judge the HEAD of each stack, not the presence of a keyword anywhere in it:
#    `"Inter", system-ui, sans-serif` is not a system stack -- Inter is what renders
#    wherever it exists, and naming it unloaded is this whole defect. Anything after the
#    first family is a fallback and never has to be carried, which is the same carve-out
#    /wp-finalize's font-parity check makes for an intentional system stack.
while IFS= read -r line; do
  decl=${line#*:}
  first=${decl%%,*}
  first=$(printf '%s' "$first" | tr -d '";' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$first" ]] && continue
  case "$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')" in
    ui-sans-serif|ui-serif|ui-monospace|ui-rounded|system-ui|-apple-system|blinkmacsystemfont) continue ;;
    sans-serif|serif|monospace|cursive|fantasy|inherit|initial|unset|revert) continue ;;
    var\(*) continue ;;
  esac
  grep -rqi -- "$first" "$starter/assets/fonts" 2>/dev/null \
    || fail "$main_css leads --font-* with the family '$first', which the starter neither ships in assets/fonts/ nor loads -- it silently renders the next entry in the stack"
done < <(grep -E '^\s*--font-[a-z]+:' "$main_css")

# 4. /wp-init emits a preload, and emits it for ONE file. Preloading every unicode-range
#    subset defeats the lazy loading that makes carrying them all cheap, so the contract is
#    the narrow one; a check that only grepped for `preload` would pass on the pessimization.
grep -Fq 'rel="preload"' "$init" \
  || fail "$init's font carry emits no preload hint -- a self-hosted face is discovered only after the CSS parses, costing a round trip on first paint"
grep -Fq 'never every subset' "$init" \
  || fail "$init no longer scopes the preload to one file -- preloading every unicode-range subset downloads faces the page never renders"

# 5. /wp-yolo agrees. It used to permit a Google Fonts preconnect; two commands giving
#    different answers about the same demo is how the fallback shipped in the first place.
grep -Fq 'Never emit a `fonts.googleapis.com` request' "$yolo" \
  || fail "$yolo no longer forbids runtime Google Fonts requests -- it contradicts $init's self-hosting rule"
if grep -Fq 'Only add a Google Fonts `<link rel="preconnect">`' "$yolo"; then
  fail "$yolo still carries the old rule permitting a Google Fonts preconnect"
fi

echo PASS
