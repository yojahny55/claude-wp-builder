# Known ceilings

Deliberate, documented limits of this plugin and its checks: each one is a decision with a cost that is written down, not a bug to fix on sight. Read the relevant entry before changing behaviour in its area. Moved out of `CLAUDE.md` so that file stays small enough to load on every session.

These are deliberate, documented limits — not bugs to "fix" on sight:

- **A clone carries data, never code.** `/wp-clone` transfers the database and
  `wp-content/uploads/`; plugin and theme **files** are never transferred. That is
  deliberate — a dev clone should get its code from the same place the project does, not
  from a production server's disk — but it means the imported database activates plugins
  that are not present, so `/wp-clone` inventories them from the source while the SSH
  session is open and splits them into recoverable (on WordPress.org, with a version-pinned
  install command), unobtainable (custom, licensed or premium — the clone stays incomplete),
  and unclassified. The third group exists because the WordPress.org lookup is a network
  call: guessing it into either of the others sends the operator to install a different
  plugin that shares a slug, or to ask a client for a file they could have downloaded.
  Path B has no source to ask and derives a weaker list from the database alone, which it
  says.
- **The clone's destination backup is a database export, and nothing else.** `/wp-clone`
  Step 1.5 refuses an occupied destination without `--force` and exports its database to
  `~/.wp-clone-backups/` first — outside the project, because a backup under `wp-content/`
  is reached by the next clone's `rsync` and by an `rm -rf` of the project. What it does not
  copy is the destination's **uploads**: `rsync` overwrites matching paths, and files it
  overwrote are not in the `.sql`. Restoring from one of these backups restores the content
  and the field values, not the media. Deliberate — duplicating an uploads tree on every
  clone costs more than the case is worth — but it means "a backup was taken" is a narrower
  promise than it sounds, which is why it is written down here.
- **A clone is isolated at the seams a copy shares with its original, not at every one.**
  `/wp-clone` Step 5.4 captures mail at `pre_wp_mail` (a must-use plugin, so it survives a
  plugin being reactivated and cannot be undone by an option write) and disables `WP_CRON`
  — **before `wp db import`**, because both are files and neither needs the database. That
  ordering is the fix for a real gap: they used to run in Step 5.5, after the import, and
  between the two both paths ran `wp search-replace` and `wp rewrite flush` while Path B
  also ran `wp plugin list` and `wp option list`. `rewrite flush` fires `init` with the
  source site's plugins active, so production code had already executed against a
  production database before the mail guard existed. The old isolation check could not see
  it: it asserted only that isolation preceded Step 6. Step 5.5 keeps `blog_public`, which
  genuinely has to wait — it is a `wp_options` row the import would overwrite.
  What it does **not** do is change live payment credentials, webhook URLs or API keys: it
  reports them. It does switch payment gateways off (every enabled one outside `bacs`, `cheque`
  and `cod`, with the keys left stored), because a clone that can charge or refund a real
  customer is worse than one that needs a gateway re-enabled on purpose with test credentials
  when a payment bug has to be reproduced. Webhooks and the keys of integrations that are not
  gateways stay report-only. The cost of that choice is
  real and is the operator's to carry — a clone can still reach a production endpoint through
  any integration that does not use `wp_mail()` or cron, and the database holds live customer
  records from the moment the import finishes. `/wp-anonymize` is the opt-in remedy, and
  the report names it at the moment the operator is told the records are there.
- **`/wp-anonymize` replaces a catalog, not a database, and says so in every report.** It
  rewrites `wp_users`, `wp_usermeta` billing and shipping keys, comment author rows
  (including the IP, which is personal data on its own) and WooCommerce order addresses on
  both the postmeta and HPOS layouts. Everything else is listed by name and row count under
  *Not examined*, because an explicit catalog is only honest if what it excludes is printed:
  a plugin holding customers in its own table is invisible to the catalog and appears in
  that list. Three narrower limits follow from the same shape — serialized blobs in
  `wp_options` and `wp_postmeta` outside the WooCommerce keys are not rewritten;
  `user_login` is deliberately kept, because it is the join key half the ecosystem
  recognises an account by and it is far less identifying than an address; and the run
  cannot undo itself, which is why the backup to `~/.wp-clone-backups/` is unconditional and
  a failed export stops the command. The gate — the isolation mu-plugin must be present —
  takes no `--force`, the only refusal in this plugin that does not, because the cost of the
  check being wrong is an annoyance and the cost of the operator being wrong is a production
  site with its customers overwritten.
