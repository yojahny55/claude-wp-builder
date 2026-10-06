---
name: wp-css-system
description: Plain-CSS design system for template=basic themes — custom property tokens, BEM naming, spacing, typography and colour scales, reset rules, section delimiters and layout utilities, with no build tools. Use when writing or reviewing theme or demo CSS on a basic template (the wp-css agent, /wp-demo). A project whose template is tailwind uses wp-tailwind-system instead.
user-invocable: false
---

> **Applies to `template=basic` only.** If the project's `.claude/CLAUDE.md` says
> `Template: tailwind`, stop and use the `wp-tailwind-system` skill instead. The two
> are mutually exclusive: this skill's BEM + `:root` custom-property system is the
> wrong output surface for a Tailwind theme.

# CSS Design System Standards

This skill defines the CSS architecture for `template=basic` themes. The system uses **CSS custom properties** (variables), **BEM naming**, and **no build tools** -- plain CSS files served directly.

## Reference files

- [references/tokens.md](references/tokens.md) — every `:root` token and its default
  value. Read when writing the `:root` block or mapping a demo value to a token.
- [references/patterns.md](references/patterns.md) — worked BEM examples, the
  `.container` and `.section` utilities, and the grid, flex row, card and section
  title patterns. Read when building a block and you want the house shape to copy.

---

## Principles

1. **No frameworks on this template** -- `basic` themes use no Bootstrap, Tailwind,
   Foundation, or any CSS framework. (A `tailwind` project is not covered by this
   skill at all — see the banner above.)
2. **No preprocessors** -- no Sass, Less, or PostCSS
3. **No build step** -- CSS files are authored and served as-is
4. **All values use custom properties** -- never hardcode colors, spacing, font sizes, or other design tokens directly in rules
5. **BEM naming convention** for all class names
6. **Consistency between demo HTML and WordPress theme CSS** -- the design system carries over from the demo to the theme unchanged
7. **Layout is flex or grid** -- `position: absolute` is only for a real superposition (see below)

---

## Custom Property Reference

All design tokens are defined in `:root` at the top of the main stylesheet: a
primary, secondary and tertiary palette with light/dark variants, a neutral ramp
(`--color-neutral-50` … `-900`) and semantic colours (`--color-text`,
`--color-background`, `--color-border`, …); spacing `--spacing-xs` … `-3xl`;
font families, sizes `--font-size-xs` … `-6xl`, weights and line heights;
shadows, radii, transitions and `--container-max`. Every name and default value is
in [references/tokens.md](references/tokens.md) — read it when writing the `:root`
block or deciding which token a value maps to.

---

## Using Custom Properties in Rules

**Every** color, spacing, font size, shadow, radius, and transition value in CSS rules MUST reference a custom property. Never hardcode values.

```css
/* CORRECT */
.hero__title {
    font-family: var(--font-family-secondary);
    font-size: var(--font-size-4xl);
    color: var(--color-text);
    margin-bottom: var(--spacing-lg);
}

.card {
    background: var(--color-background);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: var(--spacing-xl);
    transition: var(--transition-base);
}

/* WRONG — hardcoded values */
.hero__title {
    font-family: 'Cormorant Garamond', serif;
    font-size: 3rem;
    color: #262626;
    margin-bottom: 1.5rem;
}
```

---

## BEM Naming Convention

All CSS classes follow the **Block Element Modifier** pattern: `.block__element--modifier`.

### Structure

- **Block**: A standalone entity (`.card`, `.hero`, `.nav`, `.footer`)
- **Element**: A part of a block (`.card__title`, `.card__image`, `.nav__link`)
- **Modifier**: A variation (`.card--featured`, `.btn--primary`, `.nav__link--active`)

Worked block, element and modifier rules (a hero, a button family) are in
[references/patterns.md](references/patterns.md).

### Naming Rules

- Use lowercase with hyphens inside block/element names: `.service-card__title` (not `.serviceCard__title`)
- Maximum two levels: `.block__element` (never `.block__element__subelement`)
- If nesting is needed, create a new block: `.card__header` contains `.card-header__title`
- Modifiers are always on the block or element, never standalone

---

## CSS Reset / Normalize Baseline

Every stylesheet begins with a minimal reset to ensure consistent rendering across browsers.

```css
/* ============ Section: Reset ============ */
*,
*::before,
*::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

html {
    scroll-behavior: smooth;
    -webkit-text-size-adjust: 100%;
}

body {
    font-family: var(--font-family-primary);
    font-size: var(--font-size-base);
    line-height: var(--line-height-normal);
    color: var(--color-text);
    background-color: var(--color-background);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

img,
picture,
video,
canvas,
svg {
    display: block;
    max-width: 100%;
    height: auto;
}

a {
    color: inherit;
    text-decoration: none;
}

button {
    font: inherit;
    cursor: pointer;
    border: none;
    background: none;
}

ul,
ol {
    list-style: none;
}

h1, h2, h3, h4, h5, h6 {
    font-weight: var(--font-weight-semibold);
    line-height: var(--line-height-tight);
}

input,
textarea,
select {
    font: inherit;
}
```

