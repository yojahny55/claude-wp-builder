# Compositions

`compositions/README.md` is the role table. Each folder beside it holds the
fragment, its CSS written on the token names, two rendered previews (1440 and
390) and a README naming what it ports and under which licence. **Look at the
previews before choosing.** They are the reason this library exists: v1 had no
picture of a good section anywhere in it.

## Choosing

Walk the feeling curve from `demo/BRIEF.md`. For each section pick one
composition by role and write the row into the plan:

    section | role | composition | why | motion cost | domain signal

The last column is the domain signal that justified the choice, citing the brief
constraint the domain classification folded in, or "no domain signal" when the
domain does not touch that row. It is what makes the classification bind on the
plan instead of sitting unread, and it is the same row format `/wp-demo` Step 2.6
and `SKILL.md` state — do not restate it a fourth way.

Sum the motion cost before building. The index adds at most four
viewport-heights beyond its section count; the role table carries each
composition's cost in vh so the sum is arithmetic, not a measurement taken after
the page is already 12,000px tall. Promote exactly one composition to the peak
with `data-motion-peak`. Interior pages take the cheap roles and never pin.

Deviate from a composition only with a one-line reason in `demo/BRIEF.md`. A role
the table does not cover is built by hand under the same contract — delimiters,
`data-motion-*` only, BEM block scoped to its own name, tokens only — and noted
the same way. The one-line reason is the whole cost of deviating; a build that
cannot write the line was not deviating on purpose.

## Inspiration when the docs name nothing

The free Landing Gallery MCP at `https://www.landing.gallery/api/mcp` (no
account, no key) exposes `search_inspiration` by page type and device. Pull four
screenshots for the page kind, name in one sentence what each one does with its
first viewport, and choose compositions with that in hand. The screenshots are
inspiration only. Never recreate one: that is how a demo acquires a layout that
belongs to a competitor.

## Ports

Effects ported from React libraries — Magic UI, Aceternity, motion-primitives —
are rewritten in vanilla CSS and GSAP inside the `data-motion` contract, and the
origin and its licence are named in the composition's README. The libraries are
never dependencies: a demo that needs npm to render is a demo the client cannot
open.