- **`/wp-seed` owns records and values separately, and the second is the weaker claim.**
  Phase 1.5's marker says who created a *record*; `_<prefix>_seeded_digest` says what this
  command last wrote into each *field* of it, so an editor's edit is distinguishable from a
  source change. A field whose current value no longer matches that digest is the client's,
  and is left alone and reported; `--force-fields` is the only way past it, and is not
  implied by `--force` anywhere else. A field with **no** recorded digest is treated as a
  conflict rather than as ours, which makes the first re-seed of a project created before
  this existed noisy — correctly, since nothing on disk can say whose value it holds.
  Two things it cannot do: a client edit that happens to reproduce the demo's value reads as
  no edit, and the digest records a value, not a history, so it cannot say *when* the edit
  happened or how many times.
- **Seed media deduplicates by source, not by content.** `/wp-seed` records
  `_<prefix>_seeded_source` — the URL a remote image came from, or the repository-relative
  path of a local one — and skips an import whose source it has already seen. The same
  image served from two different URLs therefore imports twice. Hashing every import on
  every run costs more than that case is worth, and a duplicate attachment is a tidiness
  problem where a duplicate *page* splits a site's navigation. Generated plates are
  unaffected: `assets/img/gen-<hash>.jpg` already carries a content hash in its path, so a
  regenerated plate is a different source and correctly imports again.
- **The three WordPress default records are deleted only while they are still defaults.**
  `/wp-seed` Phase 7 removes the "Hello world!" post, the sample page and the sample
  comment — the one place the command deletes a record it does not own, since WordPress
  ships these and they never carry the `_<prefix>_seeded_content` marker the Phase 1.5
  rule keys off. It used to do it unconditionally with `--force` and `|| true`, which
  permanently destroyed a sample page an editor had repurposed into About, on that site's
  second seed run, and hid that it had. Each delete is now gated on the original slug and
  on `post_modified` still equalling `post_date`, and a record that fails either test is
  reported as kept. The ceiling that remains is narrow: an editor who changes a default
  and changes it back reads as untouched.
- **Seeded menu items are rebuilt, not reconciled.** Every other record `/wp-seed` owns is
  updated in place; menu items are deleted and re-added, because a demo whose navigation
  dropped a page would otherwise leave that item behind forever, and matching an existing
  item to a demo link is guesswork the moment a title is edited. Items the client added are
  kept. The cost is that a seeded item's own ID changes on every run, so nothing may hold a
  reference to one.
- **A resumed `/wp-yolo` trusts that its own output was correct output.** The ledger
  records a `sha256` of each artifact as it was written, so `--resume` now distinguishes
  three states where it used to see two: the file matches what this command wrote (skip
  it), the file differs (someone edited it afterwards — reported as a list, with
  `--skip`/`--rebuild` per unit, never silently replaced or silently kept), or it is
  absent (build it). What the digest cannot see is a template part that a failed agent
  wrote *wrongly but completely*: the ledger digested exactly that file, so it matches
  itself and is skipped. The Step 5.5 parity gate is the net under that one, and it
  measures geometry at rest — not behaviour, and not whether a section says what the demo
  said. Deliberate: the alternative is re-verifying every completed unit on every resume,
  which costs what the resume was meant to save.
  Two things the ledger still does not do, both larger than a field: it does not model
  which manifest key feeds which unit, so there is no dependency-aware selective rebuild
  (`--accept-drift` permits continuation; it does not scope one), and it records no
  database mutations, so recovery covers files only.
- **`settings` is recorded, not verified.** `/wp-settings` writes nine or so WordPress
  options and produces no single file, so its ledger entry carries `artifact: null` and
  is trusted on the ledger alone. A probe asserting one option out of nine would read
  as verification while proving almost nothing, which is worse than the stated gap.
