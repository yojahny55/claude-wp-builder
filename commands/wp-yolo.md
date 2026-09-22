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

`demo/.original/` exists only if a conversion has run, so its presence is the signal:

```bash
bash -c "test -d demo/.original && ls demo/.original/*.html 2>/dev/null | head -1"
```

If it holds any page, stop:

```
Error: demo/ has already been converted to Tailwind (demo/.original/ holds <n> pristine pages).
Normalizing converted markup would empty the manifest's cssRules, fonts and backgrounds —
silently, and the build would still report success.

Restore the originals first, then run again:
  cp demo/.original/*.html demo/
Or run against a pristine copy of the demo folder.
```

**`--force` does not bypass this.** `--force` means "discard the built theme and rebuild",
and it is about the theme; it says nothing about the demo, and rebuilding from converted
markup produces exactly the degraded output above. The two flags answer different questions,
and the destructive one here is the quiet one. Restoring the originals is the only way past
this guard, because it is the only thing that makes the build correct.

This is the check Step 2.6 already performs, moved to where it can still act: 2.6's own
idempotence test ("Tailwind evidence and no plain-CSS evidence") runs *after* Step 2 has
dispatched normalize, which is why 2.6 can skip correctly and the run is degraded anyway.

On the plain path nothing converts, `demo/.original/` never exists, and this guard never
fires.

Then dispatch the **wp-normalize** agent against the demo folder from Step 1. It scans every
page, resolves shared header/footer, splits sections, classifies content types
(static-repeater vs custom-post-type), and writes:
- `demo/*.html` — canonical, delimited pages (the same `<!-- SECTION: X -->` format the
  existing builders consume)
- `demo/.yolo-manifest.json` — the orchestration source of truth (`pages[]`, `shared`,
  `contentTypes[]`, `review[]`)

**A demo this plugin generated is not re-analyzed.** `/wp-demo` writes
`demo/.demo-plan.json` recording the page roles, section names, kinds, CPTs and block names
it decided while authoring the pages; `wp-normalize` reads it and copies those verbatim
instead of re-deriving them, per page, wherever the plan still matches the markup. What the
agent still does on such a demo is the reading no one can do ahead of time — CSS
consolidation, field guesses, assets, `cssRules`, `fonts`, `backgrounds` — which is why it is
still dispatched rather than skipped: the manifest is its output, and nothing else writes
one. A demo from anywhere else, or one edited by hand since it was generated, is classified
the old way and says so in `review[]`.

Read `demo/.yolo-manifest.json` back once the agent completes.

