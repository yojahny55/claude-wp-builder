# closing-block

**Role:** closing. The last thing on the page, and it has to end on a lit
statement rather than fade to an empty stage. `reveal` does that here: it fades
the frame in once on entry and leaves it up. Nothing re-hides on the way back.

**Port of:** Magic UI "border beam", rewritten as a rotating conic gradient on a
pseudo-element with a second pseudo-element inset 1px painting the ground back
over it. The original animates an element around the border path; this animates
`transform` only, which is what the motion floor allows.
**Licence:** Magic UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 0 vh added. Devices: reveal on the block (stagger 70) and the
CSS beam, which is scroll-linked (`animation-timeline: view()`,
`animation-range: entry 0% cover 60%`) and stops under
`prefers-reduced-motion`. No `data-motion-cue`: cues
are read only for the scrubbed devices, so one on a `reveal` section does nothing
— see `../README.md`. No
`magnet` on the CTA: the role table lists two devices for this composition and a
third would be one more thing moving in the section that has to be still enough
to read.

**Pick when:** the page needs an ending. Every index does. Skip only if the page
already closes on a form section that does the same job.

**Slots:** kicker, title (six to ten words, the sentence you want quoted),
lede (max 26 words), cta_label/cta_href, aside (the reassurance that would
otherwise be invented small print: hours, response time, what happens next).

**Notes:** the beam runs on `transform` alone, and it does not run continuously.
The rotation is driven by the view timeline rather than by a clock: it makes one
sweep as the section enters and then holds, because it signals arrival and
carries no content, so it has no reason to run forever. `animation-fill-mode:
both` is what keeps it settled instead of snapping back on scroll up, and an
`@supports not (animation-timeline: view())` block gives a browser without
scroll-driven animation a static beam rather than one frozen on an arbitrary
frame. An infinite version of this is also what `impeccable` reports as
`marquee` at `category: slop` — see `bin/composition-gate.sh`. If a build ever does give this section a
scrubbed device, `devices.md` rule 3 applies: only the last section on a page may
hold a cue, and this is the section that qualifies.
