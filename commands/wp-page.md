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

### CSS agent routing

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

- `basic` → dispatch `wp-css` exactly as described below.
- `tailwind` → dispatch `wp-tailwind` in **author** mode instead, passing the page
  slug (which selects `components/<slug>.css`) and the block name. The agent reads
  `skills/wp-tailwind-system/SKILL.md` for the decision ladder. It writes utility
  classes into the markup and only adds `@apply` rules where the ladder demands
  them. It must never write `assets/css/styles.css`.

Dispatch exactly one of the two, never both.

Every `tailwind` dispatch opens its quoted prompt with this line, verbatim:

> Mode: **author**

The quoted prompt it opens is the one under "The `tailwind` prompt body" below — **not**
the quoted prompt at the dispatch site, which is the `basic` branch's and names
`assets/css/styles.css`, the one file the `tailwind` path must never write.

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else, so
the line is not decoration: omit it and the dispatched agent falls into Demo Conversion
Mode, reads the prompt as a demo-file conversion and writes a `.tmp` nobody asked for. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, precisely so that an ordinary demo page named after
the word cannot flip the mode by accident.

This routing governs every "Dispatch **wp-css** agent" step below (blog, generic,
legal, 404, search, embed, custom) — each one marks its `tailwind` counterpart with
`(routed — see "CSS agent routing" above)` rather than repeating the block.

**Editing rule for this file.** `tests/checks/wp-commands-tailwind.sh` walks every
dispatch site by matching `Dispatch` and `**wp-css**` on one physical line, and accounts
for every other bolded `**wp-css**` in the file. So: keep `Dispatch` and `**wp-css**`
together on a single line at each dispatch site (never hard-wrap between them), and write
`wp-css` unbolded when you mean it in prose. The one place bolded prose is allowed is
inside this `### CSS agent routing` block — everything from this heading down to the next
heading at `###` or above is exempt, sub-headings and fenced examples included.

#### The `tailwind` prompt body

Every dispatch site below is the `basic` branch, and **on `tailwind` none of them runs at
all** — do not follow the instructions in the site's own quoted prompt there. Dispatch
`wp-tailwind` in author mode with the prompt below instead, substituting the page slug,
the block name and the type this site is for (blog, generic, legal, 404, search, embed,
custom).

**File ownership.** `wp-template` owns every `.php` file this command generates, on both
paths — it is the only agent carrying the ACF, escaping and i18n contract
(`prefix_get_field()`, the `?:` fallbacks, `esc_html()` / `esc_url()` / `esc_attr()`, the
`@package` header, the ABSPATH check), none of which `agents/wp-tailwind.md` describes.
On `tailwind`, `wp-template` keeps the Tailwind utility classes already on the markup it
was handed instead of inventing BEM names, and `wp-tailwind` runs **after** it returns —
never beside it — editing only class names in the file `wp-template` wrote. The invariant:
no page ships without its ACF wiring and escaping, and no page ships on BEM class names in
a Tailwind theme.

> Mode: **author**
>
> Promote the `<type>` page's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Page slug: `--page <slug>` (decides `components/<slug>.css`)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: the template files the wp-template agent has just written for this
>   page type, already carrying Tailwind utility classes — quoted below.
>
> Requirements:
> 1. Those template files belong to wp-template. Edit them in place; do not create
>    them and do not rewrite them. The only thing you change is class names. Leave
>    every `prefix_get_field()` call, every `esc_html()` / `esc_url()` / `esc_attr()`
>    wrapper, every fallback and every PHP control structure exactly as you found it.
> 2. Tailwind utility classes in the markup are the default. Most pages need no CSS
>    file entry at all, and the templates come back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `components/<slug>.css` if it
>    is local to this one. Grep the theme's other `components/*.css` and `*.php`
>    before choosing.
> 4. Name a class you write into `components/<slug>.css` `<block>__<element>`. Name
>    one you write into `utilities/site.css` `site__<element>` instead — it qualified
>    for that file precisely because it spans more than one block.
> 5. If a target CSS file does not exist, create it with its first rule already in it
>    and add its `@import` to `main.css` in the same step, naming its cascade layer
>    (`layer(components)` for `components/<slug>.css`, `layer(utilities)` for
>    `utilities/site.css`) — a bare `@import` beats every Tailwind utility regardless
>    of specificity. Never leave an empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`). No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Page markup:
> ```php
> <paste the generated template files here>
> ```

---

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

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

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

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

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

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

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

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

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

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add custom page CSS to `assets/css/styles.css` within delimiters.

## Step 3.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Step 4: Print Summary

```
=== Page Template "<Type>" Built ===
Files created:
  - <list of files>

Next: Continue with more sections or run /wp-finalize when ready.
```