**Demo mode.** If `.wp-create.json` already has `demo mode`, read it and move on;
do not re-derive it. Otherwise decide it here using the same craft-versus-plain
test as `/wp-demo` Step 2.5 (project docs, `.claude/CLAUDE.md`, `.wp-create.json`;
`--craft`/`--plain` in `$ARGUMENTS` override), state the one-line reason, and write
`"demo mode"` into `.wp-create.json`. When the mode is **craft**, read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/SKILL.md` and apply its order of work to
the whole multi-page build: the browser gate first, one `demo/DESIGN.md` for the
site, one composition plan covering every page, one evaluator loop over the
directory, and one fingerprint row for the site, not one per page.

**Research the client, here too, once for the site.** If `demo/RESEARCH.md`
already exists — a prior `/wp-demo` run against this project wrote it — read it
and move on. If `.wp-create.json` records `"research": "none"`, skip in one line
and do not retry. Otherwise, a craft `/wp-yolo` run never calls `/wp-demo`, so
it must research the client itself, in these same terms `/wp-demo` Step 2.4
uses on purpose — do not restate them a third way:
dispatch the `wp-research` agent, which reads
`${CLAUDE_PLUGIN_ROOT}/skills/wp-research/SKILL.md` for the method, the source
ladder and the fetch cap.

This run is unattended, so the agent **asks nothing**: it takes the top
candidate, records `confidence: "unconfirmed"` with the candidates it rejected,
and Step 6 states that the identity was unconfirmed. An unconfirmed identity
records no `research.site`, so `designlang` is never pointed at a guess.
Research never blocks this run: if every rung of the ladder fails, record
`"research": "none"` and carry on.

**Classify the domain, here too, once for the site.** If `.wp-create.json`
already has `"domain"` — a prior `/wp-demo` run against this same project
recorded it — read it and move on; do not re-classify. Otherwise, a craft
`/wp-yolo` run never calls `/wp-demo`, so it must classify the domain itself, in
these same terms `/wp-demo` Step 2.6 uses on purpose — do not restate them a
third way: match the
English-language material in **the client documents and `demo/RESEARCH.md`**
(sections `## What they actually say` and `## Competitors`) against the
keyword lists in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/domains/domains.csv`. A
domain is matched when **two distinct keywords** from its list appear in that
corpus; below that, report `unclassified` and carry on without constraining
anything. When more than one domain clears the threshold, the highest hit count
wins; on an exact tie for the top count, report both names and proceed
`unclassified` for the same reason. The lists are English-only: a corpus with
no English-language material is `unclassified` **with that reason stated**, and
the operator may name the domain directly instead of relying on the match.
Record the result once, for the site, not once per page, in `.wp-create.json`
under `"domain"` as `name`, `score`, `matched` and `confidence`, recording in
`matched` **which corpus produced each hit** — `docs` or `research`. The
threshold does not move: two distinct keywords are still required. A matched
domain's `page_pattern` and `considerations` fold into the brief as stated
constraints; it **never touches tokens**, which come from `demo/DESIGN.md` and
the client's own material, never from a category.

**The browser gate, here, before anything is built.** The gate is not `/wp-demo`'s
alone — a craft `/wp-yolo` run never calls `/wp-demo`, so it must run the probe
itself, in these same terms. Run
`node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" --probe`. On exit 2, run
`npm i -D playwright-core` in the project root and probe again (say first that this
writes a `package.json` and a `node_modules/` into the WordPress project root).
After the retry, **only exit 0 continues** — exit 2 means print what the probe said
is missing (`playwright-core` or Chrome; the fix is `WP_DEMO_CHROME` pointing at a Chrome or
Chromium already on the machine, never a browser download), and any other exit code (127 for a missing `node`, or a crash) means print it
verbatim. Either way **stop** the whole run there: do not normalize on, never fall back to plain,
and never build a craft demo blind. `--yolo` does not waive this. The
verify loop that follows is `/wp-demo-verify demo/` over the directory, at most
**three rounds**, reading the pass/fail table it writes to `demo/VERIFY.md` and
fixing every failed line before the next round; after three rounds with failures,
stop and write `demo/FAILED.md` — in the same shape `/wp-demo` Step 2.6 defines —
rather than converting a demo the rubric never passed. Open the loop with
`rm -f demo/FAILED.md`, exactly as `/wp-demo` Step 2.6 defines: the marker
describes this run and not a past one, and clearing it is the only thing that
lets a run which wrote the marker get back past this command's own Step 0 gate.
That loop is the gate this mode exists for, and it blocks — unlike Step 5's
`/wp-responsive-check`, whose findings are folded into the Step 6 review list. The
rules are stated here in the same terms `/wp-demo` Step 2.6 uses on purpose, because
the two entry points must gate identically — do not restate them a third way.

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
   evidence and no plain-CSS evidence behind. It does **not** by itself make a re-run safe:
   by the time this step ran again, Step 2 would already have re-dispatched `wp-normalize`
   and emptied the manifest's `cssRules`, `fonts` and `backgrounds`. **Step 2's guard** is what
   refuses such a run, applying the same evidence test to the whole demo before normalize is
   dispatched. The two tests are not redundant: the guard asks "has this demo
   been converted" and stops the run; this one asks "has *this page* been converted" and
   skips one page. See Step 3's abort branch.
