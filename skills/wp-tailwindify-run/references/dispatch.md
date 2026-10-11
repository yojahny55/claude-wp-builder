# /wp-tailwindify — Step 3

`commands/wp-tailwindify.md` sends the run here at Step 3 (Dispatch Conversion Agent). Follow it in order; nothing in it is optional background.


Dispatch the `wp-tailwind` agent (@agents/wp-tailwind) with the following context. The
temp-path contract belongs in the context you actually hand the agent, not only in the
paragraph below it — an agent that only reads these bullets must still get it right.

- Input file path: `<demo-file-path>`
- Conversion source: that file **and** every project-local stylesheet it links. Resolve
  each `href` against the demo file's own directory and read it — a linked rule is as
  much conversion source as an inlined `<style>` block, and Step 4 item 4 requires the
  `<link>` to be gone from the output, so its rules have to be accounted for first.
- Resolved output path (`<output-path>`): the `--out` value when given, otherwise
  `<demo-dir>/index-tailwind.html` (alongside the original). This is the destination, not
  the file the agent writes.
- **What the agent writes: `<output-path>.tmp`, never `<output-path>` itself.** The agent
  writes `<output-path>.tmp` and stops there. It does not move, rename or delete
  `<output-path>`, and it does not verify its own work — this command owns Step 4's
  verification and owns the move.
- Project CLAUDE.md path (if exists): for @theme color mapping
- **Target version: Tailwind v4** (the `__tailwind__` starter's `package.json` pins
  `^4.1`). A v3 habit compiles to nothing or to the wrong value here: the gradient
  utility is `bg-linear-to-r`, not `bg-gradient-to-r`, and the built-in palette is
  OKLCH, so `gray-300` is `#d1d5dc` — a demo that declared `#d1d5db` is *not* that
  class. Colour rule: **exact match or arbitrary value.** Use a scale name only when
  its value equals the demo's declared value byte for byte; otherwise keep the demo's
  literal (`border-[#d1d5db]`), and if the value came from a `:root` custom property,
  map it to a `@theme` token and reference it by name. Never round a declared value
  onto a near neighbour because the class name reads right.
- **Preflight moves the UA baseline, so a faithful conversion still renders
  differently.** Compiled Tailwind ships a reset the demo never had: `button` inherits
  the page font instead of the UA's ~13.33px Arial, `img` becomes `display:block;
  max-width:100%`, `p` and headings lose their UA margins, and a bare `<a>` loses its
  underline. Translating every declaration correctly and adding nothing leaves the
  page wrong at the end. Re-add, as a utility on the element, each UA value the demo
  was relying on. Read `skills/wp-tailwind-system/SKILL.md` § "Preflight" — it carries
  the measured list — before translating.
- **Bare element selectors have to land somewhere.** `a { … }`, `h1, h2, h3 { … }`,
  `body { … }` and `*, *::before, *::after { … }` carry real declarations and have no
  class to hang them on. Distribute each one onto every element it actually reaches,
  as utilities; keep it as a rule in the theme's `base` CSS only when it reaches
  markup the demo does not contain (WordPress-generated output). To decide whether a
  bare selector is dead, read the markup and check the elements, never the stylesheet:
  it is dead only when every element it matches already carries a class that sets the
  same property. A logo `<a>` with no class is the case that has already been missed.
  **Not an exception**, even though it reads like one: `*, *::before, *::after {
  box-sizing: border-box }` and `img { max-width: 100%; display: block }` are things
  Preflight already sets, in its own `base` layer — drop them, never duplicate them.
- **A demo's `max-width: Npx` is inclusive; Tailwind's `max-*` is exclusive.**
  `max-width: 768px` in the demo matches width 768 itself; `max-md:` compiles to
  `width < 768` and does not. The two most common desktop-first stops a demo
  declares, 768 and 1024, are exactly where this bites. Convert `max-width: Npx` to
  `max-[N+1px]:`, or redeclare the named breakpoint in `@theme` as `N+1` when the
  project uses that stop by name (`--breakpoint-md: 769px;`). `min-width` is already
  inclusive on both sides and needs no adjustment. Read
  `skills/wp-tailwind-system/references/breakpoints.md` § "`max-width: N` in the demo is INCLUSIVE" —
  and re-measure the layout AT 768 and AT 1024 after converting, not only at the
  sweep's far corners.
- **Every hand-written CSS file this conversion writes into is imported with its
  cascade layer**, not a bare `@import`: `base/` → `layer(base)`, `components/` and
  `layouts/` → `layer(components)`, `utilities/` → `layer(utilities)`. An unlayered
  import beats every Tailwind utility regardless of specificity or source order —
  the starter's own default imports already carry this; extend the same pattern to
  any file this conversion adds to `main.css`.

**Never write the output path directly — write a temporary path and move it.** The agent
writes the converted HTML to a temporary path (`<output-path>.tmp`) and stops. **This
command**, not the agent, moves it over the output path **only after** Step 4's
verification passes on the temporary file: section delimiter count preserved, no
`<style>` blocks remaining, no project-local stylesheet `<link>` remaining. If
verification fails, discard the temporary file and leave the output path exactly as it
was.

The agent cannot own that move even in principle: Step 4 runs here, in the command, after
the agent has returned, so the agent has nothing to condition on.

This is a mechanism, not an exhortation, and the in-place case is why it has to be one.
Under it the agent never overwrites its own input, even when `--out` names that input: it
reads `<output-path>` and writes `<output-path>.tmp`, which are different files.
An interrupted write leaves a truncated `.tmp` nobody reads, which costs nothing. An
interrupted write straight onto `demo/<slug>.html` destroys the page with no recovery
path. `/wp-yolo` Step 2.6's detect step then reads the truncated remains, sees utility
classes and no project stylesheet, declares the page already Tailwind-native and skips it
on every later run.