- **Drift is detected per file, not per section.** The ledger digests the whole
  manifest, so any edit to it invalidates every section and `--resume` refuses until
  `--accept-drift` is passed. Sub-document digests would let a resume continue across an
  unrelated edit, but they would have to model which manifest key feeds which unit, and
  a wrong model there silently reuses stale input — the exact failure the ledger exists
  to prevent. Refusing too often is the cheaper error.
- **Media is not translated.** The Polylang importer copies an image or file id to the counterpart
  as-is rather than swapping it for that attachment's own translation. Mapping media is a separate
  decision; `pll-import.php` and the live suite both state the ceiling.
- **ACF reference re-pointing recurses, and records ownership per path.** `link`,
  `page_link`, `post_object` and `relationship` are re-pointed wherever they sit, including
  inside groups, repeater rows and flexible-content layouts, through the same
  `pllx_acf_zip()` traversal and the same layout-by-name rule the text walk uses — so a
  structure one can see is a structure the other can see. `_pll_ref_` ownership meta is
  keyed by the dotted path, so two references differing only by row keep separate records
  of what the importer last wrote and an editor's change to one is not read as a change to
  the other. What is **not** carried is the ceiling that used to sit here: for one release
  the text walk recursed while this did not, which gave a nested link a translated title on
  a source-language URL — translated-looking and wrong, worse than the untranslated link it
  replaced. `tests/fixtures/wp/acf-refs.php` exists to keep that from coming back, and
  fails if the collector stops recursing or if ownership is keyed by field name again.
- **Parent structure mirrors the source.** Both parent fixup passes rewrite the counterpart's parent
  on every run, so a post or term an editor deliberately re-parented in the target language is put
  back. Only the ACF reference pass records ownership; parents do not.
- **The site tagline is written in the primary language only.** `/wp-init` Step 9 sets
  `blogname` and `blogdescription` from the confirmed tagline; under `i18n strategy: polylang`
  the secondary language is left to `/wp-polylang`, which exports both as registered strings.
  Writing them is still the prerequisite — Polylang omits an empty option from its string table.
- **Fonts are carried once, at scaffold time.** `/wp-init` Step 4.5 self-hosts the demo's
  families; `/wp-section`, `/wp-header` and `wp-css` do not detect fonts, on purpose — fonts
  are a site-wide asset and per-section detection would repeat the download N times and race
  under `/wp-yolo`'s concurrent section builds. The cost is that a demo swapped in *after*
  `/wp-init` has run brings no new fonts with it: re-run the step, or carry the woff2 by hand.
- **`/wp-init`'s Polylang branching is verified by grep, not by an automated end-to-end run.**
  The path has been run against a real project and works — that is why it is now the default —
  but its scripts are covered automatically only by `tests/checks/wp-polylang-live.sh` (which
  needs `PLL_TEST_SITE`), and the command's own prose branching only by the grep checks in
  `tests/checks/wp-polylang.sh` and `wp-init-templates.sh`.
- **Compositions are ports, not copies: the role table in `skills/wp-demo-craft/compositions/README.md` lists them.** Effects
  from Magic UI and Aceternity are rewritten in CSS and GSAP inside the `data-motion`
  contract; the React libraries are never dependencies. A feeling curve that needs an
  eleventh role builds it by hand under the same contract with a reason in
  `demo/BRIEF.md`.
- **The evaluator reads headless sheets.** Real-device feel is still unproven, and
  Landing Gallery screenshots are inspiration only.
- **`designlang` extracts what a site declares.** A site built on inline styles or
  canvas yields thin tokens; the catalogue fallback fills the gap and is cited.
- **A craft demo emits no bilingual `<!-- i18n: … -->` hint comments.** The craft build
  path takes only the header, footer and responsive requirements from the plain path,
  so nothing in the markup marks a translatable string. The bilingual pipeline reads
  the recorded `i18n strategy` instead — which it should anyway; markers in a demo were
  never the source of truth.
