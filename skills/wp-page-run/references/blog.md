# /wp-page — Type: blog

`commands/wp-page.md` sends the run here at "Type: blog" (the blog archive, single post and card templates, their ACF fields and CSS dispatch). Follow it in order; nothing in it is optional background.

Dispatch **wp-template** agent:

> Generate these blog template files:
>
> **archive.php** — Blog archive/listing page:
> - `get_header()`
> - Page title section with `prefix_get_field('blog_heading')` fallback "Blog"
> - Loop through posts using the main query
> - Each post uses `get_template_part('template-parts/journal/content', 'journal-card')`
> - Pagination with `the_posts_pagination()`
> - `get_footer()`
>
> **single.php** — Single post view:
> - `get_header()`
> - Article with `get_template_part('template-parts/journal/content', 'single-post')`
> - Post navigation with `the_post_navigation()`
> - `get_footer()`
>
> **template-parts/journal/content-journal-card.php** — Blog card component:
> - Thumbnail with `get_the_post_thumbnail()` and fallback placeholder
> - Category label
> - Title linked to permalink
> - Excerpt
> - Date and read time estimate
> - BEM classes: `.journal-card__*`
>
> **template-parts/journal/content-single-post.php** — Full post content:
> - Featured image (full width)
> - Category, date, author
> - `the_content()` for post body
> - Tags
> - Author bio box
> - BEM classes: `.single-post__*`
>
> All output must be escaped. Use semantic HTML5. Follow the project conventions.

Dispatch **wp-acf** agent:

> Generate `fields/blog.php`:
> - Field group shown on Posts page (options page or page for posts)
> - Fields: `blog_heading` (text, bilingual), `blog_subheading` (textarea, bilingual), `blog_posts_per_page` (number, default 6)
> - Group key: `group_blog`

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add blog CSS to `assets/css/styles.css` within delimiters:
> ```css
> /* ============ BLOG ============ */
> ...
> /* ============ END BLOG ============ */
> ```
> Include: archive grid layout, card styles, single post layout, featured image, author bio, pagination styling, responsive breakpoints.
