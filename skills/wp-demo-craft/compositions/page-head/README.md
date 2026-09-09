# page-head

**Role:** page-head. The opening band of an interior page. A kicker, the title and
one sentence that says what the page is for, on a hairline. Three elements, and
the third is the one that matters: an interior page that opens on a title and a
divider is the failure this whole library exists to stop.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added, and it must stay 0. No pin, no `min-height`, no
`100dvh`. Devices: reveal on the block, greet-and-hold cue on the title so the
heading is lit on first paint.

**Pick when:** any page that is not the index. Every one of them.

**Slots:** kicker (the section of the site this page belongs to, two or three
words), title, lede (12 to 24 words, what the reader will get from this page).

**Notes:** the previews are the full band and then the page ground beneath it,
because that is what this composition is: roughly 40% of a 900px screen, not a
hero. The content that follows fills the rest on a real page. Deliberately
shorter than every hero in the library.
