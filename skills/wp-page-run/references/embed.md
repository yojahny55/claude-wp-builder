# /wp-page — Type: embed

`commands/wp-page.md` sends the run here at "Type: embed" (the provider-embed page template, its optional ACF fields, CSS dispatch and the summary line). Follow it in order; nothing in it is optional background.

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
