# Taste floor

Adapted from nateherkai/scroll-craft (MIT).

Read before writing markup, not after. Build without a checklist announcement.

Everything here checks the rendered result, not the intention. "I used the
spacing scale" is not evidence; the computed value is.

---

## Spacing

Rhythm comes from contrast between tight and generous, never one value
repeated until everything weighs the same. If you cannot point to which
intervals are tight and which are the breaks, the page has no rhythm.

- Use a 4px-base scale (`--space-1` through `--space-11`). A 4-base gives
  useful middle steps an 8-only scale misses.
- **More space above a heading than below it.** The gap belongs at the
  boundary between sections, not inside a heading-and-body pair. Getting this
  backwards is the single most common spacing error, and it makes the page
  read as a list.
- Section padding is fluid (`--space-section`). A phone should not inherit
  desktop air; 8rem of padding on a 375px screen is a scroll tax.
- Group by proximity before reaching for a container. If you added a border
  to show two things are related, the spacing was wrong first.
- Gutters scale with viewport (`--space-gutter`). Full-bleed media goes edge
  to edge; text never does.

**Optical, not mathematical.** Equal computed padding around an irregular
shape produces uneven visual weight and looks wrong. Correct against the
render, not the number.

---

## Typography

- **Two families maximum.** Display carries voice, text carries prose. A
  third is a costume.
- **Tracking tightens as size grows.** A typeface set at 6rem with default
  tracking reads loose and amateur. A ramp handles this: `--font-track-tight`
  on display, `--font-track-normal` on body. This is optical correction, not
  decoration.
- **Body measure 45 to 75ch.** `--font-measure` at 62ch. A full-width
  paragraph on a 1600px monitor is unreadable regardless of font size.
- **Line height is inverse to measure.** Wider lines need more leading.
  Display sits at 0.94 to 1.06, body at 1.6.
- **Light text on dark needs compensation on three axes**: slightly more line
  height, a touch more tracking, one step more weight. Dark-mode type set to
  light-mode metrics looks thin and blurry, and this is why.
- `text-wrap: balance` on headings, `pretty` on body. Free, and it removes
  the orphan word that makes a headline look accidental.
- Display size maxes around ~6rem outside a genuine hero moment. Bigger is
  not more confident.
- **Step the hero down one rung below ~700px.** `--font-t-4xl` floors at
  3.4rem, which is a *desktop* floor: 390px wraps a normal hero headline into
  six lines. `--font-t-2xl` on the hero inside a phone media query fixes it.
  The portrait crop of the image is covered in devices.md; the portrait crop
  of the type is missed more often.

**Font choice.** Inter is a discouraged default: it is the most-used face in
AI-generated pages and reads as a non-decision. Reach first for Geist,
Archivo, Outfit, Satoshi, Cabinet Grotesk, or the brand's own face. Inter is
correct when the brand asks for neutral, or when the brief is accessibility
first.

**Serif is not a synonym for premium.** "It feels editorial" is not a reason.
Use one only when the brand names it, or when the work is genuinely
editorial, luxury, or heritage and you can say why *this* serif fits *this*
brand.

**Emphasis inside a headline** uses italic or bold in the same family.
Dropping a serif word into a sans headline for visual interest is amateur.

---

## Colour

- **Six roles, one accent.** Canvas, surface, ink, ink-soft, accent,
  accent-ink. The accent owns a region's role; scattered tiny accents are
  confetti. No warm-grey CTA exception.
- On a page that hard-cuts between **light and dark grounds**, one accent
  physically cannot clear 4.5:1 on both from a single stop. The page carries
  a two-stop accent: one hue, two lightnesses, keyed per ground family and
  redefined per section alongside ink. Still one accent per ground, still one
  hue per page. Two different hues is not what this licenses.
- **Secondary text tinted, never flat gray.** Derive it from the foreground
  and surface hue. `#888` on a warm dark ground looks dirty.
- **No pure black.** `#000` has no air in it. Off-black is the minimum.
- Contrast, measured on the render: body ≥4.5:1, large text ≥3:1, controls
  and focus indicators ≥3:1.
- Colour drift keeps the whole page in one theme family. See devices.md §10.

**Redefining `--color-ink` on a subtree does not re-ink text under it.**
`color` is inherited by its *computed value*, so text whose `color` already
resolved on `<body>` keeps body's ink no matter what a section redefines the
token to. Every page that inverts ground mid-page hits this, and it fails
silently: the inverted section renders bone type on concrete at 1.15:1 while
a harness that correctly classifies the line as light-on-dark grades it in
the wrong direction. The fix is one declaration on the same subtree:

