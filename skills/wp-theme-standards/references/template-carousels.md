# wp-template — Carousels

The `wp-template` agent reads this when a section you build has a carousel, slider or scrollable strip with dots and/or arrows.

## Carousels (JS you author for a section)

A carousel's controls are correct only relative to how much the strip can actually scroll,
and that changes with the real content count — which the demo's mock cards never show,
because a demo always carries enough cards to overflow. Whenever a section script builds a
scrollable strip with dots and/or arrows:

- **Hide the controls, don't disable-and-leave-them, when the strip cannot move.** Compare
  `scrollWidth` to `clientWidth` on the scrolling element; when it cannot overflow (the real
  record count fits the viewport, which routinely happens with seeded content — three news
  posts, four team members — where the demo showed six or eight), set `hidden` on the arrows,
  the dots AND their wrapper. `hidden`, not `opacity:0` or a disabled state: a dimmed but
  present control reads as "temporarily unavailable, try again," and a strip that will never
  gain more content is never coming back. A "disabled button has no pointer cursor" report is
  usually this working correctly, not a missing `cursor:pointer` — verify against `hidden`
  before treating it as a CSS bug.
- **Dot count is `Math.round(maxScroll / step) + 1`, clamped to the number of cards.**
  `Math.ceil` turns a sub-pixel width or a scrollbar gutter (a ratio like 2.004 instead of a
  clean 2) into an extra dot nothing stops on. Whatever the arithmetic produces, a strip
  cannot have more stops than it has cards — clamp to that count as a hard ceiling.
- **Dots and arrows live OUTSIDE the element that scrolls**, never as a child of the
  `overflow-x-auto` box. A control placed inside the scrolling box is itself part of the
  scrolled content: it renders fine on the first view and slides out of sight as soon as a
  visitor moves the strip.
- **Every card inside the scrolling element is `relative`** (the strip's direct children,
  e.g. `<li class="relative ...">`). `overflow-x: auto` clips only the descendants whose
  containing block is the strip or something inside it. A `position: absolute` box in a card
  with no positioned ancestor below the strip (a `screen-reader-text` new-tab notice, a
  badge, a stretched link) is laid out against a container *above* the strip. The strip
  never clips it, and each off-screen card's copy stretches the whole document sideways at
  every width. A 1px screen-reader span shows in no screenshot, so check the document
  itself at a desktop and a phone width:
  `document.documentElement.scrollWidth <= document.documentElement.clientWidth`.
- **A mirrored icon (a prev arrow, typically) uses `transform` consistently across its
  states.** In Tailwind v4, `-scale-x-100` writes the `scale` CSS property, not `transform` —
  so a hover/focus rule that still sets `transform: translateX(...)` on the same element
  REPLACES the mirroring instead of composing with it, and the icon flips back to unmirrored
  on hover. Either keep every state on `scale`/`translate`/`rotate` (which compose with each
  other in v4) or write the mirror as part of the same `transform` value the hover state uses
  — never mix the two systems on one element.
- **If the starter theme ships a shared carousel module** (a `carousel.js` or equivalent used
  by more than one section), fix the defect THERE, not by patching around it in the section
  that found it — every other carousel on the site has the same bug and will surface it later
  if the fix stays local.
