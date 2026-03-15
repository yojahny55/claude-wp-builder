---
name: wp-responsive
description: Responsive design patterns — mobile-first breakpoints, fluid typography, responsive images, touch targets
user-invocable: false
---

# Responsive Design Patterns

This skill defines the responsive design system used across all themes and demos. It uses **mobile-first** CSS with `min-width` media queries, fluid typography, and responsive image techniques.

---

## Mobile-First Breakpoint System

All styles are written mobile-first. Base styles target the smallest screens, and `min-width` media queries progressively enhance for larger viewports.

### Breakpoint Scale

| Name | Min-Width | Target Devices |
|---|---|---|
| Base | (no query) | All phones (320px+) |
| Small | `576px` | Large phones, small tablets |
| Tablet | `768px` | Tablets (portrait and landscape) |
| Desktop | `1024px` | Desktops, laptops |
| Large | `1200px` | Large desktops |
| Extra Large | `1440px` | Ultra-wide screens |

### CSS Implementation

```css
/* Base: mobile-first (no media query) */
.services__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
}

/* Small (576px+): 2 columns */
@media (min-width: 576px) {
    .services__grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

/* Tablet (768px+): still 2 columns, wider gap */
@media (min-width: 768px) {
    .services__grid {
        gap: var(--spacing-xl);
    }
}

/* Desktop (1024px+): 3 columns */
@media (min-width: 1024px) {
    .services__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}

/* Large (1200px+): wider gap */
@media (min-width: 1200px) {
    .services__grid {
        gap: var(--spacing-2xl);
    }
}
```

### Rule: Always `min-width`, Never `max-width`

Use `min-width` queries exclusively. This enforces mobile-first thinking -- you start with the constrained layout and add complexity as space increases.

```css
/* CORRECT: mobile-first with min-width */
@media (min-width: 768px) { ... }

/* WRONG: desktop-first with max-width */
@media (max-width: 767px) { ... }
```

The only exception to the `max-width` rule is for the hamburger/mobile menu toggle (see Navigation section below), where `max-width` can be used to hide desktop nav on mobile. Even then, prefer showing/hiding with `min-width` when possible.

---

## Container Max-Widths Per Breakpoint

The container stretches to fill the viewport on small screens and caps at the design system maximum on large screens.

```css
.container {
    width: 100%;
    max-width: var(--container-max); /* 1280px */
    margin-left: auto;
    margin-right: auto;
    padding-left: var(--spacing-md);  /* 16px */
    padding-right: var(--spacing-md);
}

@media (min-width: 768px) {
    .container {
        padding-left: var(--spacing-xl);  /* 32px */
        padding-right: var(--spacing-xl);
    }
}

@media (min-width: 1024px) {
    .container {
        padding-left: var(--spacing-2xl); /* 48px */
        padding-right: var(--spacing-2xl);
    }
}
```

---

## Responsive Navigation: Hamburger (Mobile) to Horizontal (Desktop)

### HTML Structure

```html
<header class="header">
    <div class="container">
        <div class="header__inner">
            <a href="/" class="header__logo">
                <img src="logo.svg" alt="Site Name">
            </a>

            <!-- Desktop navigation -->
            <nav class="header__nav" id="main-nav">
                <a href="#" class="nav__link nav__link--active">Home</a>
                <a href="#services" class="nav__link">Services</a>
                <a href="/pricing" class="nav__link">Pricing</a>
                <a href="#contact" class="nav__link">Contact</a>
            </nav>

            <!-- CTA button (visible on desktop) -->
            <a href="#contact" class="btn btn--primary header__cta">Get Started</a>

            <!-- Hamburger button (visible on mobile) -->
            <button class="header__hamburger" aria-label="Toggle menu" aria-expanded="false">
                <span></span>
                <span></span>
                <span></span>
            </button>
        </div>
    </div>

    <!-- Mobile menu overlay -->
    <div class="mobile-menu" id="mobile-menu" aria-hidden="true">
        <nav class="mobile-menu__nav">
            <a href="#" class="mobile-menu__link">Home</a>
            <a href="#services" class="mobile-menu__link">Services</a>
            <a href="/pricing" class="mobile-menu__link">Pricing</a>
            <a href="#contact" class="mobile-menu__link">Contact</a>
        </nav>
        <a href="#contact" class="btn btn--primary mobile-menu__cta">Get Started</a>
    </div>
</header>
```

### CSS

