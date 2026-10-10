---
description: Full-site builder — convert a complete multi-page HTML demo folder into a WordPress theme in one pass
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "<demo-folder> [--yolo] [--careful]"
---

# WP YOLO — Full-Site Demo → WordPress Theme

Convert a complete multi-page HTML demo into a working theme in one orchestrated pass,
reusing the plugin's existing build pipeline end to end. Run this AFTER `/wp-create` +
`/wp-init` have scaffolded the project. This command does not reimplement any builder —
it dispatches the `wp-normalize` agent once, then drives the existing commands/agents in
dependency order.

`/wp-yolo` **never generates images.** It takes an existing demo folder and
never calls `/wp-demo`, so plates already in `demo/assets/img/` travel into the
theme like any other demo asset. Generation is `/wp-demo`'s alone, because it is
the command with a human present to approve the spend.

## Step 1: Parse Arguments & Gate

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Parse `$ARGUMENTS`:
- **First non-flag word** = path to the demo folder (required). Error and exit if missing,
  or if the path is not a directory:
  ```
  Error: A demo folder is required.
  Usage: /wp-yolo <path-to-demo-folder> [--yolo] [--careful] [--force]
         /wp-yolo <path-to-demo-folder> --resume [--accept-drift]
  ```
- **`--yolo`** = no checkpoint at all (ingest → build → seed → finalize → report, hands-off).
- **`--careful`** = checkpoint after normalization AND a per-page confirm before each inner
  page's build in Phase 2.
- **default** (neither flag) = a single checkpoint after normalization (Step 3), then
  hands-off from Step 4 onward.
- **`--resume`** = continue an interrupted run. Skips Steps 2, 2.5, 2.6 and 3 entirely
  and enters at Step 4, reading `demo/.yolo-manifest.json` from disk. See
  *Step 4.0: Resuming an interrupted run*. Requires `demo/.yolo-progress.json`.
- **`--accept-drift`** = with `--resume` only, continue even though a build input
  changed since the interrupted run. Never implied by `--force`.

The command is named `/wp-yolo`; that name is NOT the `--yolo` flag. A bare
`/wp-yolo <folder>` with no flags runs the Step 3 checkpoint and waits for the
user. Only the literal `--yolo` token in `$ARGUMENTS` skips it.

**Stop if `demo/FAILED.md` exists.** Print its first ten lines and stop. Building
a theme from a demo that never passed verification produces a verified-looking
site on an unverified foundation, and every later audit measures the theme rather
than the demo it came from. The marker is cleared only by a craft verify loop
starting over (`/wp-demo iterate`, or a fresh craft run), which deletes it at its
top — so it always describes the last loop. Do not delete it by hand to get past
this gate.

Read `.claude/CLAUDE.md` at the project root. If it does not exist, refuse:
```
Error: No .claude/CLAUDE.md found. Run /wp-init first to scaffold the project.
```

**Then refuse to run twice.** A second *build* restarts at Step 2, re-dispatches
`wp-normalize`, overwrites `demo/.yolo-manifest.json` and rebuilds the theme over
whatever has been hand-corrected since. If the theme directory already holds built
section template parts, or `.claude/CLAUDE.md` records a completed run, stop:

```
Error: <theme> already contains a built section flow (<n> template parts).
/wp-yolo rebuilds from the demo and would overwrite work done since the first run.
Use the per-step commands instead: /wp-section, /wp-page, /wp-seed, /wp-finalize.
Pass --force only to deliberately discard the current build.
```

Accept `--force` to override, and on a successful run append a
`## Workflow — DONE, do not re-run` note to `.claude/CLAUDE.md` recording the
date and which steps completed.

**`--resume` bypasses this gate, and only this gate.** Built template parts are
exactly the state a resume exists for, so the condition that stops a rebuild is the
condition a continuation expects. What `--resume` does not bypass is any other
refusal in this step — `demo/FAILED.md`, a missing `.claude/CLAUDE.md`, an invalid
manifest, a `cinematic` template — because none of those describe an interrupted
run. Delete the ledger before a `--force` rebuild (Step 4.0 says where).
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

## Model routing

Every agent this command reaches — directly or through the commands it drives — declares
its own `model:` in its frontmatter (`agents/*.md`), so dispatch cost is routed per task
without any flag on this command:

- **opus** — planning/analysis whose output steers the whole build: `wp-normalize`, `wp-context`.
- **sonnet** — code authoring and judgment audits: `wp-template`, `wp-css`, `wp-tailwind`,
  `wp-cinematic`, `wp-audit-a11y|performance|practices|security|seo`.
- **haiku** — mechanical generation and WP-CLI config: `wp-acf`, `wp-cf7`,
  `wp-audit-aios`, `wp-audit-rankmath`.

