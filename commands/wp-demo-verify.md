---
description: Scroll-walk a demo or live page, screenshots per section at every viewport, machine findings, and a contact sheet to read
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<file-path-or-url> [--positions N]"
---

# WP Demo Verify

A scroll page has no single state. Every scroll position is a different frame, and
the failures live between the two you happened to look at. This walks the page
mechanically, then hands you a contact sheet, because the half that matters is the
half a machine cannot grade.

## Step 1: Resolve the target

`$ARGUMENTS` is a file path or a URL. Default to `demo/index.html`. A URL lets this
run against the converted WordPress page, which is the only way to prove the motion
survived conversion. Serve files over HTTP when the page fetches anything; a
`file://` page silently falls back and proves nothing.

A directory (`demo/`) walks every `*.html` in it, one output folder per page
under `demo/.verify/<page>/`, and `findings.json` carries a `pages[]` array. Craft
builds always pass the directory: interior pages are where a build is emptiest.

`node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" --probe` answers only "can this
machine render?": exit 0 with the Chrome path, exit 2 with what is missing. `/wp-demo`
runs it as the craft gate before writing any markup.

## Step 2a: Detector

```bash
npx impeccable@1 detect <target> --json > <dir>/.verify/impeccable.json
```

`impeccable` is an external package this repo does not install, vendor or
configure — it is fetched from the npm registry at run time via `npx`. Pin the
major version (`@1`) so a future major release cannot silently change rule
identifiers or output shape underneath this gate.

Check the exit status and the output before reading it as findings: if `npx`
could not resolve or run the package — command not found, no network reaching
the registry, or the captured output does not parse as JSON — the detector did
not run at all. Report **"detector could not run"** and fail the round on that
basis; this is not the same as zero findings, and must never be read as one.

Once the JSON is confirmed to have parsed, sixty-one deterministic rules, no
model: any finding with severity `P0` fails the round outright, before a
screenshot is taken. P1 and P2 findings are listed in the report and fixed when
the rubric below also flags the section. A target that is a URL is scanned with
Puppeteer by the detector itself; a file or directory is scanned statically.

## Step 2b: Walk it

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" <target>
```

Six positions per section at 1440x900 and 390x844, plus a reduced-motion pass at
desktop width, then full-page shots at 375, 576, 768, 1024 and 1440 (this replaces
`/wp-responsive-check`). A directory target walks every page. Output lands in
`<dir>/.verify/[<page>/]<width>/`, with `findings.json` and one `sheet.png` per
width.

Exit codes: `0` no machine findings, `1` findings printed, `2` no usable browser,
`3` the walk itself crashed (not a findings report, something threw mid-walk).

**On exit code 2**, fall back in this order: the Chrome or Playwright MCP
screenshot tools if either is connected, then ask the user for screenshots at the
five viewports. Say which route you used. (A craft build never reaches this
branch: `/wp-demo` probes first and stops on 2.)

## Step 3: Read the findings

- **dead scroll**: consecutive positions where nothing changed. Shorten the
  section's span or add a cue. Authored silence recorded in `demo/BRIEF.md` is not
  dead scroll; say so instead of "fixing" it.
- **cue never reaches full opacity**: the window is too narrow or the ramps eat
  it. Widen the window or set explicit ramps.
- **horizontal overflow**: at any width, always a defect.
- **clipped copy**: text taller than its own hidden-overflow box.

## Step 4: Critique the sheets

Read only the sheets for this step: not the source, not `demo/BRIEF.md`. Score
every page pass/fail on each line and write the table to `demo/VERIFY.md`
(one section per page, one row per line, a one-sentence reason on every fail):

- **First paint complete.** Headline, primary visual and CTA inside the 1440x900
  fold and the 390x844 fold, none hidden behind a scroll trigger.
- **One peak.** The largest visual change on the page, a quieter section before
  it, the most scroll room.
- **Squint test.** Blurred, the primary, secondary and major groups are still
  nameable in order.
- **Measured contrast.** Body 4.5:1, large 3:1, controls and focus 3:1, sampled
  from the frame.
- **Mobile headline.** Three lines or fewer at 390; nothing wider than the
  viewport.
- **Adjacent feelings.** One word per section, written cold (the feel check); no
  two adjacent words the same. Only now open `demo/BRIEF.md` and diff the
  curves.

## Step 5: Report

State the machine findings, the intended curve, the felt curve, the diff, what you
changed, and what could not be verified (composited contrast is judged by eye here,
and headless Chrome cannot prove a real phone).

**A green machine run alone is not a pass.** A green detector run and a green
walk with a failing rubric is a failing round.
