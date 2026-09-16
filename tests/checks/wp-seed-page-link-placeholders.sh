#!/usr/bin/env bash
# A demo never supplies copy for an options-page `page_link` field (privacy
# policy, terms, FAQ) -- there is no marketing section to seed it from -- so
# without a dedicated phase the field ships empty or pointed at whatever draft
# WordPress created on install, which resolves to a 404 with nothing in the UI
# to say so. Measured on a real build: the footer's legal column silently
# dropped two of its three links.
set -euo pipefail

flat() { tr '\n' ' ' | sed -e 's/  */ /g'; }

seed=commands/wp-seed.md
[ -f "$seed" ] || { echo "FAIL: $seed missing"; exit 1; }
t=$(flat < "$seed")

grep -q '^## Phase 6.5:' "$seed" \
  || { echo "FAIL: wp-seed.md has no phase creating placeholder pages for page_link options fields"; exit 1; }
grep -Eq "'type' *=> *'page_link'" <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not detect page_link fields by their ACF type"; exit 1; }
grep -qi 'placeholder pending review\|generic placeholder' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not require the seeded page to say it is provisional"; exit 1; }
grep -q '_<prefix>_seeded' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not mark the pages it creates, so a re-run cannot tell them from a client's real page"; exit 1; }
grep -qi 'safe to be rewritten\|left exactly as it is' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase does not state the re-run rule that protects a client's edited page"; exit 1; }

# The command must point at where the read-side guard actually lives, and that
# guard must exist. `page_link` has no notion of post status: printing a URL
# whose target page went back to draft serves a 404 with nothing to say so.
tpl=agents/wp-template.md
[ -f "$tpl" ] || { echo "FAIL: $tpl missing"; exit 1; }
tt=$(flat < "$tpl")
grep -q 'page_link.*guard' <<<"$t" \
  || { echo "FAIL: wp-seed.md's placeholder phase never points templates at the page_link publish-status guard"; exit 1; }
grep -qF "'publish' === get_post_status" <<<"$tt" \
  || { echo "FAIL: agents/wp-template.md has no publish-status guard for page_link fields"; exit 1; }
grep -qF 'url_to_postid' <<<"$tt" \
  || { echo "FAIL: agents/wp-template.md's page_link guard does not resolve the URL to a post before checking its status"; exit 1; }

echo PASS
