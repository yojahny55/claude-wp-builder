---
name: wp-demo
description: Demo HTML methodology — single-file demos with section comment delimiters that convert 1:1 into WordPress template parts, plus the responsive, accessibility, placeholder-image, navigation and footer requirements. Use when writing or editing a demo HTML file with /wp-demo, or converting one with /wp-init, /wp-section or /wp-yolo.
user-invocable: false
---

# Demo HTML Creation Methodology

This skill defines how to create **static HTML demo pages** that serve as the design prototype and are later converted 1:1 into WordPress templates. Each demo is a single HTML file with all CSS embedded in a `<style>` block.

## Reference files

- [references/demo-skeleton.md](references/demo-skeleton.md) — the full page skeleton (head,
  `:root` tokens, reset, section delimiters, header through footer) and the complete footer
  markup. Read when starting a demo page or writing its footer.

---

## Purpose of Demos

Demos are the design-first step before WordPress development:

1. **Design agreement** -- the client reviews a working HTML page in the browser
2. **CSS extraction** -- the `<style>` block is extracted verbatim into the theme's `assets/css/styles.css`
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

The `:root` block in the demo `<style>` is the **source of truth** for the design system. When converting to WordPress:

1. The `:root` variables are copied **exactly** into `assets/css/styles.css`
2. All CSS rules reference these variables (never hardcoded values)
3. The variable names, values, and scale MUST match the `wp-css-system` skill definitions

---

## External Skill Dependencies

The demo creation process relies on two external skills for design guidance:

- **`frontend-design`** -- provides visual design principles, layout patterns, and component inspiration
- **`ui-ux-pro-max`** -- provides UX best practices, interaction patterns, and accessibility guidelines

These skills are invoked automatically when creating demos. The demo author should follow their guidance for:
- Visual hierarchy and whitespace
- Color contrast and readability
- Component patterns and interactions
- Accessibility compliance

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

Use placeholder services with realistic dimensions that match the final design intent.

```html
<!-- Hero image -->
<img src="https://placehold.co/600x400?text=Hero+Image" alt="Description of hero image">

<!-- Team member photo -->
<img src="https://placehold.co/300x300?text=Team+Member" alt="Team member name">

<!-- Logo -->
<img src="https://placehold.co/180x50?text=Logo" alt="Site Name">

<!-- Service icon -->
<img src="https://placehold.co/64x64?text=Icon" alt="Service name icon">

<!-- Blog thumbnail -->
<img src="https://placehold.co/400x250?text=Blog+Post" alt="Blog post title">
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
the copyright and legal links. Markup:
[references/demo-skeleton.md](references/demo-skeleton.md#footer-markup).

The footer maps to the WordPress settings/options page fields:
- Logo: `site_logo` (option field)
- Tagline: `footer_tagline` (option field)
- Social links: `social_facebook`, `social_instagram`, etc. (option fields)
- Copyright: `footer_copyright` (option field)
- Contact info: `contact_email`, `contact_phone`, `contact_address` (option fields)

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
