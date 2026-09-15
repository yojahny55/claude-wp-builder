# score-scale

**Role:** explainer. The credit-score range drawn to scale, with the five bands at
their real proportions and the five scoring factors at their published weights.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: none — all motion is element-level `view()`
animation in `section.css`, so the root `data-motion` attribute is free for a
section device. The bands grow up from the baseline left to right, the marker then
travels the width of the track, and the five factors arrive in sequence.

**Pick when:** the business is credit repair, lending, mortgage broking or financial
coaching, and the page needs to say what a score *is* before it can say anything
about improving one. This is the composition that turns three paragraphs of
explanation into a picture.

**Skip when:** the sector has no published scale to draw. The value here is that the
numbers are real and public; invent an axis and the composition becomes a chart
about nothing.

**Slots:** kicker, title, lede, `scale_caption` (name the scoring model the numbers
come from — FICO 8 and VantageScore 3.0/4.0 both run 300–850, and saying which is
what makes the figure checkable), `scale_alt` (the whole figure described in one
sentence for a screen reader).

## Why the numbers are in the file and not in the slots

The band boundaries (300–579, 580–669, 670–739, 740–799, 800–850) and the factor
weights (35 / 30 / 15 / 10 / 10) are **published facts about FICO scoring**, not
claims about a client. They are hardcoded on purpose: a slot invites a build to
change them, and a changed band boundary is misinformation in a regulated field.

This is also why the composition does not display a score. `taste.md` refuses
invented statistics, and a needle reading "580 → 720" is exactly that — a claim
about results that no demo has evidence for, in the one industry where that claim
attracts regulators. The marker carries **no number**: it says *this is the
direction*, which is the honest version of the same idea and the reason the
composition can ship without client data.

If the client supplies real, attributable outcome figures, they belong in
`proof-row` with their source, not on this scale.

**Element motion:** self-sufficient. The children arrive on their own `view()`
ranges in `section.css`, so no root `reveal` is needed and `data-motion` is free
for a section-level device.

**Notes:** the bands are a five-column grid at `280fr 90fr 70fr 60fr 51fr` — the
real point spans. Poor is genuinely half the range, which is the fact most readers
are surprised by and the main argument for drawing this at all rather than writing
it. Below 640px the range numbers drop and the proportions stay, because the
proportions are the information.

The marker animates `left` rather than `translate` so its end position is the
track's own right edge at any width, with no measurement and no script.
