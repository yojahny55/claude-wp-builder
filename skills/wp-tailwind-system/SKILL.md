---
name: wp-tailwind-system
description: Tailwind v4 conventions for themes built from the __tailwind__ starter — the decision ladder for utilities vs @apply, @theme tokens, file layout, preflight, arbitrary-variant traps and what is forbidden. Use when writing or converting markup or CSS in a project whose template is tailwind (the wp-tailwind agent, /wp-section, /wp-header, /wp-footer, /wp-tailwindify).
user-invocable: false
---

# WP Tailwind System

Applies when the project's `.claude/CLAUDE.md` says `Template: tailwind`. For
`template=basic`, use `wp-css-system` instead — the two are mutually exclusive.

## Reference files

- [references/breakpoints.md](references/breakpoints.md) — naming the demo's
  breakpoints, and why a `max-width: N` becomes `N+1`. Read when converting a
  demo's `@media` queries or choosing a `max-*` variant.
- [references/components.md](references/components.md) — the card-footer
  `mt-auto` chain, and the starter's tabs, accordion and directory-filter modules.
  Read when a section has a row of cards, tabs, an accordion or FAQ, or a filter bar.
- [references/cross-engine.md](references/cross-engine.md) — the contours Firefox
  on Windows notches, and the one search clear control. Read when drawing a 1px
  outline, ring or field border, or a search input.

## Decision ladder

Applied per element, in order. Stop at the first rung that holds.

1. **Tailwind utility classes in the markup.** The default, always. A section
   whose styling is expressible as utilities produces no CSS file entry at all.
2. **Same utility group on ≥2 pages** → semantic class in `utilities/site.css`,
   defined with `@apply`.
3. **Repeated within a single page only** → semantic class in
   `components/<slug>.css`, defined with `@apply`.
4. **Raw CSS** (no `@apply`) only for what Tailwind cannot express: `@keyframes`,
   `clip-path`, exotic selectors, third-party plugin overrides.

"Repeated" means the same group appears 3+ times, or on 2+ distinct pages. A
group used twice inside one section stays inline.

## File layout

Exactly four directories are sanctioned under `assets/css/src/tailwindcss/`:
`base`, `components`, `layouts`, `utilities`. Never create a fifth.

The four are not all present in a fresh theme. Git cannot track an empty
directory, so the starter ships only the ones that already hold a file —
`layouts/` in particular is absent until something writes into it. Any of the
four may be created when the first rule that belongs there is written, in the
same step as that rule. Creating one of the four is not creating a new
directory; a fifth name is, whatever it holds.

```
main.css                  @import "tailwindcss"; @plugin; @theme{…}; then the @import list
base/                     resets and font-face
components/<slug>.css     one per page/template: home, contact, services, 404, search, blog
components/buttons.css    shared components
layouts/                  header, footer, sidebar — only when a layout needs @apply rules
utilities/site.css        utility groups repeated across ≥2 pages
utilities/wordpress.css   WordPress core class overrides
utilities/animations.css  animation helpers
```

## Never create an empty file

A `.css` file exists only once it holds **at least one rule**. Write the rule and
the file in the same step, and add its `@import` to `main.css` in that same step.
Never scaffold a file "to fill in later" — that is the exact bug this convention
replaced.

Import order in `main.css`: `base` → `components` → `layouts` → `utilities`.

