# Compositions

A composition is a finished section in the plugin's own contract: delimiter,
`data-motion-*` only, BEM block scoped to its name, tokens only, `{{slots}}` for
copy. `/wp-demo` picks one per section of the feeling curve by role, pours the
client `DESIGN.md` tokens and real copy in, and deviates only with a one-line
reason in `demo/BRIEF.md`. The previews are rendered with `_preview.md`, so they
show the composition, not a brand.

Regenerate a preview: `node bin/composition-preview.mjs skills/wp-demo-craft/compositions/<name>`

The committed PNGs were rendered with representative copy substituted for the
`{{slots}}` first, because a frame full of `{{title}}` teaches nothing about
rhythm or measure. Running the command above against the committed
`section.html` renders the markers themselves; that is expected, not a
regression.

| role | composition | motion cost (vh added) | devices | port of |
|---|---|---|---|---|
| hero | hero-split | 0 | reveal (greet cue), parallax | none |
| hero | hero-type | 0 | reveal (greet cue) | Aceternity "text generate" (MIT), rewritten as a cue on the block |
| hero | hero-bleed | 0 | parallax, scrim band | none |
| proof | proof-row | 0 | count, marquee | Magic UI marquee + number ticker (MIT) |
| feature | feature-zigzag | 0 | reveal | none |
| process | process-rail | 1.0 | pan | Aceternity sticky scroll reveal (MIT), rewritten as pan |
| offer | offer-table | 0 | reveal | none |
| testimonial | testimonial-pair | 0 | reveal, spotlight | Aceternity spotlight (MIT) |
| faq | faq-list | 0 | reveal | none |
| closing | closing-block | 0 | reveal (hold cue), border beam | Magic UI border beam (MIT) |
| page-head | page-head | 0 | reveal (greet cue) | none |
| footer | footer-columns | 0 | none | none |
| footer | footer-line | 0 | none | none |

Budget rule: the index adds at most four viewport-heights beyond its section
count; one composition may be promoted to the peak with `data-motion-peak` and a
pin span up to 3.0. Interior pages never pin.
