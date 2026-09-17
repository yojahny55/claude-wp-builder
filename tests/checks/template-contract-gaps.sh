#!/usr/bin/env bash
# Seven contract gaps found on a real bilingual build, each real content or a real
# best-practices audit turned up:
#
# 4. The ABSPATH guard read as "for templates", so 26 files (full page/single/archive/
#    taxonomy templates, inc/ includes, seed scripts) shipped with none.
# 5. Seeded records share a post_date to the second; unordered `orderby => date` ties
#    resolved differently on every request.
# 6. A custom nav walker overriding start_el() skipped nav_menu_css_class entirely, so a
#    filtered-in "current menu item" class never survived into the markup.
# 7. A demo control the Figma-to-demo tool marks MOCK:/data-mock was wired to real data
#    verbatim instead of being re-derived or dropped.
# 8. A "see more" control rendered for a demo `#anchor` placeholder with no real URL, and
#    a not-yet-seeded relation was faked with a hardcoded name/address in the template.
# 9. Carousel controls stayed painted (not hidden) when the real record count could not
#    overflow the strip, a ceil()'d dot count overshot the card count, and a v4 `scale`
#    mirror got clobbered by a hover `transform`.
# 10. A chevron rotation was wired to an attribute that lives on the wrong element instead
#    of reusing the sibling template's already-correct aria-expanded pattern.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=agents/wp-template.md
fail() { echo "FAIL: $*"; exit 1; }

[ -f "$f" ] || fail "$f missing"

# 4. ABSPATH scope beyond template-parts/.
grep -Fq 'not only `template-parts/`' "$f" \
  || fail "$f does not extend the ABSPATH rule beyond template-parts/"
grep -Eq "inc/seed" "$f" || fail "$f does not call out inc/seed scripts as needing the guard too"

# 5. Stable ordering.
grep -Fq "'date' => 'DESC', 'ID' => 'DESC'" "$f" \
  || fail "$f does not show the ID tiebreaker for date-ordered queries"

# 6. Nav walker filters.
for filt in nav_menu_css_class nav_menu_item_id nav_menu_link_attributes; do
  grep -Fq "$filt" "$f" || fail "$f does not require the $filt filter in a custom start_el()"
done

# 7. MOCK / data-mock grep step.
grep -Fq 'MOCK:' "$f" || fail "$f does not tell the agent to grep the demo for MOCK: comments"
grep -Fq 'data-mock' "$f" || fail "$f does not tell the agent to grep the demo for data-mock"

# 8. Real-URL-only CTA, no invented relations.
grep -Eq "http\(s\)://.*or site-relative|real.*http\(s\)" "$f" \
  || fail "$f does not require a real http(s)/relative URL before rendering an optional CTA"
grep -Eiq "never hardcode an example person" "$f" \
  || fail "$f does not forbid hardcoding an example person/address for an unseeded relation"

# 9. Carousel contract.
grep -Fq 'scrollWidth' "$f" && grep -Fq 'clientWidth' "$f" \
  || fail "$f does not compare scrollWidth to clientWidth to decide whether to hide carousel controls"
grep -Fq 'Math.round' "$f" || fail "$f does not require round() (not ceil()) for dot count"
grep -Eiq "clamped to the (number of cards|card count)" "$f" \
  || fail "$f does not clamp dot count to the card count"
grep -Eiq "outside the (element that scrolls|scrolling element)" "$f" \
  || fail "$f does not require dots/arrows to live outside the scrolling element"

# 10. Component reuse.
grep -Fq 'aria-expanded' "$f" || fail "$f does not reference the aria-expanded chevron pattern"
grep -Eiq "reuse (that|a) solved pattern|Solve It Once" "$f" \
  || fail "$f does not state the reuse-the-sibling's-pattern rule"

echo PASS
