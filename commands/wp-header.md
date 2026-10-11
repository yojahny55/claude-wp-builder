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

Dispatch the **wp-template** agent with the prompt in the reference below, handing it the demo header from Step 2 and the project context from Step 1.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-header-run/references/template-dispatch.md` now and send its quoted prompt: the `header.php` and `inc/nav-walker.php` contract, the language switcher rule and the class naming per `Template:`.

Then read `${CLAUDE_PLUGIN_ROOT}/skills/wp-header-run/references/css-routing.md` now and follow it: it routes the CSS agent by `Template:` (dispatch exactly one of `wp-css` or `wp-tailwind`, never both), carries the `wp-tailwind` author-mode prompt that replaces Step 5 on `tailwind`, and the file ownership rule.

## Step 5: Dispatch the CSS Agent

**This step is the `basic` branch.** On `tailwind` it does not run at all: `wp-tailwind` in
author mode writes the header's utilities into the markup and, only if a rule is genuinely
needed, into `layouts/header.css`. Nothing on the `tailwind` path writes
`assets/css/styles.css`, `:root` custom properties, or BEM rules — so do not follow the
instructions below there.

Dispatch the **wp-css** agent (routed — see "CSS agent routing" in Step 4; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

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
`primary` and `footer` ONCE (`/wp-init` Step 6 already replaced the starter's
per-language entries — confirm it, and never add them back), let
`wp_nav_menu()` take the bare location name from `prefix_nav_location()`,
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

**Under `suffix`**, read `inc/theme-setup.php` and ensure `register_nav_menus()`
includes per-language menu locations, hyphenated — `<location>-<lang>` is the
name `prefix_nav_location()` builds, and the starter already ships these:

```php
register_nav_menus(array(
    'primary-en' => __('Primary Navigation (EN)', '<textdomain>'),
    'primary-es' => __('Primary Navigation (ES)', '<textdomain>'),
    'footer-en'  => __('Footer Links (EN)', '<textdomain>'),
    'footer-es'  => __('Footer Links (ES)', '<textdomain>'),
));
```

Adjust languages to match the project configuration. If the registrations already exist, do not duplicate them.

On both strategies, ensure the nav walker file is included:
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