```css
.section--light { --color-ink: #14110C; --color-ink-soft: #4A443A; color: var(--color-ink); }
```

Restate `color` wherever you restate the token. The same applies to any
other inherited property driven from a token on a subtree.

**The premium-consumer palette trap.** Warm cream background, brass or clay
accent, espresso near-black text is the default reach for every artisan,
food, and wellness craft brief, and it makes every brand look identical.
Off-black over cream-and-brass is fine only when the brand names those
colours.

**The AI-purple trap.** Violet-to-blue gradients, neon glow, glowing buttons.
Not unless the brand asks.

---

## Text over media

"No full-frame overlay" is the rule. Here is what to do instead, because the
rule on its own sends people to a slightly weaker full-frame overlay.

There are three shapes, and which one is right depends only on where the
copy sits:

1. **A corner** density, sized to the copy block. `.scrim--lead` /
   `.scrim--trail`. Right when copy is anchored to a corner on a wide
   screen. An edge gradient darkens a whole band across the frame to cover
   one corner; a corner gradient puts density where the text is and leaves
   the photograph alone.
2. **A band**, `.scrim--band`, transparent above roughly 58%. Right whenever
   copy spans the full width of the frame, which is what *both* corner
   anchors become below 860px. The engine already switches `.scrim--trail`
   to band there for exactly that reason.
3. **A column** density under the text column, on a section where copy holds
   one side and a full-bleed image the other. Leaves the other half of the
   frame untouched.

**`width` and `height` attributes are presentational hints, and come in
pairs.** The reference template ships every `<img>` with both, correctly, to
reserve the aspect ratio and stop the page reflowing as media arrives. The
common trap is overriding only one in CSS, leaving the other resolving to the
attribute's raw pixel value, so `width: 100%` on a 1920x1080 image inside a
narrow column renders it 1080px tall and pushes everything under it off the
fold. It looks like a layout bug three elements away from the cause.
**Override both or neither**, usually `width: 100%; height: auto`, or an
explicit height plus `object-fit: cover` when the frame's shape is fixed.

Above all three: when a photographic ground sits behind a text column,
**mask the image away from the text** rather than laying anything over it. A
`mask-image` or `clip-path` that ends where the column begins gives the type
a clean ground and gives the photograph its full contrast back, and it beats
any scrim.

**A scrim must not be a child of the text it protects.** A verification pass
that hides the copy element hides everything inside it, photograph frame
underneath included, so a `::before` on the copy block is hidden too and the
scrim is never measured. Put it in a sibling element. See verify.md.

Then measure it. A scrim tuned by eye routinely lands at 9:1 where 4.5:1 was
needed, which throws the photograph away for nothing, or at 2.8:1 on one
frame while the clip brightens under the copy. Both are invisible until the
harness reports the number.

---

## Depth

The depth axis separates a premium page from a styled document, and it is
not one property. Five tools, used together:

1. **Shadow offset and blur.** Real raised things cast light downward. A
   zero-offset coloured halo is decoration, not depth. Tint the shadow to
   the canvas hue; pure black shadows on a coloured ground look like dirt.
2. **Edge light.** A 1px top highlight (`--shadow-edge`) sells a raised
   surface better than any amount of blur; real lips catch light.
3. **Scale and blur with distance.** Things further away are smaller,
   softer, lower contrast. Parallax without this reads as sliding, not depth.
4. **Overlap.** One element crossing another's boundary establishes more
   depth than shadow. Free, and underused.
5. **Grain.** A flat dark ground bands on real displays. `.grain` at 4-5%
   opacity is the difference between "a dark page" and "a lit room".

Three elevation steps (`--shadow-e1/2/3`), no more. If everything is
elevated, nothing is.

---

## Cards

A card is a lazy container. Before using one, ask what it is doing that
proximity, a hairline, or space could not.

- **Never a grid of identical icon + heading + text cards as page
  structure.** The most recognisable AI-page tell there is.
- **Never nest cards.**
- **Never three equal columns of feature cards.** Use an asymmetric grid, a
  two-column zigzag (max two in a row), a rail, or plain type on space.
- If a multi-cell grid has an empty trailing cell, the grid was planned
  wrong. Reshape it; do not paste in a blank tile.
- Pick one corner-radius scale and hold it across the page. Pill buttons on
  a square-card page is broken, not eclectic.

---

## Motion

The scroll devices are the page's motion. Everything else stays small and
fast.

- `transform` and `opacity` only for anything continuous. `clip-path` is the
  sanctioned third, for wipes. Never animate width, height, margin, padding,
  top or left, never `transition: all`. Restrict continuous animation to
  transform and opacity only.
