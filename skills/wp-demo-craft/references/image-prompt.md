# Image prompts

Adapted from [MengTo/Skills](https://github.com/MengTo/Skills)
`agent-skills/ui/design-first-ui-prompting` (MIT): *prompt like a design system,
not a wish*. The skeleton below is what every plate prompt this build sends
looks like. Half of it is written by the build; the other half is composed by
`bin/image-gen.mjs` from files the build has already written, so it cannot be
forgotten, paraphrased or left out of one plate.

## The skeleton

```
<world preamble — BRIEF.md ## World, verbatim>
SUBJECT: <the shot: who, what, the domain's own objects, where the empty space is>
FORMAT: <aspect> background plate; page copy is set over it, so the named empty space stays clear and quiet.
COLOUR: canvas <hex>, ink <hex>, one accent <hex> only - grade toward these; no other saturated colour.
NEGATIVE: no text, no letters, no words, no numerals, no logos, no watermark, no UI, no screens showing type. Never stock-photo styling.
```

## Who writes what

| Line | Written by | Read from |
|---|---|---|
| world | `image-gen.mjs` | `demo/BRIEF.md` `## World` — the block under that heading, blockquote markers stripped |
| `SUBJECT` | **the build**, as the gap's `prompt` in `demo/.image-plan.json` | `demo/BRIEF.md` (person, pain, vibe words), `demo/RESEARCH.md ## Signals` ("use" terms, none of the "avoid" terms) |
| `FORMAT` | `image-gen.mjs` | the gap's own aspect, read off the composition's `<img>` tag |
| `COLOUR` | `image-gen.mjs` | `demo/DESIGN.md` front matter: `colors.canvas`, `colors.ink`, `colors.accent` |
| `NEGATIVE` | `image-gen.mjs` | fixed |

The build writes **`SUBJECT` and nothing else**. `plan` shows the composed text
as `prompt_sent` on each gap; that is what a yes on the plan authorises, what is
hashed for the cache, and what `BRIEF.md` records per plate. Editing
`DESIGN.md`'s accent therefore regenerates every plate — correctly, since every
plate was graded to the old one.

When `DESIGN.md` or `## World` is missing the script says so on one line and
composes without that part. It never refuses: a plate without a palette line is
weaker than one with it, and still better than no plate.

## The two rules carried over

**One accent only.** The model grades toward the colours it is told. Three
named colours (canvas, ink, one accent) give it a grade; five give it a rainbow.
`DESIGN.md` has `surface`, `ink-soft`, `accent-ink` and `hairline` too — they
are deliberately not sent. They are UI tokens, not photographic ones.

**Generate without text.** Copy is set in HTML, over the plate. A plate that
carries letters carries misspelled letters, in the wrong face, at the wrong
size, under the real headline. The `NEGATIVE` line is fixed for that reason and
is not a place for the build to add sector-specific avoid terms — those belong
in `SUBJECT`, phrased positively ("honest imperfect surfaces", not "no fake
smiles"), because a generator reads a long negative list as a list of things to
draw.

## Writing the SUBJECT

Name **where the empty space is**. Copy sits on these images, so the space is
generated, never cropped in afterwards: "subject on the left third, the right
two thirds open wall in shadow" is a usable plate; "a joiner at a bench" is a
photo with a headline stamped over the joiner's face.

Name the domain's **own objects**, from `RESEARCH.md`'s "use" terms. A plate
built from sector filler looks like the sector it was meant to stand out from.

Bad — sector filler, no space, invites text:
> professional credit repair consultant helping a happy client, modern office,
> documents and a laptop showing a rising credit score chart

Good — the person, the pain, the objects, the space:
> a woman at her own kitchen table at 7am, one lamp, a stack of opened
> envelopes squared neatly to the table edge, her hand flat on the top one;
> she fills the right third, the left two thirds are the dark room

The world already says how it is lit and shot. Do not repeat the lens, grade or
film stock in `SUBJECT` — the preamble carries those, verbatim, for every plate.