### Never scope a reset to a page or section class

The reset above is safe because every selector in it is bare: `img { height: auto }`
scores (0,0,1), so any class on that image beats it. Re-scope the same declarations
to a page — `.page img { max-width: 100%; height: auto }` — and the score becomes
(0,1,1), which **outranks a single class on that same `<img>`**: `.page-step__icon
{ height: 3.1875rem }` is (0,1,0) and loses. The image ignores its own class and
paints at its intrinsic size while the class sits in the stylesheet looking correct.

The symptom is misleading — `getComputedStyle` returns the reset's value, the class
is visible in the DevTools rule list, and it reads as "my CSS is not loading". It
cost a full debugging detour once, on images exported at 3× that therefore painted
at triple their design size.

If a page really needs its own reset, give the selector no weight:

```css
/* :where() is always (0,0,0) — every class on the element still wins. */
:where(.page) img { max-width: 100%; height: auto; }
```

Generally: **a rule that exists to be overridden belongs in `:where()`.** Raising
each override to outrank it is a race you keep re-running.

### A reset class loses to nothing and wins on source order

The same trap arrives through a class rather than a scope. A `.btn-reset` that neutralises the
UA styles of a `<button>` — typically `color: inherit; font: inherit; background: none; border: 0`
— is (0,1,0), exactly like the utility classes already on the element. A tie is decided by source
order, and a reset class defined after the utilities **wins**.

That is how `<span class="icon-search text-white text-[1.625rem]">` turned into
`<button class="btn-reset icon-search text-white text-[1.625rem]">` and painted black at 18px
instead of white at 26px. Nothing about the change looked visual: the diff swapped a tag and
added a reset class, and no colour or size value was edited anywhere.

Two ways out, in order of preference:

```css
/* 1. The reset has no weight, so every utility on the element still wins. */
:where(.btn-reset) { color: inherit; font: inherit; background: none; border: 0; }

/* 2. Or reset the TAG, bare, alongside the other element resets — (0,0,1). */
button { font: inherit; cursor: pointer; border: none; background: none; }
```

Option 2 is what the reset above already does, which is why a Tailwind theme rarely needs a
`btn-reset` class at all: converting a `<span>` to a `<button>` inside this system carries no
UA styling to neutralise. Reach for the class only where a third-party stylesheet is the thing
being overridden, and then measure the element's computed `color`, `fontSize` and
`getBoundingClientRect()` before and after the change — a tie broken by source order is
invisible in the rule list, where both declarations show as applying.

---

## Section Comment Delimiters

Use the following format to separate major sections of the stylesheet. This makes the file scannable and maps to the section-based architecture of the theme.

```css
/* ============ Section: Variables ============ */
:root { ... }

/* ============ Section: Reset ============ */
*, *::before, *::after { ... }

/* ============ Section: Typography ============ */
h1, h2, h3, ... { ... }

/* ============ Section: Layout ============ */
.container { ... }

/* ============ Section: Header ============ */
.header { ... }

/* ============ Section: Hero ============ */
.hero { ... }

/* ============ Section: Services ============ */
.services { ... }

/* ============ Section: Footer ============ */
.footer { ... }

/* ============ Section: Utilities ============ */
.sr-only { ... }
```

---

## Layout Utilities

The `.container` and `.section` / `.section--compact` / `.section--alt` utilities
are in [references/patterns.md](references/patterns.md).

### Layout is flex or grid -- `position: absolute` is for superposition only

A design tool (Figma, XD, a PDF mockup) exports every element with an `x`/`y`. That
coordinate is **where the element fell in that one frame at that one width** -- it is
not the layout, and it is the weakest hint in the file. Copied into CSS it produces a
section that is exact on the designer's screen and broken everywhere else: an absolute
box is out of flow, so nothing pushes it and nothing makes room for it. The heading
beside it wraps at 1280 and the button lands on top of it; the client edits the ACF
field and the text runs under the image. Neither is visible until someone looks.

This matters more in WordPress than in a static demo: **every string in a template part
comes from the database**. The demo's copy is a placeholder. A layout that only holds at
the demo's exact text lengths is broken the first time the client saves a longer title.

**The rule.** Build every section with flex or grid. `position: absolute` is earned by a
real superposition and by nothing else:

- a badge or price tag on top of an image
- a floating icon that overlaps two boxes
- a tooltip or dropdown panel
- an overlay/veil over a photo (`position: absolute; inset: 0`)
- a sticky header or a fixed back-to-top button (`sticky` / `fixed`)
- the `.sr-only` clip pattern below

**The test, before writing the declaration:** *does this survive if the content changes
length or the viewport changes?* If **no**, it is flex/grid. If **yes**, because the
overlap is the point, absolute is correct.

