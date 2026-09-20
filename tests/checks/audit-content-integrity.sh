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

# --- a deploy gate must not fire on a host it only resembles -----------------
# strpos($url, $dev_host) also matches 'mydev.example.com' against 'dev.example.com'
# and '/go?to=dev.example.com'. Both exit 1, so both block a deploy.
grep -q "parse_url( \$url, PHP_URL_HOST )" "$MENU" \
  || fail "$MENU: the dev-host test must compare the host component, not a substring"
if grep -n 'strpos( \$url, \$dev_host )' "$MENU" >/dev/null 2>&1; then
  fail "$MENU: the substring host test is back"
fi

# --- a revision's orphan is a copy of its parent's --------------------------
# ACF can write field values onto revision posts. The operator cannot fix a revision,
# and fixing the parent fixes both, so reporting it is duplicate noise.
grep -q "post_type <> 'revision'" "$ORPHAN" || fail "$ORPHAN: revisions are not excluded"
# Only revisions. A draft or private page is real content whose fields reach a template
# on preview, so filtering on post_status would hide live findings.
if grep -n "p.post_status = 'publish'" "$ORPHAN" >/dev/null 2>&1; then
  fail "$ORPHAN: filtering parents by post_status hides drafts, which are real findings"
fi

# --- an unusable theme path must not read as a clean result -----------------
# With no read-field list every orphan is labelled DEAD-DATA and the script exits 0,
# which is the most reassuring possible output for a classification that never ran.
grep -q "is not a directory" "$ORPHAN" \
  || fail "$ORPHAN: a theme path that does not resolve is silently accepted"

# --- both quoting styles, or a read field is misfiled as dead data ----------
# Run the pattern instead of grepping for it. Every grep written against this source was
# wrong in a way that still passed: a fixed string pins the order of the character class,
# and testing the quote characters against the whole line passes on a pattern that dropped
# the double quote, because the PHP literal is itself delimited by double quotes.
behavior="$(dirname "$0")/lib/acf-field-pattern-behavior.php"
[ -f "$behavior" ] || fail "$behavior is missing"
if ! command -v php >/dev/null 2>&1; then
  echo "SKIP: php not found — the greps above passed, the field-pattern test did not run"
else
  out=$(php "$behavior" 2>&1) \
    || fail "the get_field() pattern is wrong: ${out:-(php exited non-zero with no output)}"
fi

# --- a file too large to hold in memory is skipped, and said out loud --------
# file_get_contents() reads the whole file. A generated or vendored file in the theme
# tree can be tens of megabytes, and this pass would hold all of it to collect field
# names. Skipping quietly would drop that file's field reads and misfile them as dead
# data, so the skip has to reach the operator.
grep -q "max_bytes" "$ORPHAN" \
  || fail "$ORPHAN: no size cap before file_get_contents()"
grep -q "skipped " "$ORPHAN" \
  || fail "$ORPHAN: a file skipped for size is not reported"
grep -q "isFile()" "$ORPHAN" \
  || fail "$ORPHAN: non-regular entries are read as files"

# --- a half-measured gate must say so, not report a clean run ---------------
# home_url() with no host makes the dev-host half a no-op; "0 items" would then cover
# one of the two defects this gate exists to catch.
grep -q "only the '#' check runs" "$MENU" \
  || fail "$MENU: an empty dev host is skipped silently"

# --- a menu can hold more than one location ---------------------------------
if grep -n "array_flip( (array) get_nav_menu_locations()" "$MENU" >/dev/null 2>&1; then
  fail "$MENU: array_flip keeps one location per menu and renames the rest"
fi

# --- zero is not a post ID --------------------------------------------------
# get_post_status( 0 ) answers false, so a cleared field would read as a deleted post.
grep -q "(int) \$candidate > 0" "$ORPHAN" \
  || fail "$ORPHAN: a zero in a relationship array is reported as a deleted post"

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
grep -qiE "still returns? 200" "$CMD" \
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