- **A composition's breakpoints and its fluid ramps both size to its own container now,
  except where the screen is the point.** Every composition's size-based breakpoints are
  `@container` queries against the block's own `container-type: inline-size`, so a section
  dropped into a narrow column lays out for the column. The `vw` in `clamp()` gaps and type
  scales was the one exception — 40 occurrences across 12 of the 13 compositions still keyed
  off the viewport — and is converted: 37 now read `cqi` and track the container. Three
  stay `vw`, each with a comment. Two are the display headline of a full-bleed hero
  (`hero-bleed`, `hero-type`), sized against the viewport on purpose because
  a hero in a narrow column is not a scenario those compositions serve. `hero-split`
  used to be counted a third: its title sits in a `1.1fr 0.9fr` split column, so the
  borrowed "full-bleed" justification was false for it, and since its nearest container
  is the section root the conversion is identical at full bleed (86.4px at 1440,
  measured) and correct in a narrow column (38.4px at 420px) — so it converted. The third is
  `feature-zigzag`'s root `gap`, which *cannot* be `cqi`: that rule is the element
  declaring `container-type`, and an element never matches a container query against the
  container it establishes itself, so `cqi` there would resolve against the viewport while
  reading as if it tracked the block. `compositions/README.md` states the rule; `tests/checks/wp-craft-compositions.sh`
  asserts every remaining `vw` carries its justification on that line or the line above it.
- **The two `reveal` paths differ above the fold.** The CSS path's range is
  `entry 0% entry 40%`, so an element already fully in the viewport at load is past
  its entry range and `animation-fill-mode: both` lands it on the end state with no
  animation; the JS path animates it in. A hero fades in on a browser without
  scroll-driven animation and is already there on one that has it. Deliberate — the
  CSS behaviour is the better one for the "First paint complete" rubric line — and
  recorded in `references/devices.md` rather than reconciled.
- **Composition previews need the network to regenerate.** They render against the
  neutral `references/design-md/_preview.md` and their fill copy lives in
  `compositions/fills.json`, which points at remote placeholder images. The committed
  `preview-1440.png` / `preview-390.png` are the artifact; treat them as such rather
  than assuming a rebuild is always available.
- **`@property --container-max` needs Chrome/Edge 85+, Safari 16.4+, Firefox 128+.**
  A malformed value (`wide`, an empty string) used to make `calc()` invalid at
  computed-value time and unset `padding-inline` to `0` at every viewport, the same
  failure the `var(--container-max, 1280px)` fallback only ever guarded against for
  an *absent* token. `commands/wp-demo.md` and `bin/composition-preview.mjs` now emit
  `@property --container-max { syntax: "<length>"; inherits: true; initial-value:
  1280px; }` alongside `:root`, so an invalid value falls back to `initial-value`
  instead. Where `@property` is unsupported, the `1280px` `var()` fallback remains
  the only guard, and it still covers only the absent case.
- **`unobserved` is a confession, not a measurement.** It is now a per-section
  judgment — `probe()` counts devices inside the section's own subtree, so a section
  carrying only pointer devices (`tilt`, `magnet`, `spotlight`) reports it instead of
  falling to a blocking `dead-scroll` — but a section that genuinely does not move and
  a section the harness cannot read are still not distinguished by the harness, only
  by which finding it emits and what the operator does next. `no-engine` stays
  document-wide on purpose: scoping it too would fire on every ordinary static section.
- **The harness changes were measured on a composition corpus, not on a client
  build.** The v1.15.0 baseline demo named in the plan no longer exists on disk — that
  project is now a WordPress install and its demo was consumed into the theme — so the
  before/after walk was run on a five-page corpus assembled from the in-repo
  compositions instead, with the release commit's `demo-verify.mjs` and with HEAD's.
  That proves the harness changed behaviour as intended; it does not prove what a
  messy real build now scores, and a composition corpus is cleaner than one.
- **One verification path is still not covered.** Item F's last preview-token bypass — a
  reassignment at `composition-preview.mjs`'s render call site, which happens after
  `--tokens` has exited and which no assertion on that output can see — still needs the
  render itself to close.

  `motion.js` is no longer among them. `tests/checks/motion-devices.sh` runs it in a real
  Chrome on both paths. Under `prefers-reduced-motion: reduce` it asserts what the `pan`
  device does to the DOM, including the behaviour with no visible output at all — that when
  neither box overflows it attaches *nothing*, because a focusable named region that
  scrolls nothing is a dead tab stop. Under default motion it loads the **real pinned
  GSAP** and asserts the engine works rather than merely being wired: the rail's transform
  moves leftwards as the page scrolls, and the JS `reveal` branch hides its children and
  then shows them.

  That reveal branch was unreachable on any browser this suite can run, because every one
  of them supports `animation-timeline` and the CSS engine takes over. The fixture forces
  `CSS.supports('animation-timeline', …)` to report false before `motion.js` reads it —
  which is what an older browser reports, and the only way in. Nothing else is faked: gsap
  and ScrollTrigger are the pinned builds, served from `node_modules` rather than a CDN,
  because a check that fetches its own engine over the network fails for reasons that have
  nothing to do with the code under test.
