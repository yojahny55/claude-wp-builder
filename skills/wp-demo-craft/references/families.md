# Families

The enforceable half of `uniqueness.md` §6. That section names seven aesthetic
families by what they read as and who earns them; this file says, for each one,
what its type does, what its palette does, what a card is, how it moves, how its
pages tend to sequence — and what it **forbids**. The shape is adapted from the
style-lane skills in [MengTo/Skills](https://github.com/MengTo/Skills) (MIT),
whose one real lesson is that a committed direction is mostly a list of things
it refuses to do.

**Pick one, before the first section.** Record it in `demo/BRIEF.md` under
`## Family`, with that family's Avoid list copied verbatim underneath. The
composition plan, `DESIGN.md` and every section obey the Type / Palette /
Surfaces / Motion lines; verify reads every page against the Avoid list before
the rubric, and a hit is a ship blocker (`SKILL.md`), not a graded line. A
brutalist page with one glass card is a page that chose two families, and a page
that chose two chose none — which is the shape every "generic" note describes.

**What never flexes is the taste floor.** Every item in `taste.md` holds in every
family — contrast, spacing scale, type metrics, compositable motion,
`:focus-visible`, reduced motion that keeps meaning, real copy. The floor is what
separates a chosen family from a sloppy one, and the reason offering seven is
safe. The two universal traps in §6 (cream-and-brass, violet-to-blue gradient)
stay banned everywhere and are not repeated below.

A family is a direction, not a template. Two brutalist builds still owe the
fingerprint gate four differing dimensions out of seven; the family fixes the
grammar, not the sentence.

---

### Brutalist

Blunt, structural, unstyled on purpose. Earned by tools, infrastructure,
anything anti-marketing, studios that want the work to speak.

- **Type** — one compressed or condensed display face at billboard scale, one
  neutral grotesk for everything else. Line breaks are composition: set them by
  hand and test them at every breakpoint. Labels uppercase, tracked, small.
- **Palette** — hard black and a warm white; at most one pale proof surface
  (mint, pink, paper) for verified testimonials or notices. The accent is a
  surface, not a colour on type.
- **Surfaces** — square corners, exposed hairline grid lines, no shadow, no
  blur. A card is a cell in a visible grid, or it is not a card.
- **Motion** — decisive cuts between black and white chapters; sticky contrast
  changes at section boundaries; parallax capped under 5%. Controls 160–220ms,
  masks and entrances 500–760ms. One reading transition at a time.
- **Sequence** — billboard positioning line → straight into the work on black
  → sparse white philosophy chapter → one documentary collage → verified proof
  on a pale surface → hard-ruled FAQ → oversized footer wordmark.
- **Avoid**
  - Rounded SaaS cards, glass, glow, or more than one gradient on the page.
  - Brutalism as random misalignment, or as contrast that fails the floor.
  - Decorative masonry with no narrative order in the DOM.
  - Continuous parallax or smooth-scroll theatre competing with the work.
  - Explaining the studio before showing what it made.

### Maximalist

Dense, layered, loud, generous. Earned by culture brands, events, food,
festivals, anything abundant.

- **Type** — two or three faces that argue: a display face with real character
  (slab, fat serif, display sans), a text face, optionally a mono for labels.
  Sizes jump, they do not step. Overlap is allowed when reading order survives.
- **Palette** — a full palette of four or five saturated colours used as fields,
  not accents; ink chosen per field for contrast. No single "brand accent".
- **Surfaces** — stacked, overlapping, rotated a few degrees, stickers and
  badges, thick borders, hard offset shadows. Texture on the ground: grain,
  halftone, paper.
- **Motion** — marquees, kinetic type, counts, stagger with generous overlap;
  more moving things than any other family, each one small and each one ending.
  Still within the `devices.md` budget — density without rhythm is noise.
- **Sequence** — a hero that is already three things at once → a wall of proof
  or programme → an offer with every option visible → a loud closing. Few quiet
  sections, but at least one, or there is no peak.
- **Avoid**
  - Premium-minimal restraint sneaking in: one accent, lots of air, one face.
  - Density with no spacing scale — every gap a different number.
  - Layering that breaks reading order or hides a control under a sticker.
  - Motion that never stops (infinite loops with no end state on every element).
  - Stock "energetic" gradients doing the work the palette should do.

### Playful

Bouncy, coloured, informal. Earned by kids, games, consumer apps, community,
anything that wants to be liked before it is trusted.

- **Type** — a rounded or geometric sans with a friendly display cut, generous
  x-height, big weights for headlines; text face the same family or a plain
  humanist. Never a serif display.
- **Palette** — a bright canvas (not white: cream, sky, butter) with two or
  three cheerful colours as fields and a dark ink. Colours name things
  consistently (one per plan, one per feature).
- **Surfaces** — large radii, soft or coloured shadows, pill buttons, chunky
  borders, illustrated or cut-out imagery. A card is a rounded coloured field.
- **Motion** — spring easings, overshoot, `tilt` and `magnet` on cards, icons
  that draw on, hover states that reward. Short (200–400ms) and frequent.
  Reduced motion removes the bounce and keeps the state change.
- **Sequence** — hero with the product doing something → three features each
  in its own colour → social proof as faces and quotes → simple offer → warm
  closing.
- **Avoid**
  - Dark canvas with neon accents — that is Nocturne wearing a Playful badge.
  - Corporate photography, faceless silhouettes, initials as avatars.
  - Glass, blur, mesh gradients; anything "premium".
  - Small type. If a label needs 12px the layout is wrong for this family.
  - Bounce on everything: motion with no rest reads as anxious, not fun.

### Retro

Specific to a decade, not vaguely nostalgic. Earned by heritage brands, music,
food with a real lineage, anything with a history it can prove.

- **Type** — faces from the decade, or faithful revivals, used as they were
  used then: the set width, the tracking, the case. Name the decade in
  `BRIEF.md`; "retro" alone is a costume.
- **Palette** — the decade's actual printing palette: limited, slightly off,
  ink on toned paper. Two or three spot colours plus black; no pure white.
- **Surfaces** — print artefacts, honestly: halftone, misregistration by one
  pixel, rules and borders from the period's ads, rounded or square as the
  decade had them. No drop shadows unless the decade had them.
- **Motion** — sparing. Wipes and reveals that read like a page turning or a
  slide advancing; no springs, no parallax. Motion is the one thing the decade
  did not have on a page, so it stays subordinate.
- **Sequence** — a masthead or label as the hero → the story of the thing
  (dated, with real years) → the range or menu laid out like a catalogue →
  where to find it. Proof is provenance, not testimonials.
- **Avoid**
  - Mixing decades — a 70s face over an 80s grid with a 50s badge.
  - "Vintage" filters on modern photography instead of period-appropriate art
    direction.
  - Modern SaaS structure (bento grid, pricing cards) in period clothes.
  - Distressing that makes the interface feel dirty rather than printed.
  - Any gradient the decade's printing could not have produced.

### Dense

Information-forward, small type, high count. Earned by data products,
catalogues, reference, finance, engineering — anywhere the reader came to look
something up.

- **Type** — a text-optimised sans or a mono at 13–15px body, tight leading,
  tabular figures; the display face is the same family, one or two steps up.
  Hierarchy comes from weight, colour and rules, not size jumps.
- **Palette** — monochrome or near it: paper or off-black canvas, ink, one
  functional accent for the current thing (active, linked, changed). Colour
  means something or it is not there.
- **Surfaces** — hairline rules, tables, technical frames, annotated diagrams;
  corner marks, dimension lines, index numbers. A card is a bordered region in
  a wireframe, flush to the grid.
- **Motion** — scroll-progress indicators, pinned diagrams that annotate as
  the reader passes, counts. No entrances on rows — a table that fades in
  row by row is a table the reader waits for. Controls 120–180ms.
- **Sequence** — a hero that is already the object, annotated → the system or
  spec laid out as a diagram → the data (table, matrix, index) → the terms →
  contact. Proof is the specification itself.
- **Avoid**
  - Marketing sections (big hero copy, testimonial carousels) competing with
    the annotated object.
  - Bright accents breaking the monochrome; more than one functional colour.
  - Overloading the diagram until labels, lines and widgets become noise.
  - 3D renders or illustration where a wireframe or a photograph would inform.
  - Generous whitespace as a virtue — here it is unspent space.

### Editorial

Paper, folios, measure, restraint. Earned by long-form substance: studios,
architecture, publications, portfolios, professional services with something
to say.

- **Type** — a grotesk display over a text serif, or a serif display over a
  neutral sans; one pairing, held. Measure 60–72 characters, real leading, a
  visible baseline rhythm. Folios, running heads, pull quotes as structure.
- **Palette** — near-black or warm white as the ground, ink, one muted colour
  field per chapter or project, a hairline colour. The accent is a field
  behind a chapter, not a button colour.
- **Surfaces** — 12-column grid with 40–64px desktop margins; square or barely
  rounded media, deliberately cropped; hairline rules; almost no shadow.
  Full-bleed is rare and means something.
- **Motion** — 160–220ms controls, 500–760ms entrances, stagger direct children
  45–70ms on `cubic-bezier(.22,.61,.36,1)`; parallax under 5%; navigation
  background changes tied to section boundaries. Nothing decorative loops.
- **Sequence** — near-black opening with one positioning line → chapters, each
  a project or argument on its own colour field, the strongest allowed to
  change scale → a paper chapter for how the practice thinks → proof → an
  index-like footer.
- **Avoid**
  - Identical rounded cards repeated across a chapter.
  - Explaining the practice before showing its work.
  - Fast card choreography, large parallax, decorative motion loops.
  - Titles or actions revealed only on hover.
  - Cold enterprise blue-grey, or flat white SaaS structure, losing the paper.

### Premium-minimal

Quiet, dark, one accent, air. Earned by luxury — and **only when asked for**.
This is the family the skill drifts toward when nobody decides; choosing it has
to be an act, recorded, with the client's word for it in `BRIEF.md`.

- **Type** — one display face with presence (a refined grotesk or a light
  serif), one text face, generous size contrast and generous air. Tracking
  opened on small caps labels. Few words.
- **Palette** — near-black or deep charcoal canvas, bone or off-white ink, one
  accent used less than the eye wants: on a rule, a numeral, a single CTA.
  Never a second accent.
- **Surfaces** — frosted depth used sparingly: one glass surface per viewport
  at most, over real imagery rather than blobs; hairlines; large radii or none,
  chosen once. Shadow as a soft contact, not a lift.
- **Motion** — slow (600–900ms), long eases, `reveal` and `pin` over `tilt`
  and `magnet`; one moving thing per section. Stillness is the material.
- **Sequence** — a hero that is one image, one line, one action → a slow
  reveal of the thing itself → a small number of proof points → the offer
  with almost no comparison → closing.
- **Avoid**
  - Glass cards floating over colourful blobs, or glass on every surface.
  - Neon glow, saturated mesh gradients, "AI" violet-to-blue.
  - Bento grids and feature card rows — density is the opposite of this family.
  - Flat black boxes with no depth at all, which is not minimal, only empty.
  - Two accents, or the accent on body text.

---

## What this file cannot do

The Avoid list is read by the evaluator, page by page, in the same round as the
rubric. Nothing measures it: a glass card is `backdrop-filter`, a rounded SaaS
card is a radius over 12px on a bordered box, and both are detectable — but a
detector that fires on a brutalist page's one deliberate exception is a detector
the build learns to argue with. If Avoid hits keep shipping, the upgrade path is
a `bin/family-lint.mjs` that reports, never blocks, and the evaluator decides.
