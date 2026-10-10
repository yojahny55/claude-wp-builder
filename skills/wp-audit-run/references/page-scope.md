# /wp-audit — Step 2.7

`commands/wp-audit.md` sends the run here at Step 2.7. Follow it in order; nothing in it is optional background.

The audit reads the theme. A client reads a site, page by page, and several criteria exist
only by comparing pages: a logo that moves between templates, a type scale that changes, a
menu item that is marked active on one page and not another. None of those is visible from
a single template, and none of them has a `file:line`.

So before any page-level check runs, fix the list of pages. Skip this step entirely when
the scope is `none`.

**`auto` derives the list, in this order, and stops at the first that yields pages:**

1. `.wp-create.json` `pages`, if the project records one.
2. The primary menu — `$WP menu item list <menu> --format=json` at Tier 2.
3. `sitemap.xml` (or `sitemap_index.xml`) from the site URL.
4. The internal links on the home page.

Then **always** add, if they exist: the 404, and any page carrying a form. They are where a
third of the usability catalog lives and no derivation finds them by ranking.

- **Taxonomy archives** are not at `/category/<slug>/` by assumption. Read the bases first:
  `$WP option get category_base` and `$WP option get tag_base` (empty means `category` and
  `tag`), and take archive URLs from the sitemap or `$WP term list category --field=url`
  rather than building them.
- **The 404** is a URL that cannot resolve — `<site>/<a path nothing serves>`. Do not look
  for it; construct it.
- **The form page**, at Tier 2, from the site itself rather than by fetching every candidate:

  ```bash
  bash -c "$WP post list --post_type=page --fields=ID,post_name,post_title --format=csv \
    --s='[contact-form-7' --meta_key=_wp_page_template"
  ```

  Repeat for the form plugin actually installed (`[gravityform`, `[wpforms`, `<form`). With
  no Tier 2, fetch the pages already in the list and keep the first whose HTML contains a
  `<form>` that is not the search form; when none does, say the form page could not be found
  rather than reporting category A as passing.

**Cap the list at eight pages and say you capped it.** A representative set — home, a
listing, a detail, the page with the main form, the 404 — measures the templates; auditing
forty pages measures the same five templates eight times each and makes the report unusable
for the person who has to act on it. When the site has more, take one page per template and
name the templates covered.

**Grouping by template** is `_wp_page_template` at Tier 2:

```bash
bash -c "$WP post list --post_type=page --fields=ID,post_title --format=csv \
  --meta_key=_wp_page_template --meta_value=<template.php>"
```

Without Tier 2 there is no template metadata, so group by URL shape instead — one page per
path depth and per post type prefix — and say in the report that the grouping was inferred
from URLs. An inferred grouping that is announced is usable; one that is presented as
template coverage is not.

Print the scope before measuring:

```
=== Page Scope ===
Source: <manifest|menu|sitemap|home links>
Pages (N):
  /                      home
  /services/             listing
  /services/<one>/       detail
  /contact/              form
  /<404 probe>           404
<Capped from M pages — one per template.>
```

**A page-level criterion with no page list is `UNMEASURED`, never `PASS`.** This is the same
rule the tiers already follow, and it is worth restating here because the failure is quiet:
an audit that measured nothing page-level and printed no failures reads exactly like a site
with no page-level problems.

### Page-level and site-level are different answers

A criterion answered per page is reported on **every page it fails on** — the fix is per
template and a single row would hide which page is wrong. A criterion that can only be
answered by comparing pages is evaluated **once**, and when it fails it names the pages it
differs between. `skills/wp-audit-ux-standards/SKILL.md` holds the split; the same shape
applies to any other category that grows page-level checks.

### What a score means once pages exist

With a page list, the report scores: criteria passed over criteria that **applied**, per
page, per category and overall.

**`N/A` is excluded from the denominator and reported beside it, never inside it.** A site
is not worse for lacking a feature it was never meant to have, and 30/40 on what applied is
a measurement where 30/56 against a list including sixteen that never applied is a number
that punishes a site for its own shape. `UNMEASURED` is excluded too, and for the opposite
reason: it is work outstanding, and folding it into either side of the fraction hides it.