- **`motion.js` sets `overflowX` on the rail, not on the frame — and it is not inert.**
  Under reduced motion the stylesheet resets the rail to `width: auto`, and a scroll
  container is sized by its box rather than by its content, so the assignment makes the
  *rail* the scroller and the frame stops overflowing: measured at 1280, rail 2042/1280,
  frame 1280/1280. The frame's own `overflow-x: auto` is then only the no-JS fallback.
  Which box scrolls therefore depends on whether the engine ran, which is why the
  keyboard affordance in the pan device picks the scroller by measurement, not by name.
- **Verification serves over HTTP; the delivered demo is a `file://` artifact.**
  A defect that only appears when the file is double-clicked can pass a green walk.
  `external-module` findings name the one case known to matter.
- **The same-client rule reads the plan, which is prose.** It constrains a build
  that argues honestly and does not stop one that does not.
- **The image generator's HTTP call and response parsing are not covered.** No
  check can drive a real adapter request without a live key and a real bill,
  and a mock would only ever assert the mock. What the suite does cover is
  everything around the call — slot discovery, crop and size resolution, the
  cache, the ambiguity refusal, and the missing-key stop.
- **The key-leak guard catches the leaks a careless author writes, not every
  leak possible.** `say()`/`warn()` route every write through `scrub()`, and
  the pin greps for `console.log`, `.error`, `.warn`, `.info`, `.debug`,
  `.trace`, `process.stdout.write` and `process.stderr.write` appearing
  outside those two functions. An aliased stream (`const w = process.stderr; w.write(...)`),
  computed member access (`process['stderr'].write(...)`), `fs.writeSync(2,
  ...)` and `process._rawDebug` all pass that grep untouched — a grep cannot
  follow aliasing, and pinning a seventh spelling would mostly teach the next
  reader that the sixth one was the ceiling. The threat model is an honest
  mistake by a future author, not an attacker with commit access, who could
  delete the pin anyway.
