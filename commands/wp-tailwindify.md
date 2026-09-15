---
description: Convert an HTML/CSS demo to Tailwind-native HTML — preserves section delimiters, maps colors to @theme variables
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[path/to/demo.html] [--out <output-path>]"
---

# WP Tailwindify — Convert Demo to Tailwind

Convert a standard HTML/CSS demo file into Tailwind-native HTML.

## Step 1: Locate the Demo File and Resolve the Output Path

Parse `$ARGUMENTS`:
- **First non-flag word** = the input demo file.
  - If it is provided and is a file path, use that file.
  - Otherwise, check for `demo/index.html` in the current working directory.
  - If no demo file found, ask the user for the path.
- **`--out <output-path>`** = where to write the converted HTML (optional). When
  omitted, the output path defaults to `<demo-dir>/index-tailwind.html` — the original
  behavior, unchanged for standalone/manual use.

`--out` may name the input file itself. That is a deliberate **in-place conversion**:
the caller is responsible for having kept a backup first (this is how `/wp-yolo`
Step 2.6 uses the command — it copies `demo/<slug>.html` to `demo/.original/<slug>.html`
and then converts `demo/<slug>.html` onto itself, so every downstream reader that names
`demo/<slug>.html` picks up Tailwind-native markup with no argument change).

Verify the input file exists and is an HTML file.

## Step 2: Read and Validate

Read the demo HTML file. Check:
- **Is it already Tailwind-native?** Absence of `<style>` blocks does not settle that — a
  plain-CSS demo can keep every rule in a linked stylesheet. Count a `<style>` block, a
  static `style="` attribute **or** a `<link rel="stylesheet">` pointing at a
  project-local `.css` file as plain CSS to convert. Treat the demo as already
  Tailwind-native only on positive evidence: `class` attributes that are predominantly
  Tailwind utilities (`flex`, `px-4`, `text-lg`, `md:`) and no project stylesheet. If it
  is ambiguous, convert — confirm with the user first when running standalone.
- Does it have section delimiters? (Warn if missing — suggest running `/wp-polish` first.)

## Step 3: Dispatch Conversion Agent

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

## Step 4: Verify Output

After the agent completes, and **before** the temporary file is moved over the output
path:
1. Read the temporary file the agent wrote
2. Verify section delimiters are preserved (count should match original)
3. Verify no `<style>` blocks remain (except `@keyframes`)
4. Verify no project-local stylesheet `<link>` remains. Only `fonts.googleapis.com`,
   `fonts.gstatic.com` and `cdn.tailwindcss.com` links may survive the conversion; a
   `<link>` to any other `.css` file means the demo's own stylesheet is still attached,
   the page is not Tailwind-native, and `/wp-yolo` Step 2.6 will re-convert it on every
   later run because a linked project stylesheet is plain-CSS evidence.
5. **Verify what it RENDERS, not only what it contains.** Items 2-4 are structural: a
   page can pass all three and still have lost a declaration. One did. The demo's reset
   read

       button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}

   and the conversion dropped the whole line as covered by preflight. Preflight covers
   five of those six declarations and NOT `cursor` — Tailwind v4 leaves buttons on the
   UA default, which is `default`. Every button on the site lost its pointer. Nothing
   downstream could catch it either, because every later gate compares the theme against
   the CONVERTED demo: once a declaration is gone from the reference, both sides agree
   and the site is wrong. **This is the only point in the pipeline where the original is
   still available to compare against.**

   ```bash
   node <plugin>/bin/tailwindify-parity.mjs <converted> --against <original> \
        --widths 1440x900,390x844
   ```

   It renders both and joins leaf elements on tag + text — the two use different class
   systems, so a selector join is impossible, but they render the same words. Exit 0
   clean, 1 deltas, 2 no usable browser (not a failure: say the gate could not run), 3
   crashed. Findings grouped by property, because a dropped reset shows up as the same
   property on many unrelated elements, and that shape is the diagnosis.

   **Run it where the converted page renders.** Conversion strips the demo's stylesheet
   and adds no replacement (see Step 5), so unless the demo carries its own Tailwind
   runtime the converted page is bare HTML and there is nothing to compare — the gate
   detects that shape and says so rather than reporting every element as a delta. On the
   `/wp-yolo` path, run it once after Step 2.6 has converted every page. A delta the gate
   reports is not automatically a defect: `oklab()` for a colour with an opacity modifier
   and `rgba()` for the same colour are the same pixels, and the gate already resolves
   both through a canvas, but a `visually-hidden` heading that no one can see is still
   going to differ. Read them; do not paste them.
