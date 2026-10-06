---
name: wp-demo
description: Demo HTML methodology — single-file demos with section comment delimiters that convert 1:1 into WordPress template parts, plus the responsive, accessibility, placeholder-image, navigation and footer requirements. Use when writing or editing a demo HTML file with /wp-demo, or converting one with /wp-init, /wp-section or /wp-yolo.
user-invocable: false
---

# Demo HTML Creation Methodology

This skill defines how to create **static HTML demo pages** that serve as the design prototype and are later converted 1:1 into WordPress templates. Each demo is a single HTML file with all CSS embedded in a `<style>` block.

## Reference files

- [references/demo-skeleton.md](references/demo-skeleton.md) — the plain-mode page skeleton
  (font link, `:root` tokens, reset and accessibility rules, section delimiters, header with
  language switcher, footer). Read when starting a demo page or writing its footer.

---

## Which parts apply

Read `"demo mode"` from the project's `.wp-create.json` before using this skill; an absent
key means `plain`. `/wp-demo` records it, and nothing downstream re-derives it.

- **Both modes:** file naming, the section delimiters and the 1:1 mapping, accessibility,
  navigation and the footer markup contract.
- **Plain mode only:** the single-file rule, the `:root` token vocabulary, the font link and
  the placeholder images below.
- **Craft mode:** tokens come from `demo/DESIGN.md` onto the names in
  `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md.md`, never the
  vocabulary below. Images are real client files or generated plates; a placeholder image
  is a craft ship blocker. Compositions, motion and verification are `wp-demo-craft`'s.

---

## Purpose of Demos

Demos are the design-first step before WordPress development:

1. **Design agreement** -- the client reviews a working HTML page in the browser
2. **Token carry** -- `/wp-init` reads the demo's colours and fonts and writes them into the theme's Tailwind `@theme` block; each section's CSS moves with its template part when `/wp-section` builds it
3. **Section mapping** -- each marked section in the demo maps to a `template-parts/section-*.php` file in WordPress
4. **Field definition** -- every piece of content in the demo becomes an ACF/SCF field

---

## File Structure

```
demo/
├── index.html          # Homepage demo
├── pricing.html        # Pricing page demo
├── about.html          # About page demo
└── ...                 # One file per page
```

### Naming Convention

- **Homepage**: `demo/index.html`
- **Other pages**: `demo/<page-slug>.html` (e.g., `demo/pricing.html`, `demo/software.html`)

---

## Single-File HTML Structure

Each demo is a **single HTML file** containing everything: meta tags, embedded CSS, HTML content, and optional inline JS.

### Template Skeleton

Start every page from the skeleton in [references/demo-skeleton.md](references/demo-skeleton.md):
fonts in `<head>`, then one `<style>` block holding the `:root` tokens, reset, layout and each
section's rules under `/* ============ Section: Name ============ */`, then the page sections.
Each section opens with `<!-- ============ SECTION: Name ============ -->` and closes with
`<!-- ============ END SECTION: Name ============ -->`.

---

## Section Comments

Every distinct section MUST be wrapped with an HTML comment in this exact format:

```html
<!-- ============ SECTION: Hero ============ -->
```

These comments serve as:
1. **Visual delimiters** when scanning the HTML source
2. **Mapping markers** -- each comment maps to a `template-parts/section-<name>.php` file in WordPress
3. **Conversion guide** -- when building the WordPress theme, each section is extracted into its own template part

### Common Section Names

| Comment | WordPress Template Part |
|---|---|
| `SECTION: Header` | `header.php` |
| `SECTION: Hero` | `template-parts/section-hero.php` |
| `SECTION: Services` | `template-parts/section-services.php` |
| `SECTION: About` | `template-parts/section-about.php` |
| `SECTION: Testimonials` | `template-parts/section-testimonials.php` |
| `SECTION: CTA` | `template-parts/section-cta.php` |
| `SECTION: Contact` | `template-parts/section-contact.php` |
| `SECTION: Footer` | `footer.php` |

---

## Design System Variables in :root

In plain mode the `:root` block in the demo `<style>` is the **source of truth** for the design system. When converting to WordPress:

1. `/wp-init` reads its colour and font values and writes them into the theme's `@theme` block
2. All CSS rules reference these variables (never hardcoded values)
3. The variable names and scale are the `wp-css-system` skill's (`references/tokens.md`):
   `--color-background`, `--spacing-md`, `--font-family-primary`, `--transition-base` —
   never `--color-bg`, `--space-md`, `--font-heading` or `--transition`

Fonts load from one Google Fonts `<link>` in `<head>`, the only external request a plain demo
makes: `/wp-init` Step 4.5 self-hosts the families it names, so the theme never calls
Google at runtime.

---

## 1:1 Section Mapping to WordPress

Each section in the demo becomes a WordPress template part. The mapping is direct:

```
Demo HTML                          WordPress
─────────────────────────────      ─────────────────────────────
<!-- SECTION: Hero -->        →    template-parts/section-hero.php
  <h1>Static Title</h1>      →    <h1><?php echo esc_html(prefix_get_field('hero_title')); ?></h1>
  <p>Static description</p>  →    <p><?php echo esc_html(prefix_get_field('hero_subtitle')); ?></p>
  <img src="placeholder">    →    <?php $img = prefix_get_field('hero_image'); ?>
                                   <img src="<?php echo esc_url($img['url']); ?>"
                                        alt="<?php echo esc_attr($img['alt']); ?>">
```