2. **Back up, per page.** Otherwise create `demo/.original/` if it does not exist and
   copy `demo/<slug>.html` to `demo/.original/<slug>.html` — but **only if
   `demo/.original/<slug>.html` does not already exist**. If it does, it is already the
   pristine original from an earlier run; overwriting it with an already-converted page
   would destroy the only plain-CSS reference that exists.
3. **Convert in place, per page.** Run
   `/wp-tailwindify demo/<slug>.html --out demo/<slug>.html` — the output path is the
   demo page itself, so the converted markup lands on the same path the original
   occupied.

   **Convert a repeated card once, not once per copy.** `section.repetition` is an array
   with one entry per repeated list, so a section holding two lists carries two entries and
   **both** are handled — treating it as a single object collapses the first list and leaves
   every copy in the second to be converted one by one. For each entry, pass its `selector`,
   `exemplar` and `variants` through to `/wp-tailwindify` and tell it to convert the
   exemplar plus each variant, then apply that exemplar's resulting `class` attributes to
   its non-variant siblings position-for-position. **Only the `class` attribute is written.**
   Every other attribute and all text stay exactly as the demo had them — not just the
   obvious `href`, `src`, `alt` and `data-*`, but `id`, `aria-*`, `title`, `role` and
   anything else on the element; the list is illustrative, not a licence to drop what it
   omits. Each index listed in `variants[]` **keeps its own
   converted `class` attributes** — it was converted precisely because it differs, so
   stamping the exemplar's string over it would flatten away the difference that made it a
   variant. The remaining siblings are the same component with different content — that is
   what the entry asserts — so their utility strings are identical by construction and
   re-deriving each one from the same CSS is pure repetition of work.

   A variant never donates its classes either. `exemplar` is guaranteed not to appear in
   `variants[]`, so stamping is always from a plain copy; if a manifest violates that, treat
   the entry as unusable, convert the list in full and say so in the report.

   This matters more than it looks. A directory page drawing sixteen cards from four
   records, or a board page drawing eighteen from three, is the most expensive page in the
   demo *and* the one whose markup collapses hardest: in the theme all N become a single
   template part inside a loop, so the N-1 extra conversions are paid for and then thrown
   away. Skipping them does not reduce fidelity, because the copies were never independent.

   If the conversion of a sibling would differ from the exemplar's — a card that is
   genuinely wider, ordered differently, or hidden at a breakpoint — then it is a variant
   and the manifest should have listed it in `variants[]`. Do not apply the exemplar's
   classes to it: convert it in full and add a `review[]` note so the next run's
   classification is corrected rather than silently worked around.
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

Unless the literal `--yolo` flag is set, this step is a **hard stop**. Print the build
plan below, ask, and END YOUR TURN. Do not answer on the user's behalf, do not assume
approval, and do not start Step 4 in the same turn. The build resumes only after the
user replies.

Print the detected map from the manifest as a build plan:
```
Build plan for <demo-folder>
Pages to build:   <slug> (<role>) — <n> sections: <name:kind>, ...
CPTs to register: <name> (archive: yes/no, <n> seed items) | none
Content types:    <name>: <field list>
Shared header/footer: <ok | divergent on <slugs>>
Skipped:          <out-of-scope pages, missing-HTML pages> | none
Review:           <review[] items> | none
```
Cover, at minimum:
- Pages (slug, role: home / inner / cpt-archive / blog) and their sections (name, kind,
  confidence where < 1.0)
- Shared header/footer flags and any divergent pages
- Content-type classifications (`contentTypes[]`) with field lists
- **Scope annotations** (if `docs/.scope-manifest.json` was loaded): each page's
  `delivery` (theme/idx/plugin), out-of-scope pages skipped, and approved-but-missing-HTML
  pages awaiting a demo
- The full `review[]` list of low-confidence decisions

