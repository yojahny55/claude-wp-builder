# /wp-demo-verify — Step 3

`commands/wp-demo-verify.md` sends the run here at Step 3. Follow it in order; nothing in it is optional background.

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
  never accumulate a stall. On a site the plugin did not build, this is expected
  and not a defect: re-run with `--no-motion` (Step 2b). Never pass it for a page
  the plugin built, where a missing engine is the failure being caught.
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
- **horizontal overflow**: at any width, always a defect. The row lists up to five
  `culprits`, the boxes past the right edge that no ancestor clips, widest first.
  Fix those, not the rows under them. A culprit with `escapes` is a
  `position: absolute` box that got past that clipping box, because its containing
  block sits outside it. A screen-reader span inside a carousel card is the usual
  case: it is 1px and shows in no screenshot. Give an ancestor inside the named box
  `position: relative`, usually the card.
- **breakpoint-gap**: blocking. A `max-width: N` rule and a `min-width: N+1` rule leave the
  fractional widths between them (zoom, display scaling) matched by neither, and the page
  there differs from both N and N+1: it overflows, a box is more than 50% and 100px wider
  than at either neighbour, or boxes hidden at both are visible. The row gives `width` (N),
  the measured `viewport`, and up to five `culprits`; `gap-<N>.png` and `gap-<N>.jpg` sit
  beside the sheets. Close the gap: `max-width: N.98px`, or range syntax `(width < N+1)`.
- **clipped copy**: text taller than its own hidden-overflow box.