- **A thrown error that embeds the key is not a leak, and that is by design.**
  `scrub()` runs on every value `say()`/`warn()` print, and again on the
  caught error in `cmdRun`'s own catch block, so `throw new Error('... ' +
  key)` is redacted before it reaches a stream. Worth stating because it
  reads like a gap next to the entry above and is not one — the grep pins
  correctly leave it unflagged.
- **Image cost figures are estimates and will drift.** Google publishes no
  per-image price in its own documentation — the figures in `bin/image-gen.mjs`
  come from third-party trackers — and OpenAI bills tokens rather than images,
  so its per-image number is an approximation by construction. The plan
  output prints the total as `~$0.10`, followed by its own line, "Costs are
  estimates, not a bill." — never a number presented as a bill.
- **Aspect fidelity is provider-dependent.** Google fills all three of the
  library's crops — 4:5, 3:2, 4:3 — exactly. OpenAI offers only three fixed
  sizes, so every one of those crops lands inexact and is cropped by
  `object-fit: cover` after the pixels have already been paid for. This is
  why `google/...` is the recommended default, ahead of price.
- **A generated plate is detectably AI-generated.** Every Google plate
  carries an invisible SynthID watermark. `demo/BRIEF.md` records this for
  the client, not only the build log, because whoever ships these to
  production is entitled to know.
- **The audit's checks are contract greps, so no test can fail because an audit
  *missed a defect*.** `tests/checks/*.sh` assert that the wording defining a check is
  present in the command, agent or skill that owns it — the house style, and the reason
  documentation and behaviour stay in step. What it cannot do is run an audit against a
  WordPress site and notice that a real defect went unreported: that would need a fixture
  site with seeded defects and an expected-findings file, which is a test harness rather
  than a check. So a coverage gap — a defect class nothing looks for — is invisible to the
  suite by construction, and is found the way the site-name and schema `@id` gaps were
  found: by auditing a real site by hand and asking which contract should have caught it.
  Deliberate; recorded here rather than papered over with a check that would only assert
  its own mock.
- **The manifest reconciliation measures, but only what WP-CLI can reach.** `/wp-audit`
  Step 2.5 re-measures plugins, PHP version, web server and Tier 3 availability on every
  run instead of trusting the manifest. Without Tier 2 it can measure none of them, and
  reports the whole block `UNMEASURED` — which is honest, and still means a Tier 1 run on
  a stale project cannot tell you the manifest is wrong.
- **Coverage is tracked per check, but findings are still counted, not tracked.** Step 2.5d
  diffs `categories_run` against the categories this version offers *and* diffs each run
  category's `audit.checks_run` ids against that category's own agent catalog, so a check
  added to a category a project already ran is reported by name as never measured there.
  Catalogs are read from the catalogs listed in `bin/lib/audit-schema.mjs` (`CATALOGS`) rather than from a stored list, because a
  stored list is a second copy and a stale one would report green coverage for checks
  nobody ran — the defect the diff exists to prevent. A project with no `checks_run` yet
  reports its per-check history as unknown rather than reporting every check in those catalogs as
  never-measured.
  **A check id now carries an optional revision** (`SEC-036@2`), because an id is an
  address and not a version: a project holding `SEC-036` stayed "covered" after SEC-036 was
  rewritten to look for something else, which is this same diff's failure mode one level
  down. A bare id means revision 1 — what every id written before this meant — so no
  history is invalidated and nothing has to be re-tagged; bump only when the rule changes
  what it would report on an unchanged site. What this does not do is *detect* a rule
  change: the bump is an author's deliberate act, and a rewritten check whose author
  forgot to bump it reads as covered exactly as before.
  Findings now carry identity too: Step 7.5 keys each one by **check id + resource** in
  `.wp-audit-findings.json`, beside the manifest rather than inside it — the manifest is
  configuration every command parses on every run, and a ledger grows without bound (one
  check found 70 orphan ids on one site). `audit.findings_ledger` is a pointer, and
  `bin/wp-config.mjs` refuses an inlined one. `issues_found` / `issues_fixed` survive as
  derived values because a summary still needs a number.
  **`resolved` requires a measurement.** A check that did not run yields `unmeasured`, never
  `resolved` — otherwise a Tier 1 run would mark every Tier 2 finding fixed and the report
  would show a site cleaning itself up by being audited with less access than before. What
  the ledger still cannot do is notice a finding whose *resource* is only a `file:line`
  moving because someone added an import above it: that one reports resolved-and-new. Rules
  identify by record, option or element wherever one exists, and the ones that cannot churn.
- **A dev host is now distinguishable from a missing report, and both still block.**
  `bin/geo-scan.sh` exits `3` for a host it cannot reach publicly and `2` for a host with no
  report yet, so the audit can tell a configuration problem from an absence. Neither is a
  pass, and `--host` is the fix for the first. What neither exit code proves is that the
  public URL someone passes actually serves the same site as the one WP-CLI is talking to.

- **Prompt quality is judgment, not machinery.** Nothing stops a weak prompt
  from producing a plate that fills its slot while reading as generic.
  `demo/BRIEF.md` is the only defence there is.
- **The network half of client research is covered by no check.** No assertion
  can drive a real search or fetch without live network, and a mock would only
  assert the mock. `tests/checks/wp-research.sh` covers everything around the
  call: the branch order, the `"research": "none"` contract in both directions,
  the degradation lines, and the six citation rules.
- **The Firecrawl and DataForSEO rungs are never exercised by the suite.** Both
  need a connected MCP server. Only the `WebSearch`/`WebFetch` baseline is
  reachable from a test, so the two upgrade paths are verified by reading, not
  by running.
- **`unconfirmed` is a confession, not a measurement.** A business the agent
  could not confirm and a business with no web presence are not distinguished by
  the artifact — only by the candidates it lists. What the flag does guarantee is
  narrower and real: no `research.site` is recorded, so `designlang` is never
  pointed at a guess.
- **Research quality is judgment, not machinery.** A weak competitor set yields a
  weak differentiation line, and nothing catches it. The six citation rules force
  the artifact to be read; they cannot force it to be good. `demo/RESEARCH.md` is
  the only defence there is.
- **Competitor design signal is read from markup, not from rendering.** The agent
  reads HTML and CSS, never a screenshot, so a site whose identity lives in
  motion or in canvas yields a thin row — the same ceiling `designlang` already
  carries.
- **`research.at`, `research.tier`, `research.location` and
  `research.competitors` are recorded, not wired up.** `agents/wp-research.md`
  writes all four into `.wp-create.json`, for the operator and for future use,
  but no command reads them today — only `research.site`, `confidence` and the
  scalar `"research": "none"` are read. Reuse keys off `demo/RESEARCH.md`'s
  existence, not off `research.at`'s date.
- **An MCP server's instructions reach every session, not just the command that wants
  them.** Measured: `inspo-mcp@0.1.16` returns 1,478 characters of instructions on
  `initialize`; `wp-design-library` returns none. Registering a reference server puts
  its guidance in front of every task in that project, which is why inspo is opt-in
  rather than shipped. Inspo's own text currently defers to the project, but the
  precedence line in `commands/wp-demo.md` does not rely on that surviving their next
  release.
- **The inspo exclusions are prose, and prose binds an agent that reads it — but a
  produced build can now be checked against its own transport log.** The greps in
  `tests/checks/wp-library.sh` pin the wording. `tests/checks/wp-demo-references.sh`
  goes one step further, on demand: pointed at a `demo/` built with
  `tests/fixtures/mcp-spy.sh` wrapping each reference server (`MCP_SPY_LOG` set), it
  reads the build's citations and the JSON-RPC requests that actually went over the
  wire, and fails when a citation names a server no call reached, or when the build
  called `get_reference_jsx`, `find_by_color` or `get_design_system` — the three
  Step 2.6 sub-step 3.7 forbids. `recommend` exists on both servers and is
  reported, asserted on by neither. It `SKIP`s without `DEMO_DIR`, so the suite
  stays network-free; it is evidence an operator gathers, not a gate CI runs. What
  remains prose-only is everything a call cannot show — whether the build *used*
  what it fetched, which is the same ceiling the transcription and fidelity mandates
  carry.
- **Inspo's corpus is a runtime dependency on a third party's storage.** Nothing is
  vendored. If it goes away, builds degrade through the `References: inspo
  unavailable` path, which is why that line exists in both modes.
- **Opt-in means most builds will not have it.** Registration is a deliberate act, so the
  plain path's reference gap is closed only for operators who take that act. That is the
  cost of not shipping a third-party network dependency in the default path.
- **The validator binds the commands that call it.** `bin/wp-config.mjs` is the single
  definition of a valid `.wp-create.json`, but a command whose gate line is deleted simply
  stops validating, and only `tests/checks/wp-config-gate.sh` notices. Same ceiling every
  prose contract here carries.
- **The gate substitutes its own path.** `${PROJECT_PATH}` is prose, not an environment
  variable the way `${CLAUDE_PLUGIN_ROOT}` beside it in the same `bash -c` is — a Claude
  that treats both alike runs `validate ''`, gets the usage line and exit `1`, and the
  table reads that as "stop". The block now says where the path comes from, and
  `tests/checks/wp-config-gate.sh` diffs every site against one canonical copy so
  the sentence cannot be lost from one of them; nothing can check that the directory a
  Claude substituted is the right one, and the tool still answers a missing argument and an
  invalid manifest with the same exit code.
- **An adopted site's code scope is a heuristic that the operator confirms.**
  `wp-config.mjs adopt` treats code that no updater knows as the site's own. The update
  transients are the only offline signal. They misclassify a vendor add-on bundled with a
  theme, and a site that has never checked for updates has empty transients, so every
  plugin reads as the site's own. `/wp-adopt` makes the operator confirm every path for
  that reason. The read-only guard in `/wp-audit`'s fix phase is prose plus a
  `git status` check after each fix. A root that is not a git repository falls back to
  modification times, which is weaker.
- **A tested compatibility range is a claim someone has to keep honest.** An absent range
  is reported as untested, which makes the gap visible; nothing keeps a declared range true
  as plugins release.
- **Writing the generated block is what retires the legacy prose lines.** `render-context`
  comments them out in the same pass that writes the block, so any caller that takes
  ownership also retires the old record and a project states each decision exactly once
  instead of contradicting itself with `validate` exiting 0. It happens only there, and
  only downstream of `render-context`'s refusal to render an incomplete manifest — a block
  with a blank where a decision belongs is not worth the record it would retire, which is
  how migration used to leave a project permanently invalid. `contextDrift` still compares
  only inside the markers, so a decision line an operator writes outside them afterwards is
  invisible, and `/wp-init` Step 7 still writes those lines into a fresh project that has no
  generated block at all.
- **Generated credentials are only as private as the local file.** Splitting them into
  `.wp-create.local.json` keeps them out of the committed manifest; it encrypts nothing, and
  a password already committed needs rotating rather than migrating.
- **Gateway keys from constants cover Stripe only.** `store-kit` supplies the Stripe settings
  from `STORE_KIT_STRIPE_*` constants; every other gateway keeps its keys in its own option row,
  and SEC-040 reports them. The same design would extend to another gateway one option at a time.
- **"Connect with Stripe" does not work with `store-kit` credentials.** Its OAuth flow saves the
  keys through `update_option()`, and `store-kit` strips the fields a constant supplies. Stripe
  is configured with API keys.
- **The general Store API limiter is off on purpose.** In WooCommerce 11.1.2 it keeps the same
  per-IP row as the checkout limit, and ordinary cart traffic created that row first in the
  measurement, so six checkout attempts in a row went through. Setup turns on only the checkout
  limit; `tests/checks/store-kit.sh` fails if anything enables the general one.
- **Setup ownership is by value hash.** A client edit that happens to restore setup's own value
  reads as setup's, and the hash records a value, not a history.
- **Setup reports what the block stopped naming, and never deletes it.** A zone, shipping method
  or tax rate setup recorded that is no longer in the `store` block but still exists in
  WooCommerce is a `degraded` line, counted in the summary — a stale rate or method keeps
  charging, so a run must not read as a clean match. Removing it is the operator's act in
  WooCommerce. Zones and rates are matched by name, so a renamed zone is a new zone plus a stale
  one.
- **Store profiles need native WP-CLI.** `bin/store-kit-sync.sh` copies into the host's
  `wp-content/plugins`, and `woo-setup.php` and `.wp-create.json` are host paths; the Docker
  template mounts only the theme, wp-env loads no plugin from the project, and DDEV and Lando
  run WP-CLI in a container that mounts neither this plugin's scripts nor the host project path.
  `/wp-create` and `/wp-woo-setup` read `environment.engine` and stop before syncing on anything
  but `native` rather than fail at `plugin activate` or the dry run. Supporting a container
  means mounting the plugin and the project into it, which no template does today.
- **The fixture proves checkout through the Store API with cash on delivery.** A real card
  payment and Stripe's own flow are never exercised — no network, no bill — and Turnstile's
  verification is a stub at the HTTP boundary (`tests/fixtures/wp/net-guard.php`).
- **Tax is merchant-provided rates.** No tax engine; Stripe Tax is the documented upgrade.
- **Setup reads Stripe keys from the environment and `.wp-create.local.json` inside the WP-CLI
  wrapper's own environment.** A Docker wrapper sees neither the host's environment nor host
  paths unless they are passed or mounted — the limit `skills/wp-polylang/scripts/` carries too.
- **The `woocommerce_uploads` deny rule reaches the plugin's own nginx and Caddy templates
  only.** The native templates and the Docker `docker/nginx.conf` (rendered by `/wp-create`
  from `templates/docker/nginx.conf.tpl`) carry it; DDEV, Lando and wp-env keep their own
  server configs.
  SEC-039 still measures every one of them live.
- **`store-kit` is linted at PHP 7.4 and executed on the fixture's PHP.** Syntax on the floor is
  proven; behaviour on 7.4 itself is not.
