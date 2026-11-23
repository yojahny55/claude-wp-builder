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

## Blog language (suffix strategy only)

Read the `i18n strategy` line of the project's `.claude/CLAUDE.md`. Run this step only when
it says `suffix`, or when the line is absent (a project that predates the choice is
`suffix`). Under `polylang`, skip it: Polylang already gives every post its own language.
Skip it too when the project has one language only. It does not depend on the CSS route:
the `basic` and `tailwind` branches both run it.

Under the suffix strategy one page carries every language, but a post is written in one.
This step gives posts a `post_language` select field and filters the blog index, post
archives and search by the visitor's language. A post with no language is listed in every
language, so existing posts stay listed exactly as before until an editor sets one.

The PHP is not written by you or by an agent. It is a fixed file,
`${CLAUDE_PLUGIN_ROOT}/templates/blog-language/blog-language.php`, held to the PHP 7.4 floor.
**Copy it and substitute the three tokens; do not retype or "improve" it.**

| Token | Replace with |
|---|---|
| `__prefix__` | the bare function prefix from `.claude/CLAUDE.md` (no trailing underscore) |
| `__PREFIX__` | the same prefix in upper case, as in the theme's `<PREFIX>_SUPPORTED_LANGS` |
| `__textdomain__` | the theme slug (the theme's `Text Domain`) |

```bash
tmp=$(mktemp)
sed -e "s/__prefix__/<prefix>/g" -e "s/__PREFIX__/<PREFIX>/g" -e "s/__textdomain__/<slug>/g" \
  "${CLAUDE_PLUGIN_ROOT}/templates/blog-language/blog-language.php" > "$tmp"
if grep -q '__prefix__\|__PREFIX__\|__textdomain__' "$tmp"; then echo "UNSUBSTITUTED TOKENS"; exit 1; fi
php -l "$tmp"
grep -c "<PREFIX>_SUPPORTED_LANGS" "<theme>/inc/i18n.php"
```

The last line must print at least `1`: the file reads the language list from that constant
and does nothing without it. When `<theme>/inc/blog-language.php` already exists and differs
from `$tmp`, stop and show the diff — someone edited it. Otherwise copy `$tmp` there, and
require it from `functions.php` after `inc/i18n.php`, unless the theme already loops over
`inc/*.php` (never load it twice):

```php
require_once __DIR__ . '/inc/blog-language.php';
```

The field is registered in code, not in `fields/`: it is part of this file's contract with
the query filter, not a dashboard-editable group. Report it in the summary as
"Blog language: posts carry `post_language`; lists filter by it".
