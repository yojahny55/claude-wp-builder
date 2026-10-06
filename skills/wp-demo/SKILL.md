---
name: wp-demo
description: Defines the demo page contract — single-file demo/index.html and demo/slug.html pages whose SECTION and END SECTION comment delimiters map 1:1 to WordPress template parts — plus the accessibility, navigation and footer markup every demo carries and, in plain mode, the token names, font link and placeholder images. Use when writing or editing a demo page with /wp-demo, or converting one with /wp-init, /wp-section, /wp-seed or /wp-yolo. Craft-mode design rules are in wp-demo-craft, responsive CSS in wp-responsive.
user-invocable: false
---

# Demo HTML Creation Methodology

A demo is a static HTML page that serves as the design prototype and is later converted 1:1
into WordPress templates: the client approves it in a browser, `/wp-init` carries its tokens
into the theme, `/wp-section` turns each delimited section into a template part, and every
piece of content becomes an ACF/SCF field.

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

## Files

One file per page: `demo/index.html` for the homepage, `demo/<page-slug>.html` for the rest
(`demo/pricing.html`). In plain mode each is a single file — meta tags, one `<style>` block,
the markup and any inline JS — started from
[references/demo-skeleton.md](references/demo-skeleton.md).

---

## Section Delimiters

Every section is wrapped in an opening and a closing comment, exactly:

```html
<!-- ============ SECTION: Hero ============ -->
<section class="hero">…</section>
<!-- ============ END SECTION: Hero ============ -->
```

The name is a **verbatim join key**. `/wp-section`, `/wp-seed`, `/wp-polish` and the
`wp-normalize` agent extract sections by it, and `demo/.demo-plan.json` records each section
under the same name — a plan whose names do not match its own markup is discarded. So the
name is identical in both comments, never reworded between them, and unique on the page.
`Header` and `Footer` are the names of the shared chrome on every page. The section's CSS
sits under the matching `/* ============ Section: Hero ============ */` delimiter, so it moves
to its template part whole.

| Comment | WordPress Template Part |
|---|---|
| `SECTION: Header` | `header.php` |
| `SECTION: Hero` | `template-parts/section-hero.php` |
| `SECTION: Services` | `template-parts/section-services.php` |
| `SECTION: Testimonials` | `template-parts/section-testimonials.php` |
| `SECTION: Contact` | `template-parts/section-contact.php` |
| `SECTION: Footer` | `footer.php` |

---

## Design Tokens and Fonts (plain mode)

The `:root` block in the demo `<style>` is the **source of truth** for the design system:

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

- Static text becomes `prefix_get_field('field_name')`
- Images become ACF image fields; repeated items (cards, list items) become repeaters
- Links become ACF URL or link fields; navigation becomes `wp_nav_menu()`
- The HTML structure and CSS classes are preserved exactly

---

## Accessibility Requirements

The skeleton already carries each of these; keep them when editing:

- A skip link first in `<body>`: `<a href="#main-content" class="sr-only sr-only--focusable">Skip to content</a>`,
  with `.sr-only` and `.sr-only--focusable` defined in the `<style>` block
- `<main id="main-content">` as its target
- The hamburger button: `aria-label="Toggle menu"`, `aria-expanded="false"`,
  `aria-controls` naming the mobile menu; its menu behaviour (focus trap, Escape, focus
  return) is `wp-responsive`'s `references/navigation.md`
- A visible `:focus-visible` style
- Real `alt` text on every image, a `<label>` on every form input, WCAG AA contrast

---

## Placeholder Images

Plain mode only. A real client image from `docs/` always wins. Where there is none, the
placeholder is an `<img>` whose `src` is an inline SVG at the intended aspect ratio, with
`width`, `height` and real `alt` text — never an external image URL. A placeholder-service
URL breaks the page offline, and `/wp-seed` imports every `img[src]` URL it finds into the
media library. Keeping the `<img>` element, rather than a coloured CSS box, keeps the 1:1
mapping to an ACF image field.

```html
<!-- Hero image, 3:2 -->
<img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 400'%3E%3Crect width='600' height='400' fill='%23e5e5e5'/%3E%3C/svg%3E"
     width="600" height="400" alt="Description of hero image" fetchpriority="high">

<!-- Team member photo, 1:1 -->
<img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 300'%3E%3Crect width='300' height='300' fill='%23e5e5e5'/%3E%3C/svg%3E"
     width="300" height="300" alt="Team member name" loading="lazy">
```

---

## Navigation Structure

The demo navigation matches the planned WordPress site structure: the pages and sections that
will exist.

```html
<nav class="header__nav">
    <a href="index.html" class="nav__link nav__link--active">Home</a>
    <a href="#services" class="nav__link">Services</a>
    <a href="pricing.html" class="nav__link">Pricing</a>
    <a href="#contact" class="nav__link">Contact</a>
</nav>
```

Internal pages link by relative file path (`pricing.html`), sections by `#id`, and the active
page carries the `--active` modifier. The header also carries a language switcher with one
link per configured language.

---

## Footer Pattern

Four columns (brand and logo, quick links, contact info, social) above a bottom bar carrying
the copyright and legal links. Markup: the footer in
[references/demo-skeleton.md](references/demo-skeleton.md).

The demo's contract with WordPress is the **class names**, not field names: `/wp-seed` reads
`.footer__description` (the tagline) and `.footer__copyright` out of the demo, and `/wp-footer`
owns which settings-page fields they become. Keep both classes: under any other class, or
in a bare `<p>`, the seeder skips the line. The
copyright line carries no year: a year typed into the demo is stale by the next January, and
`/wp-footer`'s fallback prints the current one.

---

## Responsive Design and Verification

Every demo is mobile-first with `min-width` queries only; the breakpoints, the mobile menu and
the touch-target rules are the `wp-responsive` skill's. Then:

1. Run `/wp-demo-verify demo/` (or on one page).
2. Fix every overflow and clipped-copy finding at the element it names.
3. Run it again. Stop when it reports no overflow and no clipped copy at any width.
