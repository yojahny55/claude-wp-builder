# proof-row

**Role:** proof. Three figures on hairlines, each with the label *and the source*
that makes it checkable, then a slow drift of client or supplier names underneath.

**Port of:** Magic UI `marquee` and `number-ticker`. The marquee is rewritten as a
single CSS keyframe on `transform` over one track; the ticker is the
kit's own `count` device, dispatched by `data-motion-count` alone.
**Licence:** Magic UI is MIT. No code was copied; both effects are reproduced.
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 80), count on
each figure, and a CSS marquee.

**The marquee is scroll-linked, not time-linked, and that is why it has no pause
button.** The keyframe runs on `animation-timeline: view()` over
`animation-range: cover 0% cover 100%`, so the track advances only while the
reader is moving the section through the viewport, and stops the instant they
stop. WCAG 2.2.2 asks for a mechanism to stop anything that moves
*automatically*; nothing here does, so there is nothing to pause and the earlier
`:hover` / `:focus-within` rules are gone. (They never fired anyway: the track
items are plain text, so there was nothing in them to focus.) Reduced motion is
handled by applying the drift only inside
`@media (prefers-reduced-motion: no-preference)` — under `reduce` the rule is
never applied at all, rather than applied and then paused. A browser without
scroll-driven animation is covered by the same `@supports` wrapper: it gets a
motionless row of names, which is a logo wall, which still reads.

The other reason to prefer this over the loop: `impeccable` reports any infinite
CSS animation as `marquee` at `category: slop`, which failed the craft
verification round before a screenshot was taken. See `bin/composition-gate.sh`.

**Pick when:** the client has figures they can defend. **Skip the whole section when
they do not.** `data-motion-count` takes real, verified numbers only. A brand
before launch has none, so it gets no counters and no proof row; invent nothing.

**Slots:** kicker, title, then per figure `nN` (written exactly as it should
render, e.g. `3,500` or `12.5`), `labelN`, `sourceN` (who counted it and when, in
under ten words). `marquee_label`, and `name1` to `name6`, each repeated once in
the track; the second copy is `aria-hidden`. The duplicate is what gives the
track enough width to drift across without running out of names.

**Notes:** the track is one `ul` holding the six names twice rather than two `ul`
elements, because the keyframe has to translate a single box that contains both
halves. The drift stops at `-38%` rather than the loop's `-50%`: the loop needed
the second half to hide its seam at the wrap, a one-way drift has no wrap and so
should stop short of exposing the end of the track. The edge fade is a `mask-image`, so it costs no extra element and
tints nothing; the `black` in that gradient is an alpha channel rather than a
colour, which is why it is the one literal in the library and not a precedent.
