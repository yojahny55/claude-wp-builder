#!/usr/bin/env bash
# The starter's header.php/footer.php/search.php ship calling get_template_part()
# on a placeholder part (header/site-branding.php, header/navigation.php,
# footer/site-info.php, content-search.php). /wp-header, /wp-footer and
# /wp-page search fully replace those top-level files with project markup and
# drop that get_template_part() call — but on a real build, nothing then deleted
# the now-unreferenced part file, so a starter placeholder (including a credit
# link to an external domain) shipped on disk, unreviewed, one accidental
# get_template_part() away from actually rendering. wp-template.md must instruct
# deleting an orphaned part in the same step its last caller is removed.
#
# Separately: content-page.php (the generic/legal page template) shipped as the
# unstyled underscores boilerplate while every other template in the theme is
# pixel-matched to its demo — it needs its own small baseline.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

# Slice a markdown doc from a heading line down to (not including) the next
# heading of any level, so a grep against the slice can only match inside the
# section it names — not any incidental mention of the same filename or phrase
# elsewhere in a large doc.
section() { # file, heading-regex (ERE, matched against the whole heading line)
  awk -v start="$2" 'on && $0 ~ /^#{1,6} / && $0 !~ start { exit } $0 ~ start { on=1 } on { print }' "$1"
}

wt=agents/wp-template.md
[ -f "$wt" ] || fail "$wt is missing"
orphan=$(section "$wt" 'Delete a starter scaffold part you just orphaned')
[ -n "$orphan" ] || fail "$wt: no 'Delete a starter scaffold part you just orphaned' section"
grep -Fq "site-branding.php" <<<"$orphan" || fail "$wt: orphan-deletion section does not mention header/site-branding.php"
grep -Fq "navigation.php" <<<"$orphan" || fail "$wt: orphan-deletion section does not mention header/navigation.php"
grep -Fq "site-info.php" <<<"$orphan" || fail "$wt: orphan-deletion section does not mention footer/site-info.php"
grep -Fq "content-search.php" <<<"$orphan" || fail "$wt: orphan-deletion section does not mention content-search.php"
# (delete|remove) — a semantically equivalent rewording ("remove the part file")
# must still satisfy this, not just the literal "delete". `part` is word-bounded
# so this cannot be satisfied by "remove that get_template_part() call" -- the
# `_part` in that function name is not the standalone word "part" this pins.
# Body only (tail -n +2): the heading itself is "Delete a starter scaffold
# part you just orphaned" and would otherwise trivially satisfy this on its own.
grep -Eiq "(delete|remove)[^\n]{0,40}\bpart\b" <<<"$(tail -n +2 <<<"$orphan")" \
  || fail "$wt: orphan-deletion section has no instruction to delete/remove the orphaned part file"

cp=starter-theme/__tailwind__/template-parts/content-page.php
[ -f "$cp" ] || fail "$cp is missing"
grep -Fq "if ( ! defined( 'ABSPATH' ) )" "$cp" || grep -Fq "if (!defined('ABSPATH'))" "$cp" \
  || fail "$cp: missing the ABSPATH guard"
grep -Fq "prose" "$cp" || fail "$cp: no styled baseline (expected the prose utility class) — still the unstyled underscores boilerplate"

echo PASS
