---
name: wp-aos-animator
description: WordPress AOS animation installer — audits, installs, enqueues, initializes, and seeds Animate On Scroll on every visual element across all PHP templates. Use when the user asks to add scroll animations, AOS, fade-in effects, entrance animations, or "make elements appear on scroll" in any WordPress theme.
user-invocable: false
---

# WP AOS Animator

Automates AOS (Animate On Scroll) implementation in WordPress themes. Covers the full pipeline: audit → install → enqueue → init → animate.

## Phases

Run these in order. Each phase depends on the previous one succeeding.

### Phase 0: Read the motion decision — AOS is for plain builds only

Read two recorded decisions before touching the theme:

- `demo mode` in the project's `.wp-create.json`. An absent key means `plain`.
- `Template:` in the project's `.claude/CLAUDE.md`.

| Recorded | Do |
|---|---|
| `Template: cinematic` | **Stop.** The cinematic theme drives its own scroll engine (GSAP, ScrollTrigger, Lenis); AOS would be a second motion system on the same elements. Report it and change nothing. |
| `demo mode: craft` | **Stop and report.** A craft theme already ships GSAP and `motion.js` (`data-motion`) in its bundle. Continue only if the user explicitly confirms a second motion system. |
| `demo mode: plain` (or absent), `Template: tailwind` | Continue with Phase 1. |

### Phase 1: Audit

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

Report findings: what's present, what's missing, and the baseline count.

### Phase 2: Install (if missing)

If no `aos.js` / `aos.css` exists, download AOS 2.3.4 into `assets/vendor/aos/`. This
needs `curl` and network access. `-f` makes a 404 fail instead of saving GitHub's error
page as `aos.js`, and `test -s` stops the pipeline on an empty file:

```bash
mkdir -p <theme>/assets/vendor/aos
curl -fsSL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.js"  -o <theme>/assets/vendor/aos/aos.js
curl -fsSL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.css" -o <theme>/assets/vendor/aos/aos.css
test -s <theme>/assets/vendor/aos/aos.js && test -s <theme>/assets/vendor/aos/aos.css && echo AOS-OK
```

No `AOS-OK` line means the install failed: stop and report, never continue to Phase 3.
If Phase 1 found AOS already installed elsewhere in the theme, use that path instead.

### Phase 3: Enqueue (if missing)

In `functions.php`, inside the existing `wp_enqueue_scripts` callback and **before** the
main bundle's `wp_enqueue_script()`, add the two files. `PREFIX_URI` and `PREFIX_DIR` are
the theme's own constants — the starter's `__STARTER___URI` / `__STARTER___DIR`, which
`/wp-init` renames to the project prefix in uppercase (`KAIRO_URI`). Read the names from
the theme's `functions.php`; never paste a constant from another project, which is
undefined here and a fatal error on PHP 8:

```php
// AOS
wp_enqueue_style( 'aos-css', PREFIX_URI . '/assets/vendor/aos/aos.css', array(), filemtime( PREFIX_DIR . '/assets/vendor/aos/aos.css' ) );
wp_enqueue_script( 'aos-js', PREFIX_URI . '/assets/vendor/aos/aos.js', array(), filemtime( PREFIX_DIR . '/assets/vendor/aos/aos.js' ), true );
```

AOS has no dependency of its own — no `jquery`. Then make the main bundle depend on
`aos-js`, so WordPress always prints AOS first. Nothing else orders them: the starter
defers its bundle, and an AOS script enqueued after it, or deferred as well, can run after
the bundle — the init module's `if (!window.AOS) return;` then turns the whole setup into a
silent no-op. In the starter the bundle's dependencies come from `index.asset.php`:

```php
wp_enqueue_script( '<slug>-main', /* … */ array_merge( $asset['dependencies'], array( 'aos-js' ) ), /* … */ );
```

If AOS JS is already enqueued but CSS is missing, add just the CSS line right before the JS line. Put them together with a `// AOS` comment.

### Phase 4: Initialize (if missing)

`AOS.init()` alone leaves two seams that only show up after the entrance has already run
once, so a quick visual check of the first load will not catch them. Both were found by
testing a real build past its first scroll, not by reading the AOS docs:

1. **`aos.css` rewrites `transition-property`, `-duration` and `-delay` on every element that
   still carries `data-aos`, for as long as the attribute stays on it** — not just while the
   entrance plays. A card that lifts on hover, or a button that fades its background color,
   loses that transition (and inherits the entrance's timing instead) for the rest of the
   page's life, because the attribute is still there long after the entrance finished. Strip
   `data-aos`/`data-aos-delay`/`data-aos-duration` off each element once its own entrance
   settles, so `aos.css` stops matching it and the element's own classes govern its
   transitions again. `once: true` makes this safe — AOS never needs the attribute back.
2. **Measuring trigger points at `DOMContentLoaded` runs before web fonts and images have
   settled layout.** A block whose position moves once a font swaps in (or an image finishes
   loading) keeps AOS's stale, pre-reflow trigger point and can end up permanently below it —
   invisible, forever, because `once: true` will never re-trigger it once the page has
   scrolled past where AOS thought it was. Initialize on `DOMContentLoaded` (so the entrance
   can start as soon as possible) but call `AOS.refresh()` again on `load`.

Add a dedicated module (adjust the export style to the theme's existing JS — vanilla ES
module shown, wrap in `$(document).ready(...)` instead if the theme is jQuery-based) and call
it from wherever the theme's other init code runs:

```js
export default function aos() {
  if (!window.AOS) {
    return;
  }

  // Strip the attributes once an element's own entrance transition ends, so
  // aos.css stops rewriting its transition-property/-duration/-delay and the
  // element's own hover/interaction transitions apply again. `once: true`
  // means AOS never needs the attribute back.
  document.addEventListener('transitionend', (event) => {
    const el = event.target;
    if (event.propertyName === 'opacity' && el.classList?.contains('aos-animate')) {
      el.removeAttribute('data-aos');
      el.removeAttribute('data-aos-delay');
      el.removeAttribute('data-aos-duration');
    }
  });

  window.AOS.init({
    once: true,
    disable: () => window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  });

  // Two things need the page's full load, not DOMContentLoaded:
  const settle = () => {
    // a) AOS measured trigger points before fonts/images finished reflowing
    //    the layout — measure again now that they have.
    window.AOS.refresh();
    // b) AOS only fires once an element is ~120px inside the viewport, so
    //    whatever peeks above the bottom edge of the FIRST screen sits empty
    //    until the visitor scrolls. Reveal anything already on screen at once
    //    instead of waiting for a scroll that may never come. Above-the-fold
    //    elements still carry data-aos (for the fade itself) but are never
    //    skipped outright — see Phase 5's LCP guidance for how to keep this
    //    from delaying the LCP paint.
    document.querySelectorAll('[data-aos]:not(.aos-animate)').forEach((el) => {
      if (el.getBoundingClientRect().top < window.innerHeight) {
        el.classList.add('aos-animate');
      }
    });
  };
  if (document.readyState === 'complete') {
    settle();
  } else {
    window.addEventListener('load', settle, { once: true });
  }
}
```

Add the reduced-motion escape hatch to the theme's animation CSS — `AOS.init()`'s own
`disable` option stops new entrances from triggering, but does not undo the starting
`opacity: 0` / `transform` that `aos.css` already applied to every `[data-aos]` element
before that check runs:

```css
@media (prefers-reduced-motion: reduce) {
  [data-aos] {
    opacity: 1 !important;
    transform: none !important;
    transition: none !important;
  }
}
```

### Phase 5: Animate templates

Scan every `.php` template in the theme root and `template-parts/` directory. For each file:

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

**Animate these elements (when they lack data-aos):**
- `<h1>`, `<h2>`, `<h3>` — use `data-aos="fade-up" data-aos-duration="1000"`
- `<p>`, section descriptions — use `data-aos="fade-up" data-aos-delay="50" data-aos-duration="1000"`
- Buttons/CTAs — use `data-aos="fade-up" data-aos-delay="100" data-aos-duration="1000"`
- `<img>`, image wrappers — use `data-aos="fade-up" data-aos-delay="150"`
- Cards, grid items — use `data-aos="fade-up" data-aos-delay="<?php echo esc_attr( min( $index, 5 ) * 100 ); ?>"` when inside PHP loops
- Layout items, mosaics — use `data-aos="fade-up"` with staggered delays (100, 150, 200, 250...)
- Banner containers, CTA sections — use `data-aos="fade-up" data-aos-delay="200"`
- Footer columns, social icons — use `data-aos="fade-up" data-aos-delay="100"` with +100 increments per sibling

**Animation convention:**
| Element type | Animation | Typical delay |
|---|---|---|
| Hero titles, section headings | `fade-up` + duration 1000 | 0 |
| Subtitles, descriptions | `fade-up` + duration 1000 | 50 |
| Buttons, CTAs | `fade-up` + duration 1000 | 100 |
| Images, illustrations | `fade-up` | 150 |
| Cards (looped with $index) | `fade-up` | `min( $index, 5 ) * 100` |
| Layout grid items | `fade-up` | 100, 150, 200, 250... |
| Banner content | `fade-up` | 200 |
| Footer elements | `fade-up` | 100, 200, 300 |

### Edits approach

Work through templates one at a time. Use `Read` to see the file, then `Edit` with exact string matching. Make each edit atomic — one element at a time. Use unique surrounding context so the Edit tool finds the right match.

For `wp_get_attachment_image` calls that need animation, add data attributes to the 4th parameter array:
```php
// Before
echo wp_get_attachment_image($id, '', '', ['class' => '...']);
// After
echo wp_get_attachment_image($id, '', '', ['class' => '...', 'data-aos' => 'fade-up', 'data-aos-delay' => '100']);
```

### Parallelization

Phase 5 can be parallelized: spawn one agent per template file. Each agent gets a specific file path and the list of elements to animate from the audit. The main agent orchestrates and verifies.

## Verification

After all edits, run a quick sanity check:
```bash
grep -c "data-aos" <theme>/*.php <theme>/template-parts/*.php
```
Count should have increased from baseline (recorded in Phase 1).