Ask the user to **approve / edit / abort** with AskUserQuestion, then stop and wait:
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

  **Step 2 now refuses rather than relying on this being remembered.** `demo/.original/`
  holding any page means a conversion has run, and Step 2 stops with the restore command
  before dispatching normalize — including under `--force`, which discards the theme and
  says nothing about the demo. The degradation was silent, and a workaround documented
  three steps away from the command that triggers it is a workaround nobody applies.

  **`--resume` is the only continuation entrypoint, and it is never `--yolo`.**
  `--yolo` suppresses this checkpoint and nothing else (Step 1: "no checkpoint at all"):
  Step 2 still dispatches `wp-normalize` and still overwrites `demo/.yolo-manifest.json`
  before Step 3 is ever reached, so re-running with it *is* the unconditional-normalize
  path described above and it regenerates the very manifest a resume would have to
  preserve.

  `--resume` is the one entrypoint that does not have this problem, because it does not
  run Step 2 at all — it enters at Step 4 with the manifest already on disk (Step 4.0).
  That is the whole mechanism rather than an optimisation: the steps it skips are
  precisely the ones that consume the demo in place. An abort *before* Step 4 has
  therefore built nothing, so a resume has no work to find and no ledger to read:
  restore the originals and start fresh, as above.

Under `--yolo`, skip this step and proceed straight to Phase 2 with the manifest as
emitted by `wp-normalize`.

## Step 4.0: The build ledger, and resuming an interrupted run

Phase 2 and the carries after it are thirty to fifty dispatches and the better part of
an hour. Every one of them writes a real file, and until this step existed an
interruption — a crash, a closed terminal, one failing dispatch — threw all of it away,
because the only way to run this command again was from Step 2, which regenerates the
manifest the build reads.

### The unit

One dispatch, one unit. Ids are recomputed from the manifest on every run rather than
stored as a list, so a manifest edit cannot leave the ledger describing units that no
longer exist:

```
settings                      cpt:<name>                header       footer
section:<page-slug>:<block>   page:<slug>               page:blog
page:404                      page:search               seed-cpt:<name>
promotion                     fonts                     behaviour
```

`<page-slug>` is `index` for the home page and the page's own slug for an inner page;
`<block>` is the unique BEM block Step 4 already assigns each section so parallel agents
cannot collide on a selector. `section:index:hero` is therefore stable across runs with
no counter to keep.

**A section is one unit, not three.** `/wp-section` dispatches three agents in parallel;
two of three finished is not a built section.

**There is no resume inside a unit.** An interrupted unit writes no ledger entry, so the
next run re-dispatches it and it overwrites its own half-written file. The granularity
is the recovery — there is no partial state to reconcile and nothing to roll back.

### What the ledger does not cover

Two kinds of step are deliberately absent, and adding them would each cause a defect.

- **Steps that are already idempotent.** `/wp-seed` re-enters correctly by itself: it
  owns records by marker and fields by digest, and reports a client's edit rather than
  reverting it. A resume simply runs it. A ledger entry here would be a second source of
  truth for a question the command already answers, and a stale one skips a seed the
  demo needs.
- **Steps that measure.** The Tailwind rebuild, `/wp-finalize`, `/wp-polish`,
  `/wp-responsive-check` and the Step 5.5 parity gate all read the **live site**.
  Skipping one because an earlier run performed it would report a gate result for a
  build that no longer exists — a signed-off deliverable nobody measured. These always
  run, on a resume exactly as on a fresh build.

Stated once: **the ledger covers work that generates, never work that verifies.**

### The ledger file

`demo/.yolo-progress.json`, beside the manifest — not in `.wp-create.json`, which is
configuration every command parses on every run, where this is transient build state
that dies with the demo folder.

