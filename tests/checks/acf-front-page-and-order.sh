#!/usr/bin/env bash
# Three ACF defects found on a real bilingual build:
#
# 1. `page_template == front-page.php` never matches a front page selected through
#    Settings > Reading and rendered by the template hierarchy — its `_wp_page_template`
#    meta stays `default`, so the field group vanished from the editor while its fields
#    kept rendering on the front end. `page_type == front_page` matches either way.
# 2. Every group had `menu_order` 0, so the editor stacked boxes in load order instead of
#    page order, and titles mixed languages and were not numbered.
# 3. A single field tried to serve both a card's short excerpt and a detail page's full
#    write-up; both directions broke. Two distinct-purpose strings need two fields.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=agents/wp-acf.md
fail() { echo "FAIL: $*"; exit 1; }

[ -f "$f" ] || fail "$f missing"

# 1. Front page location rule.
grep -Fq "'value' => 'front_page'" "$f" \
  || fail "$f does not show page_type == front_page for the front page"
grep -Fq "page_template == front-page.php" "$f" \
  || fail "$f no longer explains WHY page_template == front-page.php is the wrong rule — the negative example must stay so the lesson survives"

# 2. menu_order + numbered, single-language titles.
grep -Fq "'menu_order'" "$f" || fail "$f never shows menu_order on a field group"
grep -Eq "menu_order.*equal to its section" "$f" \
  || fail "$f does not state the menu_order == section position rule"
grep -Fq "'1. Hero'" "$f" || fail "$f lost the numbered-title example"
grep -Eiq "never number|no number.*single|single box for one record" "$f" \
  || fail "$f does not carve out single-record detail groups from numbering"

# 3. Two distinct-purpose strings need two fields.
grep -Fq '_excerpt' "$f" || fail "$f does not name the <section>_excerpt / <section>_bio pattern"
grep -Eiq "model TWO fields|two fields from the start" "$f" \
  || fail "$f does not state the two-field rule for card-excerpt vs full-bio content"

echo PASS
