# hero-split

**Role:** hero. Copy left, one real photograph right, crossing the gutter on
desktop so the image overlaps the page edge (overlap sells depth better than
shadow). Headline carries a greet-and-hold cue, so it is visible on first paint
and never masked.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: reveal on the block, parallax 0.35 on the
image only. Never body copy on the parallax layer.

**Pick when:** the client owns one strong photograph of people or place. Skip when
the only imagery is stock or generated.

**Slots:** kicker, title (max two lines at 1440, three at 390), lede (max 20
words), cta_label/cta_href, alt_label/alt_href, image_src/image_alt (4:5 crop).

**Notes:** the image gets `max-height: 68vh` above 900px. A 4:5 crop in the right
column is taller than the viewport at desktop widths, and without the ceiling the
section grows past `100dvh` and pushes the headline off the first screen. The
`object-fit: cover` on the image absorbs the crop.
