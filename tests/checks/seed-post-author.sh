#!/usr/bin/env bash
# /wp-seed never set a post author. Every `wp post create` and `wp media import` in it ran
# without --post_author, so every seeded page and attachment belonged to user 0 -- a user
# that does not exist. The site renders, so nothing looked wrong until /wp-finalize Check 7's
# author sweep failed the delivery (and the_author(), the Article schema's author and the
# admin column were empty in the meantime). wp-cli-patterns already had the rule and the
# recipe; the command never used them, and neither did the skill's own examples, two agents,
# the cinematic seeders or pll-import.php's new counterparts.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=commands/wp-seed.md
skill=skills/wp-cli-patterns/SKILL.md

# A create or import that is a command -- the verb followed by an argument -- not prose
# about one ("`wp post create` and `wp media import` leave post_author at 0").
cmd='(\$WP|\bwp) (post create|media import) +[-'"'"'"<]'

n=$(grep -cE "$cmd" "$s" || true)
[ "$n" -ge 8 ] || fail "$s has only $n post create / media import commands -- this check would be close to vacuous"
missing=$(grep -nE "$cmd" "$s" | grep -vF -- '--post_author=$AUTHOR' || true)
[ -z "$missing" ] || fail "$s creates or imports without --post_author=\$AUTHOR (user 0 owns it):"$'\n'"$missing"

# The author is resolved once, as the skill says, not per create -- and resolving it is a
# stop when there is no administrator rather than a silent empty --post_author=.
grep -qF '### Always set an author' "$skill" || fail "$skill lost the 'Always set an author' rule wp-seed points at"
[ "$(grep -cF 'user list --role=administrator --field=ID --number=1' "$s")" = 1 ] \
  || fail "$s does not resolve the author exactly once"
tr '\n' ' ' < "$s" | grep -qF 'No administrator is a stop' || fail "$s does not stop when there is no administrator to own the posts"
grep -qF "post_author = 0 AND post_status != 'auto-draft' AND post_type != 'nav_menu_item'" "$s" \
  || fail "$s does not sweep for authorless posts before reporting the seed done"

# Every other command, agent and skill that creates content the same way.
missing=$(grep -rnE "$cmd" commands agents skills --include=*.md | grep -vF -- '--post_author=' || true)
[ -z "$missing" ] || fail "a create or import with no --post_author:"$'\n'"$missing"

# /wp-seed's polylang path hands untranslated pages to pll-import.php, whose new
# counterparts came from wp_insert_post() under wp eval-file -- user 0 again.
imp=skills/wp-polylang/scripts/pll-import.php
awk '/\$target_id = wp_insert_post\( wp_slash\( \$postarr \), true \);|\$target_id += wp_insert_post\( wp_slash\( \$postarr \), true \);/{print prev} {prev=$0}' "$imp" \
  | grep -qF "\$postarr['post_author'] = (int) \$source_post->post_author;" \
  || fail "$imp creates a translated counterpart without its source's post_author"

echo PASS
