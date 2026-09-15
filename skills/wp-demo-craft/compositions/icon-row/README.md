# icon-row

**Role:** capability. Four short capability marks in a row — an icon, a name and
one line — under a two-line head.

**Port of:** none. The marks are drawn in the file, not a dependency.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: `reveal` on the block (stagger 60) plus
element motion in `section.css` — the head fades and rises, the four cards arrive
left to right, and each icon **draws itself on** with
`stroke-dasharray`/`stroke-dashoffset` a beat behind its card. None of that
lengthens the page, so none of it is metered by the budget in
`../../references/devices.md`; see "Two kinds of motion" there.

**Pick when:** the page needs to say what a business actually does, in four
pieces, and the client has no photography for it. This is the composition that
replaces a stock-photo grid.

**Skip when:** the four items are not genuinely parallel. Four capabilities read
as a set; three services and a phone number read as a list that ran out.

**Slots:** kicker (two or three words), title, and `item_N_name` /
`item_N_note` for N = 1..4. The note is one line — twelve words is long.

**Notes on the icons.** They are inline SVG with `stroke="currentColor"`, so they
take `--color-accent` from the theme and need no asset pipeline, no sprite and no
icon font. The four shipped marks are deliberately generic — a building, a
currency mark, a rising chart, a shield with a check — because a composition
cannot know the sector. **Replace the `d` attributes with marks that mean
something for this client**; keep `class="icon-row__stroke"`, the 40×40 viewBox
and `fill="none"`, and the drawing motion works unchanged.

`stroke-dasharray: 120` is a user-unit length chosen to exceed every path in the
four marks. A custom path longer than 120 units draws with a visible gap; either
raise the value or set `pathLength="100"` on the path and use `100`.

The `taste.md` refuse list bans a grid of identical icon + heading + text cards
as a **page's** organising idea. One capability row inside a page that also has a
hero, a proof row and real copy is not that, and never was — the failure being
refused is a whole page made of feature cards, not the existence of an icon.

**Interior pages:** this is the body composition most interior pages want, and it
carries element motion on its own, which satisfies the interior motion floor in
`../../references/devices.md` without a scrubbed device.

**Element motion:** self-sufficient. The children arrive on their own `view()`
ranges in `section.css`, so the root `data-motion="reveal"` is redundant here and
may be dropped to free `data-motion` for a section-level device (`drift`,
`parallax`, a pin). See "One attribute, one device" in
`../../references/devices.md`.
