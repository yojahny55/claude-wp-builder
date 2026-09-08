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
#
#    Scoped deliberately to the invariant that holds here: the starter ships NO font files,
#    so every token must lead with a system or generic family. Do not try to match a family
#    name against a carried file -- it is unreliable in both directions. A woff2's name table
#    lives inside the compressed stream so grepping its bytes finds nothing, and Google's
#    filenames are opaque hashes, so a correctly carried family would fail either test while
#    any stray file in the directory would satisfy the first. Per-project parity -- family,
#    @font-face and file together -- is /wp-finalize's job; it can see all three.
shopt -s nullglob
carried=("$starter"/assets/fonts/*.woff2 "$starter"/assets/fonts/*.woff "$starter"/assets/fonts/*.ttf "$starter"/assets/fonts/*.otf)
shopt -u nullglob
[[ ${#carried[@]} -eq 0 ]] \
  || fail "$starter now ships font files (${carried[0]}) -- this check assumes it ships none, so extend it or move the per-family parity assertion to /wp-finalize rather than letting it pass silently"

[[ $(grep -cE '^[[:space:]]*--font-[a-z]+:' "$main_css") -gt 0 ]] \
  || fail "$main_css declares no --font-* token at all -- the scan below would pass vacuously"
while IFS= read -r line; do
  decl=${line#*:}
  first=${decl%%,*}
  first=$(printf '%s' "$first" | tr -d "\";'" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$first" ]] && continue
  case "$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')" in
    ui-sans-serif|ui-serif|ui-monospace|ui-rounded|system-ui|-apple-system|blinkmacsystemfont) continue ;;
    sans-serif|serif|monospace|cursive|fantasy|inherit|initial|unset|revert) continue ;;
    var\(*) continue ;;
  esac
  fail "$main_css leads --font-* with the family '$first', which the starter does not ship -- it silently renders the next entry in the stack"
done < <(grep -E '^[[:space:]]*--font-[a-z]+:' "$main_css")

# 4. /wp-init emits a preload, and emits it for ONE file. Preloading every unicode-range
#    subset defeats the lazy loading that makes carrying them all cheap, so the contract is
#    the narrow one; a check that only grepped for `preload` would pass on the pessimization.
grep -Fq 'rel="preload"' "$init" \
  || fail "$init's font carry emits no preload hint -- a self-hosted face is discovered only after the CSS parses, costing a round trip on first paint"
grep -Fq 'never every subset' "$init" \
  || fail "$init no longer scopes the preload to one file -- preloading every unicode-range subset downloads faces the page never renders"

# 5. Every fetch fails loudly. Without -f, curl writes a 404 or a rate-limit page into the
#    target and exits 0 -- an @font-face built from an error document, or a .woff2 that is
#    HTML. The stylesheet and the font files both need it, so assert no bare `curl -sS`.
if grep -Fq 'curl -sS' "$init"; then
  echo "FAIL: $init has a curl without -f in the font carry -- an HTTP error body gets written to the target file and the step reports success"
  grep -n 'curl -sS' "$init"
  exit 1
fi

# 6. An extraction that yields nothing is a failure, not a quiet no-op. Without the guard a
#    TTF stylesheet, an error page or a format change at Google runs the download loop zero
#    times and the step reports success having carried no fonts -- the silent fallback again.
grep -Fq 'no woff2 URLs in the Google Fonts response' "$init" \
  || fail "$init does not fail when the Google Fonts response yields no woff2 URLs -- the carry then reports success with zero fonts"

# 7. font-display is added when Google omits it, not merely kept when present. A css2 URL
#    without &display=swap yields blocks with no font-display at all, which is FOIT.
grep -Fq 'add it where it does not' "$init" \
  || fail "$init only keeps font-display when the response has it -- a demo whose css2 URL omits display=swap then ships FOIT"

# 8. A family that could not be carried is dropped from the head of its token, in BOTH
#    commands. Keeping it leaves the theme naming a font it does not have -- the exact state
#    /wp-finalize's font-parity check fails on -- and two commands answering this differently
#    is how the contradiction got in.
grep -Fq 'drop that family from' "$init" \
  || fail "$init keeps an uncarried family at the head of its token, contradicting its own closing confirmation and /wp-finalize"
grep -Fq 'drop the family' "$yolo" \
  || fail "$yolo keeps an uncarried family at the head of its token -- it disagrees with $init about the same demo"
for f in "$init" "$yolo"; do
  if grep -Fq 'keep the family' "$f"; then
    fail "$f still says to keep an uncarried family at the head of its font token"
  fi
done

# 9. /wp-yolo agrees. It used to permit a Google Fonts preconnect; two commands giving
#    different answers about the same demo is how the fallback shipped in the first place.
grep -Fq 'Never emit a `fonts.googleapis.com` request' "$yolo" \
  || fail "$yolo no longer forbids runtime Google Fonts requests -- it contradicts $init's self-hosting rule"
if grep -Fq 'Only add a Google Fonts `<link rel="preconnect">`' "$yolo"; then
  fail "$yolo still carries the old rule permitting a Google Fonts preconnect"
fi

echo PASS
