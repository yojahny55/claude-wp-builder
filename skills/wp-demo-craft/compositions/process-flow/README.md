# process-flow

**Role:** process. A pipe with a node per step and a line the scroll draws along
it: stacked on a phone, horizontal once the container can hold a column per step.
The line's progress and the arrival of the node it points at are the same
quantity, so they run on one named timeline rather than on `view()` each.

**Port of:** none. Built for this library as the second answer in the `process`
role, because a library with one good answer per role gives every build the same
answer — `uniqueness.md` §1. `process-rail` costs a viewport-height of scroll and
pins; this costs nothing and does not, so the two are chosen on page budget rather
than on taste.

**Licence:** plugin (MIT).

**Motion cost:** 0 vh. No pin, no span, no added page length.

**Pick when:** the offer is a sequence of three to five steps and the page cannot
afford `process-rail`'s viewport-height — an interior page, or a home page that
already spends its one pin elsewhere. Skip when there are two steps (a pipe
between two nodes is a line, and a line is not a process) or more than five (the
horizontal layout stops holding a readable column and the stagger outlives the
scroll window).

**Slots:** kicker, title, lede, then `step_N_n` (`01`, `02`, …), `step_N_title`,
`step_N_body` (20 to 40 words) for three to five steps.

## The geometry, and why it is per-step

The rail is drawn as **one segment per step**, on the step itself, rather than as
a single element spanning the list. Each segment starts at its own node's edge and
ends at the next node's edge — both local facts, needing no count.

The single-rail version was written first and measured wrong. A spanning rail has
to be inset to the first and last node *centres*, and there is no count-based
expression for that: the nodes are not centred in their cells and the steps are not
equal in height. Measured at 1440 with four steps, an inset of `100% / (2 × N)`
put the rail start **130px** from the first node's centre and the rail end **95.8px**
from the last — out by different amounts at the two ends, because the columns are not
equal either. At 390 the vertical version was out by **44.7px**. The per-step version
measures **0.0px** at every junction, at 1440, 1024, 768 and 390, and at every step
count from three to six.

**Nothing here counts the steps at all.** The horizontal track list is
`grid-auto-flow: column` with `grid-auto-columns: minmax(0, 1fr)`, which lays every
child in one row of equal columns whatever the number of them is. An earlier draft
carried a `--pipe-count` custom property for the track list, and it was the last
thing left that had to *agree* with the number of children — a value that has to
agree with something else is a value that eventually does not. Measured at 3, 4, 5
and 6 steps, at 1440 and 390: every junction 0.0px, one row when horizontal, one row
per step when stacked, no overflow, and the last step never draws a trailing segment.

`minmax(0, 1fr)` rather than `1fr` because a grid item's automatic minimum size is
its min-content width, so a plain `1fr` lets one long word in a step body push its
column past its share and overflow the section.

The motion ranges are written out to five steps. A sixth still lays out correctly but
falls back to the default range, which is why the slot guidance above stops at five.

**Nothing but `__step` children belong in `.process-flow__steps`.** The rail used to
be a sibling element inside that list and it was a grid item like any other — it took
a column, pushed the fourth step onto a second row, and overflowed the section by
**153px** at 1440 (`scrollWidth` 1481 against a 1440 viewport). That is the bug that
survived the CSS rewrite, because the markup was not rewritten with it.

## Two traps this composition is shaped around

**`z-index: -1` is not used, and the reason is not style.** A negative index paints
the element behind its stacking context's background, and an entrance animating
`translate` or `scale` on any ancestor *establishes* a stacking context — so a rail
on `-1` is visible in a static preview and gone the moment the section animates.
Everything here sits at or above `0`, and the node carries an opaque
`background-color` to cover the segment that ends behind it. A translucent tint shows
the line running through the middle of the number.

**`.process-flow__node` carries no padding.** The segment geometry is derived from
the node's edges, so its size must not depend on the label inside it — a node sized
by its content would move the rail every time a number got wider. It is a fixed box
with the glyph centred by `place-items`. `justify-self` is set for the same reason:
without it the grid stretched and shrank the nodes, which measured **44, 43.8, 43.3
and 42.6px** across one row — a circle that is not a circle. With it, four nodes of
44px at every width tested.

## The motion

Every animated element runs on `--flow-tl`, the `view-timeline-name` declared on the
section, and none of them on `view()`. That is the point of the composition: a
segment's progress and the arrival of the node it points at describe one quantity,
and `view()` builds a timeline from each element's own box, so a segment and a node
below it would report different progress and disagree on screen while every probe
called both of them working. Verified: all four nodes and every segment resolve to
**one timeline object**, at all four widths. Segment *k* and node *k+1* share an
endpoint, so the line reaches the node exactly as the node lights.

**The node arrives, it does not appear.** A node that fades in leaves its step's
title and body standing over nothing until the line reaches it, which reads as a
section that failed to load rather than as a process with a position in it. The whole
pipe is legible from the first frame; what the scroll moves is the active point along
it. Everything behind that point stays lit, because a completed step is completed.

See `references/devices.md`, "two elements that display the same value share a named
timeline".
