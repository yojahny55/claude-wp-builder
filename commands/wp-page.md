---
description: Generate page templates — blog, generic, legal, 404, search, embed, or custom page types
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<type> [name] [screenshot-path] [--provider <name>]"
---

# WP Page — Page Template Generator

Generate complete page templates with associated ACF fields and CSS based on the page type.

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:
- **First word** = page type (required): `blog`, `generic`, `legal`, `404`, `search`, `embed`, or `custom`
- **Second word** = name/slug (required for `custom` AND `embed` types)
- **`--provider <name>`** (used by `embed`) = sets the provider name; strip this flag and its value from the arguments before resolving the screenshot path, so it is never treated as the screenshot path
- **Remaining words** = screenshot path (optional)

If no type is provided, print an error:
```
Error: Page type is required.
Usage: /wp-page <type> [name] [screenshot-path]
Types: blog, generic, legal, 404, search, embed, custom
Examples:
  /wp-page blog
  /wp-page generic
  /wp-page legal
  /wp-page 404
  /wp-page search
  /wp-page embed home-search --provider "Showcase IDX"
  /wp-page custom pricing
```

## Step 2: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix**
- **Theme slug**
- **Languages**
- **Theme directory path**

## Step 3: Generate by Type

### Type: blog

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

Dispatch **wp-css** agent:

> Add blog CSS to `assets/css/styles.css` within delimiters:
> ```css
> /* ============ BLOG ============ */
> ...
> /* ============ END BLOG ============ */
> ```
> Include: archive grid layout, card styles, single post layout, featured image, author bio, pagination styling, responsive breakpoints.

---

### Type: generic

Dispatch **wp-template** agent:

> Generate `page-generic.php`:
> ```php
> <?php
> /**
>  * Template Name: Generic Page
>  * @package <slug>
>  */
> ```
> - `get_header()`
> - Page title from `get_the_title()`
> - `the_content()` for flexible page content
> - `get_footer()`
> - Simple, clean layout with `.page-generic__*` BEM classes

Dispatch **wp-css** agent:

> Add generic page CSS to `assets/css/styles.css` within delimiters. Include: content width constraint, typography for body content (headings, paragraphs, lists, blockquotes), responsive spacing.

---

### Type: legal

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

Dispatch **wp-acf** agent:

> Generate `fields/legal.php`:
> - Field group shown on pages using "Legal Page" template
> - Fields: `legal_title` (text, bilingual), `legal_last_updated` (date_picker), `legal_content` (wysiwyg, bilingual)
> - Group key: `group_legal`

Dispatch **wp-css** agent:

> Add legal page CSS to `assets/css/styles.css` within delimiters. Include: narrow content width, readable typography, heading anchors, list styling, last-updated styling.

---

### Type: 404

Dispatch **wp-template** agent:

> Generate `404.php` — a fully styled theme template, NOT the starter/underscores
> boilerplate. Overwrite any existing `404.php`. Match the site's visual design:
> reuse the theme's buttons, typography, and spacing, and apply frontend-design
> best practices so it reads as a converted theme page (header/footer supply the chrome).
> - `get_header()`
> - Centered error message section:
>   - Large "404" display heading
>   - Message: `prefix_get_field('404_message', 'option')` with fallback "Page not found"
>   - Description: `prefix_get_field('404_description', 'option')` with fallback
>   - Search form using `get_search_form()`
>   - "Back to Home" button linking to `home_url('/')`, styled with the theme's button class
>   - Optional: recent posts or suggested pages
> - `get_footer()`
> - BEM classes: `.error-404__*`, matching the design tokens in the theme CSS

Dispatch **wp-css** agent:

> Add 404 page CSS to `assets/css/styles.css` within delimiters, using the project's
> design-system custom properties (no new colors). Include: centered layout, large 404
> text, search form styling, themed button, responsive design.

---

### Type: search

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

Dispatch **wp-css** agent:

> Add search-results + no-results state CSS to the theme stylesheet within delimiters,
> using the project's design-system custom properties (no new colors).

---

### Type: embed

For provider-delivered pages (IDX, booking, tours) that are NOT built as normal templates — the third-party plugin supplies the functionality; we supply a styled page with a clear insertion point.

If `<slug>` is `home` or `front` (the site's front page), the generated template file is
**`front-page.php`** (WordPress never uses `page-home.php` for a static front page);
otherwise the file is `page-<slug>.php`. The marked insertion point and container go into
whichever file applies.

Dispatch **wp-template** agent:

> Generate `front-page.php` (if `<slug>` is `home`/`front`) or `page-<slug>.php` (otherwise):
> - `get_header()`
> - Optional page title/intro from `prefix_get_field()` (chrome only)
> - A styled container `<div class="embed-<slug>">` containing a clearly-marked insertion point:
>   `<!-- EMBED: <provider> shortcode/block goes here -->`
> - `get_footer()`
> - Escape all output; BEM class `.embed-<slug>__*`

Dispatch **wp-acf** agent (optional, chrome only):

> Generate `fields/<slug>.php`: heading/intro/notes fields bound to the `<Slug> Page` template. NOT the provider data. Group key `group_<slug>`.

Dispatch **wp-css** agent:

> Add `.embed-<slug>` container + placeholder styling within delimiters, using design-system custom properties (no new colors).

Print in the summary: `Requires plugin: <provider> — install and configure, then insert its shortcode/block at the marked insertion point.`

---

### Type: custom

Dispatch **wp-template** agent:

> Generate `page-<name>.php`:
> ```php
> <?php
> /**
>  * Template Name: <Name> Page
>  * @package <slug>
>  */
> ```
> - `get_header()`
> - Content structure based on what the user described or the screenshot
> - Use `prefix_get_field()` for all dynamic content
> - `get_footer()`
> - BEM classes: `.<name>__*`

Dispatch **wp-acf** agent (if the page has custom fields):

> Generate `fields/<name>.php`:
> - Field group shown on pages using "<Name> Page" template
> - Fields based on the page content requirements
> - Group key: `group_<name>`

Dispatch **wp-css** agent:

> Add custom page CSS to `assets/css/styles.css` within delimiters.

## Step 4: Print Summary

```
=== Page Template "<Type>" Built ===
Files created:
  - <list of files>

Next: Continue with more sections or run /wp-finalize when ready.
```