**Read a mockup's offsets as relationships, not coordinates.** Two elements 32px apart is
`gap: var(--spacing-md)`, never `left: 632px`. An element 64px from its container's edge
is `padding`, never `top: 64px`. Elements sharing a row, a column or a spacing are ONE
flex/grid container, not N placed boxes.

```css
/* NO -- the mockup's coordinates, frozen */
.hero__title  { position: absolute; left: 0; top: 120px; width: 551px; }
.hero__cta    { position: absolute; left: 600px; top: 116px; }

/* YES -- the same geometry, as a relationship */
.hero__row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-xl);
}
.hero__title { max-width: 551px; }

/* YES -- absolute earned: the badge really does sit ON the image */
.card__media { position: relative; }
.card__badge { position: absolute; top: var(--spacing-sm); left: var(--spacing-sm); }
```

When converting a demo (`/wp-polish`, `/wp-section`, `/wp-yolo`), an `absolute` inherited
from the source HTML is **not** a value to preserve -- rebuild it as flex/grid unless it
passes the test above. Only if the client explicitly asks for an overlap effect does a new
absolute enter the theme.

### Screen Reader Only

```css
.sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
}
```

---

## Page-Specific CSS Files

When a page has substantial unique styles (e.g., a pricing calculator, a software portfolio page), create a dedicated CSS file and enqueue it conditionally.

```
assets/css/
├── styles.css      # Main design system (always loaded)
├── software.css    # Software page only
└── pricing.css     # Pricing page only
```

These files:
- Must still use the same custom properties from the design system
- Are enqueued via `is_page_template()` in `functions.php`
- Should NOT duplicate base styles already in `styles.css`

---

## Consistency Between Demo and Theme

When building the demo HTML first and then converting to WordPress:

1. The `:root` custom properties in the demo `<style>` block MUST match the theme `styles.css` exactly
2. All BEM class names in the demo MUST be preserved in the WordPress templates
3. The CSS from the demo is extracted into `assets/css/styles.css` with minimal changes (primarily removing the `<style>` tags)
4. Section ordering and naming must match

---

## Common Patterns

Grid layout, flexbox row, card component and the section title pattern are in
[references/patterns.md](references/patterns.md).

---

## Contours That Render the Same in Every Engine

Verification runs Chromium, plus Firefox on Linux when a build exists. Firefox on Windows
draws a 1px `border` with a `border-radius` with visible notches where each corner curve
meets the straight edge, and Linux Firefox does not reproduce it. `bin/css-contour-lint.mjs`
is the guard (`/wp-finalize` runs it over the theme and the demo):

- **A 1px contour on a transparent or white/near-white background is drawn with
  `box-shadow: inset 0 0 0 1px <color>`**, never `border`: outline buttons, focused and
  error fields, ringed icon links. The inset shadow occupies no layout space, so replace the
  border with `border: 0` plus the shadow and keep the padding the border used to add:

  ```css
  .btn--outline {
      border: 0;
      border-radius: var(--radius-full);
      background: transparent;
      box-shadow: inset 0 0 0 1px var(--color-primary);
      padding: calc(var(--spacing-sm) + 1px) calc(var(--spacing-lg) + 1px);
  }
  ```

  A border on a solid fill, a card or a divider is fine.
- **Never `filter: drop-shadow()` on a bordered rounded ring.** The filter follows the
  anti-aliased edge and picks up the same artifacts. Stack ring and shadow in one
  `box-shadow`: `box-shadow: 0 0 0 1px var(--color-accent), 0 2px 4px rgb(0 0 0 / .2);`.

### Search Inputs: One Clear Control, and It Is Yours

Chromium and Safari draw a native clear "×" inside `type="search"`; Firefox draws none. A
design that shows a clear affordance therefore needs a real `<button type="button">` that
empties the field and fires `input`, and the native one must be hidden, or Chromium shows
two:

```css
input[type="search"]::-webkit-search-cancel-button { -webkit-appearance: none; appearance: none; }
```

A design with no clear affordance still hides the native one, for the same parity reason.

## Summary Checklist

- [ ] All design tokens defined as `:root` custom properties
- [ ] Color palette includes primary, secondary, tertiary, and neutral scale (50-900)
- [ ] Spacing scale from `--spacing-xs` to `--spacing-3xl`
- [ ] Typography scale from `--font-size-xs` to `--font-size-6xl`
- [ ] Shadow, radius, transition, and container variables defined
- [ ] All CSS rules reference custom properties (no hardcoded values)
- [ ] BEM naming used for all classes
- [ ] Every section laid out with flex/grid -- each `position: absolute` is a real superposition
- [ ] CSS reset/normalize included at the top
- [ ] Section comment delimiters used throughout
- [ ] No CSS frameworks, preprocessors, or build tools
- [ ] Page-specific CSS in separate files, conditionally enqueued
- [ ] Demo and theme CSS use identical design tokens and class names
