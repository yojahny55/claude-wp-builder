---
name: wp-responsive
description: Responsive design patterns for theme and demo CSS — mobile-first breakpoints, container widths, navigation, grid and flex stacking, fluid type with clamp(), responsive images, touch targets, reduced motion and no horizontal scroll. Use when writing or checking responsive styles for a section, header or footer (/wp-demo, /wp-init, /wp-responsive-check).
user-invocable: false
---

# Responsive Design Patterns

This skill defines the responsive design system used across all themes and demos. It uses **mobile-first** CSS with `min-width` media queries, fluid typography, and responsive image techniques.

## Reference files

- [references/navigation.md](references/navigation.md) — the hamburger-to-horizontal header:
  full HTML, CSS and toggle JavaScript. Read when building or fixing a header's mobile menu.
- [references/images.md](references/images.md) — `srcset`/`sizes`, `<picture>` art direction,
  `wp_get_attachment_image()` and lazy-loading markup. Read when emitting an image in a demo
  or template.
- [references/layout-patterns.md](references/layout-patterns.md) — worked CSS for grid and flex
  stacking, per-element touch targets, a complete section, section spacing, the heading scale
  and the footer. Read when writing a section's breakpoints and you want the pattern to copy.

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

**A breakpoint is a range, not a line.** Whatever you declare at one step stays in force until the
next step overrides it, so the layout must be checked BETWEEN the steps and not only at them. The
first desktop step is the usual casualty: a row of cards that reads well at 1440 is handed the same
row rule at 1024, where the columns are 40% narrower and the copy no longer fits. Before calling a
component done, resize through the middle of each range — 1100-1200 especially — and give that
range its own rule when the design's desktop layout does not survive it.

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

Below `1024px` the desktop nav and header CTA are hidden, and a hamburger button (44x44,
`aria-label="Toggle menu"`, `aria-expanded`) opens a full-screen mobile menu whose
`aria-hidden` flips with it while body scroll is locked. From `1024px` the nav is a flex row
and the hamburger and mobile menu are hidden. Markup, CSS and JS:
[references/navigation.md](references/navigation.md).

---

## CSS Grid and Flexbox Stacking

Grids start at one column and add columns at `768px`, `1024px` and `1200px`; flex rows start
as `flex-direction: column` and become `row` at `1024px`. Use `column-reverse` on mobile when
the image must come first. Worked examples:
[references/layout-patterns.md](references/layout-patterns.md#css-grid-and-flexbox-stacking).

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

- Give content images `srcset` and `sizes`; use `<picture>` only for art direction (a
  different crop per viewport).
- In templates, output images with `wp_get_attachment_image()`, which writes `srcset` from the
  registered sizes. From an ACF/SCF image array, build `srcset` from `$image['sizes']` and
  emit `width` and `height`.
- Add `loading="lazy"` to all images below the fold. Do NOT add it to the hero/LCP image (which
  should be preloaded instead); it gets `fetchpriority="high"`.

Markup for each case: [references/images.md](references/images.md).

---

## Touch-Friendly Targets

Every interactive element outside running text (links, buttons, form inputs, icon links)
MUST render at least **24x24 CSS pixels** at every viewport — WCAG 2.2 AA 2.5.8, and the
threshold the accessibility audit fails on. **44x44** (2.5.5, AAA) is the comfortable size
to design new controls at; it is advice, not a failing threshold.

When a designed element is smaller than 24px (a 16px social icon, a 20px nav line, a
breadcrumb home glyph), enlarge the hit area **without moving anything**: padding plus an
equal negative margin, so the layout box and the text position stay where the design put
them.

```css
/* 16px icon: 4px padding each side = 24x24, -4px margin keeps its place */
.footer__social-link {
    display: inline-flex;
    padding: 4px;
    margin: -4px;
}

/* 20px line of nav text: 2px top and bottom */
.nav__link {
    display: inline-block;
    padding-block: 2px;
    margin-block: -2px;
}
```

On a `tailwind` project the same pair is `inline-flex p-1 -m-1` and `inline-block py-0.5 -my-0.5`
on the element.

Measure it at desktop and mobile with `getBoundingClientRect()` (24x24 or more), and
compare the text's own `getBoundingClientRect().top/left` before and after the change: it
must not move.

### Icon Buttons

For small icon buttons (close, hamburger, social links), the clickable area is at least 24px (44px where the design has room) even if the visible icon is smaller. Inside a row whose spacing is fixed by the design, use the padding plus negative margin pattern above instead of a fixed box.

Sizing for buttons, navigation links, form inputs (`font-size: var(--font-size-base)`, which
prevents zoom on iOS) and icon buttons:
[references/layout-patterns.md](references/layout-patterns.md#touch-target-sizing-per-element).

---

## Every Section MUST Have Responsive Styles

When building any section, you MUST define how it looks at each major breakpoint. No section should rely on desktop-only styles.

A complete section to copy (base, `768px`, `1024px`):
[references/layout-patterns.md](references/layout-patterns.md#pattern-for-every-section).

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

## Section Spacing, Heading Scale and Footer

Section padding steps from `--spacing-2xl` (mobile) to `--spacing-3xl` (`768px`) and
`calc(var(--spacing-3xl) * 1.5)` (`1200px`). `h1`–`h3` use `clamp()`; `h4` and body text use
fixed tokens. Footers stack to one column, go to two at `768px` and to `2fr 1fr 1fr 1fr` at
`1024px`, with the bottom bar becoming a row at `768px`. The CSS for all three:
[references/layout-patterns.md](references/layout-patterns.md#responsive-section-spacing).

---

## Testing Checklist

Before marking any page or section as complete, verify responsiveness at these viewport widths:

| Width | Device Class | Check |
|---|---|---|
| 375px | Mobile (iPhone SE) | Layout stacks, text readable, touch targets 24px+ |
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
- [ ] Touch targets are at least 24x24px at desktop and mobile (44x44 where the design has room)
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
- [ ] All touch targets minimum 24x24px (WCAG 2.5.8), none moved to get there
- [ ] Every section has styles for all breakpoints
- [ ] No horizontal scroll at any width (tested at 320px+)
- [ ] `prefers-reduced-motion` media query included
- [ ] Tested at: 375px, 576px, 768px, 1024px, 1440px
