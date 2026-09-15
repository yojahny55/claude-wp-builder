#!/usr/bin/env bash
# The conversion is the one lossy step nothing was checking.
#
# `/wp-tailwindify` rewrites a plain-CSS demo into utilities and archives the original.
# Its Step 4 verified STRUCTURE — delimiters kept, no <style> block, no project stylesheet
# <link> — and nothing verified what the result RENDERS. A demo whose reset read
#
#     button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}
#
# converted with the whole rule dropped as "preflight covers it". Preflight covers five of
# those six declarations and not `cursor`, so every button on the site lost its pointer.
# Every later gate compares the theme against the CONVERTED demo, so both sides agreed and
# the defect was structurally invisible from that point on. Conversion is the last moment
# the original still exists to compare against.
set -euo pipefail

gate=bin/tailwindify-parity.mjs
[ -f "$gate" ] || { echo "FAIL: $gate is missing — the conversion has no rendering gate, and it is the only step where the original is still available to compare against"; exit 1; }
[ -x "$gate" ] || { echo "FAIL: $gate is not executable"; exit 1; }
node --check "$gate" >/dev/null 2>&1 || { echo "FAIL: $gate is not valid JavaScript"; exit 1; }

g=$(tr '\n' ' ' < "$gate" | sed 's/  */ /g')

# The join cannot be on selectors: the two files use different class systems by
# construction. Text is what survives the conversion unchanged.
printf '%s' "$g" | grep -qF 'tag + text' \
  || { echo "FAIL: $gate does not document joining on tag + text — a selector join is impossible across two class systems, and an undocumented join key gets 'fixed' into one"; exit 1; }

# `cursor` is the declaration that started this. If it leaves the property list the gate
# stops catching the exact defect it was built for.
for p in cursor lineHeight fontWeight whiteSpace letterSpacing; do
  printf '%s' "$g" | grep -qF "'$p'" \
    || { echo "FAIL: $gate does not compare '$p' — preflight does not restore it and a demo commonly declares it"; exit 1; }
done

# Tailwind emits oklab() for a colour with an opacity modifier where plain CSS emits
# rgba(). Same pixels. Comparing the strings produced dozens of false findings and buried
# the real ones, so colours are resolved through a canvas in the page.
printf '%s' "$g" | grep -qF 'getImageData' \
  || { echo "FAIL: $gate does not resolve colours through a canvas — oklab() vs rgba() for the same colour is a notation difference, and string-comparing them floods the report with noise"; exit 1; }

# A converted page with no Tailwind runtime renders as bare HTML, where EVERY element
# differs. Reporting that as lost declarations is how a gate gets ignored.
printf '%s' "$g" | grep -qF 'unrenderable' \
  || { echo "FAIL: $gate does not detect an unstyled converted page — conversion strips the demo's stylesheet, and without this guard a page with no Tailwind runtime reports every element as a delta"; exit 1; }

# Exit codes are a contract: a missing browser is not a failing gate.
printf '%s' "$g" | grep -qF 'process.exit(2)' \
  || { echo "FAIL: $gate does not exit 2 when no browser is usable — the caller cannot tell 'could not run' from 'found defects'"; exit 1; }

# And the command has to actually run it.
cmd=commands/wp-tailwindify.md
flat=$(tr '\n' ' ' < "$cmd" | sed 's/  */ /g')
printf '%s' "$flat" | grep -qF 'tailwindify-parity.mjs' \
  || { echo "FAIL: $cmd never invokes bin/tailwindify-parity.mjs — a gate nothing calls is documentation"; exit 1; }
printf '%s' "$flat" | grep -qF -- '--against' \
  || { echo "FAIL: $cmd invokes the gate without --against, so it compares the converted page with nothing"; exit 1; }
printf '%s' "$flat" | grep -qiE 'renders?, not only what it contains|what it RENDERS' \
  || { echo "FAIL: $cmd does not say the structural checks are insufficient — items 2-4 all pass on a page that has lost a declaration"; exit 1; }

echo PASS
