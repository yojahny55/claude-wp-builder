---
name: wp-demo
description: Demo HTML creation methodology — single-file demos with section comments for 1:1 WordPress conversion
user-invocable: false
---

# Demo HTML Creation Methodology

This skill defines how to create **static HTML demo pages** that serve as the design prototype and are later converted 1:1 into WordPress templates. Each demo is a single HTML file with all CSS embedded in a `<style>` block.

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

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Site Name — Page Title</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@400;500;600;700&display=swap" rel="stylesheet">

    <style>
        /* ============ Section: Variables ============ */
        :root {
            /* Colors */
            --color-primary: #1a5632;
            --color-primary-light: #2d7a4a;
            --color-primary-dark: #0f3d22;
            --color-secondary: #c9a84c;
            --color-neutral-50: #fafafa;
            --color-neutral-100: #f5f5f5;
            --color-neutral-200: #e5e5e5;
            --color-neutral-500: #737373;
            --color-neutral-800: #262626;
            --color-neutral-900: #171717;
            --color-text: var(--color-neutral-800);
            --color-text-light: var(--color-neutral-500);
            --color-text-inverse: #ffffff;
            --color-background: #ffffff;
            --color-background-alt: var(--color-neutral-50);
            --color-border: var(--color-neutral-200);

            /* Spacing */
            --spacing-xs: 0.25rem;
            --spacing-sm: 0.5rem;
            --spacing-md: 1rem;
            --spacing-lg: 1.5rem;
            --spacing-xl: 2rem;
            --spacing-2xl: 3rem;
            --spacing-3xl: 4rem;

            /* Typography */
            --font-family-primary: 'Inter', sans-serif;
            --font-family-secondary: 'Playfair Display', serif;
            --font-size-xs: 0.75rem;
            --font-size-sm: 0.875rem;
            --font-size-base: 1rem;
            --font-size-md: 1.125rem;
            --font-size-lg: 1.25rem;
            --font-size-xl: 1.5rem;
            --font-size-2xl: 2rem;
            --font-size-3xl: 2.5rem;
            --font-size-4xl: 3rem;

            /* Other tokens */
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
            --radius-sm: 0.25rem;
            --radius-md: 0.5rem;
            --radius-lg: 1rem;
            --radius-full: 9999px;
            --transition-base: all 0.3s ease;
            --container-max: 1280px;
        }

        /* ============ Section: Reset ============ */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { scroll-behavior: smooth; }
        body {
            font-family: var(--font-family-primary);
            font-size: var(--font-size-base);
            line-height: 1.5;
            color: var(--color-text);
            background: var(--color-background);
        }
        img { display: block; max-width: 100%; height: auto; }
        a { color: inherit; text-decoration: none; }
        ul, ol { list-style: none; }

        /* ============ Section: Layout ============ */
        .container {
            width: 100%;
            max-width: var(--container-max);
            margin: 0 auto;
            padding: 0 var(--spacing-md);
        }

        /* ============ Section: Header ============ */
        .header { ... }

        /* ============ Section: Hero ============ */
        .hero { ... }

        /* ============ Section: Services ============ */
        .services { ... }

        /* ... more sections ... */

        /* ============ Section: Footer ============ */
        .footer { ... }

        /* ============ Section: Responsive ============ */
        @media (max-width: 1024px) { ... }
        @media (max-width: 768px) { ... }
        @media (max-width: 576px) { ... }
    </style>
