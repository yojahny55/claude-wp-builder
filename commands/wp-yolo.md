---
description: Full-site builder — convert a complete multi-page HTML demo folder into a WordPress theme in one pass
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<demo-folder> [--yolo] [--careful]"
---

# WP YOLO — Full-Site Demo → WordPress Theme

Convert a complete multi-page HTML demo into a working theme in one orchestrated pass,
reusing the plugin's existing build pipeline end to end. Run this AFTER `/wp-create` +
`/wp-init` have scaffolded the project. This command does not reimplement any builder —
it dispatches the `wp-normalize` agent once, then drives the existing commands/agents in
dependency order.

## Step 1: Parse Arguments & Gate

Parse `$ARGUMENTS`:
- **First non-flag word** = path to the demo folder (required). Error and exit if missing,
  or if the path is not a directory:
  ```
  Error: A demo folder is required.
  Usage: /wp-yolo <path-to-demo-folder> [--yolo] [--careful]
  ```
- **`--yolo`** = no checkpoint at all (ingest → build → seed → finalize → report, hands-off).
- **`--careful`** = checkpoint after normalization AND a per-page confirm before each inner
  page's build in Phase 2.
- **default** (neither flag) = a single checkpoint after normalization, then hands-off.

Read `.claude/CLAUDE.md` at the project root. If it does not exist, refuse:
```
Error: No .claude/CLAUDE.md found. Run /wp-init first to scaffold the project.
```
Extract function prefix, theme slug, languages (primary + secondary), template
(basic|tailwind), and CF plugin (scf|acf) — needed by every downstream command.

## Step 2: Phase 1 — Normalize

Dispatch the **wp-normalize** agent against the demo folder from Step 1. It scans every
page, resolves shared header/footer, splits sections, classifies content types
(static-repeater vs custom-post-type), and writes:
- `demo/*.html` — canonical, delimited pages (the same `<!-- SECTION: X -->` format the
  existing builders consume)
- `demo/.yolo-manifest.json` — the orchestration source of truth (`pages[]`, `shared`,
  `contentTypes[]`, `review[]`)

Read `demo/.yolo-manifest.json` back once the agent completes.

## Step 2.5: Phase 1.5 — Load & reconcile scope

If `docs/.scope-manifest.json` exists, read it and reconcile with the `wp-normalize`
manifest by matching pages on slug/name. Annotate each page with `delivery`, `inScope`,
`approved` from the scope manifest. Determine, per page:
- in-scope + demo HTML + `delivery: theme` → normal build.
- in-scope + `delivery: idx` or `plugin` → build a styled shell with `/wp-page embed <slug> --provider <provider>` (NOT a normal section build), regardless of whether demo HTML exists.
- in-scope + `delivery: theme` + NO demo HTML → do not build; add to Review: "approved/designed but no HTML — needs demo."
- demo page NOT in scope → skip; add to Review: "in demo but out of scope — skipped."
Fold `constraints` into the guidance passed to every dispatched agent (e.g. forms = email-only, no mobile designs, SEO scope). If `docs/.scope-manifest.json` is absent, proceed demo-governed (existing behavior).

These rules are evaluated in priority order — `delivery` decides first, so the `idx`/`plugin`
rule always wins over the no-demo-HTML rule.

## Step 3: Checkpoint (skipped under --yolo)

Unless `--yolo` is set, print the detected map from the manifest:
- Pages (slug, role: home / inner / cpt-archive / blog) and their sections (name, kind,
  confidence where < 1.0)
- Shared header/footer flags and any divergent pages
- Content-type classifications (`contentTypes[]`) with field lists
- **Scope annotations** (if `docs/.scope-manifest.json` was loaded): each page's
  `delivery` (theme/idx/plugin), out-of-scope pages skipped, and approved-but-missing-HTML
  pages awaiting a demo
- The full `review[]` list of low-confidence decisions

Ask the user to **approve / edit / abort**:
- Edit = rename/merge/split a section, drop a page, flip a `kind` between `static` and
  `cpt-teaser`, etc. Apply edits directly to `demo/.yolo-manifest.json` before continuing.
- Abort = stop here, leave `demo/*.html` and the manifest in place for a later resumed run.

Under `--yolo`, skip this step and proceed straight to Phase 2 with the manifest as
emitted by `wp-normalize`.

## Step 4: Phase 2 — Build (dependency order)

Drive the existing commands/agents in this exact order, reading everything from the
(possibly edited) manifest. Do not reimplement any builder's logic — dispatch it.

1. **`/wp-settings`** — logo, contact info, social links, legal links, copyright, derived
   from the header/footer/contact content found by `wp-normalize`.
