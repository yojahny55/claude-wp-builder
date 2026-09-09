# proof-row

**Role:** proof. Three figures on hairlines, each with the label *and the source*
that makes it checkable, then a slow drift of client or supplier names underneath.

**Port of:** Magic UI `marquee` and `number-ticker`. The marquee is rewritten as a
single CSS keyframe on `transform` over one duplicated track; the ticker is the
kit's own `count` device, dispatched by `data-motion-count` alone.
**Licence:** Magic UI is MIT. No code was copied; both effects are reproduced.
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 80), count on
each figure, and a CSS marquee.

**The marquee must stay pausable.** WCAG 2.2.2 asks for a mechanism to stop
anything that moves automatically beside static content, and
`prefers-reduced-motion` is not that mechanism: it is a standing preference, not
a control. So the track pauses on `:hover` and on `:focus-within`, the second
because hover alone is not keyboard reachable. Only the `:hover` rule sits inside
`@media (hover: hover) and (pointer: fine)`; the `:focus-within` rule is outside
it, because a keyboard attached to a coarse-pointer device (a tablet, a TV, a
touchscreen laptop) fails that query, and gating focus on it would withdraw the
one keyboard-reachable pause exactly where hover is already gone.
`prefers-reduced-motion` pauses it as well, separately. Known ceiling: the track
items this composition ships are plain text, so there is nothing in them to focus
and `:focus-within` never fires — it is the correct rule waiting for focusable
content, not a working pause today. If a build makes the names links, it starts
working at once, on every pointer type; if it does not, and the section must
satisfy 2.2.2, give the marquee a real pause button.

**Pick when:** the client has figures they can defend. **Skip the whole section when
they do not.** `data-motion-count` takes real, verified numbers only. A brand
before launch has none, so it gets no counters and no proof row; invent nothing.

**Slots:** kicker, title, then per figure `nN` (written exactly as it should
render, e.g. `3,500` or `12.5`), `labelN`, `sourceN` (who counted it and when, in
under ten words). `marquee_label`, and `name1` to `name6`, each repeated once in
the track so `translateX(-50%)` returns to the start seamlessly; the second copy
is `aria-hidden`.

**Notes:** the track is one `ul` holding the six names twice rather than two `ul`
elements, because the `-50%` keyframe has to translate a single box that contains
both halves. The edge fade is a `mask-image`, so it costs no extra element and
tints nothing; the `black` in that gradient is an alpha channel rather than a
colour, which is why it is the one literal in the library and not a precedent.
