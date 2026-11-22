#!/usr/bin/env bash
# /wp-section Step 6.7: a blog section runs /wp-page blog, except in the five cases that skip it.
#
# A blog section on the front page lists posts that need an archive and a single view, and
# /wp-page blog builds them. The step must not reimplement /wp-page, must not run twice inside
# /wp-yolo (which runs /wp-page blog itself and marks its walk with --transcribe), and must not
# overwrite blog templates that already exist. The "already exists" test reads a file that
# /wp-page blog writes, so this check also binds that path to the /wp-page reference, and the
# --transcribe skip to the two sentences in /wp-yolo and /wp-section that make it true.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-section.md
ref=skills/wp-section-run/references/blog-templates.md
marker='template-parts/journal/content-journal-card.php'

. tests/checks/lib/expand-command.sh
expand_command "$cmd"
x=$EXPANDED

# The step exists, between the Tailwind rebuild and the summary, and names its slugs.
# awk, not grep: a heading that is gone must reach the fail below, not abort under pipefail.
at() { awk -v re="$1" '$0 ~ re { print NR; exit }' "$cmd"; }
s65=$(at '^## Step 6[.]5:'); s67=$(at '^## Step 6[.]7: Blog templates'); s7=$(at '^## Step 7:')
[ -n "$s65" ] && [ -n "$s67" ] && [ -n "$s7" ] || fail "$cmd must keep '## Step 6.5:', '## Step 6.7: Blog templates' and '## Step 7:'"
[ "$s65" -lt "$s67" ] && [ "$s67" -lt "$s7" ] || fail "Step 6.7 must sit after Step 6.5 and before Step 7"
need_token "$cmd" 'section slug is `blog`, `journal`, `news` or `posts`' 'Step 6.7 must name the slugs it applies to'
need_token "$cmd" '[--no-blog-page]' 'the argument hint must name --no-blog-page'
need_token "$cmd" '**`--no-blog-page` flag**' 'Step 1 must parse --no-blog-page'

# It runs the real command rather than a copy of it.
need_token "$x" 'read `${CLAUDE_PLUGIN_ROOT}/commands/wp-page.md` and follow it with the arguments' 'Step 6.7 must run /wp-page by reading commands/wp-page.md'
need_token "$x" 'this step does not reimplement any part of it' 'Step 6.7 must say it does not reimplement /wp-page'
need_token "$x" 'do not undo the section' 'a /wp-page stop must leave the built section in place'

# The five skips.
need_token "$x" '**`--no-blog-page` was passed.**' 'the --no-blog-page skip is gone'
need_token "$x" '**`--transcribe` was passed.**' 'the /wp-yolo (--transcribe) skip is gone'
need_token "$x" '**The project is cinematic**' 'the cinematic skip is gone (/wp-page has no cinematic CSS route)'
need_token "$x" '**The blog templates already exist.**' 'the already-built skip is gone'
need_token "$x" "$marker" 'the already-built skip must test the card template /wp-page blog writes'
need_token "$x" '**`archive.php` or `single.php` exists and the operator does not confirm.**' 'the overwrite confirmation is gone'
need_token "$x" 'Never overwrite a template to get past one of them.' 'the skips must forbid overwriting'
[ "$(grep -Ec '^Usage: /wp-section .*\[--no-blog-page\]' "$cmd")" -gt 0 ] || fail 'the Step 1 usage line must list --no-blog-page'
need_token skills/wp-section-run/SKILL.md '[references/blog-templates.md](references/blog-templates.md)' 'the skill table must list blog-templates.md'

# The skips are checked in order, so their numbers must run 1..5 in the reference.
order=$(awk '/^[0-9]\. \*\*/ { printf "%s", substr($0, 1, 1) }' "$ref")
[ "$order" = 12345 ] || fail "blog-templates.md skips must be numbered 1-5 in order, found '$order'"

# The facts the skips rest on.
need_token skills/wp-page-run/references/blog.md "**$marker**" \
  "/wp-page blog no longer writes $marker, so Step 6.7's already-built test would never fire"
need_token commands/wp-yolo.md '**Blog** — if any `pages[role=blog]` entry exists, run `/wp-page blog`.' \
  '/wp-yolo no longer runs /wp-page blog itself, so the --transcribe skip would leave a yolo build without blog templates'
need_token "$cmd" '`/wp-yolo` sets `--transcribe --block <block> --css <css-source>` on every `/wp-section` dispatch' \
  '/wp-yolo no longer marks its walk with --transcribe, so the skip would not fire inside /wp-yolo'

# The summary reports the step.
need_token "$cmd" 'Blog templates: built by /wp-page blog | skipped (<reason>)' 'the Step 7 summary must report Step 6.7'
for line in 'Blog templates: built by /wp-page blog' 'Blog templates: skipped (<reason>)' 'Blog templates: /wp-page blog stopped: <its message>'; do
  need_token "$ref" "$line" "blog-templates.md must give the summary line: $line"
done

echo PASS