When dispatching an agent with the Agent tool, do **not** pass a `model` parameter — a
per-invocation override beats frontmatter (resolution order: env var >
per-invocation param > frontmatter > main model), and passing one silently defeats this
routing. The orchestration itself (manifest reasoning, checkpoint edits, gate decisions)
stays on the main conversation model.

## Step 2: Phase 1 — Normalize

**First, refuse to normalize a demo that has already been converted.** `wp-normalize`
derives `cssRules`, `fonts` and `backgrounds` from the declarations and `@font-face` rules
in the demo's markup. Step 2.6's Tailwind conversion removes both — it strips the `<style>`
blocks and the project stylesheet `<link>` whose rules it absorbed — so running normalize
over an already-converted page derives those three keys from markup that no longer contains
them, and writes an emptied manifest. **Nothing fails.** Step 2.6 then correctly detects the
pages as already Tailwind-native and skips them, while Step 4.5's font carry and
`/wp-finalize`'s Layer 1 parity gate read the gutted manifest and pass over nothing. The
build completes, reports success, and ships a theme with no carried fonts and no background
parity.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/normalize.md` now and follow it — it is this step, not background. It covers the `demo/.original/` refusal, the `wp-normalize` dispatch and the manifest it writes, demo mode, client research, domain classification, and the browser gate.

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

Skip it entirely when `demo mode` is **craft**, too, and say so in one line. A craft
demo is built from `skills/wp-demo-craft/compositions/`, whose CSS is already
authored against the token vocabulary `/wp-init` writes into the theme, so
converting it to utilities discards that seam rather than crossing it: `wp-tailwind`
maps colours to the nearest utility class, which replaces every `var(--color-ink)`
reference with a hardcoded class. The detection below cannot reach this decision on
its own — a craft demo carries a `:root` and BEM classes and so is plain-CSS evidence
by every test in it — which is why the stop is here, before the walk. `/wp-init`
Step D4 makes the same exception in the same terms; do not restate it a third way.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/demo-conversion.md` now and follow it — it is this step, not background. It covers the in-place conversion and its backup, the per-page detection, converting a repeated card once, failure handling, and the `--careful` confirmation.

## Step 3: Checkpoint (skipped under --yolo)

