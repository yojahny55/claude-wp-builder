# Cross-Engine Contours

From the `wp-tailwind-system` skill: drawing that renders the same in Chromium,
Safari and Firefox on every platform.

## Contours that render the same in every engine

Verification runs Chromium, plus Firefox on Linux when a build exists. Neither shows what
Firefox on Windows does to a thin rounded contour: a 1px `border` with a `border-radius`
draws visible notches where each corner curve meets the straight edge, on exactly the
outline buttons and ringed icon links a design is full of. Linux Firefox does not reproduce it,
so `${CLAUDE_PLUGIN_ROOT}/bin/css-contour-lint.mjs` is the guard (SKILL.md § Verify runs it;
`/wp-finalize` runs it again):

- **A 1px contour on a transparent or white/near-white background is a box-shadow**, never a
  `border`: outline buttons, focused and error fields, ringed icon links. Write
  `border-0 shadow-[inset_0_0_0_1px_var(--color-primary)]`; in CSS,
  `box-shadow: inset 0 0 0 1px <color>`. The shadow takes no layout
  space, so the box loses the 1px per side the border had: add it back to the padding
  (`px-[17px] py-[9px]` for `px-4 py-2`) and measure the box before and after, it must not
  change. A border on a solid fill, a card or a divider is fine.
- **Never `drop-shadow-*` on a bordered rounded ring.** The filter follows the anti-aliased
  edge and picks up the same corner artifacts. Stack the ring and the shadow in one
  `box-shadow` instead.
- **One search clear control** (below).

### Search inputs: one clear control, and it is yours

Chromium and Safari draw a native clear "×" inside `type="search"`; Firefox draws none. A
design that shows a clear affordance therefore needs a real `<button type="button">` that
empties the field and fires `input`, and the native one must be hidden, or Chromium shows
two:

```css
input[type="search"]::-webkit-search-cancel-button { -webkit-appearance: none; appearance: none; }
```

A design with no clear affordance still hides the native one, for the same parity reason.
