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
>   - `wp_nav_menu()` call using per-language menu location (e.g., `'primary_' . prefix_current_lang()`)
>   - Use the custom nav walker class
>   - Language switcher showing all configured languages with active state
>   - Mobile hamburger toggle button with aria attributes
>   - Skip-to-content link for accessibility
>
> ### inc/nav-walker.php
> - Custom Walker_Nav_Menu extension named `Prefix_Nav_Walker` (using actual prefix)
> - BEM class naming on output elements
> - Support for dropdown/submenu items if the demo has them
> - Proper escaping on all output
>
> Make sure to match the visual layout from the demo as closely as possible.

## Step 5: Dispatch wp-css Agent

Dispatch the **wp-css** agent with these instructions:

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
> For each new field:
> 1. Add the primary language field after the existing Header tab fields (before the Footer tab)
> 2. Add the bilingual `_es` variant in the Spanish Translations tab
> 3. Follow the existing naming convention: `field_settings_header_<element>`
>
> All fields use `'option'` as post ID. Instructions on Spanish fields: "Leave empty to use English version."

## Step 7: Update Theme Setup

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

## Step 8: Print Summary

```
=== Header Built ===
Files created/updated:
  - header.php
  - inc/nav-walker.php
  - inc/theme-setup.php (menu locations)
  - assets/css/styles.css (header CSS)
  - fields/settings.php (header ACF fields in Header tab)

Features:
  - Responsive navigation (hamburger on mobile)
  - Logo from settings page
  - Language switcher (<languages>)
  - [Sticky header] (if applicable)

Next: Run /wp-footer to build the footer.
```
