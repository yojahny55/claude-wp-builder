# page-head

**Role:** page-head. The opening band of an interior page. A kicker, the title and
one sentence that says what the page is for, on a hairline. Three elements, and
the third is the one that matters: an interior page that opens on a title and a
divider is the failure this whole library exists to stop.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added, and it must stay 0. No pin, no `min-height`, no
`100dvh`. Devices: none on the block. The kicker, title and lede light in that
order from their own `view()` ranges in `section.css` — on an interior page,
immediately — which is the same motion a root `reveal` with a stagger used to
express, without the second writer. No `data-motion-cue` either: cues are read
only for the scrubbed devices — see `../README.md`.

**Pick when:** any page that is not the index. Every one of them.

**Slots:** kicker (the section of the site this page belongs to, two or three
words), title, lede (12 to 24 words, what the reader will get from this page).

**Notes:** the previews are the full band and then the page ground beneath it,
because that is what this composition is: roughly 40% of a 900px screen, not a
hero. The content that follows fills the rest on a real page. Deliberately
shorter than every hero in the library.

**Element motion:** self-sufficient, and the root carries **no** `data-motion`.
The children arrive on their own `view()` ranges in `section.css`, so a root
`reveal` would not add motion — it would take it away. `reveal` does
`gsap.set(kids, {opacity, y})` on exactly these elements, which is a second
writer on the properties the CSS is already animating, and the two resolve
differently in a demo and in a theme: the demo wins that race and the theme
loses it, freezing each child at its keyframe's start value. This composition
shipped with that attribute and the defect reached a client's every interior
page. `data-motion` here is free for a section-level device (`drift`,
`parallax`, a pin) — see "One attribute, one device" and the collision rule in
`../../references/devices.md`.
