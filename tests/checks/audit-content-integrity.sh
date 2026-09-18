#!/usr/bin/env bash
# Data defects a correct theme cannot reveal, and the two rules that keep them reportable.
#
# WP-048  A relationship field kept the ID of a deleted post, so the template painted a card
#         with no title, no terms and an empty href. The sweep found 70 orphans and exactly 1
#         reached the HTML, so the rule has to split by whether a template reads the field —
#         70 flat warnings bury the one that is visible.
# SEO-054 A `custom` menu item stores its target in postmeta._menu_item_url, so a broken menu
#         link is invisible to anything that reads the theme, and the menu in question was
#         assigned through a widget rather than a registered location. The child exclusion is
#         load-bearing: a `custom` item with `#` and children is a submenu header.
# 6.10    §6.9 makes a finding a measurement; nothing said the same of a fix. A 200 response
#         after an edit proves the site did not break, not that the defect is gone.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

PRA=agents/wp-audit-practices.md
SEO=agents/wp-audit-seo.md
CMD=commands/wp-audit.md
SKILL=skills/wp-cli-patterns/SKILL.md
ORPHAN=skills/wp-cli-patterns/scripts/find-orphan-acf-ids.php
MENU=skills/wp-cli-patterns/scripts/audit-menu-links.php

for f in "$PRA" "$SEO" "$CMD" "$SKILL" "$ORPHAN" "$MENU"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- both codes are tabulated; an agent only runs what a table lists ----------
grep -qE "^\| WP-048 \|" "$PRA" || fail "$PRA: WP-048 is not tabulated"
grep -qE "^\| SEO-054 \|" "$SEO" || fail "$SEO: SEO-054 is not tabulated"

# --- WP-048: the split is what makes the finding readable --------------------
grep -q "REACHES-TEMPLATE" "$ORPHAN" || fail "$ORPHAN: findings are not split by template reach"
grep -q "DEAD-DATA" "$ORPHAN" || fail "$ORPHAN: findings are not split by template reach"
grep -qiE "70 |70\b" "$PRA" || fail "$PRA: WP-048 does not carry the measured ratio that justifies the split"
# A value is only an ID when the field's type says so. Without this a date field is an orphan.
grep -q "acf_get_field" "$ORPHAN" || fail "$ORPHAN: field types are not resolved, so numeric fields become false positives"
for t in relationship post_object page_link; do
  grep -q "'$t'" "$ORPHAN" || fail "$ORPHAN: field type $t is not in the ID-bearing list"
done
# A trashed post still has a permalink, and get_post_status() answers 'trash', not false.
grep -q "get_post_status" "$ORPHAN" || fail "$ORPHAN: a non-publish status is not treated as a finding"
grep -qi "non-\`\?publish\`\? status\|status=\|non-publish" "$PRA" \
  || fail "$PRA: WP-048 does not cover an ID that resolves to a draft or trashed post"

# --- SEO-054: the child exclusion, and menus read from the database ----------
grep -q "_menu_item_url" "$SEO" || fail "$SEO: SEO-054 does not say where a custom item's target lives"
grep -q "menu_item_parent" "$MENU" || fail "$MENU: submenu headers are not detected"
grep -qi "children are excluded" "$SEO" || fail "$SEO: SEO-054 does not exclude items with children"
grep -qi "not optional" "$SEO" || fail "$SEO: the child exclusion is not marked load-bearing"
grep -qi "widget" "$SEO" || fail "$SEO: SEO-054 does not say a menu can be assigned by widget"
grep -q "wp_get_nav_menus" "$MENU" || fail "$MENU: must walk every menu, not only assigned locations"
# Editing the URL leaves a custom item carrying a host; converting the type does not.
grep -q "post_type" "$SEO" || fail "$SEO: SEO-054 does not prefer converting to a post_type item"

# --- both scripts are read-only deploy gates ---------------------------------
for f in "$ORPHAN" "$MENU"; do
  if grep -nE '\$wpdb->(query|update|delete|insert|replace)\(|wp_(update|delete|insert)_post\(|update_post_meta\(' "$f" >/dev/null 2>&1; then
    fail "$f: an audit script must be read-only"
  fi
  grep -qE "^exit\( \\\$(findings|reaching) > 0 \? 1 : 0 \);" "$f" \
    || fail "$f: must exit 1 on a finding so a shell script can gate on it"
  grep -q "WHY THIS EXISTS" "$f" || fail "$f: the header does not name the defect that motivated it"
done

# --- both scripts are documented where an agent will find them ---------------
for name in find-orphan-acf-ids.php audit-menu-links.php; do
  grep -q "$name" "$SKILL" || fail "$SKILL: $name is not documented"
done

# --- matching by ID across installs, and the drafts gotcha -------------------
grep -q "post_name__in" "$SKILL" || fail "$SKILL: the slug-lookup pattern is not documented"
grep -qi "does not return drafts" "$SKILL" \
  || fail "$SKILL: the 'name' + 'any' gotcha is not written down"

# --- a fix is measured against the case that produced the finding ------------
grep -q "Step 6.10" "$CMD" || fail "$CMD: nothing requires a fix to be verified"
grep -qi "still returns 200\|still return 200" "$CMD" \
  || fail "$CMD: 6.10 does not say a 200 response proves nothing"
grep -qi "reproducing case" "$CMD" || fail "$CMD: 6.10 does not require naming the reproducing case"
grep -q "UNVERIFIED" "$CMD" || fail "$CMD: an unverifiable fix has no outcome"
# 6.10 has to come after 6.9 and before Step 7, or the run order makes it unreachable.
awk '/^## Step 6\.9/{a=NR} /^## Step 6\.10/{b=NR} /^## Step 7/{c=NR}
     END { exit !(a && b && c && a < b && b < c) }' "$CMD" \
  || fail "$CMD: Step 6.10 is not between 6.9 and Step 7"

# --- no client, host or slug names reach the plugin --------------------------
# A bare `.local` is generic and already used in commands/wp-audit.md to describe the shape of
# a development URL. What must never appear is a real host: a label followed by a TLD.
if grep -nEi "[a-z0-9-]+\.local\.[a-z]{2,}" "$PRA" "$SEO" "$CMD" "$SKILL" "$ORPHAN" "$MENU" >/dev/null 2>&1; then
  fail "a development host name reached the plugin"
fi

echo PASS
