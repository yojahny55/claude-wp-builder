---
name: wp-aos-animator
description: Installs AOS (Animate On Scroll) into a plain-mode WordPress theme and adds data-aos entrance animations across its templates — the library under assets/vendor/aos/, the functions.php enqueue, the init module, and the attributes in front-page.php and template-parts/. Reads demo mode and the Template line first and stops on a craft or cinematic theme, which already run GSAP and data-motion. Use when the user asks to add scroll, fade-in or entrance animations, install AOS or put data-aos attributes on a plain theme's sections, or fix AOS elements that never appear or a dropdown painted behind cards after its entrance. Run through /wp-aos-animator. Not for GSAP, ScrollTrigger or data-motion work (wp-demo-craft).
user-invocable: false
---

# WP AOS Animator

Adds AOS (Animate On Scroll) to a plain-mode WordPress theme: audit → install → enqueue →
init → animate. The phases run in order, and each depends on the previous one succeeding.

## Reference files

- [references/install.md](references/install.md) — Phases 2 to 4: the download, the
  `functions.php` enqueue and bundle dependency, the init module and the reduced-motion CSS.
  Read it only when the Phase 1 audit finds AOS missing or half-installed.

## Phase 0: Read the motion decision — AOS is for plain builds only

Read two recorded decisions before touching the theme:

- `demo mode` in the project's `.wp-create.json`. An absent key means `plain`.
- `Template:` in the project's `.claude/CLAUDE.md`.

| Recorded | Do |
|---|---|
| `Template: cinematic` | **Stop.** The cinematic theme drives its own scroll engine (GSAP, ScrollTrigger, Lenis); AOS would be a second motion system on the same elements. Report it and change nothing. |
| `demo mode: craft` | **Stop and report.** A craft theme already ships GSAP and `motion.js` (`data-motion`) in its bundle. Continue only if the user explicitly confirms a second motion system. |
| `demo mode: plain` (or absent), `Template: tailwind` | Continue with Phase 1. |

## Phase 1: Audit

Check if AOS is already present and initialized, and record the baseline:

```bash
find <theme> -path '*/node_modules' -prune -o \( -name 'aos.js' -o -name 'aos.css' \) -print
grep -n "aos" <theme>/functions.php <theme>/inc/*.php
grep -rn "AOS.init" <theme>/assets/js/
grep -c "data-aos" <theme>/*.php <theme>/template-parts/*.php    # the baseline Verification compares against
```

The starter's JavaScript is a wp-scripts bundle built from `assets/js/src/`, so the
`AOS.init` grep must reach that directory: a grep of `assets/js/*.js` alone never finds an
existing init, and a re-run then adds a second one.

Report what is present, what is missing, and the baseline count.

## Phases 2–4: Install, enqueue, initialize

Run each phase whose piece the audit found missing, exactly as
[references/install.md](references/install.md) gives it, and stop on the first failure —
Phase 5 on a theme with no library loaded animates nothing.

## Phase 5: Animate templates

Scan every `.php` template in the theme root and `template-parts/` directory. Work one
element at a time, each edit anchored on context unique to that element.

**Never animate an element that also needs a stacking context or a slide.** AOS's
`[data-aos^=fade]` rules put a `transform` on the element — a translate before the
entrance and `translateZ(0)` after it, plain `fade` included — and it stays until the
Phase 4 module strips `data-aos` (for the whole life of the page when that module is not
installed). A transform does two things that outlive the animation:

- It creates a **stacking context**. Any `z-index` inside the animated element only
  competes with its siblings, never with the rest of the page. An animated toolbar
  holding a dropdown is the classic case: the open menu has `z-20`, the toolbar has
  `z-index: auto`, so the menu paints under every card that follows the toolbar in
  the DOM. Animate it anyway only if you also give it an explicit `z-index` above
  what follows, and print that class in the template — not in an overridable class
  variable, where the next archive that overrides it silently loses the fix.
- It makes the element a **containing block** for its `position: fixed` and
  `absolute` descendants, and it rewrites `transition-property` to
  `opacity, transform` — so an element that slides on `translate` (a mobile drawer,
  an off-canvas panel) stops transitioning and jumps. Animate a wrapper INSIDE it
  instead, never the sliding element itself.

