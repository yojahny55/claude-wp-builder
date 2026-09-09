# hero-type

**Role:** hero. No image at all. One sentence set as large as the grid allows,
anchored to the bottom of the first screen so the empty space above it reads as
a held breath rather than a section that failed to fill. A hairline over the
kicker gives the block a top edge; without it the type floats.

**Port of:** Aceternity "text generate", reproduced as the block's own `reveal`
rather than a word-by-word split. A per-word reveal on the first headline a
visitor ever sees costs the landing screen its meaning for the length of the
stagger; one 620ms fade of the whole block does not.
**Licence:** Aceternity UI is MIT. No code was copied; the effect is rewritten
inside the `data-motion` contract.
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 70). No
parallax, nothing to parallax. No `data-motion-cue`: cues are read only for the
scrubbed devices, so one on a `reveal` section does nothing — see `../README.md`.

**Pick when:** the brand has a sentence worth the whole screen and no photograph
worth showing. Skip when the client owns real imagery; an empty hero is a choice,
not a default.

**Slots:** kicker (three to five words), title (four to seven words; it must not
pass three lines at 390px), lede (max 24 words), cta_label/cta_href.
