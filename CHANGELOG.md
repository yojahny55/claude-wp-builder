# Changelog

## [Unreleased]

### Added

- `/wp-demo` Step 5.5 fills a composition's image slots from a client file or a
  generated plate, via the new `bin/image-gen.mjs`. Provider-agnostic across
  `google/gemini-3.1-flash-image` (nano banana) and `gpt-image-2.5-flare` /
  `gpt-image-2.5-sunburst`. The provider decision is asked once, when a key is
  present and plates are needed, and recorded as `"image provider"` in
  `.wp-create.json` — `"<vendor>/<model>"` on a yes, `"none"` on a decline — so
  a later run never re-asks. The aspect and size of every request are read off
  the composition's own `<img>` tag, so a plate arrives at the crop the CSS
  displays. Plates are content-hashed on prompt, aspect and model, so a re-run
  or a verify round never re-bills, and an edited prompt always regenerates
  instead of serving the stale image. The API key is read from
  `GEMINI_API_KEY` / `OPENAI_API_KEY` in-process only — never a CLI argument,
  never written to a file, never logged — and a missing key stops the build
  naming the variable rather than falling back to a placeholder. `/wp-yolo`
  never generates; it consumes plates already on disk.

### Fixed

- `/wp-seed` could not import a demo-relative image path. Phase 2 collected
  `img[src]` as "URLs" and Phase 3's example was remote, so a local
  `assets/img/...` source failed on every import. Sources are now resolved
  against the demo folder, and a failed import of a generated plate is reported
  on its own line rather than folded in with a remote URL that 403'd.

## [1.16.0] - 2026-09-11

### Fixed

- **The `@property --container-max` guard stopped at the demo; the delivered
  theme reproduced the bug it closed.** `/wp-section` copies thirteen
  `padding-inline: max(var(--space-gutter), calc((100% - var(--container-max,
  1280px)) / 2))` rules into the theme, but `/wp-init` Step D4 wrote neither the
  token nor its registration into the Tailwind `@theme` block, so a malformed
  value there unset `padding-inline` to `0` at every viewport in the artifact the
  client actually receives. Step D4 now writes `--container-max` from
  `demo/DESIGN.md`'s `spacing.container` and emits the same `@property` rule at
  the top level of `main.css`. Measured at a 1920 viewport on that exact gutter
  rule: `1440px` → 232px either way, `wide` → 312px with the rule and 0px
  without, empty → 312px with and 0px without.
- **`/wp-demo` Step 6 told the build to emit the `@property` rule "in the same
  `<style>`", inside a step that writes one file per page.** A builder could
  satisfy that on `index.html` alone and leave every interior page with the
  unguarded token. The instruction now says every page this step writes, and the
  suite pins the wording.
- **Three records had the `overflow-y` rationale backwards.** The composition
  comment, the check beside it and the CHANGELOG all said the implicit `auto`
  would "silently clip". `auto` scrolls — it would add a second, vertical
  scrollbar to a horizontal scroller; `hidden`, the value actually chosen, is the
  one that clips, and clipping is what is wanted there. All three now say what
  each value does.
- **Both composition unit gates pinned one spelling and let the whole family
  past.** The `vw` justification loop fed on a literal `[0-9.]vw`, so a `6dvw`
  or `6vmin` ramp dropped into a composition with no comment passed (rc=0,
  sha-verified), and `svw`/`lvw`/`vi`/`vmax` are the same shape — all of them
  the viewport-relative sizing the conversion removed, and `dvw` the spelling a
  mobile-aware author reaches for first. The self-container loop matched
  `[0-9.]cqi` only, so a `6cqw` inside the rule declaring `container-type` also
  passed, reintroducing the identical resolve-against-the-viewport defect with
  a unit the library already uses elsewhere. Both patterns now cover their
  families — `(d|s|l)?(vw|vi|vmin|vmax)` and `cq(i|b|w|h|min|max)`, each with a
  trailing class so a unit cannot match inside a longer identifier. Viewport
  *height* is deliberately excluded and the check says why: `container-type:
  inline-size` offers no block-axis container unit to convert to.
- **`demo-verify` failed a round on correct CSS whenever a container query was
  scoped to a breakpoint.** `containerAudit()` decides whether an `@container`
  rule can ever match by reading `container-type` off the subject's ancestors,
  and it was sampled once per page at the first width. That was harmless while
  the audit only saw top-level `@container` rules; once it also collected the
  ones nested in `@media` — which is exactly where breakpoint-scoped
  `container-type` lives — liveness became width-dependent. Measured on the new
  `tests/fixtures/container-audit/index.html`: the single-width audit reported
  `.bp-max__child`, whose container is declared inside `@media (max-width:
  700px)` and is live at 390, as dead from its 1440 sample. `container-noop` is
  blocking, so a demo written the ordinary way failed all three rounds and
  `/wp-demo` wrote `demo/FAILED.md`, which `/wp-init`, `/wp-section` and
  `/wp-yolo` then refuse to build on. The audit now runs at every width walked
  and reports only the selectors dead at all of them; `external-module`, which
  genuinely is width-independent, stays a once-per-page read. The fixture
  carries both halves — two breakpoint-scoped pairs that must not be reported
  and one genuinely dead rule that must be — and `tests/checks/wp-demo-verify.sh`
  runs the real script over it and requires exactly `.dead__child`, so a fix
  that reports nothing fails it too.
- **`process-rail` shipped a dead tab stop and a phantom landmark on every craft
  build at default motion.** The `tabindex="0" role="region" aria-label="{{title}}"`
  added with the reduced-motion scroll fix was unconditional, but the scroll
  region only exists under `prefers-reduced-motion`: at default motion the frame
  is `overflow-x: hidden` and pinned, so Tab landed on a box that could not be
  scrolled and every AT landmark list gained a region named after the `<h2>`
  sitting inside it. The markup carries no a11y attributes now; `motion.js`
  creates the affordance in the pan device's reduced-motion branch, on whichever
  box actually scrolls (with the engine running that is the rail, whose own
  `overflow-x: auto` makes it the scroll container; with the stylesheet alone it
  is the frame), and names it with `aria-labelledby` pointing at the section's
  own heading — so no unsubstituted `{{slot}}` and no hand-written, one-language
  label can reach a screen reader. Measured in both modes on the real
  composition with `motion.js` running: reduce → Tab lands on the rail,
  `role=region`, name taken from the heading, ArrowRight moves `scrollLeft`
  0 → 40; default → no `tabindex`, no `role`, no name, Tab skips the section.
  `tests/checks/wp-craft-compositions.sh` asserts the markup is clean, that the
  three lines live inside the pan device's reduced branch (extracted by its own
  brace range, comments stripped), and that every `{{slot}}` used as an
  accessible name anywhere in the library has a value in `fills.json`.
- **`process-rail`'s reduced-motion rail overflowed the whole document instead
  of scrolling inside its own frame.** Under `prefers-reduced-motion` the
  section's own comment calls the rail "a native scroll region", but nothing
  made it one: the frame was `overflow: visible` with no `overflow-x`
  anywhere, so the row overflowed `documentElement` itself — measured
  `scrollWidth` 2496 at a 1920 viewport, i.e. a horizontally scrolling page.
  `.process-rail__frame` now carries `overflow-x: auto` inside that media
  query, placed after the `overflow: visible` shorthand (which resets both
  axes and would otherwise win by source order and silently undo the fix).
  Measured before/after with a headless-Chrome probe with
  `prefers-reduced-motion: reduce` forced, at four viewports:
  `documentElement.scrollWidth` 1587 → 390, 1981 → 768, 2074 → 1280 and
  2496 → 1920, with the frame itself still scrollable at each
  (`scrollWidth` > `clientWidth`). `overflow-y: hidden` is then stated
  explicitly, because CSS corrects a `visible` axis to `auto` when the other
  axis is not visible — left implicit it computed to `auto`, which would give
  anything that later grew vertically out of the frame a second, vertical
  scrollbar on a horizontal scroller. `hidden` clips that overflow instead,
  which is the intended behaviour here and the reason the value is stated at
  all. And the scroll region takes `tabindex="0"` with `role="region"`, added
  by `motion.js` under reduced motion rather than written into the markup: a
  scroll container no keyboard can reach is a different bug, not a fix, and
  before this change the overflowing row at least scrolled with the page.
  Verified with real key events — without the affordance, ArrowRight left
  `scrollLeft` at 0; with it, `scrollLeft` moved 0 → 80 at both 390 and 1920.
  `tests/checks/wp-craft-compositions.sh` asserts
  `overflow-x: auto` on the `__frame` rule specifically inside the
  reduced-motion block, and after the `overflow: visible` shorthand, not
  merely present anywhere in the file.
- **A composition's fluid ramps ignored the container its breakpoints already
  respected.** `@container` sizing (Task 3) covered layout, but the `vw` inside
  `clamp()` gaps, padding and type scales still keyed off the viewport, so a
  section dropped into a narrow column laid out for the column and then took
  desktop-maximum spacing anyway — 40 occurrences across 12 of the 13
  compositions. 37 now read `cqi`, tracking the block's own inline size. The
  remaining 3 stay `vw`, each with a comment recording why. Two are the display
  headline of a full-bleed hero (`hero-bleed`, `hero-type`),
  sized against the viewport on purpose: a hero in a narrow column is not a
  scenario those compositions serve. `hero-split` was counted a third until its
  justification was checked against the composition it defends: that title sits
  in a `1.1fr 0.9fr` split column, not the bleed. Its nearest container is the
  section root, so `6cqi` measured identical at full bleed (86.4px at 1440,
  76.8px at 1280, 38.4px at 390, same box and position) and 38.4px rather than
  86.4px in a 420px column — it converted. The third is `feature-zigzag`'s root `gap`,
  which *cannot* be `cqi` — that rule is the element declaring `container-type`,
  and an element never matches a container query against the container it
  establishes itself, so `cqi` there would resolve against the viewport while
  reading as if it tracked the block. `tests/checks/wp-craft-compositions.sh`
  asserts every remaining `vw` carries that justification on its own line or the
  line directly above it, so one justified ramp can no longer green-light every
  other `vw` left in the same file.
- **A present but malformed `--container-max` (`wide`, an empty string) unset
  `padding-inline` to `0` at every viewport, phones included.** `var(--container-max,
  1280px)` only ever guarded an *absent* token — `var()` still substitutes a
  malformed one, which makes `calc()` invalid at computed-value time. A craft build
  now emits `@property --container-max { syntax: "<length>"; inherits: true;
  initial-value: 1280px; }` alongside `:root` in `commands/wp-demo.md`'s generated
  demo and in `bin/composition-preview.mjs`'s preview harness, so an invalid value
  falls back to `initial-value` instead of unsetting. Measured before/after with a
  headless-Chrome probe: `1440px` → 240px (unchanged), `wide` → 320px (was 0px),
  empty → 320px (was 0px). Where `@property` is unsupported, the `1280px` `var()`
  fallback remains the only guard, and it still covers only the absent case.
- **`unobserved` could not fire, so a section that only the harness could not read
  was reported as a section that does not move.** `demo-verify.mjs`'s `probe()`
  counted `samplable` over a document-wide `querySelectorAll('[data-motion]')`, so
  `samplable === 0` required *every* device on the page to be unreadable — the kind
  could only fire where `no-engine` already did, and a single live `reveal` child
  anywhere closed the door for the whole document. A section carrying only pointer
  devices (`tilt`, `magnet`, `spotlight` publish nothing a scroll walk can sample)
  was therefore judged by whether some *other* section happened to be readable, and
  fell to `dead-scroll`, which blocks: a blocking finding on a working section.
  `probe()` now takes the section index `bounds` already carries and walks
  `[data-motion]` inside that subtree only, root included. A section's frame
  signature is its own as a result, instead of being perturbed by every other
  section on the page. The cue sweep, the canvas sample, `clipped` and `overflow`
  stay page-level facts and keep querying `document`.
- **A plain `<section>` on a moving page is not a dead engine.** `bounds` walks
  `section, [data-motion]`, so scoping the device count alone would have made
  `no-engine` — a blocking finding — fire on every ordinary static section, which is
  the false positive the whole gate exists to avoid. `probe()` returns a separate
  document-wide `pageDevices` count and `no-engine` keeps testing that, so it still
  means "this demo carries no motion at all". A section with no device of its own on
  a page that does move is now reported as nothing at all, not even advisory.