**Skip these elements:**
- `<html>`, `<head>`, `<body>`, `<meta>`, `<link>`, `<script>`, `<style>`, `<title>`
- Elements that already have `data-aos`
- Elements inside `<nav>` or `<header>` (they have their own animations)
- `role="presentation"` decorative elements
- Any ancestor of a dropdown, popover, tooltip or custom `<select>` menu, unless you
  also set an explicit `z-index` on it (see above)
- Anything that slides: off-canvas drawers, filter panels, anything transitioning
  `translate`
- Skip links (`<a class="skip-link">`)
- Screen reader text

**The above-the-fold LCP candidate (hero `<h1>`, hero image, page-title `<h1>` on an
archive/404/search) is not one more element to skip — animate it, with a fast plain `fade`
instead of the slower `fade-up` used elsewhere:**

```php
<h1 data-aos="fade" data-aos-duration="400" class="...">…</h1>
```

Skipping it outright reads worse than a small, deliberate cost: with `once: true` and the
Phase 4 module's on-load reveal, an above-the-fold element enters as soon as the page loads
rather than waiting for a scroll that may never come, so the page's first screen looks
animated instead of static against every section below it. `fade` (no translate, so the
element never moves) with a short duration keeps that cost small. It still carries
`translateZ(0)` until the Phase 4 strip, so the stacking-context rule above applies to it
too. This is a trade-off, not a rule to apply blindly: if a project's own LCP
budget cannot absorb it, skip the single LCP element and animate everything else around it
normally.

**Delays and durations are multiples of 50, from 50 to 3000.** `aos.css` styles
`data-aos-delay` and `data-aos-duration` through one attribute selector per value, and
it ships exactly those sixty values. Any other number matches nothing and is a silent
no-op — a delay of 20 animates with no delay at all. A loop's stagger is capped
for the same reason and because a grid that staggers for seconds reads as broken:
`min( $index, 5 ) * 100`.

Only AOS's own animation names exist. `fade-up` carries the upward slide; a name the
library does not define (a `fade-up-slow`, say) gets the fade with no movement. Make an
entrance slower with `data-aos-duration`, never with an invented name.

**Animate these elements (when they lack `data-aos`):**
- `<h1>`, `<h2>`, `<h3>` — use `data-aos="fade-up" data-aos-duration="1000"`
- `<p>`, section descriptions — use `data-aos="fade-up" data-aos-delay="50" data-aos-duration="1000"`
- Buttons/CTAs — use `data-aos="fade-up" data-aos-delay="100" data-aos-duration="1000"`
- `<img>`, image wrappers — use `data-aos="fade-up" data-aos-delay="150"`
- Cards, grid items — use `data-aos="fade-up" data-aos-delay="<?php echo esc_attr( min( $index, 5 ) * 100 ); ?>"` when inside PHP loops
- Layout items, mosaics — use `data-aos="fade-up"` with staggered delays (100, 150, 200, 250...)
- Banner containers, CTA sections — use `data-aos="fade-up" data-aos-delay="200"`
- Footer columns, social icons — use `data-aos="fade-up" data-aos-delay="100"` with +100 increments per sibling

For `wp_get_attachment_image` calls, add the attributes to the 4th parameter array:

```php
// Before
echo wp_get_attachment_image($id, '', '', ['class' => '...']);
// After
echo wp_get_attachment_image($id, '', '', ['class' => '...', 'data-aos' => 'fade-up', 'data-aos-delay' => '100']);
```

## Verification

1. Count the attributes and compare with the Phase 1 baseline:

   ```bash
   grep -c "data-aos" <theme>/*.php <theme>/template-parts/*.php
   ```

2. If the count did not rise for a template Phase 5 was meant to change, run Phase 5 once
   more on that file alone, then count again. Still unchanged: stop and report the file.
3. Walk the page, because every failure above shows only after scrolling:
   `/wp-demo-verify <url>`. A section that stays blank, a dropdown under the next card or a
   drawer that jumps is one of the traps in Phase 5.
