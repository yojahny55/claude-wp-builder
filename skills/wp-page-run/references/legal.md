# /wp-page — Type: legal

`commands/wp-page.md` sends the run here at "Type: legal" (the legal page template, the search-exclusion include, its ACF fields and CSS dispatch). Follow it in order; nothing in it is optional background.

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