- **The two verification contracts said both counters were page-wide.** That is now
  true only of `no-engine`. `skills/wp-demo-craft/references/verify.md` and
  `commands/wp-demo-verify.md` record `unobserved` as a per-section judgment, name
  the pointer devices that produce it, and state that a device-free section is not a
  defect.
- **`containerAudit()` never saw an `@container` rule nested inside `@media`,
  `@supports` or `@layer`.** The lint walked only each stylesheet's top-level
  `cssRules`, so a rule nested even one level down was silently unlinted — the
  exact failure class `container-noop` exists to catch, and `proof-row`'s own CSS
  already nests `@media` inside `@supports`. The sheet loop now recurses into
  `CSSMediaRule`, `CSSSupportsRule` and `CSSLayerBlockRule` bodies and collects
  every `@container` rule found at any depth, keeping the existing all-matches
  (`querySelectorAll`) and `parentElement`-rooted ancestor walk unchanged.
  `skills/wp-demo-craft/references/verify.md` and `CLAUDE.md` no longer record
  the top-level-only scope as a known limit.

- **A full-site build paid three times over for work the flow then discarded.** Measured
  on a real twelve-page bilingual Tailwind build: roughly 1.9M subagent tokens before a
  single template part existed, ~90% of it spent reading and rewriting demo HTML. Three
  causes, all contract holes rather than model error.

  `wp-normalize` captured verbatim `section.cssRules` for every section on **both**
  template paths, which costs a full read of every stylesheet and a full write of every
  matched rule. On the `tailwind` path `/wp-yolo` Step 2.6 converts each demo page and
  then forbids the section walk from reading that field at all — so the capture produced
  something the flow is contractually required to ignore. It is now skipped on that path
  and written as `null`, with a `review[]` entry so the null is not read as a failed scan.
  `backgrounds`, `fonts` and `computed` are still captured on both paths: the font carry
  and the demo-parity gate read them regardless, and `fonts` cannot be recovered from
  converted markup at all, because conversion strips the `@font-face` rules it absorbed.

  Step 2.6 converted **every copy** of a repeated card. A demo pads a list with mock
  repetition — sixteen profile cards cut from four records, eighteen board members from
  three, twelve branch cards from two — and those pages were the most expensive
  conversions in the run while collapsing hardest in the theme, where all N become one
  template part inside a loop. `wp-normalize` now records `section.repetition` as an array with
  one entry per repeated list (`selector`, `count`, `distinct`, `exemplar`, `variants`;
  the exemplar is never one of the variants) and Step 2.6 converts the
  exemplar plus any real variants, applying the exemplar's `class` attributes to its
  siblings position-for-position and leaving each sibling's own text, `href`, `src`, `alt`
  and `data-*` untouched. Lists whose children genuinely differ are not collapsed.

  `wp-acf` and `wp-template` each ship a "WP-CLI Integration" section instructing the
  agent to run `$WP …`, while their frontmatter granted `Read, Write, Edit, Grep, Glob`
  and no `Bash`. Both reported verification they had no way to perform, and the
  orchestrator had to re-run it. Both now grant `Bash`; the check also refuses the reverse
  drift — an agent gaining `Bash` by copy-paste with no shell step in its instructions.

  New check: `tests/checks/wp-yolo-transcription-cost.sh`.

