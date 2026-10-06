---
name: wp-theme-standards
description: Sets the standards for a classic (non-block) WordPress theme built from this plugin's starters — the layout read from the recorded template, one enqueue callback with filemtime cache busting, escaping (esc_html, wp_kses with an allowlist, never the_field), the unfiltered_html gate on SVG uploads, the SCF/ACF Local JSON field model in acf-json/, image delivery in inc/performance.php, self-hosted fonts and the LCP preload, and the .nav__toggle and .nav__link class contract shared by the walker and the header CSS. Use when writing or reviewing a theme's functions.php, inc/*.php or templates (enqueueing, escaping a headline that carries markup, theme supports, SVG uploads, image delivery, a stale stylesheet that will not update), or the nav classes in header CSS. Not for a site audit (wp-audit-standards) or Tailwind CSS (wp-tailwind-system).
user-invocable: false
---

# WordPress Classic Theme Standards

This skill defines the mandatory standards for building WordPress themes using the **classic theme** architecture. No block themes, no Full Site Editing (FSE), no theme.json.

## Reference files

The rules are below. The PHP that implements them lives in two files — copy from there rather
than retyping it:

- [references/setup-and-enqueue.md](references/setup-and-enqueue.md) — enqueueing code (styles, scripts, `wp_localize_script()`, page-specific assets),
  theme supports and content width, custom body classes, the SCF/ACF options page, helper
  functions and SVG upload support. Read when writing `functions.php` or `inc/theme-setup.php`.
- [references/head-and-performance.md](references/head-and-performance.md) — the self-hosted font preload, the LCP preload, emoji and version removal, and
  the meta-description fallback. Read when writing anything hooked to `wp_head` or `init`.

---

`style.css` carries the theme header and no styles: every rule goes where the template's
layout puts it (below), enqueued via `functions.php`.

---

## Theme layout — read the recorded template, then the starter

There is no single layout to type from memory. Read the `Template:` line in the project's
`.claude/CLAUDE.md`, then take every path from the starter that template was copied from
(or from the project's own theme, which `/wp-init` copied from it):

| `Template:` | Styles | Scripts | Read |
|---|---|---|---|
| `tailwind` | exactly one compiled stylesheet, `assets/css/dist/main.css`, built from `assets/css/src/tailwindcss/` — never a second stylesheet enqueue | `assets/js/dist/index.js`, a wp-scripts bundle built from `assets/js/src/`; dependencies and version come from `index.asset.php` | `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/functions.php` and its `inc/` |
| `cinematic` | `assets/css/cinematic.css` | the scroll engine, enqueued by `inc/cinematic-loader.php` | `${CLAUDE_PLUGIN_ROOT}/starter-theme/__cinematic__/functions.php` and `inc/cinematic-loader.php` |
| `basic` | a project scaffolded before the basic starter was removed: its own `functions.php` is the only reference (`assets/css/styles.css`, `assets/js/main.js`) | | the project's theme |

Both starters split `functions.php` into `inc/` files it requires — the Tailwind one into
`theme-setup.php`, `i18n.php`, `performance.php`, `security.php`, `nav-walker.php`,
`template-tags.php`, `template-functions.php` and `cf7-helpers.php`. Add code to the file
that already owns its concern, never a parallel one: a second declaration of a starter
function is a fatal error.

### SCF/ACF field model — Local JSON is the source of truth

Field groups are **not** left as pure PHP `acf_add_local_field_group()` registrations:
a PHP-local group has no post (`ID=0`), never appears in **Custom Fields → Field
Groups**, and can't be edited or extended by the client. Instead the `acf/init`
loader in the starter's `functions.php` (both starters carry it — read it there rather than
rewriting it) treats `fields/*.php` as a **one-time bootstrap**: it
registers each group once, writes it to `acf-json/<key>.json`, then loads only the
Local JSON thereafter. ACF/SCF auto-loads `acf-json/`, so groups are visible,
editable, and two-way synced (dashboard edits — including manually added fields —
are written back to the JSON files and stay in version control). Never point
`save_json`/`load_json` elsewhere — ACF already defaults to the theme's `acf-json/`.

To **redefine** an existing group in code — a destructive write, so in this order:

1. Read `acf-json/<key>.json` first. Fields a client added in the dashboard live only
   there; carry each one into `fields/<section>.php`, or it is lost in step 3.
2. Edit `fields/<section>.php`.
3. Delete the matching `acf-json/<key>.json` and, if the group was imported to the
   database, delete it there too through the project's WP-CLI wrapper (`$WP` from
   `.wp-create.json`): `$WP eval "var_dump( acf_delete_field_group( 'group_<section>' ) );"`
   (`false` means it was never in the database, which is fine).
4. Load any admin page so the loader re-bootstraps, then confirm `acf-json/<key>.json`
   exists again with the new definition. Not rewritten means the loader did not run or
   `acf-json/` is not writable — stop and report it.

---

## Asset Enqueueing

**NEVER** add `<link>` or `<script>` tags directly in templates. Always use WordPress enqueueing functions.

The theme has one `wp_enqueue_scripts` callback, in `functions.php`; add to it, never a
second one. Styles and scripts are the files the layout table above names, scripts in the
footer. On `Template: tailwind` the theme enqueues exactly one stylesheet, the compiled
`assets/css/dist/main.css`: every rule — fonts included — is compiled into it, so a second
stylesheet enqueue is always wrong there. The code is in
[references/setup-and-enqueue.md](references/setup-and-enqueue.md) § Asset Enqueueing.

### Cache Busting

Version a local stylesheet with `filemtime()` of the file itself, so browsers re-download it
whenever it changes, without manual version bumping. The wp-scripts bundle is versioned by
the `version` in its `index.asset.php`, which changes with the bundle's content.

```php
filemtime( PREFIX_DIR . '/assets/css/dist/main.css' )
```

For a third-party asset served from a CDN, pass `null` as the version to omit the query string.

### Passing PHP data to JavaScript

Use `wp_localize_script()` to pass PHP data (dynamic content, URLs, translations) to a script you
already enqueued — never an inline `<script>`. Example in [references/setup-and-enqueue.md](references/setup-and-enqueue.md).

---

## Page-Specific Asset Enqueueing

Load page-specific assets only where they are needed, keyed on the template file:
`is_page_template( 'page-<name>.php' )`, and `is_front_page()` for the home page. Never key
them on a slug with `is_page( '<slug>' )`: under the default `i18n strategy: polylang` each
language is its own post with its own slug, so a slug test matches one language and the
translated page loads without its assets.

Code: [references/setup-and-enqueue.md](references/setup-and-enqueue.md) § Page-Specific Asset Enqueueing.

---

## Theme Supports

Register all required theme features inside an `after_setup_theme` hook.

Required: `title-tag`, `post-thumbnails`, `custom-logo`, `html5` (search-form, comment-form,
comment-list, gallery, caption, style, script), `automatic-feed-links`, and the starter's
`register_nav_menus()` locations — one per language (`primary-en`, `primary-es`, …), which the
header's walker reads — kept, never collapsed into a single `primary`. Set
`$GLOBALS['content_width']` (1280, filterable) on `after_setup_theme` at priority 0. The
Tailwind starter does all of this in `inc/theme-setup.php`. Code:
[references/setup-and-enqueue.md](references/setup-and-enqueue.md) § Theme Supports.

---

## Security: Output Escaping

**Every** dynamic value rendered in HTML MUST be escaped, at the point of output: `esc_html()`
for text, `esc_url()` for URLs, `esc_attr()` for attribute values, `wp_kses_post()` for
editor (WYSIWYG) HTML — and, for a **text** field that carries a little markup by design,
`wp_kses()` with an explicit allowlist:
`<h2><?php echo wp_kses( $title, array( 'br' => array(), 'span' => array() ) ); ?></h2>`.

- **Never output raw** `get_field()`, `$_GET`, `$_POST`, or any user input without escaping
- **`the_field()` and `the_sub_field()` echo unescaped.** Neither belongs in a template.
  Use `echo esc_html( prefix_get_field( … ) )` and its siblings, so the escaping is visible at
  the point of output. A grep for `the_field(` in the templates should return nothing.

### A headline that carries markup is neither `esc_html()` nor `wp_kses_post()`

Section headlines routinely hold two tags on purpose: a `<span>` the CSS paints as a
highlight pill, and `<br>` where the design breaks the line. Escaping is still
mandatory, but both usual answers are wrong for this field:

- `esc_html()` prints the tags as visible text and destroys the design.
- `wp_kses_post()` admits everything a post can contain — `<script>` is out, but
  `<iframe>`, `<img>`, inline `style` and a `class` on any tag are all in. An editor
  can restyle the page from a headline field, which is exactly the blast radius a
  headline should not have.

Give it `wp_kses()` with the two tags it is allowed and nothing else. The allowlist is
also the enforcement: **a CSS class inside field content is not a thing that exists.**
`<br class="brand-br-lg">` cannot survive `array( 'br' => array() )`, and it should not
— which width a break applies at is presentation, and presentation lives in the
stylesheet:

```css
/* Field value: "One line<br> then another<br> and the <span>highlight</span>"
   Two breaks in the mobile frame, one on desktop — chosen here, by position. */