6. Only if 2, 3, 4 and 5 all hold — or 5 exited 2 and you reported that the rendering
   gate could not run — move the temporary file over the output path. Otherwise
   discard it, leave the output path untouched, and report the conversion as failed —
   never a partial success.
7. **Move with `\mv -f`, then prove the move happened.** An interactive shell aliases
   `mv` to `mv -i`; the prompt goes unanswered, the file is not moved, and the command
   still exits 0 — a whole demo folder has already been "converted" this way, three
   pages left untouched with three orphan `.tmp` files beside them and every page
   reported as a success. The leading backslash bypasses the alias and `-f` answers the
   prompt. Then check the post-condition before reporting anything for this page:
   `<output-path>.tmp` no longer exists **and** `<output-path>` now holds the converted
   markup (the delimiter count from item 2, no `<style>` block, no project-local
   stylesheet `<link>`). If the `.tmp` is still on disk, the move did not happen: report
   the page as failed, not converted. A page whose post-condition was not checked is
   never reported as converted.
8. Report the conversion result to the user

## Step 5: Offer Next Steps

**The converted file is an intermediate artifact, not a viewable page. Do not tell the
user to open it in a browser.** Conversion strips every `<style>` block and every
project-local stylesheet `<link>` (Step 4, items 3 and 4) and adds no replacement, so
the converted demo renders as **unstyled HTML** — correct markup, correct utility
classes, no CSS to resolve them. Its styling arrives later, when the theme is built and
its Tailwind source is compiled to `assets/css/dist/main.css`. Say so in the report, so
the unstyled page reads as expected output rather than as a failed conversion.

```
=== Demo Converted to Tailwind ===
Original:  <original-path>
Tailwind:  <output-path>
Sections:  <count> preserved

This file renders UNSTYLED in a browser — that is expected. The conversion removed
the demo's CSS and replaced it with utility classes, which only resolve once the
theme's Tailwind build compiles them. Review the class attributes against the
original; keep the plain-CSS original as the visual reference.

Next steps:
- Diff <output-path> against the original to review the conversion
- If satisfied, replace the original: cp <output-path> <original-path>
- Run /wp-init to scaffold the project with the Tailwind template
```

When `--out` pointed at the input file, the conversion was in place: `<original-path>`
and `<output-path>` are the same file, so drop the "replace the original" line — there
is nothing left to copy. The visual reference is then the caller's backup — under
`/wp-yolo` Step 2.6 that is `demo/.original/<slug>.html`.

**Why the conversion does not emit a runtime stylesheet to make the page viewable.**
Two candidates exist and both cost more than they return. `cdn.tailwindcss.com` is the
**v3** runtime: it is still exempted as a surviving `<link>` in Step 4 item 4 for demos
that arrive carrying it, but it cannot compile v4 syntax and would not resolve a
`@theme` token such as `bg-primary` at all, so it renders a page that is wrong rather
than unstyled. `@tailwindcss/browser@4` is the v4 equivalent and does compile, but the
converted markup leans on the project's own `@theme` tokens (`bg-primary`,
`font-primary`), which the runtime can only see from an inline
`<style type="text/tailwindcss">` block — and a `<style>` block in the output is
precisely what Step 4 item 3 forbids and what `/wp-yolo` Step 2.6 reads as plain-CSS
evidence, so every converted page would be re-converted on every later run. A preview
that costs the idempotence of the whole conversion step, and that still differs from the
compiled theme, is not worth an unstyled page's honest report.
