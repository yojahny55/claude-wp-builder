# feature-zigzag

**Role:** feature. Two rows, image and copy, the second row mirrored. Two rows and
no more: a third is where a zigzag stops being a rhythm and starts being a list.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: reveal on the block, stagger 90 so the head
and the two rows arrive as three beats rather than one wash.

**Pick when:** there are exactly two things worth showing side by side with a
picture each. Skip when the images would be icons or screenshots of nothing;
a zigzag of weak images is twice the weakness.

**Slots:** kicker, title, then per row `feature_N_title`, `feature_N_body` (30 to
55 words, measure capped at 58ch), `feature_N_label`/`feature_N_href`,
`feature_N_image_src`/`feature_N_image_alt` (4:3).

**Notes:** the mirror is `direction: rtl` on the grid with `direction: ltr` back on
the children, so the DOM order stays image-then-copy in both rows and the reading
order does not flip with the visual one. Below 880px both rows stack image-first.
