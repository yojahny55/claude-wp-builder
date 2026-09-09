# footer-line

**Role:** footer, the small one. A single row: wordmark, three links, legal line.
The second footer variant exists because a four-page site given a four-column
footer looks like a site with pages it does not have.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. No devices, same reason as `footer-columns`: the
closing block is the ending, and a footer that animates ends the page twice.

**Pick when:** six pages or fewer, or when the closing block already carries the
contact details. Skip when there is an address, opening hours or a second
audience to route; use `footer-columns` instead.

**Slots:** wordmark, nav_label, three `link_N`/`href_N` pairs, legal_line.

**Notes:** three columns above 720px with the links centred and the legal line
right-aligned; stacked and left-aligned below it. On the page canvas rather than
`--color-surface`, because a one-row footer with its own ground reads as a bar
rather than an ending.
