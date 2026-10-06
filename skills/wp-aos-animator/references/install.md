# Installing AOS — Phases 2 to 4

From the `wp-aos-animator` skill. Read this only when the Phase 1 audit finds AOS missing
or half-installed; run each phase whose piece is missing, in order, and stop on the first
failure.

## Contents

- Phase 2: Install
- Phase 3: Enqueue
- Phase 4: Initialize — the two seams `AOS.init()` leaves, the init module, the
  reduced-motion CSS

## Phase 2: Install

Download AOS 2.3.4 into `assets/vendor/aos/`. This needs `curl` and network access. `-f`
makes a 404 fail instead of saving GitHub's error page as `aos.js`, and `test -s` stops the
pipeline on an empty file:

```bash
mkdir -p <theme>/assets/vendor/aos
curl -fsSL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.js"  -o <theme>/assets/vendor/aos/aos.js
curl -fsSL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.css" -o <theme>/assets/vendor/aos/aos.css
test -s <theme>/assets/vendor/aos/aos.js && test -s <theme>/assets/vendor/aos/aos.css && echo AOS-OK
```

No `AOS-OK` line means the install failed: stop and report, never continue to Phase 3.
If Phase 1 found AOS already installed elsewhere in the theme, use that path instead.

## Phase 3: Enqueue

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

If AOS JS is already enqueued but CSS is missing, add just the CSS line right before the JS
line. Put them together with a `// AOS` comment.

## Phase 4: Initialize

`AOS.init()` alone leaves two seams that only show up after the entrance has already run
once, so a quick visual check of the first load will not catch them:

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

Add a dedicated module. In the starter that is `assets/js/src/aos.js`, imported by
`assets/js/src/index.js` and called beside the other init calls there; `npm run build` then
rebuilds the bundle. In a jQuery-based theme, wrap the body in `$(document).ready(...)`
instead of exporting it:

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

Add the reduced-motion escape hatch to the theme's animation CSS — in the starter,
`assets/css/src/tailwindcss/utilities/animations.css`, compiled by
`bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme>`. `AOS.init()`'s own `disable`
option stops new entrances from triggering, but does not undo the starting `opacity: 0` /
`transform` that `aos.css` already applied to every `[data-aos]` element before that check
runs:

```css
@media (prefers-reduced-motion: reduce) {
  [data-aos] {
    opacity: 1 !important;
    transform: none !important;
    transition: none !important;
  }
}
```
