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
  Usage: /wp-yolo <path-to-demo-folder> [--yolo] [--careful] [--force]
  ```
- **`--yolo`** = no checkpoint at all (ingest → build → seed → finalize → report, hands-off).
- **`--careful`** = checkpoint after normalization AND a per-page confirm before each inner
  page's build in Phase 2.
- **default** (neither flag) = a single checkpoint after normalization, then hands-off.

Read `.claude/CLAUDE.md` at the project root. If it does not exist, refuse:
```
Error: No .claude/CLAUDE.md found. Run /wp-init first to scaffold the project.
```

**Then refuse to run twice.** This command has no resume entrypoint: a second
run restarts at Step 2, re-dispatches `wp-normalize`, overwrites
`demo/.yolo-manifest.json` and rebuilds the theme over whatever has been hand-
corrected since. If the theme directory already holds built section template
parts, or `.claude/CLAUDE.md` records a completed run, stop:

```
Error: <theme> already contains a built section flow (<n> template parts).
/wp-yolo rebuilds from the demo and would overwrite work done since the first run.
Use the per-step commands instead: /wp-section, /wp-page, /wp-seed, /wp-finalize.
Pass --force only to deliberately discard the current build.
```

Accept `--force` to override, and on a successful run append a
`## Workflow — DONE, do not re-run` note to `.claude/CLAUDE.md` recording the
date and which steps completed.
Extract function prefix, theme slug, languages (primary + secondary), template
(basic|tailwind), CF plugin (scf|acf), and **i18n strategy (suffix|polylang)** —
needed by every downstream command.

If the `i18n strategy` line is absent, treat it as `suffix`: projects scaffolded
before the choice existed all use that model, and assuming `polylang` for them
would have the agents generate a field layout their theme cannot read.

If `Template:` is `cinematic`, stop. This command builds the basic|tailwind
section flow, and a cinematic project is a different scaffolding shape — one
continuous reel, scene-based authoring. Point the user at the cinematic flow
instead (`/wp-cinematic-init`, then `/wp-cinematic-scene <n>` per scene, per
`/wp-init` Step 0.5) and exit without dispatching anything. Falling through
would drive the section walk on a reel project and hand its CSS to wp-css,
which writes `assets/css/styles.css` into a theme that has its own
`assets/css/cinematic.css`.

Under `polylang`, three things change downstream, and every one of them is the
existing command's own branch — `/wp-yolo` passes the strategy along and does
not reimplement any of it:

- `/wp-section` and the `wp-acf` agent emit no `_<lang>` duplicate fields,
  except in the theme settings group.
- `/wp-header` registers one menu location per name and renders the switcher
  with `pll_the_languages()`.
- `/wp-seed` builds a counterpart page per language from the demo's own
  secondary-language copy, then hands whatever the demo did not cover to
  `/wp-polylang`.

After Phase 3 seeding completes under `polylang`, run the retrofit for each
secondary language to translate anything the demo left untranslated, then let
its verifier gate the result:

```
/wp-polylang <primary_lang> <secondary_lang>
```

Treat a non-zero exit from `pll-verify.php` exactly like the demo-parity gate
below: report it and stop, rather than declaring the build finished.

**Git baseline gate.** `/wp-yolo` rewrites the theme wholesale, so it must run against
a git repo — for a rollback point and for worktree isolation. In the theme directory:

```bash
cd <theme-dir>
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  git init -q
  printf 'node_modules/\n.DS_Store\n*.log\n' > .gitignore
}
git add -A && git commit -q -m "chore: baseline before /wp-yolo build" || true
```

This is unconditional and runs even under `--yolo`: no build starts until a clean
baseline commit exists, so the whole pass is diffable and revertible.

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

## Step 2.6: Phase 1.6 — Demo conversion (tailwind template only)

Skip this step entirely when `template == basic`.

When `template == tailwind`, the section walk must transcribe from a Tailwind-native
demo, not a plain-CSS one. Transcribing plain CSS is what produced themes with zero
utility classes.