- `--motion-p` is the one new custom property this plugin introduces: a 0-to-1
  value published per section by the motion engine. It is the seam anything
  not covered by the device kit hooks into via `calc()`.
- **Never `ease-in` on UI.** It delays the moment the eye is already on.
  `ease-out` at 200ms feels faster than `ease-in` at 200ms.
- Built-in CSS easings are too weak. Use `--transition-ease-out`
  (`cubic-bezier(0.23, 1, 0.32, 1)`).
- **UI transitions under 300ms.** Hover 120-180ms, buttons 100-160ms. Scroll
  devices are exempt: paced by hand, not by duration.
- **Never `scale(0)`.** Enter from `scale(0.95)` plus `opacity: 0`. Nothing
  in the real world appears from nothing.
- Press feedback on anything pressable: `scale(0.97)` or `translateY(1px)`.
- Stagger group entrances 30 to 80ms. Longer feels slow.
- Gate hover motion behind `(hover: hover) and (pointer: fine)`.
- Every interactive element gets hover, focus-visible, active and disabled
  states. A page with only a resting state is half-built.
- **Focus-visible must be visible.** Themed accent, with offset.
- **Button text fits on one line at desktop.** A wrapped CTA is broken.
  Primary CTA labels are one to three words.
- **One label per intent.** "Get in touch" in the nav and "Let's talk" in
  the footer are the same button with two names. Pick one, use it
  everywhere.
- **Check button contrast.** White text on a light button, or a ghost button
  on a photo with no scrim, fails.
- Real copy, not lorem. Real names, not "John Doe". Real numbers or no
  numbers.
- **No invented statistics.** Fake precision (`4.1×`, `92%`, `48k`) is a
  legal and credibility liability, not a design element.

---

## States and content

Real copy, real names, real numbers or no numbers, in every state a
component can be in: empty, loading, error, populated. A component whose
empty state was never designed will be discovered in production, not review.

---

## Browser surfaces

The parts you did not draw still carry design, and this is the cheapest
signal that a page was built rather than assembled. It is also the step that
gets skipped most reliably.

Selection colour, caret colour, focus ring, scrollbar, underline offset and
thickness, tabular numerals in anything that counts or tabulates.

---

## The refuse list

Category defaults, not bans on principle. The brief's own words can earn
back any of them; reaching for one when the axis is free means you did not
decide.

**Structure**
- Identical cards as page structure. Nested cards. Three equal feature
  columns.
- The hero-metric template: big number, small label, supporting stats,
  accent.
- More than two consecutive image-left / text-right zigzag sections.
- The same layout family twice on one page.
- The split header: giant headline left, small explainer paragraph floating
  right.

**Labels**
- An eyebrow above a section heading. At most one per three sections.
- Section numbers (`01 / 06`, `002 · Capabilities`) unless the sequence
  itself is information the reader needs.
- Scroll cues: "scroll", "↓ scroll", "scroll to explore", animated mouse
  icons. Looking at the hero, they know.
- Decoration text strips (`BRAND. MOTION. SPATIAL.`) across the hero bottom.
- Locale, time and weather strips unless the brand is genuinely about place.
- Pills or tags overlaid on photos. Version stamps on a marketing page.

**Surface**
- Gradient text. Neon and outer glows. Hard offset zero-blur shadows outside
  a world that is actually neobrutalist.
- Glass blur as decoration rather than a specific effect.
- Coloured `border-left` above 1px on cards, callouts or list items.
- Monospace as a costume for "technical" rather than for code, data, labels.
- Emoji standing in for an icon system. Use a real icon library.
- Custom cursors.

**Content**
- Em dash anywhere visible. Period, comma, colon, parentheses.
- Div-built fake screenshots, fake dashboards, fake terminals.
- Text baked into a generated image. Real markup, always.
- Filler verbs: elevate, seamless, unleash, next-gen, revolutionize,
  supercharge.
- A hero that overflows the viewport. Headline max two lines, subtext max 20
  words, CTA visible without scrolling.
- More than four text elements in the hero. Trust logos, pricing teasers and
  micro-taglines move to their own section below it.

---

## Token source of truth

Tokens are declared once in `:root`, and the demo's `:root` block is the
source of truth copied verbatim into the theme's stylesheet, so a hardcoded
hex in a section is a defect.

---

## The squint test

Blur the page until detail is gone. You should still be able to name the
primary element, the secondary element, and the major groups, in order.

If everything greys into one even field, the problem is hierarchy, and no
amount of shadow, gradient or motion will fix it.
