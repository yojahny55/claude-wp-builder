# closing-block

**Role:** closing. The last thing on the page, and the one place a cue is allowed
to hold: `data-motion-cue="0 1 0 0"` on the heading is the greet-and-hold form, so
the page ends on a lit statement instead of fading to an empty stage.

**Port of:** Magic UI "border beam", rewritten as a rotating conic gradient on a
pseudo-element with a second pseudo-element inset 1px painting the ground back
over it. The original animates an element around the border path; this animates
`transform` only, which is what the motion floor allows.
**Licence:** Magic UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 0 vh added. Devices: reveal on the block, hold cue on the
heading, and the CSS beam, which stops under `prefers-reduced-motion`. No
`magnet` on the CTA: the role table lists two devices for this composition and a
third would be one more thing moving in the section that has to be still enough
to read.

**Pick when:** the page needs an ending. Every index does. Skip only if the page
already closes on a form section that does the same job.

**Slots:** kicker, title (six to ten words, the sentence you want quoted),
lede (max 26 words), cta_label/cta_href, aside (the reassurance that would
otherwise be invented small print: hours, response time, what happens next).

**Notes:** only the last section on a page may hold its cue (`devices.md`), so
this composition must be the last one that carries a cue at all. The CTA carries
`magnet`, so nothing else may write `transform` on it; its hover is a
background-colour change only.
