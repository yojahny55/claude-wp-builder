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
. tests/checks/lib/expand-command.sh; expand_command commands/wp-seed.md; wp_seed=$EXPANDED
fail() { echo "FAIL: $*"; exit 1; }

s=$wp_seed
skill=skills/wp-cli-patterns/SKILL.md

# A create or import that is a command -- the verb followed by an argument -- not prose
# about one ("`wp post create` and `wp media import` leave post_author at 0"). The argument
# may be a flag, a quoted or redirected value, or a bare path, URL or $variable.
cmd='(\$WP|\bwp) (post create|media import) +[-'"'"'"<$./~[:alnum:]]'

n=$(grep -cE "$cmd" "$s" || true)
[ "$n" -ge 8 ] || fail "$s has only $n post create / media import commands -- this check would be close to vacuous"
# The flag differs by verb. `wp post create` takes the post field --post_author; `wp media
# import` has no such option and refuses it ("unknown --post_author parameter", measured on
# WP-CLI 2.12), so every import that carried it failed outright. An import names its owner
# with the global --user instead.
create='(\$WP|\bwp) post create +[-'"'"'"<$./~[:alnum:]]'
import='(\$WP|\bwp) media import +[-'"'"'"<$./~[:alnum:]]'
missing=$(grep -nE "$create" "$s" | grep -vF -- '--post_author=$AUTHOR' || true)
[ -z "$missing" ] || fail "$s creates without --post_author=\$AUTHOR (user 0 owns it):"$'\n'"$missing"
missing=$(grep -nE "$import" "$s" | grep -vF -- '--user=$AUTHOR' || true)
[ -z "$missing" ] || fail "$s imports without --user=\$AUTHOR (user 0 owns it):"$'\n'"$missing"

# The author is resolved once, as the skill says, not per create -- and resolving it is a
# stop when there is no administrator rather than a silent empty --post_author=.
grep -qF '### Always set an author' "$skill" || fail "$skill lost the 'Always set an author' rule wp-seed points at"
[ "$(grep -cF 'user list --role=administrator --field=ID --number=1' "$s")" = 1 ] \
  || fail "$s does not resolve the author exactly once"
tr '\n' ' ' < "$s" | grep >/dev/null -cF 'No administrator is a stop' || fail "$s does not stop when there is no administrator to own the posts"
grep -qF "post_author = 0 AND post_status != 'auto-draft' AND post_type != 'nav_menu_item'" "$s" \
  || fail "$s does not sweep for authorless posts before reporting the seed done"

# Every other command, agent and skill that creates content the same way.
missing=$(grep -rnE "$create" commands agents skills --include=*.md | grep -vF -- '--post_author=' || true)
[ -z "$missing" ] || fail "a post create with no --post_author:"$'\n'"$missing"
missing=$(grep -rnE "$import" commands agents skills --include=*.md | grep -vF -- '--user=' || true)
[ -z "$missing" ] || fail "a media import with no --user:"$'\n'"$missing"
bad=$(grep -rnE "$import" commands agents skills --include=*.md | grep -F -- '--post_author' || true)
[ -z "$bad" ] || fail "a media import with --post_author, which WP-CLI refuses (the import fails):"$'\n'"$bad"

# /wp-seed's polylang path hands untranslated pages to pll-import.php, whose new
# counterparts came from wp_insert_post() under wp eval-file -- user 0 again.
imp=skills/wp-polylang/scripts/pll-import.php
awk '/\$target_id = wp_insert_post\( wp_slash\( \$postarr \), true \);|\$target_id += wp_insert_post\( wp_slash\( \$postarr \), true \);/{print prev} {prev=$0}' "$imp" \
  | grep >/dev/null -cF "\$postarr['post_author'] = (int) \$source_post->post_author;" \
  || fail "$imp creates a translated counterpart without its source's post_author"

echo PASS
