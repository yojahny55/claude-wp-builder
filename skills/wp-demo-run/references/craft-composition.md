# /wp-demo — Step 2.6

`commands/wp-demo.md` sends the run here at Step 2.6, item 5 (Grammar, then composition plan). Follow it in order; nothing in it is optional background.

## Contents

- The grammar, then the composition plan
- Where the form answers from 3a bind
- Reading the composition column down
- 5.4. The family, the signature move and the world
- 5.5. Image plan, and where the key comes from

Pick one grammar from
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/grammars.md` — it
decides what a section is, what the chrome is for and what the ending does.
Then open
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/compositions/README.md` and look at
each candidate's `preview-1440.png` and `preview-390.png`.

**The form answers from sub-step 3a bind here.** `draw, don't write` names the
facts that must become a composition rather than a paragraph — reach for a role
that draws them, and say in the row which answer it serves. `text density` sets
how much copy each slot carries. `motion appetite` and `microinteraction
appetite` set how far the element motion goes. A row that contradicts a recorded
answer is a defect, not a judgment call: the operator was asked, and answered.

**Read the plan's composition column DOWN before building.** No two pages may
share their whole composition sequence, and the index's sequence may not be a
superset of an interior page's — `references/uniqueness.md` §2. Two pages
sharing a header and a footer is a site; two pages sharing their middle is a
template, and "all the pages are almost the same thing" is what that gets
reported as. An about page, a services page and a contact page have three
different jobs — a story, a comparison, a transaction — so three identical
sequences means the jobs were never read.

**Landing on the default grammar costs one sentence per grammar rejected**
(§3). The default is whichever one a build drifts into when nobody chooses,
and four builds in a row looking related is what that drift produces.

**The plan covers every page in the agreed set, not only the index.** Write the
index's rows from the curve, then a short block of rows per interior page. This
is the step where an interior page stops being an afterthought: a build that
plans nine compositions for `index.html` and none for the other eleven writes
those eleven from one hand-rolled template, and the result is a page set whose
interior is a content management system's default output wearing the index's
typeface. The floor per interior page is in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/compositions.md` — a
`page-head` and one body composition, with chrome not counting — and the motion
floor is in `references/devices.md`. Do not restate either here.

One row per section, for each page: section, role, composition, why, motion cost,
the domain signal that justified it, citing the brief constraint from
sub-step 4, or writing "no domain signal" when none applies; and the
research signal — what `demo/RESEARCH.md`'s `## Signals` says this
sector does at this point in the page, and whether this row follows it
or breaks it — or "no research signal" when none applies. The two are
different axes: the domain signal constrains page pattern and
considerations, while the research signal is what lets a build
deliberately not look like its competitors. This is
what makes sub-step 4's classification bind on the plan instead of
sitting unread. Mark exactly one row as the peak (`data-motion-peak`).
Sum the cost and hold it under the
budget in `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/devices.md`,
which owns the pin caps, the per-index total, and the interior-page floor and
ceiling both. Sum per page, not across the set: the index's allowance is the
index's, and an interior page does not borrow from it. When
the docs name no reference and the Landing Gallery MCP is connected, pull
four screenshots for the page kind first; when it is not, say so and choose
from the previews alone.

**5.4. The family, the signature move and the world.** All three are
recorded in `demo/BRIEF.md` before the first section is built, not after.

The **family** is the interview's `aesthetic family` answer, made binding:
one of the seven in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/families.md`,
recorded under `## Family` with that family's **Avoid list copied verbatim**
beneath it. From here on the composition plan, `demo/DESIGN.md` and every
section obey the family's Type, Palette, Surfaces and Motion lines, and step
7's verify reads every page against the Avoid list before the rubric — a hit
is a ship blocker, not a graded line. Premium-minimal is recorded only with
the client's own word for it beside the heading; it is the family the skill
drifts to when nobody chose, and the drift is what "generic" means.

The **signature move** is one bespoke interaction that exists on this site
alone — `references/uniqueness.md` §4 lists what counts and what does not. A
parameter change to a library device is not one; neither is an existing device
under a project-specific class name. The test is whether someone who has seen
the other builds could tell it apart. **A move described after the build is
usually a device with a new name**, which is why it is written down first.

The **world** is one style preamble chosen from
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/worlds.md`, recorded
verbatim under `## World`. It is written **there and nowhere else**:
`image-gen.mjs` reads that block and prepends it word for word to every
image prompt this build sends, so it is never pasted by hand into a prompt.
Reusing it verbatim is what makes separately generated plates look like one
shoot; paraphrasing it is what makes them look like eight prompts, which is
why the reuse is done by code. Every shot's `SUBJECT` then also names **where
the empty space is** — copy sits on these images, so the space is generated,
never cropped in afterwards.

