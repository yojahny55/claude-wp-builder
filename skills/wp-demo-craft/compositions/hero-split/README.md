# hero-split

**Role:** hero. Copy left, one real photograph right, crossing the gutter on
desktop so the image overlaps the page edge (overlap sells depth better than
shadow). Nothing masks the headline: `reveal` fades the copy and the figure in on
entry, and for a hero that entry is first paint.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 60), parallax
0.35 on the image only. Never body copy on the parallax layer. No
`data-motion-cue`: cues are read only for the scrubbed devices, so one on a
`reveal` section does nothing — see `../README.md`.

**Pick when:** the client owns one strong photograph of people or place. Skip when
the only imagery is stock or generated.

**Slots:** kicker, title (max two lines at 1440, three at 390), lede (about 25
words), cta_label/cta_href, alt_label/alt_href, image_src/image_alt (4:5 crop).

**Notes:** the split is a container query on the section's own inline size, not the
viewport, so the composition still stacks when it is dropped into a narrow column.
The queried layout sits on `__inner` because an element never matches a query
against the container it establishes itself.

The image gets `max-height: 68vh` above 900px. A 4:5 crop in the right
column is taller than the viewport at desktop widths, and without the ceiling the
section grows past `100dvh` and pushes the headline off the first screen. The
`object-fit: cover` on the image absorbs the crop.
