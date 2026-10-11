# /wp-page — Type: search

`commands/wp-page.md` sends the run here at "Type: search" (the search results template and its CSS dispatch). Follow it in order; nothing in it is optional background.

Dispatch **wp-template** agent:

> Generate `search.php` — a fully styled theme template, NOT the starter/underscores
> boilerplate. Overwrite any existing `search.php`. Reuse the site's card/list markup and
> design tokens so results and the no-results state read as converted theme pages.
> - `get_header()`
> - Page title: `printf( esc_html__( 'Search results for: %s', '<slug>' ), '<span>' . get_search_query() . '</span>' )`
> - `if ( have_posts() )` loop reusing the site's card/list markup via
>   `get_template_part('template-parts/content', get_post_type())` with a fallback template part
> - `the_posts_pagination()`
> - `else` → styled **no-results** block: heading, message, and `get_search_form()`
> - `get_footer()`
> - BEM classes: `.search-results__*`, matching the design tokens in the theme CSS

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add search-results + no-results state CSS to the theme stylesheet within delimiters,
> using the project's design-system custom properties (no new colors).
