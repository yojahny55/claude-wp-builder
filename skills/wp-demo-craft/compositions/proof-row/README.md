# proof-row

**Role:** proof. Three figures on hairlines, each with the label *and the source*
that makes it checkable, then a slow drift of client or supplier names underneath.

**Port of:** Magic UI `marquee` and `number-ticker`. The marquee is rewritten as a
single CSS keyframe on `transform` over one duplicated track; the ticker is the
kit's own `count` device, dispatched by `data-motion-count` alone.
**Licence:** Magic UI is MIT. No code was copied; both effects are reproduced.
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 80), count on
each figure, and a CSS marquee that pauses under `prefers-reduced-motion`.

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
tints nothing.
