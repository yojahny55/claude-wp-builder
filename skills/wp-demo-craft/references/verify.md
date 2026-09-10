# Verify

Adapted from nateherkai/scroll-craft (MIT).

A scroll page has no single state: every scroll position is a different frame,
and the failures live between the two you happened to look at. So it is verified
by walking it, and a craft build is verified in a loop — build, measure,
critique, fix — for at most **three rounds**. A build that still fails after
three rounds stops and reports rather than shipping quietly, and it
**does not record a fingerprint**. `/wp-demo-verify` runs this loop.

## Round structure

1. **Deterministic gate.** `npx -y impeccable@4 detect demo/ --json`, findings
   written to `demo/.verify/impeccable.json`. Each finding carries a `category`
   (`slop` or `quality`) and a `severity`; every finding observed here has
   carried `warning`. A **`slop`** finding at `warning` fails the round before a
   screenshot is taken; `quality` findings are read at the critique step below
   instead. The tool's own help describes an `advisory` soft-signal tier, but no
   finding carrying it has been reproduced against this library, so it is stated
   conditionally: **if the tool emits an advisory tier, a finding flagged with it
   does not by itself fail the round** — it is listed and read at the critique
   step. The gate does not depend on that being true, because it keys on `slop`
   plus `warning`. Exit
   code tracks whether the scan ran, not how many findings it made — `1` means
   a target could not be scanned, which is the real "did not run" case; findings
   are always counted from the JSON array, never from the exit code. The
   detector covers the generic machine-checkable tells — scroll cues, `01 / 06`
   counters, gradient text, visible em dashes, fake dashboards — and a detector
   is cheaper than a rule nobody read to the end of. It is an external package
   this repo neither vendors nor configures, so the rules that are this
   plugin's own stay in `taste.md` and are the author's to hold: a green
   detector run is not evidence that the taste floor was met.
2. **Contact sheets.** `node ${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs demo/`
   walks every page at every tested width. Machine findings fail the round.
3. **Critique.** A separate evaluator pass reads **only the sheets** — never the
   source, never the brief — and scores each page pass or fail on each rubric
   line into `demo/VERIFY.md`. An evaluator that has read the brief grades the
   intention; the client only ever sees the render.
4. **Fix** every failed line, then repeat from 1.

## The rubric

Seven lines, each one pass or fail per page. No scores out of ten: a 7/10 is a
build nobody has to change.

- **First paint complete.** Headline, primary visual and CTA all inside the
  1440x900 fold and inside the 390x844 fold, none of them hidden behind a scroll
  trigger. A hero whose type is masked until a trigger fires reads as an empty
  dark field to a visitor who has not scrolled yet.
- **One peak.** The largest visual change on the page, with a quieter section
  before it and the most scroll room. If two sections compete, neither wins; if
  none does, the page is a list.
- **Squint test.** Blur a sheet until detail is gone. Primary, secondary and the
  major groups must still be nameable, in order. If it greys into one even
  field, the problem is hierarchy and no shadow or motion will fix it.
- **Contrast, read from the frame.** Body 4.5:1, large text 3:1, controls and
  focus indicators 3:1 — read from the render, not from the token, and read by
  eye: nothing in this loop samples a composited pixel, which is why the line is
  not named for a measurement. A headline can clear
  the floor against one still and fail three hundred pixels later against
  another.
- **Mobile headline.** At 390 the headline wraps to three lines or fewer, and no
  section is wider than the viewport. Left at the desktop type floor, a normal
  hero headline wraps into six lines on a phone.
- **Adjacent feelings.** Write one word per section, cold, from the sheet alone.
  No two adjacent words the same. Only then open `demo/BRIEF.md` and diff the
  words against the curve; two identical neighbours are one section shown twice.
- **Name-swap.** Replace the client's name with a competitor's throughout the
  copy and read it again. If it still reads perfectly, the copy describes a
  category rather than this business, and it will not build trust. Graded from
  the sheets like the others.

## What the machine measures

**Dead scroll**: consecutive positions where nothing changed — no cue opacity
moved, no `--motion-p` advanced, no rail transform travelled, no clip-path
progressed. The reader is turning the wheel and being given nothing. Fix by
shortening the span, not by adding motion to fill it. Authored silence recorded
in `demo/BRIEF.md` is the exception, and it is only an exception because it was
written down first.

- `unobserved` — the section carries devices but none the harness can sample.
  Advisory: it never fails a round. `reveal` was reported as `dead-scroll` for
  every section that used it until v3.1, which is what taught a build to dismiss
  392 findings in prose. A gate that cannot tell a good page from a broken one
  gets overruled, and then so does every gate beside it.
- `no-engine` — the page carries no `data-motion` at all. Fails the round. A
  motionless page used to walk clean, because an empty frame signature could
  never accumulate a stall.
- A section carrying no `pin`/`pan`/`kinetic`/`wipe`/`drift` is not judged by the
  walk at all. `reveal` is a one-shot entry transition a few pixels long — it
  runs on the child's own `view()` progress, around `scrollY = top - viewport` —
  so whether a sparse walk lands inside it is sampling luck, and a miss reported
  dead scroll on a section that reveals perfectly. Such a section is judged by
  two samples instead, below the fold and fully entered, and reports
  `dead-scroll` only when no reveal child moved between them. A section that
  already sits above the fold on load is not judged: its entry happened before
  the walk could see it.

**Cues that never peak**: an element that never reaches full opacity anywhere in
its section, usually a cue window too narrow for the span.

**Horizontal overflow** at any tested width, and **copy clipped by its
container**. For cinematic demos, a **frozen stage**: the canvas is on screen,
the reader is scrolling, the playhead is not moving.

It cannot measure composited contrast, or how the page feels on a real phone
under a real thumb.

**A green machine run alone is not a pass.** The machine catches dead scroll,
missed peaks, overflow and clipping; it cannot tell you whether the page is any
good. Reading the contact sheets is not optional and does not happen
automatically because `/wp-demo-verify` exited 0.
