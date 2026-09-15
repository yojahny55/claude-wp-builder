# The structure axis

Ported from [nateherkai/scroll-craft](https://github.com/nateherkai/scroll-craft)
`references/uniqueness.md` (MIT), adapted for multi-page WordPress demos. Read it
after the brief interview and before the composition plan.

## 1. The template trap

The source skill's author built four sites with it — a protein coffee brand, a
personal brand, a landscape design-build firm, an observability product — and
his owner looked at them side by side and said they felt like a template. He was
right, and the evidence was in the files: all four opened full-bleed under a
fixed minimal bar, all four anchored the headline in the lead corner, all four
closed on a pinned stage with a magnetic CTA, all four landed between 13.6 and
13.8 viewport-heights with exactly one accent colour. What varied was the order
of the middle sections and the palette.

**This plugin inherited that failure and, for several releases, none of the
cure.** The port took the taste floor, the refuse list, the feeling curve and the
device kit — every one of them a *constraint* — and left behind the three
systems that make two builds different from each other. The result was
predictable and was in fact reported, in these words: *"all the pages are almost
the same thing."*

> The world changes how a page LOOKS. The grammar changes what a page IS.
> A build that only changes world is a re-skin.

Three things here are not optional: the **default grammar carries a burden of
proof**, every build invents a **signature move**, and every build clears the
**fingerprint gate** on structure as well as on palette.

## 2. Two axes of sameness, and this plugin has both

The source skill built one page per project, so its only sameness axis was
**build against build**. A multi-page demo has a second axis the source never
had to name.

**Across builds** — two clients get recognisably the same site. Caught by the
fingerprint gate (§5).

**Within one build** — eleven pages of one site that are the same page with
different words. This is the one that was actually reported, and no gate in this
skill ever looked for it. A composition plan that answers every page with
`page-head` → three `feature-zigzag` → `closing-block` has produced a site whose
pages are distinguishable only by their copy.

**The within-build rule: no two pages of one demo may share their whole
composition sequence, and the home page's sequence may not be a superset of any
interior page's.** Two pages sharing a header and a footer is a site; two pages
sharing their middle is a template. Write the per-page sequences into the
composition plan and read the column down before building: if two rows are the
same list, one of them is not designed yet.

Interior pages are where this bites, because they are the ones nobody plans.
An about page, a services page and a contact page have genuinely different jobs
— a story, a comparison, a transaction — and three different jobs answered with
the same three compositions means the jobs were never read.

## 3. The default grammar carries a burden of proof

`grammars.md` lists the grammars this skill offers. One of them is always the
one a build drifts into when nobody chooses, and for this skill that is
**layered landing**. It is a good grammar and it is also the reason four builds
in a row looked related.

**A build that lands on the default grammar says in `demo/BRIEF.md` why the
others did not fit.** One sentence per rejected grammar is enough. This costs
nothing when the default is genuinely right and is impossible to write honestly
when it is not, which is the whole mechanism.

## 4. The signature move

**Every build invents one bespoke interaction that exists on that site alone.**
Not in the composition library, not in any prior build, not a parameter change.
Built in the page, with CSS of its own or a small script reading `--motion-p`.
The engine stays untouched, always.

This is the thing a visitor remembers after closing the tab, and it is the only
part of a build that cannot be arrived at by following rules. It is also the
single cheapest defence against the template trap, because it is unique by
definition.

### What counts

- **Scroll-as-playhead over a persistent trace rail.** A thin trace fixed at the
  bottom edge for the whole page, drawing a real route, waveform or timeline.
  Scroll position is the playhead; passing a section stamps a marker that stays.
  By the footer the trace is a record of what the visitor went through, and it
  doubles as navigation.
- **A wordmark the pointer can pull apart.** Letters follow the cursor with
  different masses, separate under a drag, settle back into exact lockup when
  released. Hero only, once, and the settle has to be perfect.
- **A line drawing that builds itself.** An SVG technical illustration whose
  `stroke-dashoffset` is driven from scroll, so scrolling draws the object, then
  the dimension lines arrive, then the callouts. Pairs with the technical-drawing
  world in `worlds.md`.
- **A running ledger.** A small fixed panel that accumulates a line every time
  the visitor passes a claim, with real numbers, so the close arrives with the
  argument totalled. Only works with real figures, which is the check on it.
- **One control that regrades the whole page.** A time-of-day handle, a
  temperature, a load level: one input, and every image, ground and accent
  shifts together. It has to affect everything at once or it is a widget.

### What does not count

- A recoloured spotlight. A spotlight at a different radius. Two spotlights.
- `data-motion-rate="9"` instead of `6`. Any parameter change to any device.
- A different easing curve on an entrance.
- Five cards in the rail instead of three, or the rail travelling the other way.
- A third scrubbed section. More of a device is not a new device.
- Something the engine already does, given a project-specific class name.

**The test: describe the move to someone who has seen the other builds. If they
cannot tell it apart from something the library already does, it is not a
signature move.**

Record it in `demo/BRIEF.md` under `## Signature move`, in one sentence, before
building it. A move described after the fact is usually a device with a new name.

## 5. The fingerprint gate

The registry lives at `~/.claude/wp-builder/FINGERPRINTS.md`, one row per shipped
craft build. It is per-user and it starts empty: the gate is about not repeating
**yourself**.

**Before building:** read it. Every row is a shape that is now taken.

**Before writing markup:** check the planned build against every existing row on
these seven dimensions.

| # | Dimension | What it records |
|---|---|---|
| 1 | Grammar | Which grammar from `grammars.md`, or a named new one |
| 2 | Chrome treatment | What the header and footer are, and what they are for |
| 3 | Hero device | What the first screen does |
| 4 | Section-sequence shape | The composition order on the home page, the section count, total viewport-heights |
| 5 | Close pattern | How the last screen behaves and what the CTA sits in |
| 6 | Signature move | The one bespoke interaction, in a phrase |
| 7 | Type and palette | Display family, text family, accent hue |

**The gate: a new build must differ from EVERY existing row on at least
4 of the 7 dimensions.** Not 4 on average across the table — four against each
row, individually.

Dimension 6 is free, because a signature move is unique by definition. Dimension
7 has its own absolute rule on top of the count: a build fails outright when,
against any single row, **all three** of display family, text family and accent
hue within 15 degrees match. Two brands sharing a canvas and one of two faces is
coincidence; sharing the pair and the accent is the same site twice.

**A previous revision of this file kept only dimension 7 and dropped 1 through
6**, on the reasoning that the composition library chooses structure per role so
structure did not need fingerprinting. That reasoning was wrong in a way worth
recording: a library that offers one good answer per role will give every build
the same answer, and fingerprinting structure is precisely what catches that.
Cosmetic fingerprinting let two structurally identical sites pass because their
fonts differed.

**If the planned build fails the gate, change the plan, not the log.** Rewriting
a row to make a new build fit is the one thing that makes this file worthless. It
is a record of what exists, not a description of what you wish existed.

**After shipping:** append one row, all seven dimensions, and say plainly what it
shares with prior rows — the shared columns are what the next build has to avoid.

## 6. Aesthetic range

Premium-minimal is a choice. It is not the costume this skill wears by default,
and a shelf of dark-or-paper pages with one accent each is what happens when
nobody decides otherwise.

| Family | Reads as | Earned by |
|---|---|---|
| Brutalist | Blunt, structural, unstyled on purpose | Tools, infrastructure, anything anti-marketing |
| Maximalist | Dense, layered, loud, generous | Culture brands, events, food, anything abundant |
| Playful | Bouncy, coloured, informal | Kids, games, consumer apps, community |
| Retro | Specific to a decade, not vaguely nostalgic | Heritage brands, music, anything with a real lineage |
| Dense | Information-forward, small type, high count | Data products, catalogues, reference, finance |
| Editorial | Paper, folios, measure, restraint | Long-form substance |
| Premium-minimal | Quiet, dark, one accent, air | Luxury, and only when asked for |

Go where the brief points. **If the client says "loud" and the demo comes back in
charcoal with one accent, the interview was decorative.** The `surface
vocabulary` and `name the moving things` fields exist to make this answerable;
an answer recorded there binds over the default, as `SKILL.md` opens by saying.

**What does not flex:** the taste floor. Spacing scale and rhythm, type metrics
and measure, contrast measured on the render, motion built from compositable
properties, `:focus-visible` on everything, reduced motion that keeps meaning,
real copy and real numbers. Every item in `taste.md` holds in every family.

A brutalist page still needs 4.5:1 body contrast. A maximalist page still needs a
spacing scale, and needs it more, because density without rhythm is noise. A
playful page still cannot animate `top`. **The floor is what separates a chosen
aesthetic from a sloppy one**, and it is the reason offering range is safe at all.

Two traps stay banned in every family, because they are not aesthetics, they are
defaults with a look: the cream-and-brass artisan palette, and violet-to-blue AI
gradients. Both are what a page reaches for when nobody chose.
