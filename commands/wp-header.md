---
description: Build the WordPress header — responsive nav, logo, language switcher, WP menu system integration
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[screenshot-path]"
---

# WP Header — WordPress Header Builder

Generate a fully functional WordPress header with responsive navigation, logo from settings, language switcher, and WP menu system integration.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary)
- **Theme directory path**

If `.claude/CLAUDE.md` does not exist, tell the user to run `/wp-init` first.

## Step 2: Read Demo Header

Read `demo/index.html` and extract the header/nav section (between `<!-- ============ SECTION: Header ============ -->` delimiters, or the `<header>` element).

Analyze:
- Navigation structure (single-level or dropdowns)
- Logo placement (left, center, etc.)
- Language switcher position
- Whether the header is sticky/fixed
- CTA button in nav (if any)
- Mobile menu behavior

## Step 3: Screenshot Reference (Optional)

If `$ARGUMENTS` provides a screenshot path, read the screenshot file for additional visual reference. Use it to inform layout decisions that might not be captured in the HTML demo.

## Step 4: Dispatch wp-template Agent

Dispatch the **wp-template** agent with these instructions:

> Generate the following files in the theme directory:
>
> ### header.php
> - Start with `<!DOCTYPE html>`, `<html <?php language_attributes(); ?>>`, `<head>`, `<meta charset>`, `<meta viewport>`, `<?php wp_head(); ?>`, `</head>`
> - `<body <?php body_class(); ?>>`
> - Site header with:
>   - Logo from settings: `prefix_get_field('site_logo', 'option')` with fallback to `get_bloginfo('name')`
>   - `wp_nav_menu()` call using the location the project's `i18n strategy`
>     registers: under `suffix`, the per-language location
>     (`'primary_' . prefix_get_current_lang()`); under `polylang`, the bare
>     location (`primary`) — Step 7 registers one location per name there
>   - Use the custom nav walker class
>   - Language switcher per the project's `i18n strategy`: under `suffix`,
>     render all configured languages (from `SUPPORTED_LANGS`) with active
>     state, linking through `prefix_get_lang_url()`; under `polylang`,
>     render it with `pll_the_languages()` — Step 7 says why (it marks the
>     current language and hides languages with no counterpart).
>     **Never transcribe the demo's switcher markup.** A demo's switcher is a
>     mockup — typically two `href="#"` links with `aria-current` hardcoded on
>     one — and it renders as a working control, which is why copying it across
>     survives review. Take its *styling* from the demo and its *behaviour* from
>     the helper above. `demo/.demo-plan.json`'s `inert[]` declares it when the
>     demo came from `/wp-demo`; a demo from elsewhere declares nothing, so
>     assume the switcher is inert unless its markup proves otherwise — and
>     **the proof is the `href`, never the trappings.** A mock switcher carries
>     `hreflang` on both links and `aria-current="true"` on one, which is
>     precisely what a working one carries; a measured demo had both. Only where
>     each link points distinguishes them
>   - Mobile hamburger toggle button with aria attributes
>   - Skip-to-content link for accessibility
>
> ### inc/nav-walker.php
> - Custom Walker_Nav_Menu extension named `Prefix_Nav_Walker` (using actual prefix)
> - Support for dropdown/submenu items if the demo has them
> - Proper escaping on all output
>
> ### Class naming — include the line matching the project's `Template:`, drop the other
> Both files above are yours on both paths; only the class system changes.
> - `basic` → BEM class naming on output elements
> - `tailwind` → keep the Tailwind utility classes already on the demo header you were
>   handed, element for element. Never replace them with BEM names and never invent new
>   class names: `wp-tailwind` runs after you and renames only the groups its promotion
>   ladder promotes. See "File ownership" under "CSS agent routing" below.
>
> Make sure to match the visual layout from the demo as closely as possible.

### CSS agent routing

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

- `basic` → dispatch `wp-css` exactly as described below.
- `tailwind` → dispatch `wp-tailwind` in **author** mode instead. The header's
  `@apply` target is `layouts/header.css`, created only if a rule is genuinely
  needed — a nav expressible in utilities produces no CSS file at all. The agent
  reads `skills/wp-tailwind-system/SKILL.md`. It must never write
  `assets/css/styles.css`.
- `cinematic` → not routed by this command. Cinematic projects are built by
  the `/wp-cinematic-*` family (`/wp-init` Step 0.5 dispatches
  `/wp-cinematic-init`), and their CSS is `assets/css/cinematic.css` — not
  `styles.css` and not the Tailwind tree. Dispatch no CSS agent here.

Dispatch exactly one of the two, never both.

