#!/usr/bin/env bash
# A demo never supplies copy for an options-page `page_link` field (privacy
# policy, terms, FAQ) -- there is no marketing section to seed it from -- so
# without a dedicated phase the field ships empty or pointed at whatever draft
# WordPress created on install, which resolves to a 404 with nothing in the UI
# to say so. Measured on a real build: the footer's legal column silently
# dropped two of its three links.
set -euo pipefail
cd "$(dirname "$0")/../.."

flat() { tr '\n' ' ' | sed -e 's/  */ /g'; }

# Slice a markdown doc from a heading line down to (not including) the next
# heading of any level, so a grep against the slice can only match inside the
# section it names — not any incidental mention of the same words elsewhere
# in a large doc.
section() { # file, heading-regex (ERE, matched against the whole heading line)
  awk -v start="$2" 'on && $0 ~ /^#{1,6} / && $0 !~ start { exit } $0 ~ start { on=1 } on { print }' "$1"
}

seed=commands/wp-seed.md
[ -f "$seed" ] || { echo "FAIL: $seed missing"; exit 1; }
t=$(flat < "$seed")

grep -q '^## Phase 6.5:' "$seed" \
  || { echo "FAIL: wp-seed.md has no phase creating placeholder pages for page_link options fields"; exit 1; }
grep -Eq "'type' *=> *'page_link'" <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not detect page_link fields by their ACF type"; exit 1; }
grep -qi 'placeholder pending review\|generic placeholder' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not require the seeded page to say it is provisional"; exit 1; }
grep -q '_<prefix>_seed_placeholder' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not mark the pages it creates, so a re-run cannot tell them from a client's real page"; exit 1; }
grep -qi 'safe to be rewritten\|left exactly as it is' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not state the re-run rule that protects a client's edited page"; exit 1; }

# The command must point at where the read-side guard actually lives, and that
# guard must exist. `page_link` has no notion of post status: printing a URL
# whose target page went back to draft serves a 404 with nothing to say so.
# Scoped to the guard's own section, not the whole 700+ line agent doc, so an
# incidental mention of these two common WP function names elsewhere in the
# file cannot satisfy the check in place of the actual guard.
tpl=agents/wp-template.md
[ -f "$tpl" ] || { echo "FAIL: $tpl missing"; exit 1; }
guard=$(section "$tpl" 'page_link. options fields')
[ -n "$guard" ] || { echo "FAIL: agents/wp-template.md has no page_link options fields guard section"; exit 1; }
gt=$(flat <<<"$guard")
grep -q 'page_link.*guard' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase never points templates at the page_link publish-status guard"; exit 1; }
grep -qF "'publish' === get_post_status" <<<"$gt" \
  || { echo "FAIL: agents/wp-template.md's page_link section has no publish-status guard for page_link fields"; exit 1; }
grep -qF 'url_to_postid' <<<"$gt" \
  || { echo "FAIL: agents/wp-template.md's page_link guard does not resolve the URL to a post before checking its status"; exit 1; }

echo PASS
