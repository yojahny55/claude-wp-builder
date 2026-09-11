---
description: Verify a demo directory, page or live URL — impeccable detector, scroll-walk screenshots per section and viewport, machine findings, and a seven-line critique written to demo/VERIFY.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<demo-dir-or-file-path-or-url> [--positions N]"
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

`impeccable` is an external package this repo does not install, vendor or
configure — it is fetched from the npm registry at run time via `npx`. Pin the
major version (`@4`; `@1` does not exist on the registry) so a future major
release cannot silently change rule identifiers or output shape underneath
this gate.

The exit code says whether the scan ran, not how many findings it made: `0`
is a clean or advisory-only scan, `1` means a requested target could not be
scanned at all, `2` means the scan completed and found at least one
non-advisory finding — findings do not fail the process the way a linter's
would, so a nonzero exit does not by itself mean "could not run." Only exit
`1` is that case; treat it, any other exit code, a missing `npx`/no network
reaching the registry, or stdout that fails to parse as JSON the same way:
report **"detector could not run"** and fail the round on that basis, never
read as zero findings. Human-readable text goes to stderr, so the redirect
above captures only the JSON on stdout, which is what findings are counted
from — never the exit code.

Once the array parses: sixty-one deterministic rules, no model, each finding
carrying a `category` (`slop` or `quality`) and a `severity`. A `slop` finding
with `severity: "warning"` fails the round outright, before a screenshot is
taken — that is the AI-tell axis and the real gate. The tool's help also
describes an `advisory` soft-signal tier, though no finding carrying it has
been reproduced here (an em-dash-dense file, which that help names as an
advisory rule, returned zero findings): **if the tool emits an advisory tier,
a finding flagged with it is listed but does not by itself fail the round**,
matching the detector's stated design that advisories never block automation.
The gate does not rest on that, because it keys on `slop` plus `warning`
directly. `quality` findings are listed in the
report and fixed when the rubric below also flags the same section, but do
not by themselves fail a round. A target that is a URL is scanned with
Puppeteer by the detector itself; a file or directory is scanned statically.
Run against the demo that motivated this gate, the detector found twenty
issues, seven of them `slop`; run against this library's own `hero-split`
composition, it returns an empty array.

## Step 2b: Walk it

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" <target>
```

Six positions per section at 1440x900 and 390x844, plus a reduced-motion pass at
desktop width, then full-page shots at 375, 576, 768, 1024 and 1440 (this replaces
`/wp-responsive-check`). A directory target walks every page. Output lands in
`<dir>/.verify/[<page>/]<width>/`, with `findings.json` and one `sheet.png` per
width.

Exit codes: `0` nothing blocking — either no findings at all, or advisory ones
only; `1` at least one blocking finding printed; `2` no usable browser; `3` the
walk itself crashed (not a findings report, something threw mid-walk).

**On exit code 2**, fall back in this order: the Chrome or Playwright MCP
screenshot tools if either is connected, then ask the user for screenshots at the
five viewports. Say which route you used. (A craft build never reaches this
branch: `/wp-demo` probes first and stops on 2.)

## Step 3: Read the findings

- **dead scroll**: consecutive positions where nothing changed. Shorten the
  section's span or add a cue. Authored silence recorded in `demo/BRIEF.md` is not
  dead scroll; say so instead of "fixing" it.
- `unobserved` — the page carries devices but none the harness can sample, and
  the stalled section carries no scrubbed device of its own. Advisory: it never
  fails a round. `reveal` was reported as `dead-scroll` for every section that
  used it until v3.1, which is what taught a build to dismiss 392 findings in
  prose. A gate that cannot tell a good page from a broken one gets overruled,
  and then so does every gate beside it.
- A stalled section that *does* carry `pin`/`pan`/`kinetic`/`wipe`/`drift` and
  still has nothing samplable reports blocking `dead-scroll`, not `unobserved`.
  `drive()` is contractually required to publish `--motion-p` for those devices,
  so its absence means the engine never ran — the `file://`-blocked module script
  failure this split exists to keep catching — not that the device is unreadable.
- `no-engine` — the page carries no `data-motion` at all. Fails the round. A
  motionless page used to walk clean, because an empty frame signature could
  never accumulate a stall.
- **`unobserved` is a per-section judgment; `no-engine` keeps a document-wide count.**
  The probe walks `[data-motion]` inside the walked section's own subtree, so an
  `unobserved` row is a fact about that section: it carries devices this harness
  cannot read. Pointer devices — `tilt`, `magnet`, `spotlight` — publish nothing a
  scroll walk can sample, so a section carrying only those is unreadable, not dead.
  `no-engine` is still the page's fact ("this demo carries no `data-motion` at
  all") and still prints one row per section. A section carrying no device of its
  own, on a page that does move, is reported as nothing at all — a plain
  `<section>` is not a defect.
- A section carrying no `pin`/`pan`/`kinetic`/`wipe`/`drift` is not judged by the
  walk at all. `reveal` is a one-shot entry transition a few pixels long — it
  runs on the child's own `view()` progress, around `scrollY = top - viewport` —
  so whether a sparse walk lands inside it is sampling luck, and a miss reported
  dead scroll on a section that reveals perfectly. Such a section is judged by
  two samples instead, below the fold and fully entered, and reports
  `dead-scroll` only when no reveal child's **scroll-driven animation** advanced
  between them — `getAnimations()` filtered to a `ViewTimeline`, not the computed
  opacity or transform, which an unrelated `@keyframes` or a re-resolving
  percentage transform could move on a section with no reveal wired at all. A
  child with no scroll-driven animation reads as `none` at both points, so an
  unwired reveal is reported rather than skipped. A section that already sits
  above the fold on load is not judged: its entry happened before the walk could
  see it.
- **An advisory-only run exits 0.** `unobserved` and `external-module` are the
  only advisory kinds; every other kind blocks and still exits 1. Advisory
  findings are printed with `[advisory]` on the line, and their `findings.json`
  rows carry `"advisory": true` (blocking rows carry no flag) — read the field
  rather than matching on the kind. The summary reads `nothing blocking, N
  advisory finding(s)` — read that as "nothing to fix here, and here is what I
  could not see", not as a clean run.
- `container-noop` — an `@container` rule whose subject has no ancestor
  establishing a container. Fails the round: the rule provably never applies. An
  element never matches a container query against the container it establishes
  itself, so a block that queries its own root silently loses its breakpoints.
- `external-module` — the page loads `<script type="module" src=…>`. Advisory.
  Verification serves over HTTP so it runs, but a client double-clicking the
  file gets an opaque origin and Chrome blocks it, and the engine never boots.
- **cue never reaches full opacity**: the window is too narrow or the ramps eat
  it. Widen the window or set explicit ramps.
- **horizontal overflow**: at any width, always a defect.
- **clipped copy**: text taller than its own hidden-overflow box.

## Step 4: Critique the sheets

Read only the sheets for this step: not the source, not `demo/BRIEF.md`. Score
every page pass/fail on each line and write the table to `demo/VERIFY.md`
(one section per page, one row per line, a one-sentence reason on every fail):

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