```css
/* Mobile: hamburger visible, desktop nav hidden */
.header__nav,
.header__cta {
    display: none;
}

.header__hamburger {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 5px;
    width: 44px;
    height: 44px;
    background: none;
    border: none;
    cursor: pointer;
    padding: var(--spacing-sm);
}

.header__hamburger span {
    display: block;
    width: 24px;
    height: 2px;
    background: var(--color-text);
    transition: var(--transition-base);
}

/* Mobile menu (hidden by default) */
.mobile-menu {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100vh;
    background: var(--color-background);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--spacing-xl);
    transform: translateX(100%);
    transition: transform 0.3s ease;
    z-index: 999;
}

.mobile-menu.is-open {
    transform: translateX(0);
}

.mobile-menu__link {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-medium);
    padding: var(--spacing-md);
}

/* Desktop (1024px+): show nav, hide hamburger */
@media (min-width: 1024px) {
    .header__nav {
        display: flex;
        align-items: center;
        gap: var(--spacing-lg);
    }

    .header__cta {
        display: inline-flex;
    }

    .header__hamburger {
        display: none;
    }

    .mobile-menu {
        display: none;
    }
}
```

### JavaScript (Minimal)

```js
const hamburger = document.querySelector('.header__hamburger');
const mobileMenu = document.getElementById('mobile-menu');

if (hamburger && mobileMenu) {
    hamburger.addEventListener('click', () => {
        const isOpen = mobileMenu.classList.toggle('is-open');
        hamburger.setAttribute('aria-expanded', isOpen);
        mobileMenu.setAttribute('aria-hidden', !isOpen);
        document.body.style.overflow = isOpen ? 'hidden' : '';
    });
}
```

---

## CSS Grid and Flexbox Stacking

### Grid: Columns on Desktop, Stacked on Mobile

```css
/* Mobile: single column */
.features__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
}

/* Tablet: 2 columns */
@media (min-width: 768px) {
    .features__grid {
        grid-template-columns: repeat(2, 1fr);
        gap: var(--spacing-xl);
    }
}

/* Desktop: 3 columns */
@media (min-width: 1024px) {
    .features__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}

/* Large: 4 columns */
@media (min-width: 1200px) {
    .features__grid {
        grid-template-columns: repeat(4, 1fr);
    }
}
```

### Flexbox: Row on Desktop, Column on Mobile

```css
/* Mobile: stacked vertically */
.hero__inner {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xl);
}

/* Desktop: side by side */
@media (min-width: 1024px) {
    .hero__inner {
        flex-direction: row;
        align-items: center;
    }

    .hero__content {
        flex: 1;
    }

    .hero__image {
        flex: 1;
    }
}
```

### Reversing Order on Mobile

```css
.hero__inner {
    display: flex;
    flex-direction: column-reverse; /* image first on mobile */
    gap: var(--spacing-xl);
}

@media (min-width: 1024px) {
    .hero__inner {
        flex-direction: row; /* content left, image right on desktop */
    }
}
```

---

## Fluid Typography with clamp()

Use `clamp()` for headings and large text to smoothly scale between viewport sizes without media query jumps.

### Syntax

```css
font-size: clamp(<minimum>, <preferred>, <maximum>);
```

### Examples

```css
/* Hero title: 2rem at minimum, scales with viewport, caps at 4rem */
.hero__title {
    font-size: clamp(2rem, 5vw, 4rem);
}

/* Section title: 1.5rem to 2.5rem */
.section__title {
    font-size: clamp(1.5rem, 3vw, 2.5rem);
}

/* Body text: stays readable at all sizes */
.hero__subtitle {
    font-size: clamp(1rem, 2.5vw, 1.25rem);
}

/* Large display text */
.display__heading {
    font-size: clamp(2.5rem, 6vw, 5rem);
}
```

### Guidelines

- Use `clamp()` for `h1` through `h3` and hero/display text
- Body text and small text usually do not need `clamp()` -- a fixed `rem` value works fine
- The `vw` unit in the preferred value controls how aggressively the text scales
- Common preferred values: `2vw` (gentle), `3vw` (moderate), `5vw` (aggressive)

---

## Responsive Images

### srcset and sizes Attributes

Provide multiple image resolutions so the browser picks the best one for the viewport and pixel density.

```html
<img
    src="image-800.jpg"
    srcset="image-400.jpg 400w,
            image-800.jpg 800w,
            image-1200.jpg 1200w"
    sizes="(min-width: 1024px) 50vw,
           (min-width: 768px) 75vw,
           100vw"
    alt="Descriptive alt text"
    loading="lazy"
>
```

### The `<picture>` Element

