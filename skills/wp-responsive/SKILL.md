---
name: wp-responsive
description: Defines the mobile-first responsive rules for plain-CSS demo pages — the 576/768/1024/1200/1440 min-width breakpoint scale, container widths, the hamburger-to-horizontal header with an accessible mobile menu, grid and flex stacking, clamp() type, responsive images with a never-lazy hero, 24x24 touch targets, reduced motion and no horizontal scroll. Use when writing or fixing a section's breakpoints, a mobile menu, a hero's fluid type, image srcset or a too-small tap target in a /wp-demo page, or an image or touch target in a theme template. Not for a Tailwind theme's breakpoints (wp-tailwind-system), a screenshot walk of a site (/wp-demo-verify), or a cinematic site's mobile fallback (adaptive-mobile-strategy).
user-invocable: false
---

# Responsive Design Patterns

Mobile-first CSS with `min-width` media queries, fluid type and responsive images, for the
plain-CSS pages `/wp-demo` writes.

## Which parts apply

- **Plain-mode demo pages:** all of it. A demo is plain CSS whatever the project's template.
- **Theme CSS:** read `template` from the project's `.claude/CLAUDE.md`. A `tailwind` theme
  (and `basic`, its legacy alias) takes its breakpoints from `wp-tailwind-system`'s
  `references/breakpoints.md` and never writes a media query by hand, so the scale and the
  `@media` examples here do not apply to it.
- **Craft mode** (`"demo mode": "craft"` in `.wp-create.json`): compositions size to their own
  container with `@container` queries and `cqi` ramps
  (`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/compositions/README.md`); the breakpoint scale
  and `vw` clamps here do not apply to them.
- **Everywhere:** touch targets, images, reduced motion and no horizontal scroll.

## Reference files

- [references/navigation.md](references/navigation.md) — the hamburger-to-horizontal header:
  full HTML, CSS and JavaScript, with the focus trap the audit requires. Read when building or
  fixing a header's mobile menu.
- [references/images.md](references/images.md) — the hero (LCP) image, below-the-fold images,
  `<picture>` art direction and `wp_get_attachment_image()`. Read when emitting an image in a
  demo or template.
- [references/layout-patterns.md](references/layout-patterns.md) — worked CSS for grid and flex
  stacking, per-element touch targets, a complete section, section spacing, the heading scale
  and the footer. Read when writing a section's breakpoints and you want the pattern to copy.

---

## Mobile-First Breakpoint System

Base styles are the phone layout; each `min-width` breakpoint adds to them.

| Name | Min-Width | Target Devices |
|---|---|---|
| Base | (no query) | All phones (320px+) |
| Small | `576px` | Large phones, small tablets |
| Tablet | `768px` | Tablets (portrait and landscape) |
| Desktop | `1024px` | Desktops, laptops |
| Large | `1200px` | Large desktops |
| Extra Large | `1440px` | Ultra-wide screens |

**A breakpoint is a range, not a line.** Whatever you declare at one breakpoint stays in
force until the next one overrides it, so the layout must be checked BETWEEN the breakpoints
and not only at them. The first desktop breakpoint is the usual casualty: a row of cards that
reads well at 1440 is handed the same row rule at 1024, where the columns are 40% narrower
and the copy no longer fits. Before calling a section done, check the middle of each range —
1100-1200 especially — and give that range its own rule when the design's desktop layout
does not survive it.

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

Use `min-width` queries only, the mobile menu included. You start with the constrained layout
and add complexity as space increases; a `max-width` rule is desktop-first CSS undoing itself.

```css
/* CORRECT: mobile-first with min-width */
@media (min-width: 768px) { ... }

/* WRONG: desktop-first with max-width */
@media (max-width: 767px) { ... }
```

A `max-width: N` rule paired with a `min-width: N+1` rule leaves a gap at fractional
viewport widths. Browser zoom and OS display scaling produce them (a 766px window at 110%
is 767.27px wide), and there neither query matches: the page falls back to its unqueried
defaults, so a logo can render at 700px and a box hidden on every device can show. If a
`max-width` query is unavoidable, such as in a page-builder's CSS, close the gap with
`max-width: 767.98px`, or use range syntax: `@media (width < 768px)`.
`/wp-demo-verify` reports the leftover case as `breakpoint-gap`.

---

## Container Max-Widths Per Breakpoint

The container fills the viewport on small screens and caps at `--container-max` on large ones.

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
`aria-label="Toggle menu"`, `aria-expanded`, `aria-controls`) opens a full-screen mobile
menu and locks body scroll. The open menu is a modal overlay, so it must pass the
accessibility audit's A11Y-031: closed, it is `visibility: hidden` so its links leave the
tab order; open, Tab and Shift+Tab cycle inside it, Escape closes it, and focus returns to
the button. Crossing to `1024px` while it is open closes it, so body scroll is not left
locked. From `1024px` the nav is a flex row and the hamburger and mobile menu are hidden.
Markup, CSS and JS: [references/navigation.md](references/navigation.md).

