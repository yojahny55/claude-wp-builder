# Changelog

## [Unreleased]

### Added
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
- **The docs no longer say these two capabilities have no slash command.** `README.md`,
  `docs/commands.md` and `docs/workflows.md` each said so, correctly, until now; all three
  now state that the skills are invoked through their runner commands while remaining
  non-invocable themselves, so the layer rule reads as intact rather than abandoned.

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