Use `<picture>` for art direction -- serving different crops or images per viewport.

```html
<picture>
    <source
        media="(min-width: 1024px)"
        srcset="hero-desktop.jpg"
    >
    <source
        media="(min-width: 768px)"
        srcset="hero-tablet.jpg"
    >
    <img
        src="hero-mobile.jpg"
        alt="Hero image description"
        loading="lazy"
    >
</picture>
```

### WordPress wp_get_attachment_image()

In WordPress templates, use the built-in function to output responsive images automatically.

```php
<?php
$image_id = prefix_get_field('hero_image');
if ($image_id) :
    // WordPress generates srcset automatically from registered image sizes
    echo wp_get_attachment_image($image_id, 'large', false, array(
        'class'   => 'hero__image',
        'loading' => 'lazy',
        'sizes'   => '(min-width: 1024px) 50vw, 100vw',
    ));
endif;
?>
```

If you have an image array (from ACF/SCF) instead of just the ID:

```php
<?php
$image = prefix_get_field('hero_image');
if ($image) :
?>
    <img
        src="<?php echo esc_url($image['url']); ?>"
        srcset="<?php echo esc_attr($image['sizes']['medium'] . ' 300w, ' . $image['sizes']['large'] . ' 1024w, ' . $image['url'] . ' ' . $image['width'] . 'w'); ?>"
        sizes="(min-width: 1024px) 50vw, 100vw"
        alt="<?php echo esc_attr($image['alt']); ?>"
        width="<?php echo esc_attr($image['width']); ?>"
        height="<?php echo esc_attr($image['height']); ?>"
        loading="lazy"
    >
<?php endif; ?>
```

### Lazy Loading

Add `loading="lazy"` to all images below the fold. Do NOT add it to the hero/LCP image (which should be preloaded instead).

```html
<!-- Hero image: NO lazy loading (it's the LCP element) -->
<img src="hero.jpg" alt="Hero" fetchpriority="high">

<!-- Below-the-fold images: lazy loaded -->
<img src="service.jpg" alt="Service" loading="lazy">
```

---

## Touch-Friendly Targets

All interactive elements (links, buttons, form inputs) MUST have a minimum tap area of **44x44 pixels** on touch devices.

### Buttons

```css
.btn {
    min-height: 44px;
    min-width: 44px;
    padding: var(--spacing-sm) var(--spacing-lg);
}
```

### Navigation Links

```css
.nav__link {
    display: inline-flex;
    align-items: center;
    min-height: 44px;
    padding: var(--spacing-sm) var(--spacing-md);
}

.mobile-menu__link {
    display: block;
    padding: var(--spacing-md) var(--spacing-lg);
    min-height: 44px;
}
```

### Form Inputs

```css
input[type="text"],
input[type="email"],
input[type="tel"],
textarea,
select {
    min-height: 44px;
    padding: var(--spacing-sm) var(--spacing-md);
    font-size: var(--font-size-base); /* Prevents zoom on iOS */
}
```

### Icon Buttons

For small icon buttons (close, hamburger, social links), ensure the clickable area is at least 44px even if the visible icon is smaller.

```css
.icon-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    padding: var(--spacing-sm);
}
```

---

## Every Section MUST Have Responsive Styles

When building any section, you MUST define how it looks at each major breakpoint. No section should rely on desktop-only styles.

### Pattern for Every Section

```css
/* ============ Section: Values ============ */

/* Base: mobile */
.values {
    padding: var(--spacing-2xl) 0;
}

.values__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
}

.values__title {
    font-size: clamp(1.5rem, 3vw, 2.5rem);
    text-align: center;
    margin-bottom: var(--spacing-xl);
}

/* Tablet (768px+) */
@media (min-width: 768px) {
    .values__grid {
        grid-template-columns: repeat(2, 1fr);
        gap: var(--spacing-xl);
    }
}

/* Desktop (1024px+) */
@media (min-width: 1024px) {
    .values {
        padding: var(--spacing-3xl) 0;
    }

    .values__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}
```

---

## No Horizontal Scroll

The page MUST NOT scroll horizontally at any viewport width. This is tested starting at **320px minimum**.

### Common Causes and Fixes

```css
/* Prevent overflow from images */
img {
    max-width: 100%;
    height: auto;
}

/* Prevent overflow from fixed-width elements */
.container {
    width: 100%;
    overflow-x: hidden; /* Only as a last resort on the body/container */
}

/* Prevent overflow from long words/URLs */
.content {
    overflow-wrap: break-word;
    word-wrap: break-word;
}

/* Prevent overflow from pre/code blocks */
pre, code {
    overflow-x: auto;
    max-width: 100%;
}

/* Prevent overflow from tables */
.table-wrapper {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
}
```

