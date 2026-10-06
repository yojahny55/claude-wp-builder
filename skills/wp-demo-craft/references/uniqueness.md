# The structure axis

Ported from [nateherkai/scroll-craft](https://github.com/nateherkai/scroll-craft)
`references/uniqueness.md` (MIT), adapted for multi-page WordPress demos. Read it
after the brief interview and before the composition plan.

## Contents

1. The template trap
2. Two axes of sameness, and this plugin has both
3. The default grammar carries a burden of proof
4. The signature move
5. The fingerprint gate
6. Aesthetic range

## 1. The template trap

The source skill's author built four sites with it — a protein coffee brand, a
personal brand, a landscape design-build firm, an observability product — and
his owner looked at them side by side and said they felt like a template. He was
right, and the evidence was in the files: all four opened full-bleed under a
fixed minimal bar, all four anchored the headline in the lead corner, all four
closed on a pinned stage with a magnetic CTA, all four landed between 13.6 and
13.8 viewport-heights with exactly one accent colour. What varied was the order
of the middle sections and the palette.

**This plugin inherited that failure.** Porting only the constraints — the taste
floor, the feeling curve, the device kit — and leaving out the three systems that
make two builds different from each other produced exactly the report it predicts:
*"all the pages are almost the same thing."*

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
Built in the page, with CSS of its own or a small script reading `--motion-p`; the
script goes in its own `<script id="signature">` block, which `/wp-init` lifts to
`assets/js/signature.js`. The engine stays untouched, always.

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

Every build clears the fingerprint gate against every earlier build, on structure as
well as on palette. The registry, the seven dimensions and the 4-of-7 rule are in
`fingerprint.md`, which owns the gate; it is read before the composition plan and
written after shipping.

## 6. Aesthetic range

Premium-minimal is a choice. It is not the costume this skill wears by default,
and a shelf of dark-or-paper pages with one accent each is what happens when
nobody decides otherwise.

There are seven families — Brutalist, Maximalist, Playful, Retro, Dense, Editorial and
Premium-minimal — and `families.md` says, for each, what it reads as, who earns it, what
it **does** (type, palette, surfaces, motion, sequence) and what it forbids. The chosen
family is recorded in `demo/BRIEF.md` under `## Family` with its Avoid list, and an
Avoid hit on any page is a ship blocker.

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