Conversion is **in place**, with a backup. Each `demo/<slug>.html` is replaced by its
Tailwind-native form and the untouched plain-CSS copy is kept out of the way as
`demo/.original/<slug>.html`. The backup goes in a dot-prefixed subdirectory on purpose:
`/wp-seed` (Step 5, item 1) turns **every** `.html` file it finds in `demo/` into a WP
Page whose slug is the filename, so a sibling backup named `demo/<slug>.original.html` would seed a phantom
page with slug `<slug>.original` out of unconverted markup — one per demo page.
`demo/.original/` falls outside the `demo/*.html` pattern entirely, so no reader that
enumerates the demo with a `demo/*.html` glob can see it: shell globbing, Python's `glob`,
`ripgrep` and `fd` all skip dot-prefixed entries by default. `/wp-seed` states no glob of
its own — `commands/wp-seed.md` says only that it processes the `.html` files in `demo/` —
so the dodge rests on that enumeration honouring the dot rule, as every tool above does. The exception is a recursive descent that does not honour the
dot rule — `find demo -name '*.html'` walks into `demo/.original/` and returns the backups
— so anything switching to `find` must add `-not -path 'demo/.original/*'` itself, and
`-not -path 'demo/.prepolish/*'` alongside it once `/wp-polish` has run over the same
folder, because that step keeps its own backups there. Nothing downstream takes a new
filename, because the demo page's own filename never changes.

Walk **every** page in the manifest's `pages[]` — the home page and every inner page,
not just `index`. For each page, in this order:

1. **Detect, per page.** Read `demo/<slug>.html` and decide whether it is *already
   Tailwind-native*. The absence of inline CSS does not answer that question, and the shape
   of the page arriving here is why. `wp-normalize` (Step 2) consolidates every external
   CSS rule it can *match to a section* inline, into the page it emits, so each page is
   self-contained — but a rule that matches no section (`:root` custom properties, resets,
   `body`, `@font-face`, a global `@media` block) is not inlined, and `wp-normalize` is
   never told to drop the `<link rel="stylesheet">` that still carries it. So the page in
   front of you may hold an inlined `<style>` block, the original `<link>`, or both, and
   each of those is CSS this page still depends on. Decide on evidence, not on the absence
   of one delivery mechanism:

   - **Plain-CSS evidence — any one of these means convert.** A `<style>` block; a static
     `style="` attribute; or a `<link rel="stylesheet">` pointing at the project's own
     `.css` file — a relative path (`assets/styles.css`), a site-rooted path
     (`/css/main.css`) or an absolute URL on the project's own domain all count the same,
     because the delivery route is not what matters. A linked stylesheet delivers CSS to
     the page exactly as much as a `<style>` block does. Only three hosts are exempt:
     `fonts.googleapis.com`, `fonts.gstatic.com` and `cdn.tailwindcss.com`. A `<link>` to
     any of those is not plain-CSS evidence; every other stylesheet `<link>` is.
   - **Tailwind evidence — what a converted page actually looks like.** Its `class`
     attributes are predominantly Tailwind utilities: layout (`flex`, `grid`, `hidden`),
     spacing and sizing (`px-4`, `mt-8`, `w-full`), typography (`text-lg`, `font-bold`),
     colour (`bg-slate-900`, `text-white`) and variant prefixes (`md:`, `lg:`, `hover:`).
     Semantic or BEM class names (`site-header__logo`, `hero`, `card__title`) are the
     plain-CSS shape, not Tailwind evidence.
   - **Skip only on Tailwind evidence and no plain-CSS evidence.** Then, and only then,
     leave the file alone, do not back it up, do not convert it, and note
     `demo already tailwind-native — conversion skipped` in the report for that page.
   - **Ambiguous input converts.** A page carrying both utilities and a project
     stylesheet, a page carrying neither, a page you cannot classify with confidence:
     convert it. The two mistakes are not symmetrical. Converting a page that was already
     Tailwind-native costs one redundant pass over markup that is already in the target
     form. Skipping a page that was not voids the entire tailwind path — the section walk
     transcribes the manifest's plain-CSS `cssRules` instead, and the theme ships with BEM
     CSS and no utility classes — while reporting success for every page. Bias every tie
     towards converting.

   Skipping on positive evidence is what makes *this step* idempotent — a second
   `/wp-yolo` pass over an already-converted demo detects and skips instead of converting
   twice, because conversion strips the `<style>` blocks *and* the project stylesheet
   `<link>` whose rules it absorbed (`@agents/wp-tailwind`, MUST remove), leaving Tailwind
   evidence and no plain-CSS evidence behind. It does **not** make a re-run safe: by the
   time Step 2.6 runs again, Step 2 has already re-dispatched `wp-normalize` and emptied
   the manifest's `cssRules`, `fonts` and `backgrounds`. See Step 3's abort branch.