### Testing Rule

Before finalizing, verify no horizontal scroll exists at these widths:
- 320px (oldest small phones)
- 375px (iPhone SE / standard)
- 576px (large phones)
- 768px (tablets)
- 1024px (desktops)
- 1440px (large desktops)

---

## Reduced Motion

Respect the user's preference to reduce animations and motion.

```css
/* Define animations normally */
.card {
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.card:hover {
    transform: translateY(-4px);
    box-shadow: var(--shadow-lg);
}

/* Remove animations for users who prefer reduced motion */
@media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
        scroll-behavior: auto !important;
    }
}
```

This MUST be included in every stylesheet that uses animations or transitions.

---

## Responsive Section Spacing

Section vertical padding should scale with the viewport.

```css
.section {
    padding: var(--spacing-2xl) 0;
}

@media (min-width: 768px) {
    .section {
        padding: var(--spacing-3xl) 0;
    }
}

@media (min-width: 1200px) {
    .section {
        padding: calc(var(--spacing-3xl) * 1.5) 0;
    }
}
```

---

## Responsive Typography Scale

While `clamp()` handles most heading sizes, ensure consistent scaling across the page.

```css
/* Mobile base sizes */
h1 { font-size: clamp(2rem, 5vw, 3.5rem); }
h2 { font-size: clamp(1.5rem, 3.5vw, 2.5rem); }
h3 { font-size: clamp(1.25rem, 2.5vw, 1.75rem); }
h4 { font-size: var(--font-size-lg); }

p {
    font-size: var(--font-size-base);
    line-height: var(--line-height-normal);
}

@media (min-width: 768px) {
    p {
        font-size: var(--font-size-md);
    }
}
```

---

## Responsive Footer

Footers typically use a multi-column grid on desktop and stack on mobile.

```css
.footer__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-xl);
}

@media (min-width: 768px) {
    .footer__grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (min-width: 1024px) {
    .footer__grid {
        grid-template-columns: 2fr 1fr 1fr 1fr;
    }
}

.footer__bottom {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-sm);
    text-align: center;
    padding-top: var(--spacing-xl);
    border-top: 1px solid var(--color-border);
    margin-top: var(--spacing-xl);
}

@media (min-width: 768px) {
    .footer__bottom {
        flex-direction: row;
        justify-content: space-between;
        text-align: left;
    }
}
```

---

## Testing Checklist

Before marking any page or section as complete, verify responsiveness at these viewport widths:

| Width | Device Class | Check |
|---|---|---|
| 375px | Mobile (iPhone SE) | Layout stacks, text readable, touch targets 44px+ |
| 576px | Large phone | Grid may shift to 2 columns |
| 768px | Tablet | 2-column layouts, larger padding |
| 1024px | Desktop | Full navigation visible, 3+ column grids |
| 1440px | Large desktop | Max container width respected, generous whitespace |

### What to Verify at Each Breakpoint

- [ ] No horizontal scrolling
- [ ] All text is readable (no truncation, no overflow)
- [ ] Images scale properly (no stretching, no overflow)
- [ ] Navigation switches between hamburger and horizontal
- [ ] Grid layouts adjust column count appropriately
- [ ] Touch targets are at least 44x44px on mobile
- [ ] Section spacing scales (tighter on mobile, looser on desktop)
- [ ] Footer stacks properly on mobile
- [ ] `prefers-reduced-motion` disables animations
- [ ] Form inputs are at least 16px font size (prevents iOS zoom)

---

## Summary Checklist

- [ ] Mobile-first CSS with `min-width` media queries only
- [ ] Breakpoints: 576px, 768px, 1024px, 1200px, 1440px
- [ ] Container with responsive padding and max-width
- [ ] Hamburger menu on mobile, horizontal nav on desktop with ARIA attributes
- [ ] CSS Grid/Flexbox with mobile stacking
- [ ] `clamp()` used for headings and display text
- [ ] Responsive images with `srcset`, `sizes`, and `loading="lazy"`
- [ ] WordPress `wp_get_attachment_image()` used in templates
- [ ] All touch targets minimum 44x44px
- [ ] Every section has styles for all breakpoints
- [ ] No horizontal scroll at any width (tested at 320px+)
- [ ] `prefers-reduced-motion` media query included
- [ ] Tested at: 375px, 576px, 768px, 1024px, 1440px