</head>
<body>

    <!-- ============ SECTION: Header ============ -->
    <header class="header">
        <div class="container">
            <div class="header__inner">
                <a href="/" class="header__logo">
                    <img src="https://placehold.co/180x50?text=Logo" alt="Site Name">
                </a>
                <nav class="header__nav">
                    <a href="#" class="nav__link nav__link--active">Home</a>
                    <a href="#services" class="nav__link">Services</a>
                    <a href="pricing.html" class="nav__link">Pricing</a>
                    <a href="#contact" class="nav__link">Contact</a>
                </nav>
                <a href="#contact" class="btn btn--primary">Get Started</a>
                <button class="header__hamburger" aria-label="Toggle menu">
                    <span></span><span></span><span></span>
                </button>
            </div>
        </div>
    </header>

    <main>
        <!-- ============ SECTION: Hero ============ -->
        <section class="hero">
            <div class="container">
                <div class="hero__content">
                    <span class="hero__label">Welcome to Site Name</span>
                    <h1 class="hero__title">Your Compelling Headline Here</h1>
                    <p class="hero__subtitle">A brief supporting description that explains the value proposition in one or two sentences.</p>
                    <div class="hero__cta">
                        <a href="#contact" class="btn btn--primary btn--large">Primary Action</a>
                        <a href="#services" class="btn btn--secondary btn--large">Secondary Action</a>
                    </div>
                </div>
                <div class="hero__image">
                    <img src="https://placehold.co/600x400?text=Hero+Image" alt="Hero image description">
                </div>
            </div>
        </section>

        <!-- ============ SECTION: Services ============ -->
        <section class="services section section--alt" id="services">
            <div class="container">
                <span class="section__label">What We Do</span>
                <h2 class="section__title">Our Services</h2>
                <div class="services__grid">
                    <!-- Service cards here -->
                </div>
            </div>
        </section>

        <!-- ... more sections ... -->

        <!-- ============ SECTION: Contact ============ -->
        <section class="contact section" id="contact">
            <div class="container">
                <!-- Contact content -->
            </div>
        </section>
    </main>

    <!-- ============ SECTION: Footer ============ -->
    <footer class="footer">
        <div class="container">
            <div class="footer__grid">
                <div class="footer__brand">
                    <img src="https://placehold.co/180x50?text=Logo" alt="Site Name" class="footer__logo">
                    <p class="footer__tagline">Brief company tagline here.</p>
                </div>
                <div class="footer__links">
                    <h3 class="footer__heading">Quick Links</h3>
                    <ul>
                        <li><a href="#">Home</a></li>
                        <li><a href="#">Services</a></li>
                        <li><a href="#">Pricing</a></li>
                        <li><a href="#">Contact</a></li>
                    </ul>
                </div>
                <div class="footer__contact">
                    <h3 class="footer__heading">Contact</h3>
                    <p>email@example.com</p>
                    <p>(555) 123-4567</p>
                </div>
                <div class="footer__social">
                    <h3 class="footer__heading">Follow Us</h3>
                    <!-- Social links -->
                </div>
            </div>
            <div class="footer__bottom">
                <p>&copy; 2025 Site Name. All rights reserved.</p>
                <div class="footer__legal">
                    <a href="#">Privacy Policy</a>
                    <a href="#">Terms & Conditions</a>
                </div>
            </div>
        </div>
    </footer>

    <script>
        // Minimal JS for demo interactivity (hamburger toggle, scroll effects)
    </script>

</body>
</html>
```

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

The footer follows a consistent pattern matching the WordPress settings page architecture.

```html
<footer class="footer">
    <div class="container">
        <div class="footer__grid">
            <!-- Column 1: Brand/Logo -->
            <div class="footer__brand">
                <img src="https://placehold.co/180x50?text=Logo" alt="Site Name" class="footer__logo">
                <p class="footer__tagline">Company tagline or brief description.</p>
            </div>

            <!-- Column 2: Quick Links -->
            <div class="footer__links">
                <h3 class="footer__heading">Quick Links</h3>
                <ul>
                    <li><a href="#">Home</a></li>
                    <li><a href="#">Services</a></li>
                    <li><a href="#">Pricing</a></li>
                    <li><a href="#">Contact</a></li>
                </ul>
            </div>

            <!-- Column 3: Contact Info -->
            <div class="footer__contact">
                <h3 class="footer__heading">Contact</h3>
                <p>info@example.com</p>
                <p>(555) 123-4567</p>
                <p>123 Main St, City, ST 12345</p>
            </div>

            <!-- Column 4: Social -->
            <div class="footer__social">
                <h3 class="footer__heading">Follow Us</h3>
                <div class="footer__social-links">
                    <a href="#" aria-label="Facebook">FB</a>
                    <a href="#" aria-label="Instagram">IG</a>
                    <a href="#" aria-label="LinkedIn">LI</a>
                </div>
            </div>
        </div>

        <!-- Footer bottom: copyright + legal -->
        <div class="footer__bottom">
            <p>&copy; 2025 Site Name. All rights reserved.</p>
            <div class="footer__legal">
                <a href="#">Privacy Policy</a>
                <a href="#">Terms & Conditions</a>
            </div>
        </div>
    </div>
</footer>
```

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
