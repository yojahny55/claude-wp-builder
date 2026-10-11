---
description: Verify a demo directory, page or live URL — impeccable detector, scroll-walk screenshots per section and viewport, machine findings, and a seven-line critique written to demo/VERIFY.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<demo-dir-or-file-path-or-url> [--positions N] [--no-motion]"
---

# WP Demo Verify

A scroll page has no single state. Every scroll position is a different frame, and
the failures live between the two you happened to look at. This walks the page
mechanically, then hands you a contact sheet, because the half that matters is the
half a machine cannot grade.

## Step 1: Resolve the target

`$ARGUMENTS` is a file path or a URL. Default to `demo/index.html`. A URL lets this
run against the converted WordPress page, which is the only way to prove the motion
survived conversion. A local file or directory is always served over HTTP on an
ephemeral `127.0.0.1` port rather than opened as `file://`: an external
`<script type="module">` is a cross-origin fetch against an opaque `file://`
origin, Chrome blocks it silently, and the engine never boots — every page then
reports dead scroll with no trace of why.

A directory (`demo/`) walks every `*.html` in it, one output folder per page
under `demo/.verify/<page>/`, and `findings.json` carries a `pages[]` array. Craft
builds always pass the directory: interior pages are where a build is emptiest.

`node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" --probe` answers only "can this
machine render?": exit 0 with the Chrome path, exit 2 with what is missing. `/wp-demo`
runs it as the craft gate before writing any markup.

## Step 2a: Detector

```bash
npx -y impeccable@4 detect <target> --json > <dir>/.verify/impeccable.json
```

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-verify-run/references/detector.md` now and follow
it — it is this step, not background. It covers the detector's exit codes and what counts as "detector could not run", the `slop` plus `warning` gate, advisories and `quality` findings.

## Step 2b: Walk it

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" <target>
```

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-verify-run/references/walk.md` now and follow
it — it is this step, not background. It covers the viewports and positions walked, the Firefox pass, `--no-motion`, the output layout, fractional widths and `--no-gaps`, and the fallback on exit code 2.

Exit codes: `0` nothing blocking — either no findings at all, or advisory ones
only; `1` at least one blocking finding printed; `2` no usable browser; `3` the
walk itself crashed (not a findings report, something threw mid-walk).

## Step 3: Read the findings

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-verify-run/references/findings.md` now and follow
it — it is this step, not background. It covers every finding kind the walk reports (dead scroll, `unobserved`, `no-engine`, `container-noop`, `external-module`, cue opacity, horizontal overflow, breakpoint-gap, clipped copy) and which ones block a round.

## Step 3.5: Undeclared inert controls

A directory target only. Read `inert[]` from `demo/.demo-plan.json` (absent file: skip
in one line — a demo from elsewhere declares nothing) and find every control the pages
fake:

```bash
bash -c "grep -n 'href=\"#\"\|<form\( [^>]*\)\?>' demo/*.html | head -40"
```

**Grade the declaration, never the control.** A control that appears in `inert[]` is
silent; one that does not is a finding — `<name> on <page> looks interactive and is
not wired; declare it in the plan's inert[] or wire it`. A `<form>` with no `action`
counts; an in-page `href="#"` that a script binds does not, so check for a handler
before reporting one.

Failing the control itself would fail every honest mockup, and the first time it fired
on a deliberate one someone would write `href="#!"` to silence it. A rule people route
around is worse than no rule. Grading the declaration inverts that: the cheap way out
is to declare it, which is the outcome wanted.

This does not block a round. It is reported with the advisory findings, because an
undeclared inert control is a gap in what the demo *says*, not a defect in what it
renders — and the same gap reaches the theme either way, where `/wp-yolo` Step 4.6
picks the list up.

## Step 4: Critique the sheets

Read only the `sheet.jpg` files for this step — never `sheet.png` — and never the
source or `demo/BRIEF.md`. Score every page pass/fail on each line and write the
table to `demo/VERIFY.md` (one section per page, one row per line, a one-sentence
reason on every fail):

**More than ~3 sheets: dispatch, don't Read.** A directory target produces one
`sheet.jpg` per page per width (plus the reduced-motion pass at desktop width), so
a twelve-page craft build is dozens of sheets even downscaled. Reading them
straight into this conversation is the same cost mistake at a smaller unit size:
each image stays in context, re-billed on every later call until compaction. Past
~3 sheets, dispatch a `sonnet` subagent per page (or batch of pages) with the
rubric below and the sheet paths; have it Read the sheets itself and return only
the pass/fail table rows and reasons — never the images, which then never enter
this conversation at all. Assemble the returned rows into `demo/VERIFY.md` here.
At 3 sheets or fewer, reading them directly is cheaper than a subagent
round-trip.

Each round appends under its own `## Round N` heading. Nothing on disk currently
separates five walk runs from five rounds, and a build once spent its rounds
without ever knowing which one it was in.

A machine finding may be argued with, but not silently. Dismissing one requires a
`## Findings judged to be capture artefacts` heading, one entry per finding, each
carrying the measurement that justifies it. Arguing with a finding on evidence is
legitimate and has been right before; what must not be possible is a green-looking
result whose green came from prose. A reader must be able to count what was fixed
against what was argued away.

- **First paint complete.** Headline, primary visual and CTA inside the 1440x900
  fold and the 390x844 fold, none hidden behind a scroll trigger.
- **One peak.** The largest visual change on the page, a quieter section before
  it, the most scroll room.
- **Squint test.** Blurred, the primary, secondary and major groups are still
  nameable in order.
- **Contrast, read from the frame.** Body 4.5:1, large 3:1, controls and focus
  3:1, read from the frame by eye — nothing here samples a composited pixel.
- **Mobile headline.** Three lines or fewer at 390; nothing wider than the
  viewport.
- **Adjacent feelings.** One word per section, written cold (the feel check); no
  two adjacent words the same. Only now open `demo/BRIEF.md` and diff the
  curves.
- **Name-swap.** Replace the client's name with a competitor's throughout the
  copy and read it again. If it still reads perfectly, the copy describes a
  category rather than this business, and it will not build trust. Graded from
  the sheets like the others.

## Step 5: Report

State the machine findings, the intended curve, the felt curve, the diff, what you
changed, and what could not be verified (composited contrast is judged by eye here,
and headless Chrome cannot prove a real phone).

**A green machine run alone is not a pass.** A green detector run and a green
walk with a failing rubric is a failing round.
