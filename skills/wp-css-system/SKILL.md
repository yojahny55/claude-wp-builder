---
name: wp-css-system
description: Defines the plain-CSS design system of a basic-template theme's assets/css/styles.css and of a plain demo's style block — the :root token names and scales, BEM naming, the reset and its specificity traps (scoped resets, reset classes, :where()), flex or grid layout instead of position absolute, stylesheet delimiters, and contours that render the same in every engine. Use when writing or reviewing that CSS, mapping a demo's values to var() tokens, turning absolutely positioned mockup boxes into a layout, or fixing a reset that beats a class. Not for a tailwind theme (wp-tailwind-system), a cinematic theme's cinematic.css, or breakpoints alone (wp-responsive).
user-invocable: false
---

> **Which parts apply is decided by the `Template:` line in the project's
> `.claude/CLAUDE.md`. Read it first.**
>
> | `Template:` | This skill |
> |---|---|
> | `basic` — a theme scaffolded before the basic starter was removed | All of it. The output is `assets/css/styles.css`. |
> | `tailwind` | **None. Stop** and use `wp-tailwind-system`: this skill's BEM + `:root` custom-property system is the wrong output surface for a Tailwind theme. |
> | `cinematic` | **None. Stop.** The scene CSS is `assets/css/cinematic.css`, owned by the `wp-cinematic` agent and the cinematic starter. |
> | no `.claude/CLAUDE.md`, or no `Template:` line — a plain demo before `/wp-init` | The rules that shape the demo's `<style>`: tokens, BEM, the reset and its specificity rules, delimiters, flex/grid layout, contours and search inputs. Not `assets/css/styles.css` or page-specific CSS files, which do not exist until a theme does. |
>
> A craft demo (`demo mode: craft` in `.wp-create.json`) takes its tokens from
> `demo/DESIGN.md` and the `wp-demo-craft` compositions, not from this skill's token set.

# CSS Design System Standards

This skill defines the plain-CSS architecture for `Template: basic` themes and for plain
demos: **tokens** (named values, declared as CSS custom properties in `:root`), **BEM
naming**, and **no build tools** — plain CSS files served directly.

## Reference files

- [references/tokens.md](references/tokens.md) — every `:root` token name and its scale,
  with placeholder values. Read when writing the `:root` block or mapping a demo value to a
  token.
- [references/reset.md](references/reset.md) — the reset every stylesheet opens with.
  Read when starting a stylesheet or a demo's `<style>` block.
- [references/patterns.md](references/patterns.md) — worked BEM examples, the
  `.container` and `.section` utilities, and the grid, flex row, card and section
  title patterns. Read when building a block and you want the house shape to copy.

---

## Principles

1. **No frameworks on this template** — `basic` themes use no Bootstrap, Tailwind,
   Foundation, or any CSS framework. (A `tailwind` project is not covered by this
   skill at all — see the banner above.)
2. **No preprocessors** — no Sass, Less, or PostCSS
3. **No build step** — CSS files are authored and served as-is
4. **All values use custom properties** -- never hardcode colors, spacing, font sizes, or other design tokens directly in rules. The one exception is transcription mode (`/wp-yolo`, `/wp-section --transcribe`; see `agents/wp-css.md` § Transcription Mode), where the demo's declared values are copied verbatim and a token is used only on an exact match
5. **BEM naming convention** for all class names
6. **Consistency between demo HTML and WordPress theme CSS** — the design system carries over from the demo to the theme unchanged
7. **Layout is flex or grid** — `position: absolute` is only for a real superposition (see below)

---

## Tokens

All tokens are declared in `:root` at the top of the main stylesheet: a
primary, secondary and tertiary palette with light/dark variants, a neutral ramp
(`--color-neutral-50` … `-900`) and semantic colours (`--color-text`,
`--color-background`, `--color-border`, …); spacing `--spacing-xs` … `-3xl`;
font families, sizes `--font-size-xs` … `-6xl`, weights and line heights;
shadows, radii, transitions and `--container-max`. Every name is in
[references/tokens.md](references/tokens.md) — read it when writing the `:root`
block or deciding which token a value maps to. **The names and the scale are the
contract; the values there are placeholders.** Every colour and font comes from the
client's brand or the demo's own `:root`, never from the sample palette.

**Every** color, spacing, font size, shadow, radius, and transition value in CSS rules MUST reference a token. Never hardcode values — outside transcription mode (Principle 4).