---

## CSS Grid and Flexbox Stacking

Grids start at one column and add columns at the breakpoints the content needs; flex rows
start as `flex-direction: column` and become `row` at `1024px`. Use `column-reverse` on
mobile when the image must come first. Worked examples:
[references/layout-patterns.md](references/layout-patterns.md#css-grid-and-flexbox-stacking).

---

## Fluid Typography with clamp()

`h1`–`h3` and hero or display text use `clamp()`; body and small text stay on fixed `rem`
tokens. The `vw` term sets how hard the size scales: `2vw` gentle, `3vw` moderate, `5vw`
aggressive.

```css
.hero__title     { font-size: clamp(2rem, 5vw, 4rem); }
.section__title  { font-size: clamp(1.5rem, 3vw, 2.5rem); }
.hero__subtitle  { font-size: clamp(1rem, 2.5vw, 1.25rem); }
```

The floor is a phone size. A hero floored at a desktop size wraps a normal headline into six
lines at 390px.

---

## Responsive Images

- Give content images `srcset`, `sizes`, `width` and `height`; use `<picture>` only for art
  direction (a different crop per viewport).
- In templates, output images with `wp_get_attachment_image($image['ID'], …)`. ACF/SCF image
  fields return an array (`return_format => 'array'`), so pass its `ID`: the array itself
  prints nothing.
- Add `loading="lazy"` to all images below the fold. Never add it to the hero/LCP image: it
  gets `fetchpriority="high"` and no `loading` attribute (`'loading' => false` in
  `wp_get_attachment_image()`).

Markup for each case: [references/images.md](references/images.md).

---

## Touch Targets

Every interactive element outside running text (links, buttons, form inputs, icon links)
MUST render at least **24x24 CSS pixels** at every viewport — WCAG 2.2 AA 2.5.8, and the
threshold the accessibility audit fails on. **44x44** (2.5.5, AAA) is the comfortable size
to design new controls at; it is advice, not a failing threshold.

When a designed element is smaller than 24px (a 16px social icon, a 20px nav line, a
breadcrumb home glyph), enlarge the touch target **without moving anything**: padding plus an
equal negative margin, so the layout box and the text position stay where the design put
them. The same applies to an icon button (close, hamburger, social link) inside a row whose
spacing the design fixes.

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

Sizing for buttons, navigation links, form inputs (`font-size: var(--font-size-base)`, which
prevents zoom on iOS) and icon buttons:
[references/layout-patterns.md](references/layout-patterns.md#touch-target-sizing-per-element).

---

## Every Section MUST Have Responsive Styles

Every section defines how it looks at each breakpoint it needs; none relies on desktop-only
styles. A complete section to copy (base, `768px`, `1024px`):
[references/layout-patterns.md](references/layout-patterns.md#pattern-for-every-section).
Section padding, the heading scale and the footer grid:
[references/layout-patterns.md](references/layout-patterns.md#responsive-section-spacing).

---

## No Horizontal Scroll

The page MUST NOT scroll horizontally at any viewport width, down to **320px**.

### Fix the element that overflows, never the wrapper

Find the culprit before writing CSS. `/wp-demo-verify` names it: every `overflow` row in
its findings carries `culprits`, the boxes that stick out. Without the tool, run this in the
console at the failing width:

```js
[...document.querySelectorAll('*')].filter((el) => el.getBoundingClientRect().right > document.documentElement.clientWidth)
```

Then fix that element: a fixed `width` becomes `max-width: 100%`, a long word or URL gets
`overflow-wrap: anywhere`, a wide table or code block gets its own `overflow-x: auto`
wrapper, and a `position: absolute` box gets a `position: relative` ancestor inside the
box it escapes.

**Never put `overflow-x: hidden` on `.container`, `body` or a section wrapper.** It hides
the overflow the check exists to find, clips focus rings and shadows that sit past the
edge, and makes the element a scroll container, which breaks `position: sticky` inside it.

---

## Reduced Motion

Every stylesheet that uses animations or transitions MUST carry this block:

```css
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

---

## Verify

1. Run `/wp-demo-verify` on the page or the `demo/` directory. It walks every width this
   skill cares about, including the ones between the breakpoints, and reports overflow with
   its culprits and copy clipped by its container.
2. Fix each finding at its source, as above.
3. Run it again. Stop when it reports no overflow and no clipped copy at any width.
4. Then check by hand what the walk cannot: 320px (narrower than its narrowest width), the
   mobile menu open and closed from the keyboard, `prefers-reduced-motion`, and every touch
   target at 24x24 or more without the text moving.
