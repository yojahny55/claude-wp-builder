---
description: Scroll-walk a demo or live page — screenshots per section at every viewport, machine findings, and a contact sheet to read
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

## Step 2: Walk it

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" <target>
```

Six positions per section at 1440x900 and 390x844, plus a reduced-motion pass at
desktop width, then full-page shots at 375, 576, 768, 1024 and 1440 (this replaces
`/wp-responsive-check`). Output lands in `<dir>/.verify/<width>/`, with
`findings.json` and one `sheet.png` per width.

Exit codes: `0` no machine findings, `1` findings printed, `2` no usable browser.

**On exit code 2**, fall back in this order: the Chrome or Playwright MCP
screenshot tools if either is connected, then ask the user for screenshots at the
five viewports. Say which route you used.

## Step 3: Read the findings

- **dead scroll** — consecutive positions where nothing changed. Shorten the
  section's span or add a cue. Authored silence recorded in `demo/BRIEF.md` is not
  dead scroll; say so instead of "fixing" it.
- **cue never reaches full opacity** — the window is too narrow or the ramps eat
  it. Widen the window or set explicit ramps.
- **horizontal overflow** — at any width, always a defect.
- **clipped copy** — text taller than its own hidden-overflow box.

## Step 4: Read the sheet

Open every `sheet.png`. Then run the feel check from
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/feel.md`: scroll the page
cold, write one word per section, and only then open `demo/BRIEF.md` and diff the
two curves. Where they disagree, the page is wrong, not the brief.

Confirm the peak is the largest visual change and holds the most scroll room, that
something quiet sits in front of it, and that the last screen can stand still with
content on it.

## Step 5: Report

State the machine findings, the intended curve, the felt curve, the diff, what you
changed, and what could not be verified (composited contrast is judged by eye here,
and headless Chrome cannot prove a real phone). **A green machine run alone is not a pass.**
