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
fail() { echo "FAIL: $1"; exit 1; }

wt=agents/wp-template.md
[ -f "$wt" ] || fail "$wt is missing"
grep -Fq "site-branding.php" "$wt" || fail "$wt: no mention of the orphaned header/site-branding.php part"
grep -Fq "navigation.php" "$wt" || fail "$wt: no mention of the orphaned header/navigation.php part"
grep -Fq "site-info.php" "$wt" || fail "$wt: no mention of the orphaned footer/site-info.php part"
grep -Fq "content-search.php" "$wt" || fail "$wt: no mention of the orphaned content-search.php part"
grep -Eiq "delete (the|that|a) part" "$wt" || fail "$wt: no instruction to delete the orphaned part file"

cp=starter-theme/__tailwind__/template-parts/content-page.php
[ -f "$cp" ] || fail "$cp is missing"
grep -Fq "if ( ! defined( 'ABSPATH' ) )" "$cp" || grep -Fq "if (!defined('ABSPATH'))" "$cp" \
  || fail "$cp: missing the ABSPATH guard"
grep -Fq "prose" "$cp" || fail "$cp: no styled baseline (expected the prose utility class) — still the unstyled underscores boilerplate"

echo PASS