2. **Back up, per page.** Otherwise create `demo/.original/` if it does not exist and
   copy `demo/<slug>.html` to `demo/.original/<slug>.html` — but **only if
   `demo/.original/<slug>.html` does not already exist**. If it does, it is already the
   pristine original from an earlier run; overwriting it with an already-converted page
   would destroy the only plain-CSS reference that exists.
3. **Convert in place, per page.** Run
   `/wp-tailwindify demo/<slug>.html --out demo/<slug>.html` — the output path is the
   demo page itself, so the converted markup lands on the same path the original
   occupied.
4. **Verify, or restore.** Read `/wp-tailwindify`'s Step 4 verification result for this
   page: section delimiters preserved, no `<style>` blocks remaining, and no project-local
   stylesheet `<link>` remaining. The third item is what makes item 1's skip terminate: a
   converted page that still links `assets/styles.css` carries plain-CSS evidence, so the
   next run classifies it as not-yet-Tailwind-native and converts it again, forever.

   On a failure there is normally **nothing to restore**, and the restore below is a
   belt-and-braces check rather than the main line of defence. `/wp-tailwindify` has the
   agent write `<output-path>.tmp` and moves it over the demo page only after that
   verification passes (its Step 3, and Step 4 items 5-6); a page that failed never
   reaches `demo/<slug>.html`, so what is sitting there is still the pristine original
   and copying the backup over it changes nothing. Keep the check anyway, but condition
   it on that invariant instead of assuming it holds: after a reported failure, compare
   `demo/<slug>.html` byte-for-byte with the backup. **Identical** — the contract held;
   report the page as unconverted and touch nothing. **Different** — something outside
   the contract wrote that path (a hand-run conversion, an older plugin version, an
   editor, or an `mv` that prompted instead of moving), so restore `demo/<slug>.html`
   from `demo/.original/<slug>.html` and report the page as unconverted. Never leave a
   truncated or half-converted page at `demo/<slug>.html`: item 1 would read the wreckage
   on the next run, see utility classes and no project stylesheet, declare the page
   already Tailwind-native and skip it forever, and items 2-6 below would build from the
   wreckage.
5. **Re-point — nothing to re-point.** Because conversion is in place, every later
   reader picks up Tailwind-native markup with no argument change and no new flag:
   item 2 (`/wp-cpt <name> --from-demo <section>`, which reads `demo/index.html`),
   item 3 (`/wp-header`, same file), item 4 (`/wp-footer`, same file), item 5 (the home
   `sections[]` walk, `--page index` → `demo/index.html`) and item 6 (every inner page's
   walk, `--page <slug>` → `demo/<slug>.html`) all resolve to the converted file.
   `demo/.original/<slug>.html` is a reference copy only: it is never a build source, it
   is not a manifest page, no `--page` value ever resolves to it, and `/wp-seed` never
   globs it.
6. **Report.** Record which demo pages were converted, which were skipped as already
   Tailwind-native, and which were restored from backup after a failed verification.

**Accepted ceiling — a class borrowed across sections loses its provenance.** Demos
reuse a class wherever the geometry happens to match: a Contact page heading carrying
`.services__title` is ordinary demo authoring. Conversion inlines that rule's
declarations onto the element as utilities, so the render stays right and each section
still transcribes from its own markup — what is lost is the *evidence of sharing*. After
conversion the two headings read as two independent utility groups, so the decision
ladder's "same group on two or more pages" test must be run over the converted markup by
comparing utility strings, there being no class name left to record it. Missing it costs
a duplicated inline group, never a wrong render, which is why this is accepted here
rather than worked around.