- **The `@apply` promotion ran once per section, so it depended on dispatch order.** The
  `wp-tailwind-system` ladder promotes a utility group seen "3+ times, or on 2+ distinct
  pages" — a judgment about the whole theme. On the `tailwind` path `/wp-section` dispatches
  `wp-tailwind` in author mode after `wp-template` returns, per section, and tells it to grep
  what earlier sections already wrote. The first section therefore runs with nothing to grep
  and ships raw utilities; when a later sighting finally crosses the threshold, the template
  parts already written that carry the same group are never revisited. The group ends up a
  semantic class in the sections built late and raw utilities in the ones built early, so the
  `@apply` file exists without covering the repetition it was created for. On top of that it
  is one serialized agent per section, each re-reading a template part `wp-template` has just
  written and each appending to the same `main.css`.

  `/wp-section` gains `--defer-promotion` (tailwind only — on `basic` it would ship an
  unstyled section, since `wp-css` writes the section's only stylesheet). `/wp-yolo` sets it
  on every section-walk dispatch and runs the promotion once in a new Step 4.4, over every
  template part the walk produced, counting distinct pages rather than files and touching
  class names only. Hand-invoked `/wp-section` is unchanged: a section added to a finished
  theme has the whole theme to grep and nothing to aggregate.

- **The viewport-height gate judges every declaration on a line, not the first.**
  A rule written on one line carries several, and judging only the first let a
  block-axis declaration shield an inline one behind it: `.x { height: 100vh;
  width: 50vh }` exempted the `width` because the `height` came first. Measured:
  the same `width: 50vh` alone failed and behind a `height` passed.
- **The self-container check parses declaration blocks, not lines.** Line-based
  brace tracking made the verdict depend on formatting — `@supports (display:
  grid) { .a { container-type: inline-size; } .b { gap: 1cqi; } }` on one line was
  flagged while the byte-identical CSS across four lines passed. Two separate
  rules are not one rule whatever the whitespace. It now matches innermost
  `{...}` blocks, which are exactly declaration blocks, so at-rule wrappers are
  ignored without having to understand at-rules.
- **The reduced-motion rail affordance is attached only when a box actually
  overflows.** Below `process-rail`'s own documented three-step minimum neither
  the rail nor the frame scrolls, and attaching `tabindex`/`role="region"`
  anyway shipped a focusable, named region that scrolls nothing — the same dead
  tab stop the affordance was written to remove, reached by a different route.
  Measured: a short rail selects `container` unguarded (which scrolls nothing)
  and nothing at all guarded.
- **The viewport-height units are gated by AXIS, not by spelling.** Excluding
  `vh`/`dvh`/`svh`/`lvh`/`vb` outright is correct for block-axis declarations —
  a pinned frame is one screen tall by definition and `container-type:
  inline-size` gives it nothing to convert to — but it also let a height unit be
  smuggled into an inline ramp, where it is as viewport-relative as `vw` and as
  convertible. A height unit on a width, gap, font-size or inline padding now
  has to justify itself like any other. Unit detection runs over a copy with
  comment bodies blanked and line numbers preserved, so a unit merely *named* in
  prose is not mistaken for a declaration.

### Changed

- **All 26 composition previews re-rendered against the changed CSS.** Nine moved,
  all of them at 1440 and none at 390, and the split is arithmetic rather than luck.
  A container query length resolves against the query container's *content* box, so
  on the nine compositions whose root carries both `container-type: inline-size` and
  the `padding-inline` content inset, `cqi` at a 1440 viewport is 13.44px against
  `vw`'s 14.4 — every converted ramp inside an active `clamp()` band lands 4-7%
  smaller, which is the conversion doing exactly what it says. `hero-split`,
  `hero-type` and `process-rail` did not move because their inset sits on `__inner`
  / `__frame` rather than on the container, so `cqi` there equals `vw`; `footer-line`
  carries no fluid ramp at all. No preview moved at 390: at that width every
  converted ramp is already pinned to its `clamp()` minimum under both units. No
  composition changed structurally, which is the signal that no ramp was converted
  in the wrong place.
- **The before/after walk was measured on a composition corpus, not on the v1.15.0
  client demo.** That demo no longer exists on disk — the project is now a WordPress
  install and the demo was consumed into the theme — so the comparison was made
  two-sided instead of historical: a five-page corpus assembled from the thirteen
  in-repo compositions (`composition-gate.sh`'s document shape plus the generated
  `:root`, `motion.css`, GSAP and `motion.js`) was walked twice, once with
  `bin/demo-verify.mjs` as of 1.15.0 and once with this revision. Release: **0
  findings, exit 0**. This revision: **16 `unobserved`, 0 of every other kind, exit
  0** — advisory, so the exit code is unchanged. Every one of the 16 is a parallax
  image that is its own bounds entry (`hero-bleed__bed`, and `hero-split`'s unclassed
  `<img>`): a one-device subtree whose only device publishes no `--motion-p`, which
  the document-wide count could never see because the reveals elsewhere on the page
  kept `samplable` non-zero. That is the per-section scoping, on a real page, and
  nothing else in the corpus moved: no `dead-scroll`, no `no-engine`, no
  `container-noop` in either walk — the library's nested `@container` rules all match,
  so the deeper recursion found nothing new to report on clean input. A composition
  corpus is cleaner than a real client build, so this shows the harness changed
  behaviour as intended without showing what a messy build now scores; the ceiling is
  recorded in `CLAUDE.md`.
- README and `docs/commands.md` no longer describe the fluid `vw` ramps as open work,
  and state that `unobserved` is counted per section while `no-engine` stays
  document-wide.


## [1.15.0] - 2026-09-10

### Added
- **A repeat client can no longer be handed back the structure they rejected.** The
  fingerprint gate compares palette and type across clients and nothing within one, and a
  build that fails the rubric records no row — so a client who rejected a demo and had it
  deleted got a rebuild reproducing the rejected build's recorded header silhouette almost
  exactly, invisible on every axis including palette. `fingerprint.md` gains a same-client
  rule: when a row already exists for this client, the new build's grammar and hero
  composition must differ, and the plan must say how — read from the plan and from any
  prior demo in `docs/` or git history, not from the registry alone, since a deleted
  predecessor left no row to compare against. Structure stays uncompared across clients
  and v1's six retired axes stay retired; this is one same-client rule, not a seventh axis.
  `/wp-demo` Step 2.6's fingerprint gate states the requirement and rules out "it is a
  fresh build" as an answer, since the previous rebuild was written fresh and converged on
  the same silhouette anyway.
- **A content width, an asset inventory, and no inherited placeholders — three client
  complaints, three contract holes.** Craft is told to ignore plain mode's `:root` clause,
  which was the only place `--container-max` was ever defined, so every composition padded
  by the gutter alone and above about 1600px a heading sat hard left and an aside hard
  right with a dead field between them. `--container-max` joins the craft token set in
  `references/design-md.md` and the neutral `_preview.md`, and all thirteen compositions
  now constrain content with
  `padding-inline: max(var(--space-gutter), calc((100% - var(--container-max)) / 2))` —
  on the root where the root carries the gutter, on `__inner` for `hero-split` and
  `hero-type`, and on `__rail` in `100cqw` for `process-rail`, whose `width: max-content`
  box would otherwise disagree with itself about a percentage padding and leave the
  horizontal travel short. Second: `docs/` reached a craft build exactly once, in the mode
  decision, and `design-md.md` read the logo only for its colours — so a 400x400
  transparent PNG of a client's real logo sat unused while the same run listed it as owed
  by the client. Step 2.6 gains an asset inventory that writes every image, SVG and font
  under `docs/` into `demo/BRIEF.md` with a role, and the header chrome takes its logo
  from that list. Third: craft's exemption list named only Step 4's single-file, no-CDN
  and `:root` clauses, leaving Step 4's `Logo area (placeholder)` and "placeholder images
  using CSS background colors" in force — which is how a hero rendering the words
  "HERO PHOTOGRAPH PENDING" passed "First paint complete", a rubric line that asks only
  that a primary visual be present. The exemption now covers the placeholder-content
  clauses too, and `wp-demo-craft/SKILL.md` blocks a placeholder image, a placeholder
  logo, or the words "pending", "placeholder" or "TBD" in rendered text.
- **A craft build that fails verification writes `demo/FAILED.md` and cannot pass for a
  finished one.** The loop already treated a rubric FAIL as a failing round, but nothing
  downstream changed what reached the client: `demo/index.html` stayed on disk looking
  finished, no command read `demo/VERIFY.md` as a gate, and the only recorded penalty was
  an unwritten fingerprint row the client never sees. `/wp-demo` now writes
  `demo/FAILED.md` at the three-round cap — naming every failing rubric line, every
  outstanding `slop` warning, every `dead-scroll`/`no-engine`/`container-noop` finding, and
  the round count reached — and leads its report with the failure instead of burying it as
  a caveat. `/wp-yolo` carries its own copy of the same craft verify loop (a craft
  `/wp-yolo` run never calls `/wp-demo`), and its loop now writes the same marker at its
  own three-round cap, so the full-site build path gates identically to the single-demo
  one instead of only consuming a marker it never produces. `/wp-init`, `/wp-section` and
  `/wp-yolo` all stop on `demo/FAILED.md` before building a theme from an unverified demo.
  `demo/VERIFY.md` now numbers its rounds under
  `## Round N` headings and requires a `## Findings judged to be capture artefacts` heading,
  with a measurement per entry, before a machine finding can be dismissed in prose.
- **A composition gate proves the library passes its own slop rule.**
  `bin/composition-gate.sh` assembles each `skills/wp-demo-craft/compositions/*/section.html` +
  `section.css` pair into a complete document before scanning, because `impeccable detect`
  scans zero files and exits 0 against the bare fragments — the reason `closing-block`'s and
  `proof-row`'s infinite loop animations went uncaught. `tests/checks/wp-craft-composition-gate.sh`
  runs it against the library, and against two synthetic libraries it must reject: one carrying
  an infinite marquee (`rc=2`) and one with a 0-byte `section.html` behind a real
  stylesheet (`rc=1`). A gate only ever watched passing cannot be told from a disabled
  one — mutating the detector filter or zeroing `MIN_HTML_BYTES` left the old check green.
  `bin/composition-gate.sh` takes a `COMPS_DIR` override for that, and loses its disk
  recount, which could never disagree with the counter it was checking.

### Documentation
- **The `@container` lint's two blind spots are written down.** `containerAudit()` walks
  only each stylesheet's top-level `cssRules`, so an `@container` nested inside `@media`,
  `@supports` or `@layer` is never linted — and `proof-row`'s own CSS already nests
  `@media` inside `@supports` — and it judges a selector by `document.querySelector(sel)`,
  its first match only. Both under-report; neither fires falsely. Recorded in
  `references/verify.md` beside the harness's other limits and in `CLAUDE.md`'s ceilings,
  and deliberately not fixed here: a limit nobody wrote down is indistinguishable from a
  bug, which is how a gate becomes untrustworthy enough to dismiss wholesale.
- **`cramped-padding`'s dismissal gains a lower bound.** `verify.md` recorded it as a known
  false-positive source on evidence of 56/57px and 131/129px — large paddings the detector
  misread — which as written taught builds to dismiss the one machine signal that catches a
  collapsed token, whose padding computes to **0px**. A measured padding under roughly 16px
  is now stated to be a true positive, not a capture artefact.

### Fixed
- **`container-noop` stops firing on valid CSS.** `containerAudit()` resolved each
  `@container` rule's selector with `document.querySelector(sel)` — the first match only —
  and then walked that one element's ancestors, so a selector matching several elements was
  reported dead whenever the first match sat outside any container and a later one sat
  inside, even though the rule genuinely applies. `container-noop` blocks, so a verification
  round failed on correct CSS — the same untrustworthy-gate failure this branch exists to
  cure, recreated inside the cure. The lint now walks every match and reports the selector
  only when none of them has a container-establishing ancestor; the ancestor walk still
  starts at `parentElement`, because an element never matches a container query against the
  container it establishes itself. Three fixtures pin both directions: `.orphan` (no
  container anywhere) is still reported, `.good__inner` (parent establishes one) is still
  not, and the multi-match `.card` is not. The first-match limit recorded in
  `references/verify.md` and `CLAUDE.md` is retired there rather than left standing as a
  known ceiling — it was a false positive, not an under-report — and
  `tests/checks/wp-craft-detect.sh` fails if either file reasserts it.
- **The verification server enforces path containment.** `serve()` stripped leading `../`
  from the request path and then called `join(root, rel)`, which is not containment: a path
  normalising to a Windows drive-absolute `/C:/Windows/...` lands outside the root, and a
  symlink inside the root pointing outside it was followed and served (measured: a symlink
  to `/etc/passwd` returned 200 with its contents). A page under test is untrusted markup,
  and the plugin ships to other people's machines, so "we run Linux" was not an answer. The
  handler now resolves the path, follows the links with `realpathSync`, and refuses anything
  that is not the root or under it with 404; a missing file still answers 404 rather than
  throwing. The whole existing traversal battery still 404s, `/` still 403s, `/index.html`
  and a nested asset still 200, and `tests/checks/wp-demo-verify.sh` runs that battery
  against `serve()` lifted verbatim out of the script instead of grepping for it.
- **A failed bind no longer hangs the walk.** `serve()`'s promise took only `resolve`, so a
  `server.listen` that failed — port exhaustion, a sandbox refusing the bind — never settled
  it and the walk stopped with no answer at all. A verification that produces no answer is
  the failure this branch exists to stop, and a hang is its worst shape because it looks
  like progress. The promise now rejects on `server.once('error', …)`, and the handler is
  removed once `listen` succeeds so a later runtime error cannot reject an already-settled
  promise; the walk's `finally` still closes the server on the throw path.
- **`bin/composition-gate.sh` returns a verdict on an unexpected detector payload.**
  Parseable JSON without a `findings` array left `findings` bound to the dict itself and the
  next loop raised `AttributeError` — an unhandled Python traceback instead of a gate
  verdict. The payload is normalised to a list first: a list stays as-is, a dict yields
  `findings` only when that is itself a list, and anything else is a scan that did not
  happen and exits 1, the same code as "could not scan". Treating an unreadable payload as
  zero findings would be a vacuous pass. `tests/checks/wp-craft-composition-gate.sh` runs
  the real gate behind a stub `npx` that emits `{"ok": true}` and asserts rc 1, no
  traceback, and a message that says why.
- **`demo/FAILED.md` stops being a one-way latch.** Nothing anywhere deleted the marker,
  so the branch's headline mechanism shipped without its inverse: a craft `/wp-yolo` run
  that exhausted its three rounds wrote the marker at Step 2.6 and was then refused by its
  own Step 0 gate forever, and a build that failed, was fixed and then passed on a later
  `/wp-demo iterate` still left the marker on disk, with `/wp-init`, `/wp-section` and
  `/wp-yolo` permanently refusing a demo that had since passed and nothing telling anyone
  why. The craft verify loop now clears it at its top (`rm -f demo/FAILED.md`) rather than
  on success, in both entry points, so the marker always describes the **last** loop and
  never a past one; the three Step 0 gates say what clears it. `references/verify.md`
  records the rule and `tests/checks/wp-craft-failed-build.sh` pins the literal deletion
  in every file that runs the loop, so a rewording cannot satisfy the pin while the
  deletion is gone.
- **`tests/checks/wp-craft-detect.sh` greps a comment-stripped copy of
  `bin/demo-verify.mjs`.** It stripped nothing, so all ~27 of its pins on that file fell to
  comment-parking — write `<broken code> // <original line>` and every grep stays green.
  Nine were verified to fall that way, one of them re-opening the dead-engine regression a
  whole fix round had closed (dropping `&& !b.scrub` from `frame.samplable === 0 &&
  !b.scrub`). The check now strips block comments and line comments once into a temp file
  and greps that, leaving URLs and escaped slashes in regex literals intact.
- **Four more text-pins become behaviour-pins.** A comment-stripped grep does not catch a
  polarity inversion or a renamed constant, so each is pinned on the line that carries it:
  the `view()` guard including its `!` and early return (dropping one character makes
  `revealState` return the unjudged sentinel on every browser that *has* `view()` — every
  browser the harness runs on — and reveal detection ceases with the suite green); the
  `CSSContainerRule` comparison and the `if (!el) continue;` beneath it (either one
  renamed or inverted silences the `@container` lint entirely); and `revealState`'s own
  `[data-motion="reveal"]` queries, both the section-root `matches()` and the descendant
  `querySelectorAll()` (renaming the attribute value collects zero devices and every
  section is skipped). All four are the same defect as the `[type="module"]` pin this
  branch already closed.
- **`bin/composition-preview.mjs --tokens` prints the preview `:root` and exits 0 without a
  browser**, and `tests/checks/wp-craft-compositions.sh` asserts that the emitted
  `--container-max` is a CSS length. Every other assertion about that token reads source
  text, which has four recorded bypasses — comment the line out, rename the key, reassign
  after the read, add a duplicate key later in the object — and an output assertion
  defeats all four at once. One `rootBlock()` builds both the flag's output and the page's
  own `<style>`, so the two cannot drift.
- **`dead-scroll` learns to tell a section that does not move from one the harness cannot
  read.** `reveal` publishes no `--motion-p` and no composition carries a cue, so every
  library-built section reported `dead-scroll` forever — 392 findings on a 12-page build
  whose only clean section was its one hand-built pin. `bin/demo-verify.mjs`'s probe now
  samples the reveal child the ruleset targets (`[data-motion="reveal"] > *`); a section
  the harness still cannot read reports `unobserved` and stays advisory, and a page with
  zero `data-motion` devices reports `no-engine` instead of walking clean on an empty
  frame signature. Sampling the reveal child was necessary but not sufficient: `reveal`
  is a one-shot entry transition a few pixels long, driven by the child's own `view()`
  progress around `scrollY = top - viewport`, so a sparse walk caught it by luck and a
  miss reported `dead-scroll` on a section that reveals perfectly. A section carrying no
  `pin`/`pan`/`kinetic`/`wipe`/`drift` is now judged by two samples — below the fold and
  fully entered — and reports `dead-scroll` only when no reveal child moved between them.
  Scrubbed sections keep the walk and its stall logic unchanged.
- **Advisory findings stop failing the round.** `unobserved` raised `demo-verify.mjs`'s
  exit code exactly like `dead-scroll`, so a page the harness merely could not read still
  failed — the false positive moved rather than left. The blocking/advisory split is named
  once, at the top of the file; advisory lines print with `[advisory]` and land in
  `findings.json` like any other, a run whose findings are all advisory exits `0` and says
  `nothing blocking, N advisory finding(s)` instead of looking clean, and any blocking
  finding still exits `1`.
- **The compositions that failed the library's own slop gate are scroll-linked now.**
  `closing-block` ran a 7s infinite conic sweep and `proof-row` a 38s infinite translate,
  both reported by `impeccable` as `marquee` at `category=slop`/`severity=warning` — the
  shape that fails a verification round before a screenshot is taken — so every build
  using the closing or proof role failed by construction. Both are now scroll-linked
  through the view timeline: the beam sweeps once on entry, the name track drifts while
  its section is on screen. No device, no span, no motion-cost change, so the role table
  stays true. `proof-row` loses its hover/focus pause block, which existed only because
  the movement was automatic.
- **A page whose motion engine never ran fails again, and a spoofed reveal stops passing.**
  Making the harness stop crying wolf had also stopped it barking at a real intruder: a
  demo carrying `pin`/`kinetic` markup whose `motion.js` never booted — a `file://`-blocked
  module script, the failure that shipped a demo the client rejected — reported `unobserved`
  and exited `0`. `drive()` is contractually required to publish `--motion-p` for
  `pin`/`pan`/`kinetic`/`wipe`/`drift`, so a stalled section carrying one of those with
  nothing samplable now reports blocking `dead-scroll`; `unobserved` stays for the section
  the harness genuinely cannot read. The two-point reveal check now compares the reveal
  child's scroll-driven animation (`getAnimations()` filtered to a `ViewTimeline`) instead
  of its computed opacity and transform, which any decorative `@keyframes` on the same
  children — or a percentage transform re-resolving after a lazy image loads — could move
  on a section with no reveal wired at all. `findings.json` rows now carry
  `"advisory": true`, so a consumer reads the field instead of keeping its own copy of the
  kind list. Scrubbed sections keep today's geometry and stall logic.
- **A reveal on a browser without `view()` is unjudged, not dead.** `revealState` reads
  `getAnimations()` for a `ViewTimeline`, but `motion.js` drives `reveal` in GSAP whenever
  `CSS.supports('animation-timeline', 'view()')` is false, and a GSAP tween is rAF-driven
  and invisible to `getAnimations()` — so on such a browser a working section read
  `none|none` and was reported `dead-scroll`. It now returns the unjudged sentinel there,
  the same one the above-the-fold and `parallax` ceilings return, and `verify.md` records
  it as the fourth limit. Latent on the current harness, where `view()` is supported.
  `tests/checks/wp-craft-detect.sh` also pins the two-point block's own guard by polarity
  and by what it gates: inverting `!b.scrub` or wrapping the condition in `false &&` left
  every existing assertion green while reveal detection disappeared entirely.
- **`bin/demo-verify.mjs` lints dead `@container` rules and serves the walk over HTTP.**
  An `@container` rule whose subject has no ancestor declaring `container-type` never
  applies and said nothing about it — this cost a previous effort a whole task and cost a
  real client build six blocks that never rendered, found only from screenshots. A new
  `container-noop` finding, blocking, reports the selector; the ancestor walk starts at
  `parentElement`, never at the element itself, because a container query never matches
  the container an element establishes on its own. Separately, the walk loaded pages as
  `file://`, where an external `<script type="module">` is a cross-origin fetch against
  an opaque origin, so Chrome blocks it silently, the engine never boots, and every page
  reports dead scroll with no trace of why — the exact failure this branch exists to fix,
  and it cost an hour to diagnose. Local targets are now served on an ephemeral
  `127.0.0.1` port instead; the contact sheet stays on `file://`, since it is a locally
  generated file with inlined images. A new advisory `external-module` finding names any
  module script that survives into a built demo, since it works served and breaks the
  moment a client double-clicks the file.
- **A malformed percent-encoding no longer kills the walk.** `demo-verify.mjs`'s demo
  server decoded the request path outside its `try`, so a request carrying a bare `%` —
  a stray character in an href or asset path is enough — threw `URIError` out of the
  request handler and Node killed the process mid-run. The decode is inside the guard
  now and answers `400`; traversal vectors still `404` and a directory still `403`.
  Three assertions in `tests/checks/wp-craft-detect.sh` also stopped being text-pins:
  the container lint's polarity (`if (!found)`), the module-script selector
  (`script[type="module"][src]`) and the once-per-page `staticChecked` gate are each
  anchored on the token whose inversion or typo silently switches the check off.
- **The 392-finding client baseline re-walked at 33.** `bin/demo-verify.mjs demo/` against
  `next step credit solution/demo/` (12 pages, the build this branch exists to fix) now
  reports 32 `dead-scroll` and 1 `container-noop`, zero `unobserved` and zero
  `external-module`. The drop is real and traces mostly to serving over HTTP: with the
  module script no longer blocked, `motion.js` boots and most sections read as moving
  outright, with no finding at all, rather than falling back to `unobserved`. None of the
  32 remaining `dead-scroll` findings moved to `unobserved` on this walk, because
  `unobserved` requires the probe's page-wide `samplable` count to be zero — a whole-page
  "the engine produced nothing readable" state that a booted engine essentially never
  reaches, even on a page carrying a genuine dead section elsewhere. The remaining findings
  are one real design defect repeated across pages (`closing-block__inner`, dead on 9 of 12)
  and one page with two additional dead sections (`index.html`'s `how` and `steps__title`).
  This walk does not exercise the `unobserved` path at all; that it fires correctly when a
  page's engine is genuinely unreadable is asserted by `tests/checks/wp-craft-detect.sh`,
  not demonstrated by this baseline.

## [1.14.0] - 2026-09-09

### Added
- **A vendored 192-row domain table constrains the composition plan, never the tokens.**
  `skills/wp-demo-craft/references/domains/domains.csv` takes only `domain`, `keywords`,
  `page_pattern`, `considerations` and `confidence` from `nextlevelbuilder/ui-ux-pro-max-skill`
  (MIT, imported by `bin/domains-import.sh`, with `SOURCE.txt` recording the exact ref and
  commit it pulled). Its colour and typography tables were refused on sight: the source
  catalogue maps 192 product types onto 50 distinct primary colours and pairs Playfair Display
  with Inter, which would hand every client in a category the same palette — exactly what this
  plugin's fingerprint gate exists to refuse, and a pairing its own type floor already names
  Inter against as the most-used face in machine-generated pages. New check:
  `tests/checks/wp-craft-domains.sh`.
- **`/wp-demo` and `/wp-yolo` classify the client's domain before the composition plan, and
  the match never touches a token.** Two distinct keyword hits is the bar; the highest count
  wins; an exact tie reports both names and proceeds `unclassified` rather than guessing; and
  because the keyword lists are English-only, a docs set with no English-language material is
  reported `unclassified` with that reason stated instead of silently falling through. A
  match's `page_pattern` and `considerations` fold into the brief as constraints on which
  section roles the plan may pick — colour and type still come only from `demo/DESIGN.md` and
  the client's own material. Recorded once per site in `.wp-create.json` under `"domain"`, and
  read rather than re-derived on a later run.
- **`reveal` now has a second, CSS-only engine, and the two never double-drive the same
  section.** `starter-theme/__tailwind__/assets/css/src/tailwindcss/utilities/motion.css`,
  pulled in through the theme's existing Tailwind entry (`main.css`), drives every
  `[data-motion="reveal"]` child under `@supports (animation-timeline: view()) { @media
  (prefers-reduced-motion: no-preference) { ... } }`. `motion.js` tests the identical
  feature-query string, `CSS.supports('animation-timeline', 'view()')`, and yields the device
  to CSS whenever it matches and motion is not reduced, so exactly one engine drives `reveal`
  in every combination of feature support and reduced-motion preference. New/extended check:
  `tests/checks/wp-craft-motion.sh`.
- **A seventh rubric line, `Name-swap`, plus scales derived in `oklch()`.** Replacing the
  client's name with a competitor's throughout the copy and re-reading it catches a page that
  describes a category rather than a business — graded from the sheets like the other six
  lines. `demo/DESIGN.md` now carries a token's `oklch()` triple beside its recorded hex value,
  because equal numeric steps in oklch are equal perceptual steps while a scale stepped in hex
  or HSL produces visible bright and dark spots at the same interval; the hex value stays the
  recorded token so nothing downstream breaks. `taste.md`'s Depth section now warns that grain,
  film texture and tactile brutalism are in every trend roundup published this year, so
  reaching for them because they read as anti-AI is today's antidote becoming tomorrow's
  default unless the reason is stated in `demo/BRIEF.md`.

### Changed
- **Every composition sizes its breakpoints to its own container, not the viewport.** Each
  root declares `container-type: inline-size` and every size-based breakpoint is an
  `@container` query, so a section dropped into a narrow column lays out for the column
  instead of the screen. An element never matches a container query against the container it
  establishes itself, so four compositions needed an `__inner` wrapper to carry the queried
  layout. Three of them — `faq-list`, `hero-split` and `hero-type` — moved `data-motion` onto
  that wrapper so `reveal` still staggers the same children; `footer-line` carries no
  `data-motion` attribute at all, because it is not a reveal composition. The
  fluid ramps do not share the fix: the `vw` in `clamp()` gaps and type scales, 40 occurrences
  across 12 of the 13 compositions, still key off the viewport, so a section in a narrow column
  still takes desktop-maximum spacing. `compositions/README.md` and the root `CLAUDE.md` both
  record that as open work rather than claim it is done.
- **Craft mode is reference-first and render-verified (`wp-demo-craft` v2).** The first real
  craft build shipped blind — nothing checked whether a browser was even usable before the
  build started, so a 12,000px page with an empty first screen and a headline clipped mid-word
  by its own kinetic mask reached the client. v2 makes a browser a hard prerequisite:
  `bin/demo-verify.mjs --probe` exits 0 for a usable browser and 2 otherwise, `/wp-demo` stops
  on 2, and the script's `playwright-core` resolution ladder now also checks `<cwd>/node_modules`,
  which is what makes a project-local install visible to the plugin's own script. The build now
  starts from `demo/DESIGN.md` — tokens assembled from the client's own docs, `npx designlang`
  run on their site, and a vendored MIT catalogue of 64 real-brand DESIGN.md files under
  `skills/wp-demo-craft/references/design-md/` (64 and not a rounder number because ten upstream
  entries carry no YAML front matter and cannot supply parseable tokens), with a generated
  `INDEX.md` regenerated by `bin/design-md-index.sh` and a neutral `_preview.md`. Every section
  is built from a new composition library (`skills/wp-demo-craft/compositions/`, thirteen worked
  sections, each with markup, CSS, a README naming what it ports and its licence, and two
  rendered previews checked by `bin/composition-preview.mjs` against the neutral reference, plus
  a role table and `fills.json`), and the build is verified by looping `npx -y impeccable@4
  detect --json` (pinned to major version 4 — `@1` does not exist on the npm registry) plus a
  six-line critique rubric written to `demo/VERIFY.md`, for at most three rounds, with no
  fingerprint recorded for a build that never passes. Findings from the detector carry a
  `category` of `slop` or `quality` — there is no P0 severity — and are always counted by
  parsing the JSON array on stdout, never read from the exit code: exit `0` means the scan
  completed with no primary findings, `1` means a target could not be scanned, `2` means
  findings are present. A `slop` finding at `warning` severity fails the round outright; `quality` findings are
  reported and weighed against the rubric instead. New checks: `wp-craft-gate.sh`,
  `wp-craft-detect.sh`, `wp-craft-compositions.sh`, `wp-craft-design-md.sh`, `wp-craft-rubric.sh`.
- **Variety is no longer the product.** The old forced-variety rules are gone; a motion budget
  replaces them — a pin outside the peak is capped at span 2.0, the one element marked
  `data-motion-peak` may reach 3.0, and interior pages never pin — and the fingerprint gate now
  compares only palette and type pair instead of six structural axes, because fingerprinting
  structure was pushing builds into shapes chosen to clear the log rather than to suit the
  client. Split stage and rhythmic cutlist are retired from the default grammars.
- **`/wp-demo-verify` is now the runner for the detector, the walk and the critique**, and
  `/wp-demo` Step 2.6 is rewritten around the same order: gate, `DESIGN.md`, brief, grammar and
  composition plan, build, loop, record. A directory target now walks every `*.html` in it, one
  output folder per page, with `findings.json` shaped `{ pages: [...] }`. `/wp-init` reads
  `demo/DESIGN.md` before scraping `:root` and carries it into the theme through an alias table
  so the starter's own tokens resolve onto the craft vocabulary; craft demos skip
  `/wp-tailwindify`.

### Fixed
- **`motion.js`** refuses the kinetic split on an `h1` — a hero uses `reveal` and never
  `kinetic`, and a bare `data-motion-cue` does nothing outside a section the engine scrubs
  continuously, so it could not have rescued one anyway — gives the split mask headroom so
  ascenders and descenders never clip, and warns on a pin span above budget when the section is
  not marked `data-motion-peak`.

## [1.13.0] - 2026-09-09

### Added
- **`/wp-yolo` now runs `/wp-audit --all` as part of its finish phase.** A yolo build
  shipped without anyone ever measuring SEO, Core Web Vitals, accessibility, security or
  coding standards — `/wp-finalize`, `/wp-polish` and `/wp-responsive-check` all judge
  demo parity, nothing judged quality. It is Step 5 item 7, MANDATORY like the other
  three, its Step 9 fix prompt pre-answered yes, and fixes that touch theme CSS,
  templates or enqueues re-run `/wp-finalize`'s Layers 2-3 so a perf or SEO fix cannot
  silently break demo parity. `tests/checks/wp-yolo-checkpoint.sh` guards it.
- **`/wp-robin` and `/wp-aos-animator` — runner commands for the plugin's only two action
  skills.** Every skill here is `user-invocable: false`, which is the layer rule and stays
  that way, so the two skills that actually *do* something had no way in: the README once
  carried phantom command rows for them, those were removed, and the docs then told users to
  describe the task in prose — discoverable only by reading docs a user typing a slash never
  opens. `/wp-robin [wp-root]` resolves and validates a WordPress root, checks the database
  client and webp converter the skill requires, and runs the skill's bundled `robin-fix.sh`
  with `WP_ROOT` set. `/wp-aos-animator [<theme>] [templates…] [--report-only]` sequences the
  skill's audit → install → enqueue → init → animate pipeline and dispatches one subagent per
  template for the animate phase, with `--report-only` stopping after the audit on the same
  contract as `/wp-audit`'s flag. Both commands dispatch and never reimplement: the phases,
  the settings, the skip list and the animation table stay in the skills, which remain the
  source of truth. New check: `tests/checks/skill-runner-commands.sh`, whose load-bearing
  assertions are the negative ones — that neither skill has been flipped to
  `user-invocable: true`, and that neither command carries a copy of the procedure it runs.

### Changed
- **`/wp-init` now defaults to Polylang, not field suffixes.** The old default was justified
  on inertia — "what every existing project uses" — and it costs the second language its
  entire search presence: one URL serves both languages off `?lang=`/cookie/`Accept-Language`,
  so a crawler that sends no cookie only ever sees the primary language; `?lang=es`
  canonicalizes back to the primary URL; there is no hreflang pair because there is only one
  post; and per-post meta leaves Rank Math nowhere to store a translated title or description.
  Step 0.7 now lists Polylang first, defaults to it on Enter, states the SEO reason, and
  offers `suffix` as what it is — a language toggle for a site whose second language does not
  need to be found. Existing projects are untouched: the strategy is still read from the
  project's `.claude/CLAUDE.md` and an absent `i18n strategy` line still means `suffix`.
  `tests/checks/wp-polylang.sh` guards both the new default and that fallback.
- **The docs no longer say these two capabilities have no slash command.** `README.md`,
  `docs/commands.md` and `docs/workflows.md` each said so, correctly, until now; all three
  now state that the skills are invoked through their runner commands while remaining
  non-invocable themselves, so the layer rule reads as intact rather than abandoned.

### Fixed
- **A bare `/wp-yolo <folder>` skipped its own checkpoint.** The command name was being
  read as the `--yolo` flag, Step 1 called the default mode "hands-off", and Step 3 said
  "ask" without a stop, so the model approved the plan for the user and rolled into the
  build. Step 1 now states the name is not the flag, Step 3 is a hard stop that prints a
  build plan (pages, CPTs, content types, skips, review items) and ends the turn, and
  `AskUserQuestion` is in the command's tool list. `tests/checks/wp-yolo-checkpoint.sh`
  guards it.
- **`/wp-yolo` stopped after seeding and told the user to run the finish commands
  himself.** `/wp-finalize`, `/wp-polish` and `/wp-responsive-check` were bare one-word
  bullets in Step 5, so a long run treated them as optional and reported "site works"
  with the 3-layer demo-parity gate never executed. They are now marked MANDATORY with a
  dispatch instruction each, and a completion rule says a run that reaches the report
  without all three is incomplete, under `--yolo` too. Step 5.5 also pointed at the wrong
  Step 5 item for `/wp-finalize`. Same check guards it.
- **`/wp-init` never wrote the site's name or tagline, so every scaffolded site shipped
  "Just another WordPress site."** The command already asked for a one-sentence description
  and then dropped it on the floor: `blogname` was set only by `/wp-create`'s
  `core install --title` (so an adopted site kept the previous project's name) and
  `blogdescription` was set by nothing at all. Both are `critical` in `/wp-finalize`'s
  Layer 2 gate, which therefore failed on every project by construction. `/wp-init` now
  extracts a tagline from the demo (`<meta name="description">`, then the hero subtitle),
  shows it among the demo-first defaults for confirmation, prompts for it when there is no
  demo, and writes both options next to theme activation. Under `i18n strategy: polylang`
  this writes the primary language only — but that is the point, because Polylang omits an
  empty option from its string table entirely, so an unset tagline was not even translatable.
  New check: `tests/checks/wp-init-site-identity.sh`.
- **The theme named fonts it never loaded, so every non-`/wp-yolo` build rendered in a
  fallback stack.** `/wp-init` Step D4 wrote the demo's font *names* into `--font-primary`
  / `--font-secondary` and nothing ever carried a font file, which is why a converted theme
  looks "almost right" and nobody can say what changed. Three parts, one cause: the Tailwind
  starter shipped `--font-primary: "Inter"` with no `@font-face` and no Inter anywhere, so
  even a demo-less scaffold rendered in the system fallback; `functions.php` preconnected to
  `fonts.googleapis.com` unconditionally while the theme never made one request to it — a
  dead hint on every page; and the demo's families were never fetched at all. New `/wp-init`
  **Step 4.5: Font carry** self-hosts every family the theme names, including Google Fonts
  (downloading the woff2 with a browser user-agent — the default `curl` UA silently gets the
  legacy TTF build, and every fetch uses -f so an error page is never written into a .woff2),
  guarantees `font-display: swap` on every carried block rather than only keeping it where
  Google emitted it, drops a family that could not be carried from the head of its token
  instead of leaving the theme naming a font it does not have, preloads the one file that pays for itself (the primary family's regular
  latin subset — preloading every unicode-range subset would defeat the lazy loading that
  makes carrying them all cheap), and the starter's default tokens are now a system stack,
  which is the only value that renders as written when there is no demo. `/wp-yolo` Step 4.5 stops
  permitting a Google Fonts preconnect so both commands give one answer.
  New check: `tests/checks/wp-init-font-carry.sh`.
- **The audit agents now run the checks they document.** A batch of SEO, performance and
  Rank Math checks had been appended below the agents' last step with a note to "add these
  to the tables above" — an instruction to a reader, left undone, so an agent that only
  runs what Step 1 and Step 2 tabulate ran none of them. Every code is now a row in its
  own tier table (`wp-audit-seo` SEO-035 to SEO-050, `wp-audit-performance` PERF-047 to
  PERF-052), the Rank Math steps sit beside the steps they extend rather than after
  Step 13, and `tests/checks/audit-check-tables.sh` fails if a check code is ever
  referenced without being tabulated again.
- **Broken `wp eval` payloads in those checks.** Two were PHP parse errors, several used
  `$wpdb` and `$p` unescaped inside a double-quoted shell string (the shell ate the
  variable before PHP saw it), and one shipped a `TODO` as a CRITICAL check that compared
  nothing. The five checks that need rendered `<head>` values now share one snapshot
  command instead of fetching the site five times.
- **`glob('/**/*.php')` skipped the theme root.** PHP's `glob()` has no recursive `**`, so
  the theme-JSON-LD conflict scan never saw `functions.php` — the single most likely place
  for a theme to emit schema. Replaced with `RecursiveDirectoryIterator` in all three
  copies, and the new check refuses the pattern.
- **PERF-016 and PERF-048 contradicted each other** — one asked for `fetchpriority="high"`
  on the hero image, the other flagged it. They are two halves of one decision (is the LCP
  an image or text?) and are now cross-referenced as such.
- **Two audit checks passed by never looking at anything.** The Rank Math sitemap
  validation reported that noindex pages "may still be in" a sitemap it had already
  fetched, and counted drafts site-wide without looking at it at all. It now walks
  `sitemap_index.xml` into its child sitemaps — the index lists children, not URLs, so a
  permalink search against the index alone could never match — and compares whole `<loc>`
  values, because a permalink is a prefix of its own paginated children and `/blog/page/`
  was reported as listed whenever `/blog/page/2/` was. The walk is gated on
  `<sitemapindex>`: in a flat `<urlset>` the `<loc>` entries are the post URLs, and
  following them would refetch every published post.
- **The rendered-head checks (SEO-038 to SEO-043) read `canonical`, `og:locale` and
  `hreflang` out of the markup with regexes** that assumed double-quoted attributes and
  `rel` before `href`. Both are optional in valid HTML, and on the other order the regex
  returns an empty string — which reads as "no finding", so the checks passed a broken
  site. Now parsed with `DOMDocument` + `DOMXPath`. The snapshot issues one request per
  post against the site itself, so it is capped at 50 with the reason stated; SEO-041
  gains the caveat that a counterpart missing from the sample is not a broken pair.
- **PERF-047's deferral recipe unhid the theme's real print stylesheet.** It documented a
  footer script sweeping every `link[media="print"]` to `media="all"` — a genuine print
  stylesheet is such a link too. Replaced with a `style_loader_tag` filter that defers
  only the handles it names.

## [1.12.1] - 2026-09-04

### Changed
- **The demo is documented as every path's input, not a step inside path B.** Every
  path converts a demo: `/wp-init` reads it to learn the project, `/wp-yolo` converts it
  page by page, `/wp-section --transcribe` copies its declared values and `/wp-seed` turns
  its files into WP Pages. Both `README.md` and `docs/workflows.md` now carry a required
  demo stage between setup and build with the three ways in (hand a mockup to `/wp-init`,
  polish files dropped into `demo/`, or `/wp-init` then `/wp-demo` from nothing). This also
  closes an ordering trap: a bare `/wp-init` run before any demo exists can never trigger
  its demo-first flow, so a reader following the old order answered by hand what the
  mockup already knew.
- **The README opening diagram no longer contradicts the corrected section further down**,
  and three docs stopped naming a `basic` template that `/wp-init` only keeps as a legacy
  alias for `tailwind`. Both build paths open with a `Needs:` line, `/wp-init`'s three
  questions state their defaults, `/wp-demo-verify` is the name shown everywhere with
  `/wp-responsive-check` noted once as its alias, and `docs/commands.md` gains the demo
  section and the `/wp-demo-verify` table row it was missing.

## [1.12.0] - 2026-09-04

### Fixed
- **Three ways a design frame's numbers are transcribed correctly and still render wrong**,
  now in `wp-css`'s transcription contract: a frame `y` is a page coordinate in a page with
  no site chrome, so a breadcrumb the design never drew shifts everything below it (take
  vertical positions as distances between neighbours); section gaps are authored and
  irregular — one real design ran 53, 73, 103, 94, 107, 117, 147, 128, 73, so a single
  spacing token is uniformly wrong and splitting a gap across two paddings renders their sum;
  and a px width in the frame is a fraction of that frame's track, which frozen as px inside
  a `max-width` query holds the narrow-frame width up to the breakpoint.
- **Four `/wp-debug` commands ran a `bash -c` inside a command substitution and read the
  wrong path in silence.** Inside `$( … )` bash re-parses the text as a fresh command, so
  the `\"` written to survive the outer quoting arrives as a literal quote: the inner shell
  dies on `unexpected EOF while looking for matching \"`, the substitution is empty, and
  `tail -50 "$( … )/wp-content/debug.log"` reads `/wp-content/debug.log` and still exits 0.
  The wrapper bought nothing — `$WP` is a command plus its global arguments and word-splits
  correctly on its own. Dropped in all four, with the expansion quoted at the point of use.
  New check: `tests/checks/no-nested-bash-c.sh`.
- **`/wp-debug` can now diagnose "my CSS change doesn't show".** A static version constant in
  `wp_enqueue_style` keeps the URL stable while the file changes, so browsers serve the copy
  they cached. The `filemtime()` rule already existed in `wp-theme-standards` but only reaches
  themes this plugin generated; `/wp-debug` runs on themes it did not write. The same symptom
  was diagnosed twice as something else — once as broken images, once as a specificity
  problem — before anyone read the enqueue. New checks:
  `tests/checks/design-value-transfer.sh`.
- **A headline field that carries markup now has a correct escaper.** Section headlines
  routinely hold a `<span>` the CSS paints as a highlight and `<br>` where the design breaks
  the line, and both usual answers were wrong: `esc_html()` prints the tags, `wp_kses_post()`
  admits `<iframe>`, `<img>`, inline styles and a class on any tag — the run of the page from
  a headline field. `wp-theme-standards` and `wp-template` now carry `wp_kses()` with a
  two-tag allowlist, forbid `the_field()`/`the_sub_field()` by name (they echo unescaped and
  read as the natural template call), and state the corollary: a CSS class inside field
  content is not a thing that exists, so which break applies at which width is chosen in the
  stylesheet by `br:nth-of-type()`, with the `display:none` whitespace trap spelled out.
  New check: `tests/checks/acf-markup-escaping.sh`.
- **The CSS skills now say where a reset must live.** A reset scoped to a page —
  `.page img { max-width:100%; height:auto }` at (0,1,1) — outranks a single class on
  that same image at (0,1,0), so the image ignores its own class and paints at its
  intrinsic size. The symptom reads as "my CSS is not loading": `getComputedStyle`
  returns the reset's value and the class is right there in DevTools. Both
  `wp-css-system` and `wp-tailwind-system` now carry the rule and its remedy, `:where()`,
  which contributes no specificity. New check: `tests/checks/css-reset-specificity.sh`.
- **`/wp-tailwind-migrate` now gates on the Tailwind major instead of assuming it.** Every
  step it runs writes the v4 layout and Step 5 deletes `assets/css/styles.css`, so pointing it at
  a v3 theme — `tailwind.config.js`, a PostCSS build, `style.css` at the theme root carrying
  the `Theme Name:` header — turned a conversion into an unrequested v3→v4 upgrade plus a
  restructure of every partial, and then removed the stylesheet the unmigrated templates were
  still styled by. Step 0 reads the installed version and stops with what it found.
- **`/wp-tailwind-migrate`'s visual comparison no longer presents a differing-pixel count as
  proof.** `compare -metric AE` is not deterministic where the GPU composites: on a page with
  `backdrop-blur` cards, two consecutive captures of the *same unchanged page* differed by
  more than baseline-vs-migrated did. The step now establishes that noise floor first, and
  adds the numeric contract — geometry measured in the page — as the real oracle, including
  the on-screen order of every reversible row. A dropped `flex-row-reverse` mirrors a section
  while every box keeps its size, so a size-only contract reports a perfect match.
### Added
- **`wp-demo-craft` skill and craft mode for `/wp-demo`, `/wp-yolo` and `/wp-polish`**: a
  design floor, page grammars, a scroll-motion device kit and an anti-slop refuse list for
  demos that need to feel premium rather than templated. `/wp-demo` now infers craft or plain
  mode from the project's docs (`--craft`/`--plain` override it), records the choice as
  `demo mode` in `.wp-create.json`, self-authors `demo/BRIEF.md` with a per-section feeling
  curve, and checks the plan against `~/.claude/wp-builder/FINGERPRINTS.md` so two clients
  never ship the same shape. Motion is a contract, not a library call: sections carry
  `data-motion-*` attributes and an inlined `motion.js` bundle built on GSAP ScrollTrigger.
  `/wp-polish --craft` runs the same skill as a retrofit audit against an existing demo
  instead of a plain normalize pass.
- **`/wp-demo-verify`**: replaces the single-screenshot check with a scroll walk: per-section
  screenshots at desktop and mobile widths, a reduced-motion pass, full-page shots at five
  breakpoints, and machine findings for dead scroll, cues that never reach full opacity,
  horizontal overflow and clipped copy. `/wp-responsive-check` is now an alias that dispatches
  to it. A green machine run is explicitly not a pass on its own; the command still requires
  a human feel check against `demo/BRIEF.md`'s curve.
- The cinematic path (`/wp-cinematic-demo`, `agents/wp-cinematic.md`) now reads
  `skills/wp-demo-craft/` first for the same design floor and feeling curve a static craft
  demo uses, with the kit's own contract still owning everything video-specific.
  `/wp-demo-verify`'s dead-scroll check samples the stage `<canvas>` so a cinematic reel whose
  video never actually changes between scenes is caught the same way as a static section with
  no motion.
- **`position: absolute` is for superposition, not for layout**: a mockup's `x`/`y` is where
  an element fell in one frame at one width, so an absolute box copied from a demo is out of
  flow and the first longer ACF value (or the second language) puts it on top of its
  neighbour. `skills/wp-css-system/SKILL.md` and `skills/wp-tailwind-system/SKILL.md` now own
  the rule in full — flex/grid for layout, `absolute` only for a real overlap (badge on an
  image, floating icon, dropdown, `inset:0` veil, `sticky`/`fixed`, `.sr-only`), a
  survives-a-content-change test before the declaration, and the instruction to read a
  mockup's offsets as `gap`/`padding` rather than `left`/`top`. `agents/wp-css.md` carries the
  same section and a new rule in its Rules list; an `absolute` inherited from demo HTML during
  `/wp-polish`, `/wp-section`, `/wp-yolo`, `/wp-tailwindify` or `/wp-tailwind-migrate` is
  explicitly not a value to preserve. `tests/checks/wp-layout-flow.sh` fails if the wording
  disappears from any of the three files.

## [1.11.0] - 2026-09-02

### Added
- **`wp-contributing` skill and `/wp-contribute`** — the conventions a contributor could
  previously only learn by breaking them: calls go down the four layers and a command
  dispatches builders rather than reimplementing them, tests are grep gates over prose
  (with the house style for writing one), the frontmatter contract per layer, the two i18n
  systems, and the PR and release rituals including the stacked-PR squash hazard. The skill
  auto-loads when editing this repository; `/wp-contribute new` scaffolds a layer file
  together with its check and its doc rows, so a PR cannot arrive missing either.
- **`bin/doc-sync-check.sh`** — asserts the docs still describe the plugin that exists: every
  command has a README row and a `docs/commands.md` entry, every documented command exists
  (the phantom `/wp-robin` and `/wp-aos-animator` rows survived two releases), every agent and
  skill is listed, frontmatter is present per layer, the four version references agree, and
  `CHANGELOG.md` moved when behavior did. Run by `/wp-contribute check` and
  `tests/checks/wp-contributing.sh`.

### Fixed
- Documentation drift the new gate found on its first run: eleven agents (`wp-cf7`,
  `wp-normalize`, `wp-context`, `wp-cinematic` and the seven `wp-audit-*`) and three skills
  (`wp-environments`, `wp-audit-standards`, `wp-audit-seo-standards`) were missing from the
  README tables, and `wp-aos-animator` and `wp-robin` declared no `user-invocable`, leaving
  them inert rather than broken.

## [1.10.0] - 2026-09-02

### Fixed
- **Tailwind CSS is recompiled after every builder.** `functions.php` enqueues only the
  compiled `assets/css/dist/main.css`, which `/wp-init` built before any section existed;
  `/wp-section`, `/wp-header`, `/wp-footer`, `/wp-page`, `/wp-cpt` and `/wp-yolo` never
  rebuilt it, so the live site — and `/wp-yolo`'s parity gate — showed an unstyled page
  unless `npm run preview` happened to be running. New `bin/tailwind-rebuild.sh` runs
  `npm run tailwindbuild` at the end of each (no-op on non-Tailwind themes, skipped when a
  watcher owns `dist/`). `/wp-init`'s summary and `docs/workflows.md` now explain the
  live-reload workflow. `tests/checks/tailwind-rebuild.sh`.
- **`wp-robin`'s `robin-fix.sh` did nothing on MariaDB, and gave up on a partially populated queue.** Three bugs, found running it against a live site (MariaDB 10.x, WP 7.1, 95 attachments, only 2 of them in the queue): the thumbnail scan aborted the whole script under `set -e` whenever the theme registered no `add_image_size`; the attachment query used `CAST(meta_value AS JSON)`, which MariaDB does not implement, and read `_wp_attachment_metadata` with `json_decode()` even though WordPress serializes it — so the query errored out and the loop registered nothing; and registration ran only when the queue was completely empty, so a queue holding a couple of stale rows was reported as done and 93 attachments were never optimized. Registration now runs for every attachment missing from the queue, the counts are read with `unserialize()`, and both `NOT IN (...)` subqueries exclude `NULL` `object_id` values, which otherwise make the whole predicate match no rows.
- The same script no longer reports a clean run it did not have: a failed `INSERT` is counted as a failure rather than silently inflating the total, mariadb's stderr is no longer discarded, a missing queue table stops the run instead of producing ten unexplained errors, an attachment whose original file is gone is skipped instead of being queued as a successful optimization, and a failed attachment query aborts instead of announcing "0 new attachments". Step 4 now reads every attachment in one query and one PHP pass and inserts in batches, rather than opening a client and forking two interpreters per image.

### Added
- **`/wp-section --hybrid`** now exists. `/wp-init`, `/wp-cinematic-init` and
  `docs/cinematic-mode.md` had been pointing users at the flag while
  `commands/wp-section.md` never parsed it. It appends a layout to the `trailing_sections`
  flex field, renders via `get_sub_field()`, writes CSS to `cinematic.css` and skips page
  injection; refused on non-cinematic projects. `tests/checks/wp-section-hybrid.sh` guards it.
- **`/wp-seed` works without `.wp-create.json`** — falls back to bare `wp` and the
  `Languages:` line of `.claude/CLAUDE.md`, matching `/wp-debug`. `tests/checks/wp-seed-fallback.sh`.
- **Five gaps a full client build hit in production, closed at the source** (#30). `wp-cf7`
  now treats a CF7 form as what it is — a post row no build step ever scans: one hook class
  per element declared in the theme CSS instead of utility classes that vanish when the
  theme normalizes its variants, plus an idempotent `inc/seed/cf7.php` so the markup travels
  with the theme. `wp-aos-animator` documents the identity `transform` AOS leaves behind
  (stacking context, containing block, rewritten `transition-property`) as skip conditions.
  `wp-tailwind-system` separates Tailwind's `hidden` utility from HTML's `hidden` attribute.
  `/wp-page legal` emits `inc/legal-search.php`, and Rank Math builds no breadcrumb on a 404.
- **Twenty-one defects a 52-commit client build had to work around** (#31), with
  `docs/postmortem-reference-build.md` carrying the full table — defect, cost, root cause,
  fix — including the three left open and why. Five were silent bugs in the Tailwind starter
  (SVG upload support, an ACF options `ID` collision, `main.css` pathing, and 36 translation
  twin fields that were dead on a Spanish-primary site because `fields/*.php` hardcoded `_es`
  while the helper appends the non-default suffix — `/wp-init` now rewrites the suffix and a
  grep proves it). Sixteen more are now documented traps with grep gates: the `_`-in-arbitrary-
  variant escape that silently killed 22 focus indicators, unlayered CSS beating
  `@layer utilities`, `/wp-yolo` porting no demo JavaScript (new Step 4.6 enumerates
  `demo/js/*.js`) and having no re-run gate (it now refuses on an already-built theme without
  `--force`), Rank Math shipping active but unconfigured, and ACF options fields with no
  `default_value`.

### Changed
- README "Tech Stack" no longer claims vanilla CSS / no build tools; it names the Tailwind
  starter, the cinematic starter and the suffix-or-Polylang i18n choice.
- **Docs restructured around the three build paths.** README now opens with the
  setup → path A (`/wp-yolo`) / B (step by step) / C (cinematic) → finish shape and a
  command table that marks each command required / optional / auto. Long-form guides moved
  to `docs/workflows.md` (per-path how-to, `/wp-init` choices, i18n systems, shared files)
  and `docs/commands.md` (arguments, inputs, outputs per command). Removed the phantom
  `/wp-robin` and `/wp-aos-animator` command rows — they are skills, not slash commands.
- `docs/code-connect-draft.md` — proposal for Figma Code Connect integration (#26), draft only.

## [1.9.0] - 2026-08-29

### Added
- **Per-task model routing** — every agent now declares a `model:` cost tier in its
  frontmatter (opus for planning `wp-normalize`/`wp-context`, sonnet for code authoring
  and judgment audits, haiku for mechanical `wp-acf`/`wp-cf7`/AIOS/Rank Math), so
  `/wp-yolo` and every other dispatcher route subagents to the cheapest capable model
  automatically. `/wp-yolo` documents the contract in its "Model routing" section;
  `tests/checks/model-routing.sh` enforces it.

## [1.8.0] - 2026-08-27

### Added
- **`/wp-robin-image-optimizer`** — installs Robin Image Optimizer, converts the whole Media Library to WebP and rewrites the database references to the converted images.
- **`/wp-aos-animation`** — wires the AOS library site-wide and animates existing sections.
- **WebP image delivery and right-sizing** in generated themes, plus an SEO link-text fix and a defined `.screen-reader-text`.
- **Polylang as a first-class translation model, selectable at scaffold time.** `/wp-init` now asks which i18n strategy a project uses and records the answer as `i18n strategy` in its `.claude/CLAUDE.md`; `_suffix` remains the Enter-key default so existing projects and non-interactive callers are unaffected. Choosing Polylang installs and activates the plugin, creates the languages through the same `pll-setup.php` the retrofit command uses, assigns the primary language to existing content, and swaps in a per-template Polylang variant of `inc/i18n.php`. Every downstream step branches on the recorded strategy: `/wp-seed` builds a counterpart page per language from the demo's own secondary-language copy and hands the remainder to `/wp-polylang`, `/wp-header` registers one menu location per name and renders `pll_the_languages()`, the `wp-acf` agent stops emitting `_<lang>` duplicate fields outside the settings group, and `/wp-yolo` passes the strategy through and gates on the verifier.
- **`/wp-polylang`**: retrofit an existing site into a second language through the `pll_*` API — export to a manifest, translate, import, verify. Handles posts, terms, menus, attachments, ACF/SCF fields including repeaters, groups and flexible content, and re-points internal links and reference fields at their translated targets.
- **`wp-tailwind-system` skill** — the utility-first decision ladder, `@theme` tokens, and file layout for `template=tailwind`. Tailwind projects finally have a skill of their own instead of borrowing `wp-css-system`.
- **`wp-tailwind` agent gains Section Authoring Mode**, replacing `wp-css` on the Tailwind path so sections are written as utilities in the markup rather than as a stylesheet.
- **`/wp-tailwind-migrate`** — convert an already-built plain-CSS theme to Tailwind-native in place, with a before/after responsive screenshot comparison.
- **`/wp-yolo` Step 2.6 converts the demo via `/wp-tailwindify`** before the section walk, so the section builders see Tailwind-native markup.
- **`bin/tailwind-native-check.sh`** — validates any Tailwind theme against the convention; run by `/wp-finalize` before delivery.
- **An explicit `Mode: **author**` dispatch line.** `/wp-section`, `/wp-page`, `/wp-cpt`, `/wp-header`, `/wp-footer` and `/wp-tailwind-migrate` now open every author-mode prompt with it, and `wp-tailwind` selects Section Authoring Mode on that line and nothing else.

### Fixed
- **Generated SCF/ACF field groups are now editable in the dashboard.** PHP-local `acf_add_local_field_group()` groups have no DB post, so they never appeared under Custom Fields → Field Groups and clients could not edit or extend them. Each starter theme's `acf/init` loader now treats `fields/*.php` as a one-time bootstrap per group: it registers the group only until `acf-json/<key>.json` exists, then persists it there. ACF/SCF auto-loads the local JSON and syncs dashboard edits back to the file, so groups stay both client-editable and versioned in code. Editing a group's PHP definition after the JSON exists requires the documented invalidation step.
- **`/wp-polylang` import no longer corrupts real content.** Payloads handed to WordPress are slashed, so backslashes survive a round trip instead of being stripped once per cycle; a manifest naming the wrong `target_id`, another site's `site_url`, or one menu as both source and target is refused instead of overwriting live content; a child whose parent has no counterpart stays dirty for the next run instead of being permanently stranded at the site root; term hierarchies survive re-import; a trashed counterpart is detected instead of reading as fully translated; an editor's own reference-field values are no longer re-derived away on every import; a reference the importer finds already correct is recorded as its own, so a later source change still reaches it instead of being refused forever; and a rewritten link keeps the `&amp;` separators its surrounding markup was written with.
- **`wp-bilingual` skill no longer claims the plugin does not support Polylang**, and now routes to the right skill based on the project's recorded strategy.
- **`/wp-init` no longer offers a starter template that does not exist.** "Basic Starter" was option 1 *and* the Enter-key default while `starter-theme/__starter__/` had been removed as superseded by Tailwind, so the most likely path through the command copied a missing directory. Tailwind is now the default, `basic` is accepted as an alias, and `tests/checks/wp-init-templates.sh` compares the command against the filesystem so it cannot rot again.
- **The Tailwind template was cosmetic.** `/wp-init` scaffolded a working Tailwind build, then every downstream command ignored `Template: tailwind` and dispatched `wp-css`, producing BEM CSS written to `assets/css/styles.css` — a file the Tailwind starter never enqueues. Themes shipped with no utility classes in their markup.
- **Comment-only starter stubs.** Five CSS files (`components/navigation.css`, `components/forms.css`, `layouts/{header,footer,sidebar}.css`) shipped containing only a comment, imported by `main.css` and never filled. Removed; a CSS file now exists only once it holds a rule.
- **`/wp-polish` wrote its backup where `/wp-seed` would find it.** The pre-polish copy went to `demo/original.html` / `demo/original-<filename>`, siblings of the demo pages, so the next `/wp-seed` turned each one into a phantom WordPress Page seeded from pre-polish markup. It now goes to `demo/.prepolish/<filename>`, and is written only if no copy is already there — the documented "overwrites if exists" meant a second polish destroyed the only unpolished version.
- **`wp-css-system` forbade Tailwind unconditionally**, so even Tailwind projects were told not to use it. Now scoped to `template=basic`, with `wp-tailwind-system` owning the other path.
- **The `wp-tailwind` agent had every tool, including `Bash`, while its own text said it had none.** Its frontmatter used `allowed-tools:` where all fourteen other agents use `name:` + `tools:`, so the key was ignored and the agent registered unrestricted — and `tests/checks/wp-tailwind-agent.sh` hard-required the wrong key, cementing it.
- **The agent picked its mode from a bare `author` token anywhere in the prompt.** The demo-conversion dispatch hands over an input file path, so an ordinary `demo/author.html` flipped the agent into Section Authoring Mode and that page was silently never converted. The gate now keys on the quoted `Mode: **author**` line, which a path cannot supply.
- **`/wp-init` re-introduced the demo-detection heuristic this branch exists to remove**, and all seven repo fixtures satisfied its skip condition — so it converted nothing, ever. Replaced with Step 2.6's evidence rule.
- **The delivery gate was invoked by a bare relative path.** Commands and agents run with the working directory set to the user's WordPress project, where `bin/tailwind-native-check.sh` resolves to nothing and exits 127 — the gate silently never ran. Every documented invocation is now rooted at `${CLAUDE_PLUGIN_ROOT}`.
- **`/wp-finalize`'s report never named the Tailwind convention check**, so a Tailwind theme could be reported "ready to deliver" without a word about the one gate that decides whether its markup carries any utility classes at all.
- **`/wp-header` and `/wp-footer` gained routing blocks but kept unrouted dispatch sites** whose bodies still told `wp-css` to write BEM rules into `assets/css/styles.css`, contradicting the block directly above them.
- **`bin/tailwind-native-check.sh` had four defects of its own.** The no-new-directory rule inspected only depth 1, so `components/parts/` passed; a commented-out `@import` satisfied the import rule and shipped the file unbuilt; a theme with all its CSS in `main.css` was rejected for an "unexpected directory `*`" that was just an unexpanded glob; and the three-template floor permanently failed a correct two-template theme while reporting a reason that was not true. The floor now scales to the templates present, and a compiled theme with no class-carrying template is its own explicit failure.
- **The delivery gate could die silently.** `hits=$(grep … | wc -l)` under `set -o pipefail` fails the assignment when `grep` matches nothing, and `set -e` then killed the script with exit 1 and no output — precisely on a compiled theme with zero utilities, the case that most needed a message.
- **`/wp-polish` and `/wp-yolo` attributed a literal `demo/*.html` glob to `/wp-seed`**, which states none; and each named only its own backup directory in the `find` caveat, so a folder both had touched left one of the two exposed.
- **`/wp-tailwind-migrate` restated the promotion ladder without its threshold**, telling an agent to promote a group it saw twice inside one section — which `wp-tailwind-system` keeps inline.
- **The upstream merge left two decision trees side by side in four commands**, and a `tailwind` + `polylang` project got contradictory instructions from each pair. `/wp-init` Step D4 carried two bullets with the same condition and two `@theme` targets, one of them a file the starter does not ship; `/wp-header`'s `wp-template` and `wp-acf` prompts ordered per-language menu locations and `_es` duplicates no matter the strategy; `/wp-finalize` Check 2, Check 4 item 5, Check 7 item 2 and Layer 2 item 3 demanded `_es` variants and suffix menu locations on every project, so a correct Polylang delivery failed all four; `/wp-yolo` Step 5 stated the suffix seed model unconditionally. All of them now branch on the recorded `i18n strategy`, with the polylang half of Check 2 running the same `pll-verify.php` the retrofit uses.
- **`/wp-finalize` Check 3 failed every correct Tailwind theme.** It read `assets/css/styles.css` and demanded `@media` at fixed pixel breakpoints — a file the convention check in the same command fails delivery for existing, and a mechanism the SKILL forbids — while promising "3 of 5" breakpoints it only listed 4 of. It now branches on `Template:`: `basic` keeps the media-query walk, `tailwind` verifies responsive prefixes in the markup.
- **`/wp-yolo` never named the cinematic template.** A reel project fell through Step 1, skipped conversion, ran the section walk, and got BEM CSS in a theme whose CSS is `cinematic.css`. Step 1 now refuses it and points at the `/wp-cinematic-*` flow; `/wp-header` and `/wp-finalize` state the same boundary instead of falling through.
- **The breakpoint table was inverted.** `agents/wp-tailwind.md` mapped `max-width: 640px` to a bare `sm:`, but bare Tailwind prefixes are min-width — every responsive rule fired on the wrong side of every breakpoint, and the markup still compiled so nothing downstream caught it.
- **The `@theme` lookup read a file with no values.** Colour mapping told the agent to read `.claude/CLAUDE.md`, which names `main.css` and holds zero hex literals, so the agent found nothing and shipped the default palette. It now reads the theme's `assets/css/src/tailwindcss/main.css`.
- **The delivery gate matched utilities as substrings**, so BEM names from this repo's own fixtures — `services__grid`, `team-archive__grid` — counted as Tailwind and a purely-BEM theme printed PASS. A utility is now a whole class token; the accepted ceiling (a hand-written `bg-image-holder` vs a token utility) is documented in the script.
- **The converted demo was an unstyled page the command told the user to review.** `/wp-tailwindify` now says plainly that the conversion is an intermediate artifact whose styling arrives with the theme build, instead of inviting a browser check of HTML with no CSS.
- **Preflight was never mentioned anywhere** and silently moved the baseline (`<button>` 13.33→16px, `<img>` inline→block, `<p>` margins zeroed, logo underline dropped). The SKILL now carries a Preflight section with the measured effects, and the conversion path names it.
- **Bare element selectors had no home.** `a {}`, `h1,h2,h3 {}`, `body {}` reached elements no class covers; the rehearsal reasoned one was dead and the computed diff proved it wrong. The SKILL now states where they land and how to check for the elements they reach.
- **Tailwind v4 specifics no document named**: the OKLCH palette (v4 `gray-300` is `#d1d5dc`, not a demo's `#d1d5db`), OKLab gradient interpolation, `bg-linear-to-r` vs v3's `bg-gradient-to-r`, and the pinned `^4.1.5` version. All named once, where utilities are chosen.
- **`mv` aliased to `mv -i` cost the rehearsal three pages silently**, with the loop reporting success. The conversion now specifies `\mv -f` and proves the move happened before reporting.
- **`wp-template` and `wp-tailwind` raced on one file with opposite class systems.** The ownership rule now stands in `/wp-section` and `/wp-header` (and its one-line summary matches it): `wp-template` writes the PHP on both paths, `wp-tailwind` runs after it and owns only class names — never beside it, never BEM in a Tailwind theme.
- **The delivery gate and its checks had a list of latent defects**, each closed with an executed proof: `/wp-tailwind-migrate` Step 6 resolved the theme path twice; `-mindepth 2` exempted every sibling of `main.css`; two checks exited 1 with no message on a zero-match grep; two gates were line-anchored and died on the next re-wrap; the directory-set gate misread brace notation; a region anchor with a trailing space disagreed with its sibling; a closure proof was file-wide instead of region-wide.

### Changed
- **The check suite grew from 19 to 33 checks.** Every contract this work added is gated by a grep-for-required-tokens script under `tests/checks/`, and each assertion carries three executed proofs: the inverted wording fails, the deleted wording fails, and a realistic correct edit — a re-wrap, a heading rename, a step renumbering, a synonym — stays green.

## [1.7.0] - 2026-07-15

### Changed
- **`/wp-yolo` now transcribes the demo instead of re-authoring it.** The `wp-css` agent gained a Transcription Mode (yolo path): it copies the demo's exact declared values (colors, heights, gaps, backgrounds), captures CSS `background:url()` + `@font-face` (not just `<img>`/`<link>`), and never adds "best-practice" edits that change measured geometry — fidelity over idiom. `wp-normalize` captures the full CSS surface, tags asset roles (logo / nav-graphic / hero / content), and assigns unique BEM blocks up front so parallel agents cannot collide on generic class names.
- **`wp-normalize` fast-path for already-delimited demos**: demos that already carry the canonical `<!-- SECTION: -->` delimiters skip re-segmentation instead of being re-authored.

### Added
- **Demo-parity verification gate in `/wp-finalize`, auto-run by `/wp-yolo`.** Three layers — static (undefined `var(--x)`, CSS class collisions, font parity, background-image presence, nav-contract match), WP-CLI (`site_logo` / `inner_hero_image` seeded, menus, pages), and measured visual parity via the claude-in-chrome extension (`getComputedStyle` deltas vs the demo; hard deltas block, sub-pixel/antialiasing warn; skipped gracefully when the extension/site is unavailable). Critical findings auto-fix mechanically then re-verify; anything ambiguous blocks — `/wp-yolo` (including `--yolo`) will not report success while a divergence remains.
- **Self-hosted font carry-over, role-based asset seeding, and a shared nav-class contract** (walker + header CSS agree, incl. dropdown-toggle baseline alignment).
- **`/wp-yolo` now requires a git repo before building** (initialized in `/wp-init`), and always builds styled `404`/`search` templates instead of leaving starter boilerplate.

### Fixed
- **Tailwind starter theme**: removed a duplicate `body_classes` definition that caused a fatal redeclare, fixed a nonexistent typography pin, and gated the Spanish Translations settings tab on the active language.

## [1.6.0] - 2026-07-10

### Added
- **`/wp-context` command + `wp-context` agent**: reads a project's `docs/` folder (scope spreadsheets, design PDFs, estimate/scope markdown) and extracts a `## Project Constraints` section into `.claude/CLAUDE.md` plus an actionable `docs/.scope-manifest.json`. Auto-runs from `/wp-init` when `docs/` exists.
- **`embed` page type for `/wp-page`**: styled shell with a marked insertion point for provider-delivered pages (IDX, booking). `/wp-yolo` builds these for `delivery: idx|plugin` scope pages instead of normal templates.
- **Scope-aware `/wp-yolo`**: reconciles the docs scope manifest with the demo — scope governs which pages to build and how (theme / idx-shell / skip), the demo fills content; out-of-scope and approved-but-missing pages are reported.
- **`/wp-yolo` command**: converts a complete multi-page HTML demo folder into a WordPress theme in one pass — normalizes the demo, infers pages/sections/fields/content-types, and drives the existing build pipeline. Flag-controlled autonomy (`--yolo`, `--careful`).
- **`/wp-cpt` command**: custom post type builder — registers a CPT and generates its fields, archive, single, optional teaser query-section, and seed helper.
- **`wp-normalize` agent**: analyzes an arbitrary demo folder into the plugin's canonical delimited format plus a build manifest, splitting sections and classifying static-repeater vs custom-post-type groups.
- **`search` page type for `/wp-page`**: generates a design-matched `search.php`. `/wp-yolo` always builds `404` and `search`.

## [1.5.0] - 2026-07-08

### Added
- **Cinematic starter theme** (`starter-theme/__cinematic__/`): scroll-driven WordPress theme scaffold with persistent video stage, N scene blocks, mobile autoplay-loop fork, `prefers-reduced-motion` guard, hamburger menu, and motion-toggle. Hand-author safe runtime layer (`cinematic-loader.php`, `scenes-renderer.php`, base CSS, engine JS vendored from cinematic-scroll-kit).
- **WebCodecs scroll-scrub in the cinematic starter**: the scrub now decodes frames with WebCodecs and paints them to a `<canvas>` (frame-perfect, smooth reverse), with an automatic `video.currentTime` fallback for browsers without WebCodecs (Safari < 16.4, Firefox < 132). `video.currentTime` is not frame-accurate and cannot decode backward — the cause of "stuck frames / jumps to end / reverse stutter". Adds vendored `assets/js/cinematic-scrubber.js` (`class CinematicScrubber`), a guarded dual-path `cinematic-engine.js` (WebCodecs canvas / `currentTime` / mobile IO / reduced-motion), `.stage__c` canvas siblings in `scenes-renderer.php`, `body.webcodecs-scrub` CSS swap, and GSAP/Lenis/scrubber enqueues in `cinematic-loader.php`. See cinematic-scroll-kit `skills/07-scroll-scrub-rendering.md`.
- **`/wp-cinematic-init` command**: scaffolds a cinematic theme end-to-end. Detects and installs [cinematic-scroll-kit](https://github.com/yojahny55/cinematic-scroll-kit) as a recommended skill (`npx skills add`), or falls back to vendored kit copy. Defers to `/wp-init` for project bootstrap, then dispatches the `wp-cinematic` agent for ACF + template generation.
- **`/wp-cinematic-demo` command**: generates the cinematic HTML demo at `<theme>/demo/` with the plugin's standard `<!-- SECTION: -->` delimiters, so the demo flows through `/wp-polish` and `/wp-responsive-check` like any other plugin demo.
- **`/wp-cinematic-encode` command**: wraps the kit's `encode-keyframe.sh` + `encode-mobile-portrait.sh` ffmpeg scripts. Produces all-keyframe MP4 (desktop scroll-scrub) + 9:16 portrait MP4 (mobile autoplay) + poster JPG. Optional `--scene=N` binds outputs to an ACF row.
- **`/wp-cinematic-scene` command**: author/replace/regenerate a single cinematic scene. Mirrors `/wp-section` ergonomics. `--regenerate-schema` re-reads `scene.json` and rewrites `fields/scenes.php` while preserving `@user-block` ranges.
- **`/wp-cinematic-seed` command**: idempotent scene seeder driven by a JSON manifest validated against `scene.json`. Sideloads sample videos from the kit.
- **`wp-cinematic` agent** (`agents/wp-cinematic.md`): the bridge between the kit (runtime + ffmpeg) and the plugin (ACF + templates + i18n). Reads `schemas/scene.json` and emits all WP-side files.
- **`--hybrid` flag for `/wp-section`**: appends to the `trailing_sections` flex content field instead of creating a standalone field group. Lets cinematic pages mix the reel with conventional trailing sections (pricing, contact, etc.).
- **Step 0.5 cinematic option in `/wp-init`**: third starter choice ("Cinematic Starter") routes to the `/wp-cinematic-init` flow.
- **`bin/wp-cinematic-encode.sh`**: shell runner that drives the kit's ffmpeg scripts in parallel, verifies all-keyframe encoding via `ffprobe`, validates 9:16 mobile dimensions, and (if `--scene=N`) imports outputs into the Media Library and updates the matching `cinematic_scenes` ACF row via `wp eval`.
- **`docs/cinematic-mode.md`**: full end-to-end walkthrough — when to use cinematic mode, dependency on cinematic-scroll-kit, pipeline diagram, engine architecture, schema-driven generation, and a failure-mode reference table.

### Schema Contract
- The kit's `schemas/scene.json` is the single source of truth for scene field shape. The plugin reads, never extends locally — new fields go upstream as a kit PR.

---

## [1.4.0] - 2026-06-04

### Added
- **Tailwind CSS starter theme** (`starter-theme/__tailwind__/`): full theme scaffold with Tailwind CSS v4, WordPress Scripts build pipeline, BrowserSync, `package.json`, and all standard template parts.
- **`/wp-tailwindify` command**: converts an existing HTML/CSS demo into Tailwind-native HTML using utility classes, mapping colors to the project's `@theme` variables.
- **`wp-tailwind` agent**: handles CSS-to-Tailwind demo conversion with `@theme` variable mapping and responsive breakpoint prefix translation.
- **Template selection in `/wp-init`**: step 0.5 now asks whether to scaffold a Basic (CSS variables + BEM) or Tailwind starter theme; step 0.6 asks for SCF vs ACF Pro.
- **`vhost-install` command** in `bin/wp-env-setup.sh`: atomically installs a generated vhost config with correct mode (644), owner (root:root), and SELinux context (`restorecon -F`). Safe no-op on systems without SELinux.
- **`--vhost-src` flag for `native-setup`**: pass a staged config path and `vhost-install` runs automatically as part of the setup flow.
- Failure Handling entry in `commands/wp-create.md` for the SELinux `(13: Permission denied)` error on Fedora/RHEL/CentOS.

### Fixed
- **SELinux trap on Fedora/RHEL/CentOS**: vhost configs staged in `/tmp` and moved with `sudo mv` inherited the `user_tmp_t` label, causing nginx/apache reload to fail with `(13: Permission denied)` despite correct `ls -la` ownership. `vhost-install` and `--vhost-src` prevent this entirely.
- **Caddy + `--vhost-src`**: passing `--vhost-src` to `native-setup` for a caddy server no longer silently skips install and reloads an unconfigured server — it now aborts with a clear error.
- **ABSPATH guards**: added `defined('ABSPATH') || exit` to all PHP template files in `starter-theme/__starter__` for direct-file-access protection.

### Security
- All starter theme PHP template files now guard against direct file access.

### Migration
- No breaking changes. Existing `native-setup` calls without `--vhost-src` continue to work with updated guidance printed to the terminal.

---

## [1.3.0] - 2026-03-20

### Added
- `/wp-audit` command with 5 audit categories: security, SEO, accessibility, performance, best practices
- Security agent with AIOS plugin auto-configuration (3 security levels: basic, recommended, maximum)
- SEO agent with Rank Math auto-configuration, schema markup, breadcrumbs, llms.txt, robots.txt
- Accessibility agent with WCAG 2.1 AA + WordPress-specific checks and auto-fixes
- Performance agent with Core Web Vitals optimization, caching, compression
- Best practices agent with WordPress coding standards validation
- Two configuration agents: wp-audit-rankmath and wp-audit-aios for plugin setup
- Two knowledge skills: wp-audit-standards and wp-audit-seo-standards
- Three-tier audit system: code-only, WP-CLI runtime, and external skills (web-quality-skills)
- Dependency management: auto-detect and offer to install required plugins
- Optional integration with web-quality-skills (Addy Osmani) for Lighthouse-style audits

### Changed
- Plugin profiles: replaced Yoast SEO with Rank Math SEO, Wordfence with All-in-One WP Security

## [1.2.0] - 2026-03-18

### Added
- CF7 (Contact Form 7) integration in `/wp-section contact` — auto-generates CF7 forms, branded HTML email templates, and creates forms via WP-CLI
- New `wp-cf7` agent for CF7 form generation with bilingual support
- `inc/cf7-helpers.php` in starter theme — runtime `%%placeholder%%` resolution for CF7 email templates
- Contact section auto-detection for `contact`, `contact-us`, `contacto`, `get-in-touch` section names
- `--cf7` flag for explicit CF7 integration on any section
- Two-phase dispatch in `/wp-section` for contact sections (CF7 agent runs in parallel, template waits for form IDs)
- Branded HTML email templates (admin notification + user confirmation) with table-based layout for email client compatibility

### Changed
- Plugin metadata: added `homepage`, `repository`, `category`, `tags` fields for better marketplace discoverability

## [1.1.0] - 2026-03-15

### Added
- `/wp-polish` command — normalizes any HTML file into a plugin-compatible demo with section delimiters, semantic HTML5, and BEM class naming
- Demo-first path in `/wp-init` — detects existing demos, extracts project info (name, slug, industry, languages, sections, colors, fonts), and presents pre-filled defaults

### Fixed
- Added `END SECTION` closing delimiters to demo template skeleton in `wp-demo` skill for consistency with `/wp-section` extraction

## [1.0.0] - 2026-03-14

### Added
- Initial release
- `/wp-init` — scaffold new WordPress projects from starter theme
- `/wp-demo` — create responsive HTML demos for client approval
- `/wp-header` — build WordPress header from demo
- `/wp-footer` — build WordPress footer from demo
- `/wp-section` — one-shot section builder (ACF fields + template + CSS)
- `/wp-page` — page template generator (blog, legal, 404, generic, custom)
- `/wp-settings` — extend settings page with new fields
- `/wp-responsive-check` — responsive validation at 5 viewports
- `/wp-finalize` — pre-delivery validation checklist
- Starter theme with bilingual i18n layer, ACF auto-loader, CSS design system
- Three specialized agents: `wp-template`, `wp-css`, `wp-acf`