### Conversion Rules

- Static text becomes `prefix_get_field('field_name')`
- Placeholder images become ACF image fields
- Repeated items (cards, list items) become ACF repeater fields
- Links become ACF URL or link fields
- Navigation becomes `wp_nav_menu()`
- The HTML structure and CSS classes are preserved exactly

---

## Responsive Design Requirements

Every demo MUST be fully responsive. See the `wp-responsive` skill for detailed breakpoint and responsive design standards.

- Use mobile-first CSS with `min-width` media queries
- Test at: 375px, 576px, 768px, 1024px, 1440px
- No horizontal scrolling at any viewport width
- Hamburger menu on mobile, horizontal nav on desktop

---

## Accessibility Requirements

Demos MUST follow semantic HTML5 and accessibility best practices.

### Semantic Structure

```html
<header>    <!-- Site header with nav -->
<nav>       <!-- Navigation -->
<main>      <!-- Primary page content -->
<section>   <!-- Thematic content sections -->
<article>   <!-- Self-contained content (blog posts) -->
<aside>     <!-- Supplementary content -->
<footer>    <!-- Site footer -->
```

### ARIA and Accessibility

- All images have descriptive `alt` attributes
- Interactive elements have `aria-label` when the visible text is insufficient
- Color contrast meets WCAG AA (4.5:1 for normal text, 3:1 for large text)
- Focus styles are visible for keyboard navigation
- Skip-to-content link at the top of the page
- Form inputs have associated `<label>` elements
- Hamburger button has `aria-label="Toggle menu"` and `aria-expanded`

```html
<!-- Skip to content link -->
<a href="#main-content" class="sr-only sr-only--focusable">Skip to content</a>

<!-- Hamburger with ARIA -->
<button class="header__hamburger" aria-label="Toggle menu" aria-expanded="false">
    <span></span><span></span><span></span>
</button>

<!-- Main content landmark -->
<main id="main-content">
```

---

## Placeholder Images

Plain mode only. A real client image from `docs/` always wins. Where there is none, the
placeholder is an `<img>` whose `src` is an inline SVG at the intended aspect ratio, with
`width`, `height` and real `alt` text — never an external image URL. A placeholder-service
URL breaks the page offline, and `/wp-seed` imports every
`img[src]` URL it finds into the media library. Keeping the `<img>` element, rather than a
coloured CSS box, keeps the 1:1 mapping to an ACF image field.

```html
<!-- Hero image, 3:2 -->
<img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 400'%3E%3Crect width='600' height='400' fill='%23e5e5e5'/%3E%3C/svg%3E"
     width="600" height="400" alt="Description of hero image" fetchpriority="high">

<!-- Team member photo, 1:1 -->
<img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 300'%3E%3Crect width='300' height='300' fill='%23e5e5e5'/%3E%3C/svg%3E"
     width="300" height="300" alt="Team member name" loading="lazy">
```

Choose dimensions that match the expected aspect ratio in the final design:
- Hero images: 16:9 or 3:2 (e.g., 600x400, 800x450)
- Thumbnails: 16:10 or 4:3 (e.g., 400x250, 300x225)
- Avatars/portraits: 1:1 (e.g., 300x300)
- Logos: wide ratio (e.g., 180x50, 200x60)

---

## Navigation Structure

The demo navigation must match the planned WordPress site structure. Navigation items should reflect the actual pages and sections that will exist.

```html
<nav class="header__nav">
    <a href="index.html" class="nav__link nav__link--active">Home</a>
    <a href="#services" class="nav__link">Services</a>
    <a href="pricing.html" class="nav__link">Pricing</a>
    <a href="#contact" class="nav__link">Contact</a>
</nav>
```

- Internal page links use relative HTML file paths (`pricing.html`)
- Section anchors use `#id` links (`#services`, `#contact`)
- Active page gets the `--active` modifier class

---

## Footer Pattern

The footer follows a consistent pattern matching the WordPress settings page architecture:
four columns (brand and logo, quick links, contact info, social) above a bottom bar carrying
the copyright and legal links. Markup: the footer in
[references/demo-skeleton.md](references/demo-skeleton.md).

The demo's contract with WordPress is the **class names**, not field names: `/wp-seed` reads
`.footer__description` (the tagline) and `.footer__copyright` out of the demo, and `/wp-footer`
owns which settings-page fields they become. Keep both classes: under any other class, or
in a bare `<p>`, the seeder skips the line. The
copyright line carries no year: a year typed into the demo is stale by the next January, and
`/wp-footer`'s fallback prints the current one.

---

## Summary Checklist

- [ ] Single HTML file per page in `demo/` directory
- [ ] All CSS embedded in `<style>` block (no external CSS files)
- [ ] `:root` variables match the design system (wp-css-system skill)
- [ ] Every section wrapped with `<!-- ============ SECTION: Name ============ -->` comment
- [ ] CSS uses section comment delimiters: `/* ============ Section: Name ============ */`
- [ ] BEM class names used throughout
- [ ] Fully responsive at all breakpoints (375px to 1440px+)
- [ ] Semantic HTML5 elements (header, nav, main, section, footer)
- [ ] ARIA attributes on interactive elements
- [ ] WCAG AA color contrast
- [ ] Placeholder images with realistic dimensions
- [ ] Navigation matches planned site structure
- [ ] Footer includes: logo, copyright, social links, contact info, legal links
- [ ] Each section maps 1:1 to a future WordPress template part