```css
/* CORRECT */
.hero__title {
    font-family: var(--font-family-secondary);
    font-size: var(--font-size-4xl);
    color: var(--color-text);
    margin-bottom: var(--spacing-lg);
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

## BEM Naming

Every class is `.block__element--modifier`. Worked blocks (a hero, a button family) are in
[references/patterns.md](references/patterns.md).

- Use lowercase with hyphens inside block/element names: `.service-card__title` (not `.serviceCard__title`)
- Maximum two levels: `.block__element` (never `.block__element__subelement`)
- If nesting is needed, create a new block: `.card__header` contains `.card-header__title`
- Modifiers are always on the block or element, never standalone

---

## CSS Reset

Every stylesheet opens with the reset in [references/reset.md](references/reset.md), right
after `:root`. Every selector in it is bare, and the two rules below are why it must stay
that way.

### Never scope a reset to a page or section class

A bare reset is safe: `img { height: auto }` scores (0,0,1), so any class on that image
beats it. Re-scope the same declarations to a page — `.page img { max-width: 100%; height:
auto }` — and the score becomes (0,1,1), which **outranks a single class on that same
`<img>`**: `.page-step__icon { height: 3.1875rem }` is (0,1,0) and loses. The image ignores
its own class and paints at its intrinsic size while the class sits in the stylesheet
looking correct.

The symptom is misleading — `getComputedStyle` returns the reset's value, the class
is visible in the DevTools rule list, and it reads as "my CSS is not loading".

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
— is (0,1,0), exactly like the other classes already on the element. A tie is decided by source
order, and a reset class defined after them **wins**:

```css
.btn--primary { color: var(--color-text-inverse); font-size: var(--font-size-lg); }
/* …later in styles.css… */
.btn-reset { color: inherit; font: inherit; background: none; border: 0; }
/* <button class="btn--primary btn-reset"> now paints in the inherited colour and size. */
```

Two ways out, in order of preference:

```css
/* 1. The reset has no weight, so every class on the element still wins. */
:where(.btn-reset) { color: inherit; font: inherit; background: none; border: 0; }

/* 2. Or reset the TAG, bare, alongside the other element resets — (0,0,1). */
button { font: inherit; cursor: pointer; border: none; background: none; }
```

Option 2 is what the reset already does, so turning a `<span>` into a `<button>` inside
this system carries no UA styling to neutralise. Reach for the class only where a
third-party stylesheet is the thing being overridden, and then measure the element's
computed `color`, `fontSize` and `getBoundingClientRect()` before and after the change — a
tie broken by source order is invisible in the rule list, where both declarations show as
applying.

---

## Delimiters

The stylesheet is divided into delimited blocks, one per concern and one per page section,
in this order: Variables, Reset, Typography, Layout, then one per section (Header, Hero, …,
Footer), then Utilities. Every delimiter has this exact form — twelve `=` on each side:

```css
/* ============ Section: Hero ============ */
.hero { ... }
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

`Template: basic` only. When a page has substantial unique styles (e.g., a pricing
calculator), give it a dedicated file beside `assets/css/styles.css` and enqueue it
conditionally:

```
assets/css/
├── styles.css      # Main design system (always loaded)
└── pricing.css     # Pricing page only
```

These files:
- Must still use the same tokens from the design system
- Are enqueued via `is_page_template()` in `functions.php`
- Should NOT duplicate base styles already in `styles.css`

---

## Consistency Between Demo and Theme

When building the demo HTML first and then converting to WordPress:

1. The `:root` tokens in the demo `<style>` block MUST match the theme `styles.css` exactly
2. All BEM class names in the demo MUST be preserved in the WordPress templates
3. The CSS from the demo is extracted into `assets/css/styles.css` with minimal changes (primarily removing the `<style>` tags)
4. Section ordering and naming must match

---

## Contours That Render the Same in Every Engine

Verification runs Chromium, plus Firefox on Linux when a build exists. Firefox on Windows
draws a 1px `border` with a `border-radius` with visible notches where each corner curve
meets the straight edge, and Linux Firefox does not reproduce it, so a static lint is the
guard:

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
  `box-shadow`: `box-shadow: 0 0 0 1px var(--color-primary), 0 2px 4px rgb(0 0 0 / .2);`.

### Search Inputs: One Clear Control, and It Is Yours

Chromium and Safari draw a native clear "×" inside `type="search"`; Firefox draws none. A
design that shows a clear affordance therefore needs a real `<button type="button">` that
empties the field and fires `input`, and the native one must be hidden, or Chromium shows
two:

```css
input[type="search"]::-webkit-search-cancel-button { -webkit-appearance: none; appearance: none; }
```

A design with no clear affordance still hides the native one, for the same parity reason.

### Run the contour lint

Run it after writing CSS — do not read it:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/css-contour-lint.mjs" <theme-or-demo-dir>
```

It needs Node, scans every `.css`, `.php` and `.html` file under the directory, and takes
`--rule thin-border|drop-shadow-ring|search-clear` to run one rule. Exit 0 = pass, 1 = a
line per finding, 2 = usage. Fix each finding and run it again until it exits 0.
`/wp-finalize` runs it over the theme and the demo once more before delivery.