Every `tailwind` dispatch opens its quoted prompt with this line, verbatim:

> Mode: **author**

The quoted prompt it opens is the one under "The `tailwind` prompt body" below — **not**
Step 5's quoted prompt, which is the `basic` branch's and names `assets/css/styles.css`,
the one file the `tailwind` path must never write.

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else, so
the line is not decoration: omit it and the dispatched agent falls into Demo Conversion
Mode, reads the prompt as a demo-file conversion and writes a `.tmp` nobody asked for. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, precisely so that an ordinary demo page named after
the word cannot flip the mode by accident.

This routing governs the "Dispatch **wp-css** agent" step below (Step 5, the header and
navigation CSS) — that step marks its `tailwind` counterpart with `(routed — see "CSS agent
routing" above)` rather than repeating the block.

**Editing rule for this file.** `tests/checks/wp-commands-tailwind.sh` walks every
dispatch site by matching `Dispatch` and `**wp-css**` on one physical line, and accounts
for every other bolded `**wp-css**` in the file. So: keep `Dispatch` and `**wp-css**`
together on a single line at each dispatch site (never hard-wrap between them), and write
`wp-css` unbolded when you mean it in prose. The one place bolded prose is allowed is
inside this `### CSS agent routing` block — everything from this heading down to the next
heading at `###` or above is exempt, sub-headings and fenced examples included.

#### The `tailwind` prompt body

Dispatch `wp-tailwind` with the prompt below in place of Step 5, once Step 4's
`wp-template` agent has returned. It supplies all five inputs
`agents/wp-tailwind.md`'s Inputs table declares — the markup, the local `@apply` target,
the block name, the theme path and the function prefix. The header is site chrome rather
than a page, so its local target is named with `--layout header`, which selects
`layouts/header.css`; `--page <slug>` is the other spelling of that same input and the two
are mutually exclusive. `layouts/` is one of the four sanctioned directories, and it is
absent from a fresh theme only because git cannot track an empty directory — creating it
alongside its first rule is licensed by `skills/wp-tailwind-system/SKILL.md`'s **File
layout** section.

**File ownership.** `wp-template` owns `header.php` and `inc/nav-walker.php` on both
paths — it is the only agent carrying the ACF, escaping and i18n contract
(`prefix_get_field()`, `wp_nav_menu()`, `esc_html()` / `esc_url()` / `esc_attr()`,
`wp_head()`), none of which `agents/wp-tailwind.md` describes. On `tailwind`,
`wp-template` keeps the Tailwind utility classes already on the demo header it was handed
instead of inventing BEM names, and `wp-tailwind` runs **after** Step 4 returns — never
beside it — editing only class names in the files `wp-template` wrote. The invariant: the
header never ships without its ACF wiring and escaping, and never ships on BEM class names
in a Tailwind theme.

