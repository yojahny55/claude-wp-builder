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

Dispatch the `wp-tailwind` agent (@agents/wp-tailwind). It writes `<output-path>.tmp` and stops; this command verifies it in Step 4 and owns the move.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-tailwindify-run/references/dispatch.md` now and follow
it — it is this step, not background. It covers the context handed to the `wp-tailwind` agent (input and linked stylesheets, output path, the `<output-path>.tmp` write contract, Tailwind v4 colour rule, Preflight, bare element selectors, inclusive `max-width`, cascade layers) and why the agent never writes the output path directly.

## Step 4: Verify Output

After the agent completes, and before the temporary file is moved over the output path:

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-tailwindify-run/references/verify.md` now and follow
it — it is this step, not background. It covers the structural checks, the rendering parity gate (`bin/tailwindify-parity.mjs`), the `\mv -f` move with its post-condition check, and the report.

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