2. **CPTs first** — for every entry in `contentTypes[]`, run `/wp-cpt <name>` (using its
   `fields[]` and `seed[]` as the `--from-demo` hints). This must complete before any
   section queries that CPT. **`/wp-cpt` OWNS this CPT's teaser** (`template-parts/section-<name>.php`,
   named for the CPT — never the manifest section name — injected into `front-page.php`).
   Pass **`--no-teaser`** when the contentType has `hasTeaser: false`, OR when no
   `sections[].kind == "cpt-teaser"` with `cpt == <name>` exists anywhere in the manifest —
   otherwise let `/wp-cpt` build the teaser.
3. **`/wp-header`** — the shared header → `header.php` + nav-walker + registered menus.
4. **`/wp-footer`** — the shared footer → `footer.php`.
5. **Home page sections** — for the `pages[role=home]` entry: if the scope reconciliation
   (Step 2.5) marked it `delivery: idx` or `delivery: plugin` (rare — e.g. an all-IDX
   homepage), build it as a styled embed shell instead of assembling sections: dispatch
   `/wp-page embed home --provider <provider>` (its insertion point lives in
   `front-page.php`), skip the `sections[]` walk for this page, and note it in the
   report. Otherwise (`delivery: theme` or no scope manifest), proceed with the normal
   section walk: walk its `sections[]` in order and run the `/wp-section` procedure per
   section (defaults: `--page index`, `--target front-page.php`, so no flags are needed
   for home):
   - `kind: "static"` → `/wp-section <name> --transcribe --block <block> --css <cssRules>`
     (three-agent parallel dispatch). The `--transcribe` flag activates wp-css Transcription
     Mode via `/wp-section`'s transcription overlay; `--block` is the section's assigned
     unique BEM name (every selector is scoped under it); `--css` is its verbatim demo
     `cssRules` (the source of truth). This reproduces the demo's exact declared CSS under
     that block instead of drafting fresh styles. Because every section's `block` is already
     unique, parallel agents can never collide on a selector.
   - `kind: "cpt-teaser"` → **SKIP** — do NOT dispatch `/wp-section` for these. The CPT's
     teaser `template-parts/section-<cpt>.php` was already built and injected into
     `front-page.php` by that CPT's `/wp-cpt` run in step 2. Note it in the report as
     "teaser for `<cpt>`, built by /wp-cpt".
   - `kind: "contact"` → `/wp-section <name> --cf7 --transcribe --block <block> --css <cssRules>`,
     same transcribe dispatch as `static`.
6. **Inner pages** — for every `pages[role=inner]` entry: if the scope reconciliation
   (Step 2.5) marked this page `delivery: idx` or `delivery: plugin`, skip the normal
   page/section flow entirely and instead run
   `/wp-page embed <slug> --provider <provider>` — a styled shell, not a section build.
   Otherwise, run `/wp-page custom <slug>`, then build its `sections[]` — but each inner
   section must read from its OWN demo page and inject into its OWN page template, so pass
   `--page <slug> --target page-<slug>.php` on every dispatch:
   - `kind: "static"` → `/wp-section <name> --page <slug> --target page-<slug>.php --transcribe --block <block> --css <cssRules>`,
     passing the section's unique `block` + verbatim `cssRules` via the transcribe flags,
     exactly as in step 5.
   - `kind: "contact"` → `/wp-section <name> --cf7 --page <slug> --target page-<slug>.php --transcribe --block <block> --css <cssRules>`,
     same transcribe dispatch.
   - `kind: "cpt-teaser"` on an inner page → same skip rule as step 5 (owned by `/wp-cpt`).
   Under `--careful`, confirm with the user before building each inner page.
7. **`cpt-archive` pages** — no WP Page is created for these (their archive URL is
   `has_archive`, already wired by `/wp-cpt` in step 2). Skip page creation; note them in
   the final report as "archive of `<cpt>`, built by /wp-cpt".
8. **Blog** — if any `pages[role=blog]` entry exists, run `/wp-page blog`.
9. **Mandatory system pages — always, regardless of demo content:**
   - `/wp-page 404`
   - `/wp-page search`
   These are never conditional on the demo containing a matching page; they are
   synthesized from the derived design (shared header/footer, design tokens, section
   styling) so they read as native to the site.

## Step 4.5: Font carry