Under `--careful`, confirm the conversion result with the user before continuing.

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
- Abort = stop here, leaving the manifest and `demo/*.html` on disk. On the `tailwind`
  path Step 2.6 has already run by this point, so `demo/*.html` is the converted markup
  and the plain-CSS originals sit in `demo/.original/`.

  A later `/wp-yolo` run is **not** a resume: it starts at Step 2 and dispatches
  `wp-normalize` over the demo folder unconditionally — there is no manifest guard — so
  normalize re-derives `cssRules`, `fonts` and `backgrounds` from the now Tailwind-native
  markup, which no longer carries the plain-CSS declarations or `@font-face` rules they
  were captured from. Step 2.6 then correctly detects the pages as already Tailwind-native
  and skips them, but the manifest **that** Step 4.5's font carry and `/wp-finalize`
  Layer 1 read has already been emptied by then. Nothing fails; the output is quietly
  degraded.

  So a fresh `/wp-yolo` after an abort must start from plain-CSS demo pages: restore
  `demo/<slug>.html` from `demo/.original/<slug>.html` for every page first (or re-run
  against a pristine demo folder), then run `/wp-yolo` again from the top.

  There is no resume entrypoint in this command — not `--yolo`, and not any other flag.
  `--yolo` suppresses this checkpoint and nothing else (Step 1: "no checkpoint at all"):
  Step 2 still dispatches `wp-normalize` and still overwrites `demo/.yolo-manifest.json`
  before Step 3 is ever reached, so re-running with it *is* the unconditional-normalize
  path described above and it regenerates the very manifest a resume would have to
  preserve. Restore the originals first: every `/wp-yolo` invocation is a fresh build,
  never a continuation of an aborted one.

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
   - `kind: "static"` → `/wp-section <name> --transcribe --block <block> --css <css-source>`
     (three-agent parallel dispatch). The `--transcribe` flag activates `/wp-section`'s
     transcription overlay; `--block` is the section's assigned unique BEM name (every
     selector is scoped under it). What `<css-source>` is depends on the project's
     `Template:`, because `/wp-section`'s transcription overlay declares a different
     source per path:
     - `basic` → the section's verbatim demo `cssRules` from the manifest, which on this
       path is the source of truth. This reproduces the demo's exact declared CSS under
       that block instead of drafting fresh styles.
     - `tailwind` → the converted demo page itself, `demo/index.html` (converted in place
       by Step 2.6). The manifest's `cssRules` was captured by `wp-normalize` in Step 2
       from the plain-CSS original, before Step 2.6 ran, and is stale on this path — do
       not pass it. Per the overlay, the tailwind instruction is "reproduce this geometry
       using Tailwind utilities", not "copy the declared values verbatim".

     Because every section's `block` is already unique, parallel agents can never collide
     on a selector.
   - `kind: "cpt-teaser"` → **SKIP** — do NOT dispatch `/wp-section` for these. The CPT's
     teaser `template-parts/section-<cpt>.php` was already built and injected into
     `front-page.php` by that CPT's `/wp-cpt` run in step 2. Note it in the report as
     "teaser for `<cpt>`, built by /wp-cpt".
   - `kind: "contact"` → `/wp-section <name> --cf7 --transcribe --block <block> --css <css-source>`,
     same transcribe dispatch as `static`, including the same per-`Template:` choice of
     `<css-source>`.

   > **Template routing.** Do not pass a template flag — `/wp-section` takes no such
   > argument and inventing one would do nothing. `/wp-section` reads `Template:` from
   > `.claude/CLAUDE.md` itself. What the template changes is which agent it dispatches
   > and what you pass as `--css`: when `Template:` is `tailwind`, `/wp-section`
   > dispatches `wp-tailwind` in author mode instead of `wp-css` (see its "CSS agent
   > routing" table), and `--css` is the Step 2.6-converted demo page rather than the
   > manifest's `cssRules`. When it is `basic` nothing changes.
6. **Inner pages** — for every `pages[role=inner]` entry: if the scope reconciliation
   (Step 2.5) marked this page `delivery: idx` or `delivery: plugin`, skip the normal
   page/section flow entirely and instead run
   `/wp-page embed <slug> --provider <provider>` — a styled shell, not a section build.
   Otherwise, run `/wp-page custom <slug>`, then build its `sections[]` — but each inner
   section must read from its OWN demo page and inject into its OWN page template, so pass
   `--page <slug> --target page-<slug>.php` on every dispatch:
   - `kind: "static"` → `/wp-section <name> --page <slug> --target page-<slug>.php --transcribe --block <block> --css <css-source>`,
     passing the section's unique `block` via the transcribe flags and resolving
     `<css-source>` by `Template:` exactly as in step 5: on `basic`, the manifest's
     verbatim `cssRules`; on `tailwind`, this page's converted demo file
     `demo/<slug>.html` (converted in place by Step 2.6), never the stale manifest
     `cssRules` and never the backup at `demo/.original/<slug>.html`.
   - `kind: "contact"` → `/wp-section <name> --cf7 --page <slug> --target page-<slug>.php --transcribe --block <block> --css <css-source>`,
     same transcribe dispatch.
   - `kind: "cpt-teaser"` on an inner page → same skip rule as step 5 (owned by `/wp-cpt`).

   > **Template routing.** Do not pass a template flag — `/wp-section` takes no such
   > argument and inventing one would do nothing. `/wp-section` reads `Template:` from
   > `.claude/CLAUDE.md` itself. What the template changes is which agent it dispatches
   > and what you pass as `--css`: when `Template:` is `tailwind`, `/wp-section`
   > dispatches `wp-tailwind` in author mode instead of `wp-css` (see its "CSS agent
   > routing" table), and `--css` is the Step 2.6-converted demo page rather than the
   > manifest's `cssRules`. When it is `basic` nothing changes.

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
   styling) so they read as native to the site. When the demo has no 404/search page,
   they are still built as fully styled theme templates — the `/wp-page` runs overwrite
   any starter/underscores boilerplate `404.php`/`search.php`, never leaving it in place.

## Step 4.5: Font carry

Before seeding, collect every `section.fonts[]` entry across the manifest (dedupe by
`family`+`weight`+`style`):
- Copy each entry's `src` woff2 file(s) from the demo folder into `theme/assets/fonts/`.
  **When the file is not there.** Demos ship broken font paths as a matter of course —
  the rehearsal demo declares `src: url("assets/fonts/marcellus.woff2")` and carries no
  such file. Search the demo folder for the basename first (any subdirectory, matched
  case-insensitively). If it is genuinely absent, do **not** re-emit a `@font-face`
  whose `src` points at a file the theme does not have: that rule fails silently, and
  under `font-display: swap` the page renders the fallback stack with nothing logged
  anywhere to say why. Skip that family's `@font-face` rule entirely, keep the family
  name at the head of its font token so the demo's declared fallback stack still
  applies, and add `font <family>: <src> not found in the demo folder — supply the woff2
  or the theme renders the fallback stack` to the Step 6 Review list.
- Re-emit each `@font-face` rule with `src` rewritten to the theme-relative path
  (`assets/fonts/<file>.woff2`), and **place it by `Template:`**:
  - `basic` → enqueue the resulting stylesheet, or add the rule to the theme's existing
    fonts partial.
  - `tailwind` → write the rule into `assets/css/src/tailwindcss/base/fonts.css` and add
    its `@import` to `main.css` in the same step —
    `skills/wp-tailwind-system/SKILL.md` gives `base` the "resets and font-face" role,
    and its no-empty-file rule is why the rule and the import go in together.
    **Enqueue nothing.** A Tailwind theme has no fonts partial and enqueues exactly one
    stylesheet, the compiled `assets/css/dist/main.css`; a second enqueued stylesheet is
    the plain-CSS regression this template exists to remove, and
    `/wp-tailwind-migrate` Step 5 states the same rule — leave exactly one enqueue.

  Either way, every block's `transcribe`d CSS then resolves against a self-hosted font,
  not the demo's original path.
- Only add a Google Fonts `<link rel="preconnect">` (fonts.googleapis.com /
  fonts.gstatic.com) when the demo's own `<head>` actually references Google Fonts — never
  as a substitute for a self-hosted font family found in `section.fonts[]`. Self-hosted
  stays self-hosted; the two are not interchangeable.

## Step 4.6: Behaviour carry — port ALL of the demo's JavaScript

The chrome build ports the header and drawer scripts. **Everything else the demo
does is still sitting in the demo folder**, and nothing later in this command
notices: the parity gate measures geometry at rest, so a theme whose carousels,
lightbox, listboxes, filter drawer and accordions are all dead passes it
66/66. One project shipped exactly that and only found out from a manual
browser pass.

Enumerate the demo's scripts before writing anything:

```bash
ls demo/js/*.js demo/**/*.js 2>/dev/null
grep -rho 'src="[^"]*\.js"' demo/*.html | sort -u
```

Then account for **every** one:

- **Shared chrome** (nav, drawer, language pill, sticky rails) → the chrome
  module the header/footer build already created.
- **Section behaviour** (carousels, galleries, listboxes, filter panels,
  accordions, tabs, share menus) → one module per behaviour in
  `assets/js/src/sections.js`, each binding to nothing when its markup is
  absent, so any page can load the one bundle.
- **Duplicated-in-every-page code.** A demo with no shared footer copies the
  same block into all eleven page scripts. It belongs in the theme once, not
  eleven times — check the top of each page script before assuming a script is
  page-specific.
- **Deliberately NOT ported:** anything the server now owns. Client-side
  filtering, client-side pagination and client-side facet counts fought a real
  `WP_Query` for the same state — the facets, sort lists and pager are real
  links now. Say so in the module's header comment so the omission is not read
  as an oversight and "restored" later.
- **User-visible strings** inside the ported JS go through the theme's
  translation helper and ride on the localized data object. A string frozen
  into the bundle cannot be translated and cannot be edited by the client.
- **Guard every lookup.** The demo knows its own markup exists; a WordPress page
  does not — no menu assigned, an empty repeater, a missing `aria-controls`
  target. An unguarded dereference throws and takes the rest of the bundle with
  it.

Verify in a real browser before Step 5, one page per behaviour: click a
carousel arrow, open a listbox, open the filter drawer, open the gallery. A
console with zero errors is not evidence — dead code logs nothing.

## Step 5: Phase 3 — Seed & Finish

Run, in order:
1. **`/wp-seed --exclude-slugs <slugs>`** — create WP Pages with matching slugs (so
   `page-<slug>.php` auto-applies), populate ACF fields from extracted text per the
   project's `i18n strategy` — `/wp-seed` reads it from `.claude/CLAUDE.md` itself:
   under `suffix` it fills the primary language and flags secondary-language strings
   as untranslated; under `polylang` it builds a counterpart page per language from
   the demo's secondary-language copy — sideload images into the media library and
   wire them to fields, and build menus from the nav.
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

1. **Auto-fix mechanical findings** — no judgment required, apply directly.

   > **Template branch — read before applying any repair that writes CSS.** Every repair
   > below branches on the project's `Template:` value from Step 1.
   > On `basic`, a repair is a literal CSS declaration written into the theme CSS, read
   > from the demo's recorded CSS in the manifest.
   > On `tailwind`, a repair is expressed as **Tailwind utility classes in the markup** —
   > or an `@apply` rule, and only where the decision ladder in
   > `skills/wp-tailwind-system/SKILL.md` demands one — and is read from the
   > **Step 2.6-converted** demo page (`demo/<slug>.html`), never from the backup at
   > `demo/.original/<slug>.html` and never from the manifest's plain-CSS `cssRules`.
   > Never write a raw CSS declaration into a theme CSS file on the tailwind path: that
   > re-injects exactly the plain CSS this template exists to remove.
   >
   > **`@font-face` is the one carve-out, and the only one.** Tailwind has no utility
   > and no `@apply` form for it, so it is rung 4 of the ladder — raw CSS for what
   > Tailwind cannot express — not a breach of the line above. The missing-font repair
   > below therefore does re-emit a raw `@font-face` block; it goes into
   > `assets/css/src/tailwindcss/base/fonts.css` with its `@import` added to
   > `main.css`, exactly as in Step 4.5, and never into a section's component file or a
   > second enqueued stylesheet. No other repair on this path may write raw CSS.

   - Token-drifted value with a clear literal source in the demo → replace it with the
     demo's literal value on `basic`; on `tailwind`, re-express the corrected value as
     the Tailwind utility (or `@apply` rule) that produces it, sourced from the converted
     demo page.
   - Missing font → copy the woff2 file(s) into `theme/assets/fonts/` and re-emit the
     `@font-face` rule exactly as Step 4.5's font carry does it, including its branch:
     on `basic` into the enqueued stylesheet or fonts partial, on `tailwind` into
     `assets/css/src/tailwindcss/base/fonts.css` plus its `@import` in `main.css`, with
     no second enqueue. If the woff2 is not in the demo folder, Step 4.5's
     missing-source branch applies here too — no `@font-face` pointing at a file that
     does not exist; the finding goes to Review instead.
   - Missing logo/hero asset → seed it by its manifest `role` (`logo` / `hero`), same as
     `/wp-seed`'s role-tagged asset pass.
   - Colliding block (unscoped generic class) → rename/rescope it to its manifest-assigned
     unique `block` name.
   - Missing `background:url()` → on `basic`, transcribe it verbatim from the demo's
     recorded CSS (`section.backgrounds` in the manifest) into the theme CSS. On
     `tailwind`, take the background from the converted demo page and express it as a
     Tailwind utility (`bg-[url(...)]` and its companions) in the markup, or as an
     `@apply` rule when the ladder demands one — not as a raw declaration in a theme CSS
     file.
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