Every `@import` also names its cascade layer, matching the directory: `base/` →
`layer(base)`, `components/` and `layouts/` → `layer(components)`, `utilities/` →
`layer(utilities)` — `@import "./utilities/site.css" layer(utilities);`. A file
imported with no `layer()` sits OUTSIDE every layer, and unlayered CSS beats
every layer regardless of source order or specificity (see "Unlayered CSS beats
`@layer utilities`" below): a component class's own `display` has outranked a
`hidden` utility this way, and a promoted utility group has outranked its own
`max-md:hidden` modifier for the same reason, in the same file. The starter's
own default imports already carry this; do the same for every file a later
step adds.

## Tokens

Colors and fonts live in the `@theme` block of `main.css`, injected by `/wp-init`:

```css
@theme {
  --color-primary: #3b82f6;
  --font-primary: "Inter", sans-serif;
}
```

Reference them as utilities — `bg-primary`, `text-primary`, `font-primary`. Never
redeclare a token in a `:root` block, and never hardcode a hex value that a token
already covers.

## Responsive

Mobile-first, using Tailwind's own prefixes. Never write a media query by hand.

```html
<div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3 lg:gap-8">
```

Converting a demo's media queries follows two rules, both in
[references/breakpoints.md](references/breakpoints.md): declare the widths the demo
switches at once, as named `--breakpoint-*` stops in `@theme`, and never ship
`max-[<n>px]:`; and a demo's `max-width: Npx` becomes `N+1`, because Tailwind's
`max-*` is exclusive where CSS `max-width` is inclusive. Read it before converting
any `@media` query.

## `@apply` idiom

```css
/* components/home.css */
.home-hero {
  @apply relative flex min-h-screen items-center justify-center bg-dark text-light;
}

.home-hero__title {
  @apply text-4xl font-bold tracking-tight md:text-6xl;
}
```

The class name still scopes under the section's `--block` name so parallel
section agents cannot collide on a selector.

## Preflight

`@import "tailwindcss"` brings Preflight, Tailwind's own reset. It replaces the
browser's default stylesheet, so a theme whose every declaration was
translated correctly still does not render like the plain-CSS demo it came
from. Measured in a browser at six widths, on a faithful conversion of a
three-page demo:

| Element | Browser default | Under Preflight | Measured effect |
|---|---|---|---|
| `<button>` | `Arial 13.33px`, normal | inherits — `system-ui 16px/25.6px` | nav toggle grew |
| `<img>` | `display:inline; max-width:none` | `display:block; max-width:100%` | service card 197.9px → 190.7px |
| `<p>` | UA margin `14.4px` | `margin: 0` | footer column 71.04px → 56.8px |
| `<a>` | `text-decoration: underline` | `none` | logo link lost its underline |
| page | — | — | total height 1130.21px → 1108.78px |

The table above is every case where Preflight CHANGES the UA default. `cursor`
is the opposite case, and it is the one that has actually shipped broken:
Preflight does not touch it at all, so `<button>` stays on the UA default,
which is `default`, not `pointer`. A demo's own reset commonly restores the
hand with `button { cursor: pointer }`, and that line is not "covered by
Preflight" in either direction — dropping it as redundant removes the only
thing setting it. Carry it, scoped past a literal `<button>` to the other
controls a demo's clickable surface usually includes: `summary`,
`[role="button"]`, `[role="option"]`, `[role="tab"]`, and a form's
`input[type="submit"|"button"|"reset"]` (Contact Form 7 and WordPress's own
comment form render their submit this way, and `button { cursor: pointer }`
alone never reaches it). Pair it with `:disabled` / `[aria-disabled="true"] {
cursor: default }` when the demo's reset does.

Two consequences:

1. Where the demo leaned on a UA default, re-add it explicitly as a utility on
   the element — `inline`, `max-w-none`, `my-[0.9em]`, `underline`. The demo
   never declared these, so nothing in its CSS tells you they are load-bearing;
   only the rendered comparison does.
2. Fix the element, not the baseline. A reset of your own in `base` that undoes
   Preflight globally gives the theme two competing resets and moves every
   later section.
3. A reset rule converts **declaration by declaration**, never as a whole.
   "Preflight covers it" is a judgement about one property, not about the rule
   it sits in — a six-declaration `button { … }` reset where Preflight covers
   five is not "covered", and dropping the whole rule drops the sixth
   (`cursor`, most often) along with it.

## Bare element selectors

A demo stylesheet reaches elements no class covers — `a { color: … }`,
`h1, h2, h3 { … }`, `body { … }`, `*, *::before, *::after { … }`. Each carries
real declarations and none has a class to convert.

- Default: **distribute**. Put the declarations, as utilities, on every element
  the selector actually reaches. `body { … }` is the same operation with one
  target: the `<body>` tag's own `class` attribute.
- Exception: keep it as a rule in `base` when it reaches markup the demo does
  not contain (WordPress-generated output, plugin markup), or when it is a
  global declaration no per-element utility can carry.
- **Not an exception: a bare selector Preflight already covers.** `*, *::before,
  *::after { box-sizing: border-box }` and `img { max-width: 100%; display:
  block }` read like the "global, no utility can carry it" case above, but
  Preflight (imported by `@import "tailwindcss"`) already sets both, inside its
  own `base` layer. A hand-written second copy has shipped in this exact shape
  and cost real damage: a button's declared box was read as its OUTER box
  instead of its content box and rendered at a fraction of its design size, and
  a slider arrow deliberately overhanging its button got clamped to the
  button's width. Diff a bare selector against Preflight's own coverage
  (below) before keeping it — a declaration Preflight already sets is dropped
  entirely, never duplicated, even inside `base`.

**A bare selector is dead only when every element it matches already carries a
class that sets the same property — check the elements, not the stylesheet.**
Enumerate the matches in the markup and read each `class` attribute. "Every
`<a>` has a class" is exactly the reasoning that has already shipped a defect
here: one logo link carried no class, so `a { color: var(--color-brand) }` was
dropped and that anchor rendered in the body colour.

### A kept reset goes in `:where()`, or it outranks the classes it was meant to serve

A reset kept as a scoped rule brings a type selector with it, and a type selector
is not free. `.page img { max-width: 100%; height: auto }` scores (0,1,1) — one
class and one element — while a single class **on that same `<img>`**, say
`.page-step__icon { height: 3.1875rem }`, scores (0,1,0). The reset wins. Every
image the reset covers silently ignores the height its own class sets and paints
at its intrinsic size, and nothing about the class looks wrong: it is present,
spelled correctly, and in the compiled stylesheet.

That is a slow bug to find. `getComputedStyle` reports the reset's value, the
class sits right there in the DevTools rule list, and the symptom reads as "my CSS
is not loading" for as long as it takes to compare the two specificities. It cost
a full debugging detour once — on `height`, on images exported at 3×, so they
painted at triple the design size.

Write the reset so it contributes nothing:

```css
/* :where() is always (0,0,0), so any class on the element beats it. */
:where(.page) img { max-width: 100%; height: auto; }
```

The rule generalises past resets: **when a rule exists to be overridden, put its
selector in `:where()`.** Raising the override instead is a race you keep
re-running; lowering the thing meant to be overridden ends it.

## Tailwind v4, not v3

The starter installs Tailwind `^4.1`. Four differences bite, and the v3-shaped
answer to each is wrong in a way that still compiles:

- **Gradient direction utilities are `bg-linear-to-r`** (v4), not
  `bg-gradient-to-r` (v3).
- **The built-in palette is OKLCH**, so its hex values are not v3's: `gray-300`
  is `#d1d5dc` where a pre-v4 demo typically declared `#d1d5db`, while
  `gray-200` happens to be identical. The class name cannot tell you which case
  you are in, so the rule is **exact match or arbitrary value**: use a scale
  name only when its value equals the declared value byte for byte, otherwise
  keep the demo's literal (`border-[#d1d5db]`). A value that came from a
  `:root` custom property is a token — map it into `@theme` and reference it by
  name instead.
- **Gradients interpolate in OKLab.** `linear-gradient(90deg, rgba(0,0,0,.6),
  rgba(0,0,0,.1))` compiles to `oklab()` stops whose midpoint differs from the
  demo's sRGB ramp. That is correct v4 output; do not chase the difference with
  extra stops.
- **`transition-colors duration-200` is not `transition: background-color .2s
  ease`.** It animates ten properties on `cubic-bezier(0.4, 0, 0.2, 1)`. When
  the demo named one property and `ease`, keep both:
  `transition-[background-color] duration-200 ease-[ease]`.

## Arbitrary variants fail silently — four ways

Everything in this section compiles without an error and produces markup that
looks almost right. Assume none of it works until you have seen the selector in
the built CSS.

### `_` inside an arbitrary variant is an escaped SPACE

Tailwind reads `_` in `[...]` as a space, so a BEM class written literally turns
into a descendant combinator that matches nothing:

| Written | Compiles to | Matches |
|---|---|---|
| `[&.pager__page--current]:bg-brown` | `.pager page--current` | nothing |
| `group-[.menu__item--current]/m:font-bold` | `.menu item--current` | nothing |
| `has-[.select__field:focus]:ring` | `.select field:focus` | nothing |

Escape both underscores: `[&.pager\_\_page--current]:bg-brown`.

This is the single most expensive defect in this plugin's history — one project
shipped 22 of them, and three were focus indicators that had **never once
appeared**, an accessibility hole rather than a cosmetic one. Any BEM demo
converted to Tailwind will produce them by the dozen. Never fix one instance;
sweep the whole theme for the pattern (see **Verify**).

### Quotes inside an arbitrary variant truncate the class

`has-[[aria-expanded="true"]]:bg-primary` sits inside `class="…"`, so the HTML
parser — and Tailwind's scanner — see the class end at the first inner `"`. The
rule is emitted for a class that never existed. An attribute selector takes an
unquoted identifier: `has-[[aria-expanded=true]]:bg-primary`.

### Unlayered CSS beats `@layer utilities`

In v4 every utility lives in `@layer utilities`, and **unlayered CSS wins over
any layer** regardless of specificity. A base rule imported outside a layer
therefore overrides the markup: `a{text-decoration:none}` beats
`hover:underline`, `.icon-*{width:1em}` beats `size-*`, a body `letter-spacing`
beats `tracking-*`. Import the theme's own base and component files INTO a
cascade layer. The same rule explains third-party plugin stylesheets (Contact
Form 7, Newsletter): they are unlayered, so they beat every theme rule no matter
how specific — dequeue and reproduce, do not try to out-specify them.

This is not only a "reset" concern — every hand-written CSS file in the theme
has the same exposure, because a plain `@import "./file.css";` with no
`layer()` leaves the WHOLE file unlayered, not just the rules that look like a
reset. It has shipped twice in the same shape: a shared button component's own
`display: inline-flex` outranked a `hidden` utility placed on the same element
elsewhere, and — the same file, months later — a promoted "reveal on mobile"
class outranked its OWN `max-md:hidden` modifier written right there in the
markup, because the utilities file holding it carried no `layer()` either. Two
rules follow directly:

1. **Diff a carried-over reset against Preflight, declaration by declaration,
   before deciding what survives.** What Preflight already sets is dropped
   entirely — not kept, not duplicated, even inside a layer (see "Bare element
   selectors" above). What survives goes in `base/reset.css`, imported
   `layer(base)`.
2. **Every hand-written `components/`, `layouts/` and `utilities/` file is
   imported with its matching `layer()`** — see "File layout" → "Never create
   an empty file". This is true of the file on day one and stays true of every
   rule added to it later; a file that started layered does not need
   re-checking each time something is appended to it, but a NEW file's
   `@import` line does.

A file left deliberately unlayered must say why in a comment beside its
`@import`, the way the exception below already has to.

The exception is a document-level at-rule such as `@view-transition`, which is
not a style rule and has no business in the cascade: import it unlayered.

### Tailwind must be told where the templates are

v4 discovers sources by walking up from the stylesheet to the nearest git root.
A WordPress theme sits under `wp-content/themes/`, so that walk routinely stops
short of the theme's PHP and **every utility in the markup compiles to nothing**.
The starter's `main.css` declares `@source` explicitly. If you move the
stylesheet, move the `@source` paths with it.

## Fixed dimensions break in the second language

A demo is drawn in one language. `h-[29.25rem]` on a card, `w-[10.9375rem]` on a
button, `w-[218px]` on a pill: each is exactly right in the source language and
clips or strands whitespace in the other. In a bilingual theme:

- a box that contains text gets **`min-h-`**, never `h-` — a short card keeps the
  approved height, a long one grows;
- a control sized to its label gets **`w-fit`** plus a `min-w-` at the design's
  width — the source language lands on the frame to the pixel, a longer label
  pushes past it;
- a free-text ACF value never gets a fixed box at all.

Check every fixed dimension against the longest string the field can hold before
the second language exists, not after.

## Cards and the starter's widgets

A row of cards pins its footer with `mt-auto` at the end of a `flex flex-col h-full`
chain the template must keep, and tabs, accordions and directory filters come from
the starter's modules with no script of their own. Both contracts are in
[references/components.md](references/components.md) — read it before writing a
card row, tabs, an accordion or FAQ, or a filterable directory.

## `absolute` is for superposition, not for layout

A mockup's `x`/`y` is where an element fell in one frame at one width — not the
layout, and the weakest hint in the file. Converted into
`absolute left-[600px] top-[116px]`, a section is exact on the designer's screen
and is not a layout anywhere else: an absolute box is out of flow, so nothing
pushes it and nothing makes room for it. In a WordPress theme every string comes
from the database and the second language is longer, so the first client edit
lands the button on top of the heading.

Build layout with `flex`/`grid` and a `gap`. `absolute` is earned only by a real
superposition — a badge on an image, a floating icon, a dropdown panel, an
`absolute inset-0` veil, `sticky`/`fixed` furniture, `sr-only`.

**The test:** does this survive if the content changes length or the viewport
changes? No → it is `flex`/`grid`. Yes, because the overlap IS the point →
`absolute` is right.

Read the mockup's offsets as relationships: 32px between two boxes is `gap-8`,
never `left-[632px]`; 64px from the container's edge is `p-16`, never
`top-[64px]`. A row of elements sharing a spacing is ONE flex container, not N
placed boxes. An `absolute` inherited from the source HTML during
`/wp-tailwindify` or `/wp-tailwind-migrate` is not a value to preserve — rebuild
it unless it passes the test.

## `.btn` is already taken

The starter ships `components/buttons.css` with its own `.btn`, and a demo's
button group usually earns a class of its own at rung 2 or 3. Two sanctioned
files defining one selector is a silent conflict — the later `@import` wins.
Never write a second `.btn`. Either adopt the starter's `.btn` where the demo's
values match it, or give the demo's group the section's block name
(`.hero__btn`, `.btn--<block>`), which the block-scoping rule requires anyway.
Read `components/buttons.css` before writing any button class.

## Forbidden

- `assets/css/styles.css` — that is the `template=basic` output surface. Never write it.
- BEM-with-custom-properties authoring (`.block__element` + `var(--x)` from `:root`). That is `wp-css-system`'s job, not this one.
- A `:root { --… }` block. Tokens belong in `@theme`.
- Any directory under `assets/css/src/tailwindcss/` other than `base`,
  `components`, `layouts` and `utilities`. Never create a fifth. (Those four are
  governed by **File layout** above, not by this rule.)
- An empty or comment-only `.css` file.
- A `<style>` block or a static `style=""` attribute in a PHP template. (Dynamic
  values driven by an ACF field — e.g. a background image URL — are the one
  exception.)
- Hand-written `@media` queries.
- `absolute` with an arbitrary `left-[…]`/`top-[…]` on an element that overlaps
  nothing — that is a `flex`/`grid` row written as coordinates (see above).

## `hidden` is two different things

Tailwind's `hidden` utility is `display: none`. HTML's `hidden` ATTRIBUTE is a
separate mechanism, and it is the one JavaScript toggles (`el.hidden = false`).
Put both on the same element and the element never appears: clearing the attribute
leaves the class, and the class still says `display: none`.

Anything a script shows and hides — a status line, a live region, a panel — is
hidden with the ATTRIBUTE alone. Never with the utility, and never with both.

```html
<!-- wrong: the script clears the attribute, the class keeps it invisible -->
<p class="newsletter__status hidden …" hidden></p>
<!-- right -->
<p class="newsletter__status …" hidden></p>
```

The same applies to any class that is really a state (`opacity-0`,
`pointer-events-none`): pick ONE mechanism per element and let the script own it.

## Contours and search inputs

A 1px contour on a light background is an inset box-shadow, never a `border`, and a
search field has exactly one clear control, which is yours. Both rules are in
[references/cross-engine.md](references/cross-engine.md) — read it before drawing an
outline button, a ring, a focus or error border, or a `type="search"` field.

## Verify

Run these, in order, once the theme's templates are written — the command that dispatched
the section agents runs them, not an agent mid-walk, where a half-built theme fails them by
construction (`agents/wp-tailwind.md`). The scripts ship with the
plugin and the working directory is the user's project, so every path is rooted at
`${CLAUDE_PLUGIN_ROOT}`; a bare relative `bin/…` path resolves to nothing there and exits
127. The two `.mjs` checks need Node.

1. **Compile.** `bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>`. Steps 2
   and 3 read the compiled `assets/css/dist/main.css`: without it the convention check skips
   its markup rule and the class check prints `SKIP classes`, and both exit 0 having checked
   none of the markup.
2. **Run the checks.**

   ```bash
   # The convention: four directories, no empty or unimported file, no <style>. Exit 0 = PASS, 1 = FAIL.
   "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh" <theme-dir>

   # Every utility-shaped class exists in the compiled CSS, and no HTML entity sits inside
   # an arbitrary variant — the silent failures described above. Exit 0 = PASS, 1 = FAIL, 2 = usage.
   node "${CLAUDE_PLUGIN_ROOT}/bin/theme-template-check.mjs" <theme-dir>

   # Contours Firefox on Windows notches, and a second search clear control. Exit 0 = PASS, 1 = FAIL, 2 = usage.
   node "${CLAUDE_PLUGIN_ROOT}/bin/css-contour-lint.mjs" <theme-dir>

   # Unescaped BEM underscores inside arbitrary variants — must print nothing.
   grep -rnE '\[[^]"]*[a-z0-9]__[a-z]' --include='*.php' <theme-dir>

   # Quotes inside an arbitrary variant — must print nothing.
   grep -rn '\[\[[a-z-]*="' --include='*.php' <theme-dir>
   ```

3. **Fix and repeat.** Fix every finding, recompile (step 1) and rerun step 2 until every
   script exits 0 and both greps print nothing. Stop after three rounds and report what is
   still failing rather than looping.