> Mode: **author**
>
> Promote the site header's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Layout: `--layout header` (decides `layouts/header.css`; no `--page` on this
>   dispatch — the header is site chrome, not a page)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: `header.php` and `inc/nav-walker.php`, which the wp-template agent
>   has already written and which are quoted below, already carrying Tailwind utility
>   classes.
>
> Requirements:
> 1. Those two files belong to wp-template. Edit them in place; do not create them and
>    do not rewrite them. The only thing you change is class names. Leave every
>    `prefix_get_field()` call, every `esc_html()` / `esc_url()` / `esc_attr()`
>    wrapper, every `wp_nav_menu()` argument and every PHP control structure exactly
>    as you found it.
> 2. Tailwind utility classes in the markup are the default. A nav expressible in
>    utilities produces no CSS file at all, and the files come back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `layouts/header.css` if it is
>    local to the header. The header renders on every page, so read that condition
>    carefully: what belongs in `layouts/header.css` is a group used only inside the
>    header, however many pages the header itself appears on. Grep the theme's other
>    `components/*.css`, `layouts/*.css` and `*.php` before choosing.
> 4. Name a class you write into `layouts/header.css` `<block>__<element>`. Name one
>    you write into `utilities/site.css` `site__<element>` instead — it qualified for
>    that file precisely because it spans more than one block.
> 5. If `layouts/header.css` does not exist, create it with its first rule already in
>    it and add its `@import` to `main.css` in the same step, in `base` → `components`
>    → `layouts` → `utilities` order, naming its cascade layer (`layer(components)` for
>    `layouts/header.css`, `layer(utilities)` for `utilities/site.css`) — a bare
>    `@import` beats every Tailwind utility regardless of specificity. Never leave an
>    empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`) — including the hamburger
>    collapse. No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Header markup:
> ```php
> <paste header.php and inc/nav-walker.php here>
> ```

## Step 5: Dispatch the CSS Agent

**This step is the `basic` branch.** On `tailwind` it does not run at all: `wp-tailwind` in
author mode writes the header's utilities into the markup and, only if a rule is genuinely
needed, into `layouts/header.css`. Nothing on the `tailwind` path writes
`assets/css/styles.css`, `:root` custom properties, or BEM rules — so do not follow the
instructions below there.

Dispatch the **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add header and navigation CSS to `assets/css/styles.css`. Include:
>
> - Header layout matching the demo (flexbox, positioning)
> - If the demo header is sticky/fixed, include sticky header styles with scroll behavior
> - Desktop horizontal navigation
> - Mobile hamburger menu (hidden on desktop, slide-in or dropdown on mobile)
> - Language switcher styling (inline list, active state)
> - Logo sizing and alignment
> - CTA button in nav if present in demo
> - Responsive breakpoints: collapse to hamburger at 768px or 1024px as appropriate
> - Use CSS custom properties from the design system (defined in :root)
> - BEM naming convention
>
> Add the CSS within delimiter comments:
> ```css
> /* ============ HEADER ============ */
> ...
> /* ============ END HEADER ============ */
> ```

## Step 6: Dispatch wp-acf Agent — Add Header Fields to Settings Page

Dispatch the **wp-acf** agent with these instructions:

> Read `fields/settings.php` and ADD any project-specific header fields to the **Header tab** that are needed based on the demo design.
>
> The starter theme already includes basic header fields (CTA text/link, phone). Based on the demo, you may need to add:
> - Header tagline/subtitle text
> - Header background image or color override
> - Show/hide toggles for header elements
> - Additional CTA buttons
> - Any other header element the client should be able to edit
>
> For each new field, following the project's `i18n strategy` (read from
> `.claude/CLAUDE.md`):
> 1. Add the primary language field after the existing Header tab fields (before the Footer tab)
> 2. Under `suffix` only: add the bilingual `_es` variant in the Spanish
>    Translations tab. Under `polylang`, emit no `_<lang>` duplicate fields —
>    one field, one value per language-post; that is what Polylang is for.
> 3. Follow the existing naming convention: `field_settings_header_<element>`
>
> All fields use `'option'` as post ID. Under `suffix`, instructions on the
> secondary-language fields name the project's primary language and are written in it —
> "Leave empty to use the English version." on an English-primary project. See "Editor
> Language" in `agents/wp-acf.md`.

## Step 7: Update Theme Setup

**Under `i18n strategy: polylang`** (read it from the project's
`.claude/CLAUDE.md`), skip the per-language locations entirely: register
`primary` and `footer` ONCE, call `wp_nav_menu()` with the bare location name,
and render the switcher with Polylang's own walker, which already knows each
page's counterpart URL:

```php
<?php if ( function_exists( 'pll_the_languages' ) ) : ?>
    <ul class="site-header__lang">
        <?php pll_the_languages( array( 'show_flags' => 0, 'show_names' => 1 ) ); ?>
    </ul>
<?php endif; ?>
```

Do NOT build the switcher from `<prefix>get_lang_url()` under this strategy
unless the markup has to match a specific demo — the helper exists and works,
but `pll_the_languages()` also marks the current language and hides languages
with no counterpart.

Everything below describes the `suffix` strategy.

Read `inc/theme-setup.php` and ensure `register_nav_menus()` includes per-language menu locations:

```php
register_nav_menus(array(
    'primary_en' => __('Primary Menu (English)', '<textdomain>'),
    'primary_es' => __('Primary Menu (Spanish)', '<textdomain>'),
    'footer_en'  => __('Footer Menu (English)', '<textdomain>'),
    'footer_es'  => __('Footer Menu (Spanish)', '<textdomain>'),
));
```

Adjust languages to match the project configuration. If the registrations already exist, do not duplicate them.

Also ensure the nav walker file is included:
```php
require_once get_template_directory() . '/inc/nav-walker.php';
```

## Step 7.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Step 8: Print Summary

```
=== Header Built ===
Files created/updated:
  - header.php
  - inc/nav-walker.php
  - inc/theme-setup.php (menu locations)
  - assets/css/styles.css (header CSS)          [basic only]
  - layouts/header.css (only if a rule was needed) [tailwind only]
  - fields/settings.php (header ACF fields in Header tab)

Features:
  - Responsive navigation (hamburger on mobile)
  - Logo from settings page
  - Language switcher (<languages>)
  - [Sticky header] (if applicable)

Next: Run /wp-footer to build the footer.
```