.section__title br            { display: none; }
@media (max-width: 767.98px)  { .section__title br:nth-of-type(1),
                                .section__title br:nth-of-type(2) { display: inline; } }
@media (min-width: 1024px)    { .section__title br:nth-of-type(2) { display: inline; } }
```

One trap comes with it: `display: none` on a `<br>` removes the line break **and the
whitespace around it**. `word<br>next` renders as `wordnext` the moment the rule
hides it. Store the value with the space on one side — `word<br> next` — so hiding
the tag still leaves a word gap.

---

## Security: Input Sanitization

Sanitize all input before saving or using it, with the `sanitize_*()` function for its
type, after `wp_unslash()`:

```php
// Example: sanitize URL parameter. WordPress adds slashes to $_GET, $_POST and
// $_COOKIE, so unslash before sanitizing or a quote reaches the database escaped.
if ( isset( $_GET['lang'] ) ) {
    $lang = sanitize_text_field( wp_unslash( $_GET['lang'] ) );
}
```

---

## Querying Posts

**NEVER** use `query_posts()` — it replaces the main query. A custom query is a `WP_Query`,
followed by `wp_reset_postdata()` after its loop.

---

## No Inline Styles or Scripts

- **Never** add `<style>` blocks in PHP templates
- **Never** add `<script>` blocks in PHP templates
- **Never** use inline `style=""` attributes on elements

All CSS goes in `.css` files. All JS goes in `.js` files. Both are enqueued via `wp_enqueue_scripts`.

The only exceptions are:
- `wp_head` actions for `<meta>` tags, `<link rel="preload">`, and `<script type="application/ld+json">` (schema markup)
- SVG admin display fix in `admin_head` (minimal inline style)

---

## Performance Optimizations

**Fonts are self-hosted; preload exactly one.** The theme carries every family it names in
`assets/fonts/` (`/wp-init` Step 4.5) and emits no `fonts.googleapis.com` request — a remote
Google Fonts link is what `wp-audit-performance` PERF-022 reports. Preload one woff2 from
`wp_head` at priority 1: the primary family's regular latin file, with `crossorigin`. A
`preconnect` is only for a third-party origin the theme really requests on every page.
Code: [references/head-and-performance.md](references/head-and-performance.md).

### LCP Image Preloading

Preload the Largest Contentful Paint element (usually the hero image) on the homepage from `wp_head` at priority 2, with the same candidates the `<img>` offers: `imagesrcset` and `imagesizes` from the attachment, never the full-size original's URL alone. A preload of one URL while the `<img>` picks another `srcset` candidate downloads both. Code: [references/head-and-performance.md](references/head-and-performance.md).

The preloaded LCP `<img>` itself must carry `fetchpriority="high"` + `width`/`height`. If the hero is a background video, keep the poster `<img>` as the LCP element and lazy-load the `<video>` via JS on desktop only (never mobile / `navigator.connection.saveData`).

### Image Delivery — WebP + right-sizing (`inc/performance.php`)

Ship `inc/performance.php` (in the starter) in every theme. It handles the image-delivery waste Lighthouse flags, which `image_editor_output_format` alone does **not** cover:

1. `image_editor_output_format` → WebP for new attachment sub-sizes.
2. `wp_generate_attachment_metadata` → also writes a WebP sibling for the full-size original (so raw-URL / CSS-background usage benefits).
3. A `template_redirect` output-buffer that rewrites any `uploads/*.jpg|png` with a `.webp` sibling → `.webp` in the finished HTML (covers `src`, `srcset`, and inline `background-image` — including SCF field URLs that bypass WP's attachment pipeline). Runs once per page-cache build.
4. `prefix_image($field, $size, $attr)` — templates use this instead of `echo $field['url']` so images get a `srcset` sized to the slot. **Always pass `sizes`** matching the real display width (full-bleed `100vw`, split `(max-width: 899px) 100vw, 50vw`, fixed logo `136px`). Serving a 2200px original in a 400px slot is the top oversized-image finding.
5. `prefix_background_image($url)` — the declaration for a CSS background, with the `.webp` sibling in an `image-set()` behind the plain `url()` fallback.
6. `prefix_lazy_background_attr($url, $idle = false)` — the same declaration, held in a data attribute until an IntersectionObserver paints it, for a **decorative background below the fold**. `background-image` has no `loading` attribute, so those download with the first paint however far down they sit. `prefix_print_lazy_background_noscript()` repeats every held-back declaration inside a `<noscript><style>` block on `wp_footer`. Never defer the hero: it is the LCP element.

For a theme seeded from an existing demo (images already uploaded), batch-generate the
`.webp` siblings once so (3) picks them up. Run exactly this from the WordPress root (the
directory holding `wp-content/`). It needs ImageMagick 7 (`magick`) built with WebP
support, skips any image that already has a sibling, and reports what it wrote and what
failed. Quality 82 is the plugin's one WebP setting — the same as `wp-robin`'s converter
and `wp-audit-performance` PERF-053:

```bash
command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found — install it first" >&2; exit 1; }
n=0; failed=0
while IFS= read -r -d '' f; do
  w="${f%.*}.webp"
  [ -f "$w" ] && continue
  if magick "$f" -quality 82 "$w"; then n=$((n+1)); else failed=$((failed+1)); echo "failed: $f" >&2; fi
done < <(find wp-content/uploads -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)
echo "webp siblings written: $n, failed: $failed"
```

**Emojis and the version tag.** Remove the emoji detection script and styles on `init`, and `remove_action('wp_head', 'wp_generator')`. Code: [references/head-and-performance.md](references/head-and-performance.md).

---

## SVG Upload Support

Allow SVG file uploads in the WordPress media library — for users who may post
trusted markup, and no one else. WordPress serves an uploaded SVG straight from
the uploads directory, so a browser opening one runs any script it carries in
the site's OWN origin: granting the mime type to everyone who can upload media
hands stored XSS to the Author role. Gate it on `unfiltered_html`, the
capability core already uses for "may post markup that is trusted verbatim".

The filter receives the user the list is built *for* as its second argument, which is not
always the current user — check that user. The mime filter and the admin display fix are in
[references/setup-and-enqueue.md](references/setup-and-enqueue.md) § SVG Upload Support; the
starter ships the same gated filter in `inc/theme-setup.php`.

**Never filter `wp_check_filetype_and_ext`.** A callback that returns the type from the file
name answers for every upload, not only SVG, and switches off core's check that a file's
content matches its extension — a script renamed to `.jpg` passes it.

---

## Custom Body Classes

Add contextual CSS classes to the `<body>` tag for page-specific styling.

Code: [references/setup-and-enqueue.md](references/setup-and-enqueue.md) § Custom Body Classes.

---

## SCF/ACF as Required Dependency

All themes built with this system use **Secure Custom Fields (SCF)** or **Advanced Custom Fields (ACF)** as the custom fields plugin. SCF is an ACF-compatible fork and uses the same API (`get_field()`, `the_field()`, `have_rows()`, etc.).

Register one options page for site-wide settings (logo, footer content, social links) on `acf/init`, guarded by `function_exists('acf_add_options_page')`; options fields are read with `'option'` as the post ID. Code: [references/setup-and-enqueue.md](references/setup-and-enqueue.md).

---

## Helper Functions

Create small utility functions to keep templates clean.

`prefix_asset($path)` and `prefix_get_logo()` are in [references/setup-and-enqueue.md](references/setup-and-enqueue.md) § Helper Functions.

---

## Schema.org Structured Data

The theme prints no identity JSON-LD from `functions.php`. The `Organization` /
`LocalBusiness` node (`@id` `home_url( '/' ) . '#organization'`) has one owner:
`inc/agentic.php`, which the `wp-agentic-surfaces` agent writes (run by `/wp-audit --geo`),
and which returns early through `<prefix>_seo_plugin_owns_schema()` when Rank Math, Yoast or
SEOPress is active, because the SEO plugin then emits the graph. The tailwind starter's
`functions.php` defines that guard; `inc/agentic.php` declares it only for a theme that lacks
it. A second
`<script type="application/ld+json">` beside the SEO plugin's reads as two `Organization`
nodes to every validator; fields the plugin lacks are merged into its graph through
`rank_math/json_ld` (`wp-audit-rankmath` Step 4.7), never printed beside it.

---

## SEO Meta Descriptions

Add meta description tags, but defer to SEO plugins if present.

Return early through `<prefix>_seo_plugin_owns_schema()` — the same guard identity JSON-LD
uses, true when Rank Math, Yoast or SEOPress is active. The SEO plugin owns the tag then, and a
theme that prints its own beside it ships two description tags. Never write a second
detection: one that checks only two constants misses SEOPress and drifts from the schema
guard. Code: [references/head-and-performance.md](references/head-and-performance.md).

---

## Naming Conventions

- **All PHP functions** use the project's function prefix from `.claude/CLAUDE.md` — `prefix_` in this skill is a placeholder
- **Template parts** are named `section-*.php` for content sections, `footer-*.php` for footer variants
- **Page templates** are named `page-<name>.php`
- **CSS classes**: BEM (`.block__element--modifier`) on `Template: basic`; utilities and `@apply` classes on `Template: tailwind` (`wp-tailwind-system`)
- **JS files** use lowercase with hyphens: `<name>.js`

---

## Navigation class contract

The nav walker (generates markup) and the header CSS (styles it) MUST agree on one shared set of class names. Use exactly these — do not invent alternates:

| Class | Purpose |
|---|---|
| `.nav` | Root nav container |
| `.nav__menu` | The `<ul>` menu list |
| `.nav__item` | Each `<li>` menu item |
| `.nav__item--has-children` | Modifier on items with a dropdown submenu |
| `.nav__link` | The anchor for a plain (non-dropdown) menu item |
| `.nav__submenu` | The nested `<ul>` dropdown menu |
| `.nav__toggle` | The clickable/focusable element that opens a dropdown (e.g. `PROPERTIES ▾`) |

States: `.is-open` (added to `.nav__item--has-children` when its submenu is expanded) and `aria-expanded` (`"true"`/`"false"` attribute on `.nav__toggle`, kept in sync with `.is-open`).

**Baseline alignment rule (mandatory):** toggle items must sit on the same text baseline as plain links — never let the presence of a dropdown arrow shift a label up/down relative to its siblings. Apply `display:flex; align-items:center` to both `.nav__link` and `.nav__toggle`.

```css
.nav__link,
.nav__toggle {
    display: flex;
    align-items: center;
}
```

---

## Summary Checklist

- [ ] `style.css` has required WordPress headers
- [ ] All assets enqueued via `wp_enqueue_style()` / `wp_enqueue_script()`, from the one existing callback, at the paths the recorded template's starter uses
- [ ] `filemtime()` (or `index.asset.php`) versions every local asset
- [ ] All theme supports registered in `after_setup_theme`
- [ ] All dynamic output escaped with appropriate function; a headline with markup through `wp_kses()` and its allowlist
- [ ] No `the_field()` / `the_sub_field()` in a template; no raw `get_field()` — `prefix_get_field()` instead
- [ ] No `query_posts()` anywhere
- [ ] Field groups bootstrapped from `fields/*.php` into `acf-json/`
- [ ] Nav walker and header CSS use the navigation class contract, with `.nav__link` and `.nav__toggle` on one baseline
- [ ] No inline styles or scripts in templates
- [ ] Emojis disabled, WP version hidden
- [ ] SVG uploads gated on `unfiltered_html`; no `wp_check_filetype_and_ext` filter
- [ ] Custom body classes added
- [ ] SCF/ACF options page registered
- [ ] No identity JSON-LD outside `inc/agentic.php`
- [ ] Meta descriptions added with SEO plugin check
- [ ] No `fonts.googleapis.com`; one self-hosted woff2 preloaded; LCP image preloaded with `imagesrcset`