Before seeding, collect every `section.fonts[]` entry across the manifest (dedupe by
`family`+`weight`+`style`):
- Copy each entry's `src` woff2 file(s) from the demo folder into `theme/assets/fonts/`.
- Re-emit each `@font-face` rule with `src` rewritten to the theme-relative path
  (`assets/fonts/<file>.woff2`) and enqueue the resulting stylesheet (or add to the
  theme's existing fonts partial) so every block's `transcribe`d CSS resolves against a
  self-hosted font, not the demo's original path.
- Only add a Google Fonts `<link rel="preconnect">` (fonts.googleapis.com /
  fonts.gstatic.com) when the demo's own `<head>` actually references Google Fonts — never
  as a substitute for a self-hosted font family found in `section.fonts[]`. Self-hosted
  stays self-hosted; the two are not interchangeable.

## Step 5: Phase 3 — Seed & Finish

Run, in order:
1. **`/wp-seed --exclude-slugs <slugs>`** — create WP Pages with matching slugs (so
   `page-<slug>.php` auto-applies), populate ACF fields from extracted text in the
   **primary language only** (flag secondary-language strings as untranslated), sideload
   images into the media library and wire them to fields, and build menus from the nav.
   Pass the manifest's top-level `assets[]` (role-tagged: `logo` / `nav-graphic` / `hero` /
   `content`) through so `/wp-seed` seeds each image by its role instead of guessing.
   Set `--exclude-slugs` to the comma-joined slugs of every `pages[role=cpt-archive]` entry
   (e.g. `--exclude-slugs team`) so no stray WP Page is created for an archive slug — its
   URL comes from `has_archive`, and a WP Page would collide with `archive-<cpt>.php`.
2. **Create CPT posts** — `/wp-seed` does not create CPT posts, so after it, for each
   `contentTypes[]` entry execute its seeder `inc/seed/<name>.php` (emitted by that CPT's
   `/wp-cpt` run in Phase 2) via the project's WP-CLI wrapper — e.g.
   `$WP eval-file inc/seed/team.php` — to create that type's posts from its `seed[]`.
   **Primary language only.**
3. **`/wp-finalize`**
4. **`/wp-polish`**
5. **`/wp-responsive-check`**

## Step 5.5: Demo-parity gate — auto-fix, re-verify, and block

`/wp-finalize` (Step 5, item 3 above) already ran the 3-layer demo-parity gate (Layers 1-3).
Before this run can report success, walk every **critical** finding from that gate:

1. **Auto-fix mechanical findings** — no judgment required, apply directly:
   - Token-drifted value with a clear literal source in the demo → replace it with the
     demo's literal value.
   - Missing font → copy the woff2 file(s) into `theme/assets/fonts/` and re-emit the
     `@font-face` rule (same as Step 4.5's font carry).
   - Missing logo/hero asset → seed it by its manifest `role` (`logo` / `hero`), same as
     `/wp-seed`'s role-tagged asset pass.
   - Colliding block (unscoped generic class) → rename/rescope it to its manifest-assigned
     unique `block` name.
   - Missing `background:url()` → transcribe it verbatim from the demo's recorded CSS
     (`section.backgrounds` in the manifest) into the theme CSS.
2. **Re-verify** — after applying any auto-fix, re-run the affected gate layer(s) to
   confirm the finding actually cleared. Do not assume the fix worked; re-run and check.
3. **Ambiguous findings are reported, not guessed.** Value drift with no clear literal
   source, or a layout mismatch needing design judgment, is never auto-fixed — add it
   verbatim to the blocking **Review** list.
4. **Any critical finding still open after auto-fix + re-verify — including everything
   ambiguous — blocks delivery.** This applies **even under `--yolo`**: `/wp-yolo` does not report success while any critical remains. The run is marked incomplete and the
   Review list is printed prominently at the top of Step 6's report, before the rest of
   the summary.

## Step 6: Report

If any critical demo-parity finding survived Step 5.5's auto-fix + re-verify, do NOT
print "Build Complete." Print instead, before anything else:
```
=== WP YOLO Build INCOMPLETE — demo-parity gate blocked delivery ===

Review (blocking):
  - <every unresolved critical finding — layer, selector/property/file, demo value vs. built value>

Run /wp-finalize again after resolving the above, then re-run this gate.
```
This applies under `--yolo` too — `--yolo` skips the Step 3 checkpoint, not this gate.

Otherwise, print a summary:
```
=== WP YOLO Build Complete ===
Pages built:       <slug list, with section counts>
CPTs registered:   <name list, with archive/single status and seed count>
CF7 forms:         <count, if any contact sections were found>
Media imported:    <count>
Mandatory pages:   404, search (always built)
Embed/IDX pages:   <slug list — "install & configure <provider>" for each delivery: idx|plugin page>

Review:
  - <every review[] entry from the manifest — low-confidence splits, CPT-vs-repeater
    verdicts, ambiguous fields>
  - <untranslated secondary-language strings, if any>
  - <anything skipped — e.g. JS-only interactivity not reproducible in static templates>
  - <out-of-scope pages skipped: "in demo but out of scope — skipped">
  - <approved-but-missing-HTML pages: "approved/designed but no HTML — needs demo">
```

Note for the user: `--yolo` is best used **after** one checkpointed dry-run of the same
demo folder, once the manifest has been reviewed and edited at least once.
