#!/usr/bin/env bash
# wp-responsive: the examples an agent copies verbatim, held to what the rest of the repo
# actually does.
#
# Three of them shipped broken. references/images.md passed an ACF image field to
# wp_get_attachment_image() as an ID, but agents/wp-acf.md generates image fields with
# return_format => 'array', so the call printed nothing; and every hero example carried
# loading="lazy" against the skill's own "never lazy-load the LCP image" rule. The
# navigation reference taught a drawer that fails the audit's A11Y-031 (no focus trap, no
# Escape, no focus return, closed links still tabbable behind aria-hidden). And the
# no-horizontal-scroll fix put overflow-x: hidden on .container, which hides the overflow
# the section exists to find.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-responsive/SKILL.md
img=skills/wp-responsive/references/images.md
nav=skills/wp-responsive/references/navigation.md
for f in "$s" "$img" "$nav"; do [ -f "$f" ] || fail "$f is missing"; done

# --- images: the ACF field is an array ------------------------------------------
grep -Fq "return_format' => 'array'" agents/wp-acf.md \
  || fail "agents/wp-acf.md no longer generates array image fields; re-check $img against what it emits"
grep -Fq "wp_get_attachment_image(\$image['ID']" "$img" \
  || fail "$img does not pass the ACF image array's ID to wp_get_attachment_image()"
grep -Eq 'wp_get_attachment_image\(\$image_id\b|wp_get_attachment_image\(\$image,' "$img" \
  && fail "$img passes the ACF field itself to wp_get_attachment_image(); the field is an array and the call prints nothing"
grep -Fq "\$image['sizes']" "$img" \
  && fail "$img hand-builds srcset from \$image['sizes'] with guessed width descriptors; wp_get_attachment_image() writes the real ones"
grep -Fq "wp_get_attachment_image(\$image['ID']" "$s" \
  || fail "$s does not name the one way to output an ACF image"
grep -Fq "\$image['sizes']" "$s" && fail "$s still offers a second, hand-built srcset path"

# --- images: the hero / LCP image is never lazy -----------------------------------
# Every fenced block that mentions the hero must carry fetchpriority and no lazy loading.
bad=$(awk '
  /^```/ { if (inb) { if (blk ~ /hero/ && blk ~ /(loading="lazy"|'\''loading'\'' *=> *'\''lazy'\'')/) print NR; inb = 0; blk = "" } else { inb = 1 } ; next }
  inb { blk = blk "\n" $0 }
' "$img")
[ -z "$bad" ] || fail "$img lazy-loads a hero example (block ending at line $bad); the hero is the LCP image"
grep -Fq "'fetchpriority' => 'high'" "$img" || fail "$img's template hero does not set fetchpriority high"
grep -Fq "'loading'       => false" "$img" \
  || fail "$img's template hero does not switch off core's lazy-loading with 'loading' => false"
grep -Fq 'fetchpriority="high"' "$img" || fail "$img's markup hero does not set fetchpriority=\"high\""

# --- navigation: the drawer passes A11Y-031 ---------------------------------------
grep -Fq 'A11Y-031' agents/wp-audit-a11y.md || fail "A11Y-031 is gone from the audit; re-check $nav"
grep -Fq 'aria-controls="mobile-menu"' "$nav" || fail "$nav's hamburger does not name the menu it controls"
# The closed-state rule itself, not the prose that explains it.
awk '/^\.mobile-menu \{/{p=1} p{print} p && /^\}/{exit}' "$nav" | grep -Fq 'visibility: hidden;' \
  || fail "$nav hides the closed menu only by transform, so its links stay in the tab order"
grep -Fq "e.key === 'Escape'" "$nav" || fail "$nav's menu does not close on Escape"
grep -Fq "e.key !== 'Tab'" "$nav" || fail "$nav's menu does not trap Tab while open"
grep -Fq 'toggle.focus()' "$nav" || fail "$nav does not return focus to the button on close"
grep -Fq "matchMedia('(min-width: 1024px)')" "$nav" \
  || fail "$nav leaves body scroll locked when the viewport crosses 1024px with the menu open"
# In the code, not the prose: the prose names aria-hidden to explain why it is not used.
awk '/^```/{p=!p;next} p' "$nav" | grep -Eq 'aria-hidden="true"|setAttribute\(.aria-hidden' \
  && fail "$nav hides the menu with aria-hidden while its links stay focusable"

# --- no horizontal scroll: fix the element, never hide it -------------------------
cssblk=$(awk '/^```css/{p=1;next} /^```/{p=0} p' "$s")
printf '%s\n' "$cssblk" | grep -Eq 'overflow-x:[[:space:]]*hidden' \
  && fail "$s shows overflow-x: hidden in a CSS example; it hides the culprit instead of fixing it"
grep -Fq 'culprits' "$s" || fail "$s does not send the reader to the element /wp-demo-verify names as the culprit"

echo PASS
