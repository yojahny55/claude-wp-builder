# /wp-page — Type: legal

`commands/wp-page.md` sends the run here at "Type: legal" (the legal page template, the search-exclusion include, its ACF fields and CSS dispatch). Follow it in order; nothing in it is optional background.

## Contents

- Templates, fields and CSS — `page-legal.php`, `inc/legal-search.php`, `fields/legal.php`, the legal CSS
- Create and seed the legal pages — Privacy, Terms and Cookie Policy drafts through `scripts/legal-pages.php`

## Templates, fields and CSS

Dispatch **wp-template** agent:

> Generate `page-legal.php`:
> ```php
> <?php
> /**
>  * Template Name: Legal Page
>  * @package <slug>
>  */
> ```
> - `get_header()`
> - Legal page title from `prefix_get_field('legal_title')` with fallback to `get_the_title()`
> - Last updated date from `prefix_get_field('legal_last_updated')`
> - Content from `prefix_get_field('legal_content')` rendered with `wp_kses_post()`
> - Table of contents generated from headings (optional)
> - `get_footer()`
> - BEM classes: `.legal__*`

Dispatch **wp-template** agent (second file):

> Generate `inc/legal-search.php`, required from `functions.php`:
> - `pre_get_posts`, main query, `is_search()` only: look the legal pages up by
>   template rather than hardcoding IDs, so both languages and any legal page
>   added later are covered. `post__not_in` takes post IDs only — it cannot match
>   a meta value — so query the IDs first and pass those:
>
>   ```php
>   $legal_ids = get_posts( array(
>       'post_type'      => 'page',
>       'fields'         => 'ids',
>       'posts_per_page' => -1,
>       'meta_key'       => '_wp_page_template',
>       'meta_value'     => 'page-legal.php',
>   ) );
>   if ( $legal_ids ) {
>       $query->set( 'post__not_in', $legal_ids );
>   }
>   ```
> - The legal pages are footer boilerplate nobody searches for; a match on
>   "privacidad" or "cookies" only pushes a real result off the first page. They
>   stay published, linked and indexable — this hides them from site search only.

Dispatch **wp-acf** agent:

> Generate `fields/legal.php`:
> - Field group shown on pages using "Legal Page" template
> - Fields: `legal_title` (text, bilingual), `legal_last_updated` (date_picker), `legal_content` (wysiwyg, bilingual)
> - Group key: `group_legal`

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add legal page CSS to `assets/css/styles.css` within delimiters. Include: narrow content width, readable typography, heading anchors, list styling, last-updated styling.

## Create and seed the legal pages

The template alone leaves the site with no Privacy Policy, Terms or Cookie Policy page, and
`/wp-finalize` (GEO-A11) fails a stub privacy page. This step creates the three pages as
**drafts** with content drafted from what the project records. Nothing is published: legal
text goes live only after the client reviews it.

Resolve the WP-CLI wrapper from the manifest first and use it as `$WP` below:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" wp_cli.wrapper' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

**1. Gather the facts — only recorded ones.** Read the project's `.claude/CLAUDE.md`
(business name, country, contact email, languages, i18n strategy), the store tier from the
manifest (`store`, `catalog`, …; exit `1` with `unknown key` means the site is not a store),
and the active plugins:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" store.tier' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
$WP plugin list --status=active --field=name
```

They say what the site collects: Contact Form 7 (form submissions), WooCommerce (orders,
accounts, payments), an analytics or tag plugin (cookies and third parties), Rank Math (none
of its own).

**2. Draft each page in each language it needs.** One `privacy`, one `terms`, one `cookies`
page. Under `i18n strategy: suffix` (or no recorded strategy) draft every language the
project lists; under `polylang` draft the default language only — `/wp-polylang` translates
pages later. Use plain HTML (`<h2>`, `<p>`, `<ul>`), the jurisdiction's usual structure for
the recorded country, and only what step 1 found. **Never invent a fact.** A legal entity
name, registered address, tax or registration number, data-protection contact, retention
period or a processor the plugins do not show is written as `[[pending: <what is missing>]]`.
An invented company number is one the client ships by mistake.

Slugs in the default language: `privacy-policy`, `terms-and-conditions`, `cookie-policy`
in English; `politica-de-privacidad`, `terminos-y-condiciones`, `politica-de-cookies` in
Spanish; the usual equivalent otherwise.

**3. Write the spec and run the script.** Write the drafts to a scratch JSON file outside
the theme — `default_lang`, `updated` (today, `YYYY-MM-DD`) and `pages`, each with `role`,
`slug`, `lang` (Polylang only), and `title` and `content` keyed by language. The script
header documents the shape. Run it dry first, then for real:

```bash
WP="$WP" bash -c '$WP eval-file "$1/skills/wp-page-run/scripts/legal-pages.php" "$2" dry-run' _ "${CLAUDE_PLUGIN_ROOT}" "$spec"
WP="$WP" bash -c '$WP eval-file "$1/skills/wp-page-run/scripts/legal-pages.php" "$2"' _ "${CLAUDE_PLUGIN_ROOT}" "$spec"
```

Per page it prints one JSON line with its `action`:

- `created` — no page had the slug; a draft on the Legal Page template now holds the fields.
- `filled` — WordPress's own Privacy Policy draft, still unfilled; it is filled and stays a draft.
- `kept` — a page someone already wrote holds the slug. It is left exactly as it is; never
  overwrite it, and do not ask to.

`wp_page_for_privacy_policy` is set only when it points at no page. Exit `1` means an entry
was skipped or not written; print the warnings and fix the spec.

**4. Report.** In the summary, list each page with its action and its `pending` count, and
end with: "Legal pages are drafts. Review them with the client, resolve every
`[[pending: …]]`, then publish." Delete the scratch spec.
