# Verify

Adapted from nateherkai/scroll-craft (MIT).

A scroll page has no single state: every scroll position is a different frame,
and the failures live between the two you happened to look at. So it is verified
by walking it, and a craft build is verified in a loop — build, measure,
critique, fix — for at most **three rounds**. A build that still fails after
three rounds stops, writes `demo/FAILED.md`, and reports rather than shipping
quietly, and it **does not record a fingerprint**. `demo/FAILED.md` is the
on-disk marker `/wp-init`, `/wp-section` and `/wp-yolo` refuse to build on top
of — a craft build that failed verification is not a deliverable, and the
marker is what makes that true on disk rather than only in the transcript.
The loop **deletes the marker at its top** (`rm -f demo/FAILED.md`) rather than
on success, so it always describes the last loop and never a past one: without
that, a build that failed, was fixed and then passed would stay refused forever,
and a `/wp-yolo` run that wrote the marker could never re-enter its own Step 0
gate. Nothing else removes it.
`/wp-demo-verify` runs this loop.

## Round structure

Each round is written to `demo/VERIFY.md` under its own `## Round N` heading —
nothing else on disk separates five walk runs from five rounds. Dismissing a
machine finding as a capture artefact requires a `## Findings judged to be
capture artefacts` heading with the measurement that justifies each one; a
finding argued away without one is a finding still outstanding.

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

- `unobserved` — the page carries devices but none the harness can sample, and
  the stalled section carries no scrubbed device of its own. Advisory: it never
  fails a round. `reveal` was reported as `dead-scroll` for every section that
  used it until v3.1, which is what taught a build to dismiss 392 findings in
  prose. A gate that cannot tell a good page from a broken one gets overruled,
  and then so does every gate beside it.
- A stalled section that *does* carry `pin`/`pan`/`kinetic`/`wipe`/`drift` and
  still has nothing samplable reports blocking `dead-scroll`, not `unobserved`.
  `drive()` is contractually required to publish `--motion-p` for those devices,
  so its absence is not an unreadable device — it is an engine that never ran,
  which is exactly how a `file://`-blocked module script shipped a demo the
  client rejected.
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
  between them. What is compared is `getAnimations()` filtered to a
  `ViewTimeline`, not the computed opacity or transform: a decorative
  `@keyframes` on the same children, or a percentage transform re-resolving
  after a lazy image loads, moved the computed style and let a section with no
  reveal wired at all pass. A child carrying no scroll-driven animation reads as
  `none` at both points, so an unwired reveal is reported rather than skipped. A
  section that already sits above the fold on load is not judged: its entry
  happened before the walk could see it.

**An advisory-only run exits 0.** `unobserved` and `external-module` are the
only advisory kinds; every other kind blocks and still exits 1. Advisory
findings are printed like any other, with `[advisory]` on the line, and their
`findings.json` rows carry `"advisory": true` — blocking rows carry no flag, so
a consumer reads the field instead of keeping its own copy of the kind list.
The summary reads `nothing blocking, N advisory finding(s)` so a reader can
tell the difference between that and a run with nothing to report. A gate that
fails a round on the strength of what it could not see gets overruled in
prose, and then so does every gate beside it.

- `container-noop` — an `@container` rule whose subject has no ancestor
  establishing a container. Fails the round: the rule provably never applies. An
  element never matches a container query against the container it establishes
  itself, so a block that queries its own root silently loses its breakpoints.
- `external-module` — the page loads `<script type="module" src=…>`. Advisory.
  Verification serves over HTTP so it runs, but a client double-clicking the
  file gets an opaque origin and Chrome blocks it, and the engine never boots.

Four limits, recorded because a limit nobody writes down is indistinguishable
from a bug: a section that already sits above the fold on load is never judged
for dead reveal, since there is no below-the-fold position to sample it from;
`parallax` is not judged at all — it is neither scrubbed nor `reveal` and
publishes no `--motion-p`, and reading it would mean reading devices the harness
has never been able to sample (`counter`), which invents findings; the
two-point reveal check is an OR across the section's reveals, so one live child
excuses its dead siblings; and on a browser without
`CSS.supports('animation-timeline', 'view()')` no reveal is judged at all,
because `motion.js` drives reveal in GSAP there and a GSAP tween is invisible to
`getAnimations()` — a working section would otherwise read `none` at both
samples and be reported dead.

It used to walk only each sheet's **top-level** `cssRules`, so an `@container`
block nested inside `@media`, `@supports` or `@layer` was never linted at all —
`proof-row`'s own CSS already nests `@media` inside `@supports`, so generated
demos plausibly nest container queries too. The lint now recurses into
`CSSMediaRule`, `CSSSupportsRule` and `CSSLayerBlockRule` bodies and collects
every `@container` rule it finds at any depth, so a nested block is linted the
same as a top-level one.

It used to judge a selector by `document.querySelector(sel)`, its **first**
match only, which was a false positive and not an under-report: a selector
matching several elements applies as soon as one of them sits inside a
container, and the rule was reported dead whenever the first match happened to
be the one outside. `container-noop` blocks, so that failed a round on correct
CSS. The lint now walks **every** match (`querySelectorAll`) and reports the
selector only when no match has a container-establishing ancestor. The ancestor
walk still starts at `parentElement`, because an element never matches a
container query against the container it establishes itself.

**Cues that never peak**: an element that never reaches full opacity anywhere in
its section, usually a cue window too narrow for the span.

**Horizontal overflow** at any tested width, and **copy clipped by its
container**. For cinematic demos, a **frozen stage**: the canvas is on screen,
the reader is scrolling, the playhead is not moving.

It cannot measure composited contrast, or how the page feels on a real phone
under a real thumb.

`cramped-padding` is a known false-positive source. It fired
68–90 times per run on a build where `.entry__row` measured 56px
above and 57px below its content and `.chapter` 131px/129px, and
it fires on untouched compositions in this library. It is a
`quality` finding and does not fail a round.
**The dismissal has a floor: a measured padding under roughly 16px
is a true positive, not a capture artefact.** Every measurement
that justified the dismissal above is a large padding the detector
misread. A collapsed token — `padding-inline: var(--container-max)`
with `--container-max` never defined, say — computes to 0px, and
0px is exactly what `cramped-padding` exists to catch. Measure
before dismissing; a dismissal without the measurement is not one. We do not own the
detector, and pretending its `quality` output is precise is what
invites blanket dismissal of everything it says.

**A green machine run alone is not a pass.** The machine catches dead scroll,
missed peaks, overflow and clipping; it cannot tell you whether the page is any
good. Reading the contact sheets is not optional and does not happen
automatically because `/wp-demo-verify` exited 0.
