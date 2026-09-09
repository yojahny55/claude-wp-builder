# hero-bleed

**Role:** hero. One full-bleed photograph, copy anchored bottom-left over it, and
a scrim that is a band rather than a wash so the top two thirds of the picture
stay a picture.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: parallax 0.6 on the bed only, and a reveal
on the copy column. The reveal is deliberately *not* on the section: `reveal`
writes `transform` on every child, `parallax` writes `transform` on the bed, and
`devices.md` forbids two devices sharing one element's transform.

**Pick when:** the client owns one photograph that carries the whole promise, in a
wide crop with somewhere quiet to put type. Skip when the only candidate is a
busy image; a band scrim heavy enough to fix a busy image is a grey rectangle.

**Slots:** kicker, title (max three lines at 390), lede (max 22 words),
cta_label/cta_href, image_src/image_alt (3:2 or wider, at least 2400px).

**Notes:** the bed is inset `-80px` top and bottom and 160px over-tall, because
the parallax device translates it 60px each way and a bed sized to the section
would drag its own edge into frame. `scrim--band` is the shared helper class the
craft skill names for this treatment; the geometry lives on `.hero-bleed__scrim`
so the composition works with or without that helper present.