```json
{
  "version": 2,
  "started": "2026-09-18T14:02:11Z",
  "completed": null,
  "plugin_version": "1.24.0",
  "inputs": {
    "manifest": "<sha256 of demo/.yolo-manifest.json>",
    "pages": { "index": "<sha256>", "about": "<sha256>" }
  },
  "units": [
    { "id": "section:index:hero",
      "at": "2026-09-18T14:09:40Z",
      "artifact": "template-parts/section-hero.php",
      "output": "<sha256 of that file as written>" }
  ]
}
```

Three of those fields are new in `version: 2`, and each closes a question the old ledger
could not answer.

**`output`** is the digest of the artifact as this command wrote it. Resume used to skip a
unit when its file existed and was non-empty, which cannot tell *our* output from anyone
else's: a half-written template part that a crashed agent left syntactically valid is
non-empty, and so is a file a developer edited by hand between runs. With a digest, three
states are distinguishable where there used to be two — matches (ours, skip it), differs
(someone else's work, see below), absent (never built).

**`plugin_version`** is this plugin's version, not the ledger format's — `version` already
covers the format, and the two were conflated. A resume across a plugin upgrade is a
resume whose remaining units will be built by different instructions than the finished
ones, which is worth saying out loud rather than discovering in the diff.

**`completed`** replaces deleting the file. The old rule was to delete the ledger on
success, and its reason was sound: a leftover ledger is a `--resume` aimed at a site that
needs nothing. But deleting it also destroys the only record of what this build produced,
which is the record any later update has to start from. Setting `completed` keeps the
record and keeps the protection — `--resume` on a ledger with a `completed` timestamp
refuses, and says the build finished and when:

```
Error: this build completed at 2026-09-18T15:40:02Z — there is nothing to resume.
Run /wp-yolo --force to rebuild from the demo.
```

A `--force` rebuild still deletes the ledger before Step 2, unchanged: the inputs it
digested are about to be regenerated and every digest in it is about to become a lie.

### A generated file someone else changed

With `output` recorded, a resume can see that an artifact on disk is not the one it wrote.
It must not silently replace it, and it must not silently keep it:

```
demo/.yolo-progress.json records section:index:hero as
  template-parts/section-hero.php  sha256 9f2c…
but that file now digests to  4ab1…

Someone edited it after this build wrote it. Rebuilding replaces those edits.
  Keep the edits:    /wp-yolo --resume --skip section:index:hero
  Discard and build: /wp-yolo --resume --rebuild section:index:hero
```

Report every such unit before building any of them, so the operator sees the whole list
and makes one decision rather than being interrupted per file.

Create it at the top of Step 4 on **every** run, not only under `--resume` — a run that
is never interrupted still writes one, and that is what makes the next one resumable.
`inputs` is digested once, here, before the first dispatch:

```bash
sha256sum demo/.yolo-manifest.json demo/index.html demo/<slug>.html
```

Append one entry the moment a unit returns, with `jq` — never in a batch at the end of a
phase, which loses exactly the units a crash interrupted:

```bash
ART="template-parts/section-hero.php"
jq --arg id "section:index:hero" --arg at "$(date -u +%FT%TZ)" \
   --arg art "$ART" \
   --arg out "$(sha256sum "$ART" 2>/dev/null | cut -d' ' -f1)" \
   '.units += [{id: $id, at: $at, artifact: $art, output: $out}]' \
   demo/.yolo-progress.json > demo/.yolo-progress.json.tmp \
   && mv demo/.yolo-progress.json.tmp demo/.yolo-progress.json
```

Digest the file at the moment the unit returns, not later: anything that runs in between
can touch it, and a digest taken afterwards would record that state as ours.

`artifact` is theme-relative, and is `null` for a unit that writes no single file
(`settings`). Write it through a temp file and `mv`: a crash during the write of a
ledger is the one crash that must not also destroy the record of everything before it.

**Stamp `completed` on a successful completion**, in the same place Step 6 appends the
`## Workflow — DONE, do not re-run` note:

```bash
jq --arg at "$(date -u +%FT%TZ)" '.completed = $at' \
   demo/.yolo-progress.json > demo/.yolo-progress.json.tmp \
   && mv demo/.yolo-progress.json.tmp demo/.yolo-progress.json
```

and **delete it before Step 2 on a `--force` rebuild**, where the inputs it digested are
about to be regenerated and every digest in it is about to become a lie.

### Entering with `--resume`

`--resume` enters **here**, at Step 4. It has not run Steps 2, 2.5, 2.6 or 3, and must
not: those are the steps that convert `demo/*.html` in place and rewrite the manifest.

**Refuse when there is no ledger:**

```
Error: no demo/.yolo-progress.json — there is no interrupted run to resume.
Run /wp-yolo without --resume to build from the demo.
```

`--resume` with nothing to resume is a typo, not a request for a fresh build. Silently
converting one into the other is how a resume flag overwrites a finished site.

**Then check for drift.** Re-digest `demo/.yolo-manifest.json` and every page named in
`inputs.pages`, and compare against the stored digests. Unchanged → continue. Changed,
or a recorded page now missing → stop, naming the file, what it feeds, and how far the
previous run got:

```
Error: demo/.yolo-manifest.json changed since the interrupted run.
It feeds every section build. 4 of 11 units completed against the previous version.
  Rebuild from scratch: restore demo/.original/*.html, then /wp-yolo --force
  Continue anyway:      /wp-yolo --resume --accept-drift
```

Without those three facts the message is one an operator cannot act on. Resuming across
a changed input builds half a theme from one manifest and half from another, and nothing
downstream fails — the parity gate measures the built site against the demo it can see
now, so the half built from the old manifest is simply wrong and green.

`--accept-drift` proceeds anyway, and exists because the edit is often deliberate: the
manifest was fixed to correct whatever broke the run. It is its own flag and is **not**
implied by `--force`, the same way `--force-fields` is not implied by `--force` in
`/wp-seed`. A run that accepts drift re-digests `inputs` and says so in the Step 6
report.

### Verify before skipping

Walk the units in the Step 4 order below. For each:

- **no ledger entry** → dispatch it.
- **entry, `artifact` non-null, file present and non-empty** → skip it, and count it as
  resumed in the report.
- **entry, `artifact` non-null, file missing or empty** → **it is not done.** Dispatch
  it, and list it in the Step 6 report as rebuilt-because-missing. A ledger can outlive
  the files it describes — someone deleted a template part, or a theme directory was
  restored from elsewhere — and trusting it here leaves a hole the build reports as
  filled.
- **entry, `artifact` null** → skip on the ledger alone (`settings` only).

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

The reason is the ladder's own criterion. `skills/wp-tailwind-system/SKILL.md` promotes a
utility group to an `@apply` class when it appears "3+ times, or on 2+ distinct pages" —
a judgment about the theme as a whole, which no agent looking at one section can make.
Run per section, `wp-tailwind` in author mode is told to grep what earlier sections
already wrote, and that turns the promotion into a function of dispatch order: the first
section runs with nothing to grep and ships raw utilities; by the time the fourteenth
sighting of a group crosses the threshold, the thirteen template parts that also carry it
have been written and are never revisited. The result is the same group living as a
semantic class in the sections built late and as raw utilities in the ones built early —
worse than either extreme, because the `@apply` file now exists without covering the
repetition it was created for. The cost sits on top: one serialized agent per section,
each re-reading a template part `wp-template` has just written and each appending to the
same `main.css`.

So dispatch `wp-tailwind` in **author** mode exactly once, over every
`template-parts/section-*.php` the walk produced, with:

- the full list of template parts, and the pages each belongs to (a group on two parts
  that both render on one page has NOT crossed the 2-page test — the ladder counts
  distinct pages, not files)
- the same file-layout rules it follows per section: `utilities/site.css` for a group
  that spans pages, `components/<page-slug>.css` for one local to a page, `@import`
  registered in `main.css` in the same step, never an empty file
- the standing prohibition: it edits **class names only**. Every `prefix_get_field()`
  call, every `esc_*()` wrapper, every `?:` fallback and every PHP control structure in
  those files belongs to `wp-template` and is left exactly as found.

Hand-invoked `/wp-section` keeps promoting inline, and should: a single section added to
a finished theme has the whole theme to grep and nothing to aggregate. `--defer-promotion`
exists for the walk, where the theme does not exist yet.

## Step 4.5: Font carry

Before seeding, collect every `section.fonts[]` entry across the manifest (dedupe by
`family`+`weight`+`style`):

**An empty collection is checked, not believed.** `fonts: []` on every section means one
of two things, and they are not the same: a demo that genuinely uses a system stack, or a
manifest that missed what the demo loads. Grep the demo pages before concluding the first:

```bash
bash -c "grep -l 'fonts.googleapis.com\|@font-face' demo/*.html | head"
```

A hit means the manifest is wrong. Carry the families from the markup — the `css2` URL
names them and their weights — exactly as the recipe below does, and add one Review entry
naming the gap, because the next command to read that manifest will be misled the same way.
A build shipped a theme naming `"Inter", system-ui` over a demo rendering Archivo and
Source Sans 3, with an empty `assets/fonts/`, and nothing in the run said so: every step
after this one is conditioned on a non-empty list, so an empty one is not a warning, it is
silence.

- Copy each entry's `src` woff2 file(s) from the demo folder into `theme/assets/fonts/`.
  **When the file is not there.** Demos ship broken font paths as a matter of course —
  the rehearsal demo declares `src: url("assets/fonts/marcellus.woff2")` and carries no
  such file. Search the demo folder for the basename first (any subdirectory, matched
  case-insensitively). If it is genuinely absent, do **not** re-emit a `@font-face`
  whose `src` points at a file the theme does not have: that rule fails silently, and
  under `font-display: swap` the page renders the fallback stack with nothing logged
  anywhere to say why. Skip that family's `@font-face` rule entirely, drop the family
  name from the head of its font token so the theme stops naming a font it does not
  have, and add `font <family>: <src> not found in the demo folder — supply the woff2
  or the token keeps its fallback` to the Step 6 Review list. Keeping the name changes
  nothing at render time (a family with no face and no local install never rendered
  anyway) and leaves a token `/wp-finalize`'s font-parity check fails on: it passes a
  family with a face, or an intentional fallback stack, and nothing in between.
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
- **Never emit a `fonts.googleapis.com` request, preconnect included.** The theme self-hosts
  every family it names — a Google Fonts `<link>` in the demo is carried by downloading its
  woff2 into `assets/fonts/`, not by copying the link across. `/wp-init` Step 4.5 states that
  recipe (including the user-agent trap that silently yields TTF instead of woff2) and runs
  before this command; a preconnect to a host the theme never calls is a dead hint, which is
  what the starter used to ship. `section.fonts[]` families are self-hosted from the demo
  folder as above — self-hosted stays self-hosted, and linked fonts become self-hosted too.

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

**A script is not the only thing that can be missing.** `demo/.demo-plan.json`'s
`inert[]` is the demo's own list of controls it faked — a language switcher that is two
`href="#"` links, a search box that filters nothing — each with the `needs` line saying
what wiring it takes here. Read it as a worklist: every entry is either built in this
step (or by the chrome build, for a `pages: ["*"]` entry) or carried into the Step 6
Review list by name. It exists because a faked control has no script to enumerate, so
the walk above cannot see it: on one build the switcher was wired only because a
normalize agent happened to file it among forty-eight `review[]` entries, which is luck
and does not scale to the next demo whose fake control sits further down the page.

Verify in a real browser before Step 5, one page per behaviour: click a
carousel arrow, open a listbox, open the filter drawer, open the gallery, and **use
every `inert[]` entry** — a switcher that still goes nowhere is the one defect in this
step that renders perfectly. A console with zero errors is not evidence — dead code
logs nothing.

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