Unless the literal `--yolo` flag is set, this step is a **hard stop**. Print the build
plan below, ask, and END YOUR TURN. Do not answer on the user's behalf, do not assume
approval, and do not start Step 4 in the same turn. The build resumes only after the
user replies.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/checkpoint.md` now and follow it — it is this step, not background. It covers the build plan to print, the approve / edit / abort question, what a later run after an abort must do, and why `--resume` is the only continuation.

## Step 4.0: The build ledger, and resuming an interrupted run

Phase 2 and the carries after it are thirty to fifty dispatches and the better part of
an hour. Every one of them writes a real file, and until this step existed an
interruption — a crash, a closed terminal, one failing dispatch — threw all of it away,
because the only way to run this command again was from Step 2, which regenerates the
manifest the build reads.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/build-ledger.md` now and follow it — it is this step, not background. It covers the unit, what the ledger does not cover, the ledger file, a generated file someone else changed, entering with `--resume`, and verifying before skipping.

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
   - `kind: "static"` → `/wp-section <name> --transcribe --block <block> --css <css-source> --defer-promotion`
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
       not pass it. The converted page is the source of truth on this path exactly as
       `cssRules` is on `basic` — its utility classes ARE its declared values, and the
       overlay's mandate is to carry them across character for character, never to
       substitute a utility judged equivalent.

     Because every section's `block` is already unique, parallel agents can never collide
     on a selector.
   - `kind: "cpt-teaser"` → **SKIP** — do NOT dispatch `/wp-section` for these. The CPT's
     teaser `template-parts/section-<cpt>.php` was already built and injected into
     `front-page.php` by that CPT's `/wp-cpt` run in step 2. Note it in the report as
     "teaser for `<cpt>`, built by /wp-cpt".
   - `kind: "contact"` → `/wp-section <name> --cf7 --transcribe --block <block> --css <css-source> --defer-promotion`,
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
   - `kind: "static"` → `/wp-section <name> --page <slug> --target page-<slug>.php --transcribe --block <block> --css <css-source> --defer-promotion`,
     passing the section's unique `block` via the transcribe flags and resolving
     `<css-source>` by `Template:` exactly as in step 5: on `basic`, the manifest's
     verbatim `cssRules`; on `tailwind`, this page's converted demo file
     `demo/<slug>.html` (converted in place by Step 2.6), never the stale manifest
     `cssRules` and never the backup at `demo/.original/<slug>.html`.
   - `kind: "contact"` → `/wp-section <name> --cf7 --page <slug> --target page-<slug>.php --transcribe --block <block> --css <css-source> --defer-promotion`,
     same transcribe dispatch.
   - `kind: "cpt-teaser"` on an inner page → same skip rule as step 5 (owned by `/wp-cpt`).

   > **Template routing.** Do not pass a template flag — `/wp-section` takes no such
   > argument and inventing one would do nothing. `/wp-section` reads `Template:` from
   > `.claude/CLAUDE.md` itself. What the template changes is which agent it dispatches
   > and what you pass as `--css`: when `Template:` is `tailwind`, `/wp-section`
   > dispatches `wp-tailwind` in author mode instead of `wp-css` (see its "CSS agent
   > routing" table), and `--css` is the Step 2.6-converted demo page rather than the
   > manifest's `cssRules`. When it is `basic` nothing changes.

   > **Pass the section's line range, never the whole page.** Every dispatch above hands
   > over a page path, and an agent given a path reads the file — a craft page is ~4,000
   > lines of which perhaps 7 to 34 are the section, because the build inlines about 3,360
   > lines of CSS ahead of the body. Three of four template agents on one build died with
   > "Prompt is too long", one at the words *"Now I have everything needed."* — the run
   > spent its whole context finding the markup and had none left to write with. The
   > manifest already knows where each section begins and ends, so put the range in the
   > dispatch (`sed -n '<start>,<end>p' demo/<slug>.html`) and say that is the section. On
   > the `tailwind` path the agent has no reason to read the `<style>` block at all:
   > `cssRules` is null there by contract and the classes come from the converted page. A
   > re-dispatch carrying the range rescued all three of those agents, first time.

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

## Step 4.4: One `@apply` promotion pass (tailwind template only)

Skip this step entirely when `template == basic`, and skip it when the walk produced no
`template-parts/section-*.php` files — an author-mode agent handed an empty file list has
nothing to promote and reports as though it did.

Pass **`--defer-promotion`** on every `/wp-section` dispatch in items 5, 6 and 9 above,
then run the promotion once here, after the whole section walk has finished.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/apply-promotion.md` now and follow it — it is this step, not background. It covers why promotion runs once after the walk, and the single author-mode `wp-tailwind` dispatch that does it.

## Step 4.5: Font carry

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/font-carry.md` now and follow it — it is this step, not background. It covers collecting `section.fonts[]`, checking an empty collection against the demo pages, and self-hosting each family in the theme.

## Step 4.6: Behaviour carry — port ALL of the demo's JavaScript

The chrome build ports the header and drawer scripts. **Everything else the demo
does is still sitting in the demo folder**, and nothing later in this command
notices: the parity gate measures geometry at rest, so a theme whose carousels,
lightbox, listboxes, filter drawer and accordions are all dead passes it
66/66. One project shipped exactly that and only found out from a manual
browser pass.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/behaviour-carry.md` now and follow it — it is this step, not background. It covers enumerating the demo's scripts, accounting for every one, behaviours `demo/.demo-plan.json` names, and the browser check before Step 5.

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
3. **Rebuild Tailwind CSS** — `bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>`.
   On `tailwind` the theme enqueues only the compiled `assets/css/dist/main.css`, last
   built by `/wp-init` before any section existed. Every step below — and the parity
   gate in Step 5.5 — looks at the live site, so without this they would judge an
   unstyled page. No-op on `basic`; skipped when a `tailwindwatch` process already
   owns `dist/`.
4. **`/wp-finalize`** — MANDATORY. Run the command exactly as a user would (read
   `${CLAUDE_PLUGIN_ROOT}/commands/wp-finalize.md` and execute every step in this same
   run). It runs the 3-layer demo-parity gate (Layers 1-3) that signs off delivery;
   Step 5.5 consumes its findings. Without it there is no gate result and no delivery.
5. **`/wp-polish`** — MANDATORY. Same dispatch. Cleans the seeded site and theme
   (menus, placeholders, leftovers) after seeding, so it runs after item 1, never before.
6. **`/wp-responsive-check`** — MANDATORY. Same dispatch; it forwards to
   `/wp-demo-verify` against the built site. Fold every **blocking** finding it reports
   into Step 6. Findings printed `[advisory]` (rows flagged `"advisory": true` in
   `findings.json`) are what the harness could not read, not what the page got wrong —
   list them under Review, do not "fix" them.
7. **`/wp-audit --all --geo --security-level recommended`** — MANDATORY. Same dispatch.
   This is the only step that measures SEO, Core Web Vitals/performance, accessibility,
   security, coding standards and GEO/agent-readiness; nothing earlier does. Its Step 9
   fix prompt is pre-answered **yes** in a `/wp-yolo` run — do not stop to ask. Fold
   every finding it leaves unfixed into Step 6's Review list.
   If its fixes touched theme CSS, templates or enqueues, re-run `/wp-finalize`'s
   Layers 2-3 before Step 5.5 signs off — a perf or SEO fix can break demo parity.
8. **`bash "${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh" <home-host>`** — MANDATORY. Records
   the finish-phase agent-readiness result for the live site and re-scans once after any
   fix; item 7's `/wp-audit --geo` runs the same `bin/geo-scan.sh` as part of the audit
   pass, so this step is the finish-phase result, not a different check. `<home-host>` is
   `wordpress.url` from `.wp-create.json`, falling back to `$WP option get home`.
   - **exit 0** — a report came back: fold every **failed** check into a fix pass (the
     `wp-agentic-surfaces` loop item 7 uses), then re-run the scan **once** and record
     the before/after score in Step 6. If that fix touched theme CSS, templates or
     enqueues, re-run `/wp-finalize`'s Layers 2-3 before Step 5.5 signs off.
   - **exit 2** — no report exists yet, or no network: record it `UNMEASURED` and mark the
     run incomplete in Step 6, exactly as the completion rule requires below. An absent
     score is not a good score.
     Do not add `--start` here: it makes is-agentic fetch the host, and an unattended
     run has no operator to confirm the host is meant to be public. `/wp-audit --geo
     --host <public-url>` passes it once the operator has.
   - **exit 3** — `wordpress.url` is not publicly reachable, so the site cannot be scanned
     at that address at all. Record it `UNMEASURED — configuration` and mark the run
     incomplete. This is not the same as exit 2 and must not be reported as one: it has a
     fix, which is to re-run the scan against the public URL
     (`/wp-audit --geo --host <public-url>`). A build served from a `.local` host reaches
     this every time, and reporting it as an ordinary skip is what let a whole category
     stay unmeasured on project after project without anyone noticing.
   - **exit 1** — the scan errored: report the error and mark the run incomplete.

**Completion rule.** Items 4 through 8 are part of the build, not follow-ups for the
user. A run that reaches Step 6 without having executed all five is **incomplete**:
never print "site works" or hand the user a list of commands to run next. If one of
them cannot run (site unreachable, tool missing, scan skipped), say which, why, and mark
the run incomplete in the Step 6 report. This holds under `--yolo` as well.

## Step 5.5: Demo-parity gate — auto-fix, re-verify, and block

`/wp-finalize` (Step 5, item 4 above) already ran the 3-layer demo-parity gate (Layers 1-3); if `/wp-audit` fixes required a re-run, treat the latest Layers 2-3 findings as the gate result.
Before this run can report success, walk every **critical** finding from that gate:

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/parity-gate.md` now and follow it — it is this step, not background. It covers auto-fixing mechanical findings per template, re-verifying, and blocking on what remains.

## Step 6: Report

If any critical demo-parity finding survived Step 5.5's auto-fix + re-verify, or the
GEO scan in Step 5 item 8 did not succeed (unmeasured on exit 2 or 3, errored on exit 1), or
any of Step 5 items 4-8 did not run, do NOT print "Build Complete." Print instead,
before anything else:
```
=== WP YOLO Build INCOMPLETE — deliverable not signed off ===

Review (blocking):
  - <every unresolved critical finding — layer, selector/property/file, demo value vs. built value>
  - <GEO scan unmeasured (exit 2), not publicly reachable (exit 3 — re-run with --host), or errored (exit 1)>
  - <any of Step 5 items 4-8 that did not run, and why>

Run /wp-finalize again after resolving the above, then re-run this gate.
```
This applies under `--yolo` too — `--yolo` skips the Step 3 checkpoint, not this gate.
A run whose GEO scan did not succeed cannot print "Build Complete".

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
  - <GEO findings left unfixed — advisory, off-site (no theme file can change it)>
  - <anything skipped — e.g. JS-only interactivity not reproducible in static templates>
  - <out-of-scope pages skipped: "in demo but out of scope — skipped">
  - <approved-but-missing-HTML pages: "approved/designed but no HTML — needs demo">
  - <research identity: confirmed or unconfirmed, with the name>
```

**On a resumed run**, add a Resume block above Review, and delete
`demo/.yolo-progress.json` once the summary is printed (Step 4.0):
```
Resumed:
  Skipped (already built):     <count> units
  Rebuilt (artifact missing):  <unit id list — the ledger claimed these, the files were gone>
  Built this run:              <count> units
  Drift accepted:              <file list, only when --accept-drift was passed>
```
The rebuilt-because-missing list is never folded into the built count. It is the one
signal that the ledger and the theme directory had diverged, and a reader who cannot
see it cannot know which parts of the site this run actually looked at.

Note for the user: `--yolo` is best used **after** one checkpointed dry-run of the same
demo folder, once the manifest has been reviewed and edited at least once.