The hero is layered by default:
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/hero-depth.md`. A
full-screen photograph with one parallax transform and a text fade is the flat
hero that file exists to prevent.

**5.5. Image plan.** Craft builds only, and only when the composition plan
includes a composition that declares an image slot (`hero-split`,
`hero-bleed`, `feature-zigzag`). Skip in one line otherwise.

`image-gen.mjs plan` builds `gaps[]` from `sections[] × slotsOf(composition)`, so a
**hand-built section has no path to a plate through `plan`**. That is the supported
escape hatch, not a dead end: append the gap entries by hand to
`demo/.image-plan.json` — same shape, `slot`, `aspect`, `size`, and exactly one of
`prompt` or `use` — and call `run`, which reads `plan.gaps` as written. A bespoke
section that needs an image is a normal outcome of building a role the table does
not cover; it should not have to become a composition to get one.

Then decide whether to generate, in this order. **Neither `GEMINI_API_KEY`
nor `OPENAI_API_KEY` is set in the environment** — generate nothing, say so
in one line, and go to step 6. No question is asked, because there is
nothing to spend and nothing to decide, so a project that never opts in
behaves exactly as it does today. Otherwise, **`.wp-create.json` already has
`"image provider"`** — read it and use it; a value of `"none"` records an
earlier decline and is handled exactly like the no-key branch above:
generate nothing, say so in one line, go to step 6, and do not ask again.
Otherwise, **a key is set, gaps exist to fill, and the line is absent** —
ask once, offering the provider matching whichever key is present —
`google/gemini-3.1-flash-image` for `GEMINI_API_KEY`, or `gpt-image-2.5-flare`
(faster, cheaper) / `gpt-image-2.5-sunburst` (higher quality) for
`OPENAI_API_KEY` — and recommending `google/gemini-3.1-flash-image` when both
keys are present, because Google offers all three of the library's crops
(4:5, 3:2, 4:3) exactly while OpenAI's three fixed sizes make every one of
them inexact. Write the
operator's answer into `.wp-create.json` as `"image provider":
"<vendor>/<model>"` on a yes, or `"image provider": "none"` on a decline —
a decline then goes to step 6 exactly like the no-key branch above — so no
later run re-asks.

Write `demo/.image-plan.json` from this step's own composition table and
step 3.5's asset inventory:

```json
{
  "provider": "google/gemini-3.1-flash-image",
  "sections": [{"page": "index", "section": "hero", "composition": "hero-bleed"}],
  "assets_on_disk": [{"path": "docs/logo.png", "role": "logo"}]
}
```

Then run the planner, which makes no network call and needs no key:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" plan --demo demo/
```

It fills in `gaps[]` — one per image slot, each with the aspect and size read
off that composition's own `<img>` tag — and `unused_assets[]`.

For each gap set **exactly one of `prompt` or `use`**; the script refuses a
plan where a gap has both or neither, before it issues any request. Set `use`
to a path from `unused_assets[]` when a real client file belongs in that slot
— a real asset always wins and is never generated. Otherwise write a `prompt`
from the brief: the person, the pain, the vibe words, the domain, and
**the vocabulary from `demo/RESEARCH.md`'s `## Signals`** — its "use"
terms and none of its "avoid" terms — not a generic stock description.
A plate built from sector filler looks like the sector it was meant to
stand out from.

**The `prompt` is the `SUBJECT` line only**, per
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/image-prompt.md`.
The script composes the rest around it from files this step has already
written — the `## World` block from `demo/BRIEF.md`, a `FORMAT` line from
the gap's aspect, a `COLOUR` line from `demo/DESIGN.md`'s canvas, ink and
accent, and a fixed `NEGATIVE` line (no text, no logos, no UI) — and writes
the result onto each gap as `prompt_sent`. Do not repeat the world, the
palette or the lens in the `prompt`; name the shot and where its empty space
is. `prompt_sent` is what the plan shows, what a yes authorises, what is
hashed for the cache, and what the `gen-<hash>.json` sidecar records (and so
what `## Generated images` in `demo/BRIEF.md` summarises) — so a
later edit to `DESIGN.md`'s accent regenerates every plate, correctly.
The script does not match assets to slots itself,
on purpose: the asset roles (`logo/hero/portrait/product/texture`) and the
composition roles (`hero/proof/feature/...`) are different vocabularies, and
`feature-zigzag` has two slots of identical role, so any automatic mapping
would be invented.

Show the table the planner printed and ask once. **Costs are estimates, not a
bill.** A yes on that table is the authorisation for the whole plan; do not
ask again per image. On a no, edit the prompts in `demo/.image-plan.json` and
re-run `plan` — an edited prompt changes its hash, so it regenerates rather
than serving the previous plate.

On a yes:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" run --demo demo/
```

**The key comes from the environment and nowhere else.** It is never pasted
into chat, never written into `.wp-create.json`, never echoed into a log or
into the demo. With plates to generate and no key set, the script exits 3
having written nothing and billed nothing, and names the variable to export
(`GEMINI_API_KEY` or `OPENAI_API_KEY`). That is a stop, not a fallback: there
is no placeholder path, and step 6's `{{`-blocker still refuses the page.

Exit 2 before any request means the plan was refused: a gap with both or
neither of `prompt`/`use`, **or a `prompt_sent` that no longer matches the
one the plan showed** — `demo/DESIGN.md` or `demo/BRIEF.md ## World` was
edited after the yes, so the text that would be billed is one nobody
approved. Re-run `plan`, show the new table, ask again.

Exit 4 means some slots failed while others succeeded. Plates already
generated are kept and will not be re-billed on the next run.

Append a `## Generated images` section to `demo/BRIEF.md`, summarised from
the `gen-<hash>.json` sidecars on disk, naming the model, the date, the
estimated total, and — for Google — that every plate carries an invisible
SynthID watermark identifying it as AI-generated. Entries filled from `use`
are real client files: list them separately, never as generated.
