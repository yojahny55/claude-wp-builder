# Compositions

A composition is a finished section in the plugin's own contract: delimiter,
`data-motion-*` only, BEM block scoped to its name, tokens only, `{{slots}}` for
copy. `/wp-demo` picks one per section of the feeling curve by role, pours the
client `DESIGN.md` tokens and real copy in, and deviates only with a one-line
reason in `demo/BRIEF.md`. The previews are rendered with `_preview.md`, so they
show the composition, not a brand.

Every composition's size-based breakpoints size to their own container, never
to the screen: the root declares `container-type: inline-size` and every
size-based breakpoint is an `@container` query, so a section dropped into a
narrow column lays out for the column at those breakpoints. Its fluid ramps —
the gaps, padding and type scales inside `clamp()` — key off the container
too, in `cqi`, so a section in a narrow column takes the space it actually
has instead of desktop-maximum spacing. Four occurrences stay `vw`, each
carrying a comment saying why. Three are the display headline of each
full-bleed hero (`hero-bleed`, `hero-split`, `hero-type`), sized against the
viewport on purpose — a full-bleed hero fills the screen by definition, and a
hero in a narrow column is not a scenario this library serves. The fourth,
`feature-zigzag`'s root `gap`, cannot be `cqi` at all: that rule is the
element declaring `container-type`, and an element never matches a container
query against the container it establishes itself, so `cqi` there resolves
against the viewport while reading as if it tracked the block. Only `(hover: hover) and (pointer: fine)` and
`(prefers-reduced-motion)` stay on `@media` — they are user and device
conditions a container query cannot express. An element never matches a query
against the container it establishes itself, so where the breakpoint changes
the block's own layout it is applied to an `__inner` wrapper, which is also
where a `data-motion` attribute moves, when the block has one, so `reveal` still
staggers the same children.

Regenerate a preview:

```
node bin/composition-preview.mjs --fill skills/wp-demo-craft/compositions/<name>
```

`--fill` substitutes the representative copy in `fills.json` for the `{{slot}}`
markers before rendering, which is how the committed PNGs were made: a frame full
of `{{title}}` teaches nothing about rhythm or measure. The renderer writes into
the composition folder, so **run it with `--fill` or it overwrites the committed
previews with marker-filled ones.** Edit `fills.json`, not `section.html`, to
change what a preview says.

| role | composition | motion cost (vh added) | devices | port of |
|---|---|---|---|---|
| hero | hero-split | 0 | reveal, parallax | none |
| hero | hero-type | 0 | reveal | Aceternity "text generate" (MIT), rewritten as the block's own reveal |
| hero | hero-bleed | 0 | parallax, scrim band | none |
| proof | proof-row | 0 | count, marquee | Magic UI marquee + number ticker (MIT) |
| feature | feature-zigzag | 0 | reveal | none |
| process | process-rail | 1.0 | pan | Aceternity sticky scroll reveal (MIT), rewritten as pan |
| offer | offer-table | 0 | reveal | none |
| testimonial | testimonial-pair | 0 | reveal, spotlight | Aceternity spotlight (MIT) |
| faq | faq-list | 0 | reveal | none |
| closing | closing-block | 0 | reveal, border beam | Magic UI border beam (MIT) |
| page-head | page-head | 0 | reveal | none |
| footer | footer-columns | 0 | none | none |
| footer | footer-line | 0 | none | none |

The motion-cost column is the input to the budget; the budget itself — the pin
caps, the per-index total and the interior-page rule — is stated once, in
`../references/devices.md`, under `### pin`. Sum this column, check it there.

## Why no composition here carries a `data-motion-cue`

Cues are read by `drive()` in `motion.js`, and `drive()` runs only for the
scrubbed devices: `pin`, `pan`, `kinetic`, `wipe`, `drift`. Those are the ones
with a continuous section progress for a cue to be a function of. A `reveal`
section has no such progress, so a `data-motion-cue` on one of its headings does
nothing at all, and an attribute that does nothing is worse than none: it tells
the next author a mechanism is in place when it is not.

What actually lights a hero headline is `reveal` itself. It sets the section's
direct children to `opacity: 0` and a 14px rise, then fades and lifts them in
over 620ms, staggered, **once**, when the section's top passes 88% of the
viewport. For a hero that is on first paint, because the section is already
there. It never re-hides on the way back up.

The greet and hold cue forms in `devices.md` still matter — they are how a
*pinned* or *panned* section's copy is timed against its own scroll range — and
`devices.md` rule 3, that only the last section may hold, still binds anything
that uses them. No composition in this library does.
