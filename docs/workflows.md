# Workflows

How to get from "nothing" to a working WordPress theme, on each of the three paths the
plugin supports. Every path shares the same setup, the same demo stage and the same
finishing commands; only the middle differs.

**The demo is the input to all three paths, not a step inside one of them.** `/wp-init`
reads it to learn the project, `/wp-yolo` converts it page by page, `/wp-section
--transcribe` copies its declared values into CSS, and `/wp-seed` turns its files into WP
Pages. Nothing downstream invents design: it transcribes what the demo already decided, so
there is no path that begins at WordPress.

```
SETUP           /wp-create (optional)  →  /wp-init  →  /wp-context (optional)
                                              │
DEMO       ┌──────────────────────────────────┴──────────────────────────────┐
required   │ have a mockup    →  /wp-init path/to/mockup.html (reads it, skips the interview)
           │ files in demo/   →  /wp-polish demo/index.html
           │ nothing yet      →  /wp-init, then /wp-demo  |  /wp-cinematic-demo
           └──────────────────────────────────┬──────────────────────────────┘
                                              │
BUILD      ┌──────────────────────────────────┼──────────────────────────────┐
           │ A. Full demo folder              │ B. Step by step              │ C. Cinematic
           │    /wp-yolo <demo folder>        │    /wp-header /wp-footer     │    /wp-cinematic-*
           │    (runs everything below)       │    /wp-section … /wp-page …  │    see cinematic-mode.md
           │                                  │    /wp-seed                  │
           └──────────────────────────────────┴──────────────────────────────┘
FINISH          /wp-finalize  →  /wp-demo-verify  →  /wp-audit (optional)
```

Legend used below: **required** = the path does not work without it · **optional** =
adds something but can be skipped · **auto** = another command runs it for you; run it by
hand only to re-run or override.

---

## Setup (all paths)

### 1. `/wp-create` — local WordPress environment — *optional*

```
/wp-create --path=/var/www/html/my-project
```

Detects Docker / DDEV / Lando / wp-env / native Nginx-Apache-Caddy, downloads WordPress,
creates the database and vhost, installs a plugin profile, and writes `.wp-create.json`.

Skip it if you already have a WordPress install (it can adopt an existing one, too). Without
`.wp-create.json`, `/wp-seed` and `/wp-debug` fall back to a bare `wp` on PATH run from the
WordPress root, taking languages from `.claude/CLAUDE.md`; Docker/DDEV/Lando wrappers only
work through the manifest.

### 2. `/wp-init` — scaffold the theme — *required*

```
/wp-init                     # interactive
/wp-init path/to/mockup.html # demo-first: copies the file to demo/index.html and infers name/slug/sections from it
```

Run from the project root (the folder that will hold `wp-content/`). It asks three questions
whose answers are **recorded in `.claude/CLAUDE.md` and never re-asked** — every later command
reads them from there:

| Question | Options | Default | What it locks in |
|----------|---------|---------|------------------|
| Starter template | `tailwind` · `cinematic` | `tailwind` | Which `starter-theme/` is copied. `cinematic` hands off to `/wp-cinematic-init` (path C). A legacy `basic` answer is treated as `tailwind`. |
| Custom-fields plugin | `scf` · `acf` | `scf` | Which plugin `wp-acf` targets and which is installed. |
| i18n strategy | `suffix` · `polylang` | `suffix` | `suffix` = one page, fields duplicated as `hero_title_es`. `polylang` = one page per language. Changes how `wp-acf`, `/wp-header`, `/wp-seed` and `/wp-yolo` behave. See [Two i18n systems](#two-i18n-systems). |

Then it asks project name, slug, languages and industry (or infers them from the demo),
copies the starter theme, replaces `__starter__` placeholders, writes `.claude/CLAUDE.md`,
and — when `.wp-create.json` exists — activates the theme via WP-CLI.

**Seeing the site while you build (tailwind template).** The theme enqueues only the
compiled `assets/css/dist/main.css`. Every builder (`/wp-section`, `/wp-header`, `/wp-footer`,
`/wp-page`, `/wp-cpt`, `/wp-yolo`) recompiles it once when it finishes, so a reload shows the
result. For a live view instead, open a second terminal and keep this running:

```
cd wp-content/themes/<slug> && npm run preview
```

That is Tailwind `--watch` + `wp-scripts start` + BrowserSync proxying your site at
`http://localhost:3000`; every PHP/CSS/JS write reloads the browser, and the builders detect
the watcher and skip their own rebuild.

Things `/wp-init` does **for you** (auto):
- runs `/wp-polish` on the demo if it has no `<!-- SECTION: -->` delimiters;
- runs `/wp-context` if a `docs/` folder exists in the project root.

Non-interactive flags for scripts: `--template=tailwind|cinematic`, `--i18n=suffix|polylang`.

### 3. `/wp-context` — read the client's documents — *optional; auto when `docs/` exists*

```
/wp-context               # reads ./docs
/wp-context path/to/docs
```

Put anything the client sent into `docs/`: scope spreadsheets (`.xlsx`/`.ods`), the design
PDF, estimate/scope markdown, emails, link lists. It writes:

1. a `## Project Constraints` block into `.claude/CLAUDE.md` (integrations, forms, SEO,
   hosting, responsive notes) that every later command treats as guidance;
2. `docs/.scope-manifest.json` — per-page `inScope` / `designProvided` / `approved` /
   `delivery: theme|idx|plugin`.

`/wp-yolo` reconciles this manifest against the demo (see path A). Re-run it whenever the
client changes scope; it replaces its own block and overwrites the manifest.

---

## The demo (all paths) — *required*

Every path converts a demo, so this stage always happens. Three ways in, by what you already
have.

### You already have a mockup

```
/wp-init path/to/mockup.html
```

`/wp-init` copies it to `demo/index.html`, runs `/wp-polish` on it when it has no section
delimiters, and then reads the project name, industry, colours and fonts **out of the demo**
rather than interviewing you. This is the shortest way in when a client sent HTML, and it is
why you should not run a bare `/wp-init` first out of habit: with no demo present that flow
never triggers and you answer by hand what the file already knew. A bare `/wp-init` will also
offer to adopt an existing `demo/index.html` if it finds one.

### You already have files in `demo/`

```
/wp-polish demo/index.html
```

Drop any HTML into `demo/` yourself, then normalize it: section delimiters, semantic HTML5,
BEM classes. An unpolished copy is kept at `demo/.prepolish/<source-filename>` and never
overwritten. For a multi-page site put every page in `demo/` and let Path A convert the
folder in one pass.

### You have nothing yet

```
/wp-init                 # answer the project questions, writes .claude/CLAUDE.md
/wp-demo                 # generate demo/index.html from a brief
/wp-demo iterate         # re-read the existing demo and iterate
/wp-cinematic-demo       # the video-reel equivalent on path C
```

`/wp-demo` reads `.claude/CLAUDE.md`, so it runs **after** `/wp-init`. That is the only
ordering constraint in either direction: bring a mockup and `/wp-init` consumes it, bring
nothing and `/wp-init` sets up the questions `/wp-demo` answers from.

Send the demo to the client here. Everything after this transcribes it, and
`/wp-demo-verify demo/index.html` will walk it before the WordPress build rather than only
after.

---

## Path A — Full demo folder → site with `/wp-yolo`

**Use when** you have a complete, approved multi-page HTML site (a folder of `*.html` plus
`css/`, `img/`, fonts) and want the whole theme in one pass. That folder is the demo from the
stage above, just with more than one page in it: hand-authored, client-supplied, or polished
from a mockup. `/wp-yolo` normalizes each page before converting it, so pages without section
delimiters are fine.

```
/wp-yolo ./demo-folder             # one checkpoint after normalization, then hands-off
/wp-yolo ./demo-folder --yolo      # no checkpoint at all
/wp-yolo ./demo-folder --careful   # checkpoint + confirm before each inner page
```

Prerequisites: `/wp-init` done (it refuses without `.claude/CLAUDE.md`), a running WordPress
(`/wp-create`, or an existing install with `wp` on PATH), template is `tailwind` (a cinematic project is
redirected to path C).

What it does, in order — **you do not run any of these yourself**:

| Phase | Runs | Produces |
|-------|------|----------|
| 1 Normalize | `wp-normalize` agent | `demo/*.html` in canonical delimited format, `demo/.yolo-manifest.json` (pages, shared header/footer, detected content types, review items) |
| 1.5 Scope | reads `docs/.scope-manifest.json` if present | marks each page `theme` / `idx` / `plugin` / out-of-scope |
| 1.6 Convert | `/wp-tailwindify` per page (tailwind template) | Tailwind-native demo; originals kept in `demo/.original/` |
| — Checkpoint | you edit the manifest if needed (skipped with `--yolo`) | |
| 2 Build | `/wp-settings` → `/wp-cpt` per content type → `/wp-header` → `/wp-footer` → `/wp-section --transcribe` per section of every page → `/wp-page embed` for IDX/plugin pages | `fields/*.php`, `template-parts/*.php`, `page-<slug>.php`, CSS |
| 2.5 Fonts | copies self-hosted fonts | `assets/fonts/` |
| 3 Seed & finish | `/wp-seed` → CPT seeders → `/wp-finalize` → `/wp-polish` → `/wp-responsive-check` | pages, menus, media, ACF values |
| 3.5 Parity gate | static + WP-CLI + visual diff vs the demo | auto-fixes mechanical drift, **blocks** on anything it can't fix |
| 4 Report | | what was built, skipped, and what needs review |

Transcription mode means the sections copy the demo's exact declared CSS values rather than
re-authoring them, and every section gets a unique BEM block so parallel builds can't collide.

After it finishes, the optional tail is the same as every path: [Finish](#finish-all-paths).

**When it stops**: the parity gate prints the divergences it could not fix. Fix them (or
accept them), then re-run only the affected piece — `/wp-section <name> --page <slug>
--target page-<slug>.php`, `/wp-seed demo/<slug>.html`, etc. `/wp-yolo` itself is not
incremental; re-running it redoes the whole site.

---

## Path B — Step by step

**Use when** you are designing the site as you go, only have a one-page mockup, or want to
review each piece before the next.

### B1. Get a demo — *required*

Done in [The demo](#the-demo-all-paths--required) above, which applies to every path. Path B
picks up from an existing `demo/index.html`.

`/wp-demo` uses the `frontend-design` and `ui-ux-pro-max` skills when installed.
`/wp-tailwindify` is **auto** (run by `/wp-init` and `/wp-yolo`); run it by hand only to
convert a demo outside those flows.

### Craft demos

`/wp-demo` chooses **craft** or **plain** mode before it writes anything, from
`.claude/CLAUDE.md`, `docs/`, and `.wp-create.json` (`--craft`/`--plain` override the
inference), and records the answer as `demo mode` in `.wp-create.json`. Craft is for a
marketing, brand, launch or agency-campaign site: it self-authors `demo/BRIEF.md`, reads the
`wp-demo-craft` skill for its page grammar and device kit, checks the plan against
`~/.claude/wp-builder/FINGERPRINTS.md` so two clients never get the same shape, and drives
motion through `data-motion-*` attributes plus an inlined `motion.js` bundle built on GSAP
ScrollTrigger. Plain is for an admin tool, an intranet, or a data-heavy catalogue site, and
carries no motion contract. `wp-aos-animator` remains the skill to reach for on a plain
project that wants simple scroll animations; craft projects ship their own GSAP-based motion
through the theme bundle instead. Run `/wp-demo-verify` after either mode to walk the demo
and check what got built, see [`/wp-demo-verify`](commands.md#wp-demo-verify).

### B2. Header and footer — *required*

```
/wp-header               # header.php, nav walker, menu registration, language switcher, Header settings tab
/wp-footer               # footer.php from the Footer / Contact / Social / Legal settings tabs
```

Each takes an optional screenshot path as visual reference.

### B3. Sections — *required, one per demo section*

```
/wp-section hero
/wp-section services
/wp-section contact                        # names like contact/contacto/get-in-touch wire Contact Form 7 automatically
/wp-section pricing --page about --target page-about.php   # a section on an inner page
```

Each run emits three files in parallel: `fields/<section>.php`, `template-parts/section-<name>.php`,
and the section's CSS. Flags: `--cf7` force a form, `--page <slug>` read from `demo/<slug>.html`,
`--target <template>` inject into a template other than `front-page.php`, `--transcribe --block
<bem> --css <source>` copy the demo's CSS verbatim (what `/wp-yolo` uses).

### B4. Page templates and custom post types — *optional*

```
/wp-page blog            # archive.php, single.php, post cards
/wp-page legal           # privacy + terms with ACF fields; hides them from site search
/wp-page 404
/wp-page search
/wp-page generic         # plain content page
/wp-page custom pricing  # page-pricing.php
/wp-page embed listings --provider showcase-idx   # styled shell with an insertion point for a provider shortcode

/wp-cpt team                          # CPT + fields + archive/single + home teaser + inc/seed/team.php
/wp-cpt project --no-teaser
/wp-cpt service --from-demo services  # take field/seed hints from that demo section
```

Run `/wp-cpt` **before** any `/wp-section` that lists posts of that type.

### B5. Extra settings — *optional*

```
/wp-settings Add a Google Calendar embed URL and a newsletter signup link
```

Adds fields (with `_es` variants under `suffix`) to the theme settings page.

### B6. Seed content — *required if you want the pages filled*

```
/wp-seed                                 # demo/index.html
/wp-seed demo/about.html
/wp-seed --exclude-slugs team,projects   # don't create WP Pages for CPT archive slugs
```

Creates pages with matching slugs, sideloads media, fills every ACF field, builds menus, sets
the front page. Uses the WP-CLI wrapper from `.wp-create.json`, or bare `wp` when absent. Does **not** create CPT posts — run the seeder that
`/wp-cpt` emitted: `$WP eval-file inc/seed/<name>.php`. On a fresh database the CF7 form
body is restored the same way: `$WP eval-file inc/seed/cf7.php` (emitted by the contact section).

Then [Finish](#finish-all-paths).

---

## Path C — Cinematic (scroll-driven video reel)

**Use when** the page is one continuous story driven by video rather than a list of sections.
Choose `cinematic` at `/wp-init`'s first question (or run `/wp-cinematic-init` directly — it
calls `/wp-init` for you).

```
/wp-cinematic-init                                # kit detection → theme → ACF scenes → seed
/wp-cinematic-demo --scenes=9 --brand=./brief.md  # HTML demo for client approval
/wp-cinematic-encode ./raw/scene-3.mp4 --scene=3 --poster   # per source video
/wp-cinematic-scene 3 --headline "..." --body "..."         # per scene, replaces /wp-section
/wp-cinematic-seed [--manifest scenes.json] [--force]       # idempotent
/wp-section pricing --hybrid                                # trailing normal sections after the reel
```

Full pipeline, dependency (`cinematic-scroll-kit`) and encoding details: [cinematic-mode.md](cinematic-mode.md).
`/wp-yolo` is **not** used on this path; `/wp-section` is, but only with `--hybrid`; the normal
[Finish](#finish-all-paths) still applies.

---

## Finish (all paths)

| Command | Required? | Notes |
|---------|-----------|-------|
| `/wp-finalize` | recommended | Reports (never fixes) escaping, bilingual coverage, menus, theme structure; adds WP-CLI runtime checks when `.wp-create.json` exists. `/wp-yolo` runs it for you. |
| `/wp-demo-verify <path-or-url> [--positions N]` | recommended | Scroll-walks the demo or live page, screenshots per section and viewport plus 375/576/768/1024/1440 full-page shots, and prints machine findings. `/wp-yolo` runs it; `/wp-responsive-check` is now an alias for it. |
| `/wp-audit [--security --seo --a11y --performance --best-practices] [--report-only]` | optional | Audits and auto-fixes; installs Rank Math / AIOS as needed. |
| `/wp-polylang <src> <dst>` | only under `i18n strategy: polylang` | Translates everything the demo did not cover into the second language. `/wp-seed` hands off to it. |
| `/wp-tailwind-migrate <theme-path> [--page <slug>]` | only for old plain-CSS themes | Converts an already-built theme to Tailwind in place. Requires a clean git tree. |

---

## Utilities (any time)

| Command | Use it when |
|---------|-------------|
| `/wp-debug [issue]` | Something is broken — white screen, missing fields, plugin conflicts. Keyword-aware WP-CLI diagnostics with offered fixes. |
| `/wp-clone --from=ssh://user@host/path --to=/local/path` | You need a copy of a staging/production site locally. Also `--sql= --uploads=` for a manual dump. |

Two capabilities are **skills, not commands** — ask for them in plain language and Claude
loads them: `wp-robin` (Robin Image Optimizer fixes) and `wp-aos-animator` (AOS scroll
animations across templates).

---

## Two i18n systems

Chosen once at `/wp-init` Step 0.7, recorded as `i18n strategy` in `.claude/CLAUDE.md`.

| | `suffix` (default) | `polylang` |
|---|---|---|
| Content model | one page; every ACF field duplicated as `field_es` | one page per language, linked by Polylang translation groups |
| Extra plugin | none | Polylang (installed by `/wp-init`) |
| Templates | unchanged — `prefix_get_field()` resolves the suffix | unchanged — same helpers, different `inc/i18n.php` |
| `/wp-seed` | fills primary language, flags secondary strings untranslated | builds a counterpart page per language from the demo's second-language copy, then hands the rest to `/wp-polylang` |
| Options page | `_es` suffixes | still `_es` suffixes (options are global; Polylang doesn't reach them) |

A project without the line predates the choice and is `suffix`.

## Files the commands share

| File | Written by | Read by |
|------|-----------|---------|
| `.wp-create.json` | `/wp-create` | everything that runs WP-CLI (`/wp-seed`, `/wp-debug`, `/wp-finalize`, cinematic seeders) |
| `.claude/CLAUDE.md` | `/wp-init`, `/wp-context` | every command and agent — prefix, slug, languages, template, CF plugin, i18n strategy, constraints |
| `docs/.scope-manifest.json` | `/wp-context` | `/wp-yolo` Phase 1.5 |
| `demo/index.html`, `demo/<slug>.html` | `/wp-demo`, `/wp-polish`, `wp-normalize` | `/wp-header`, `/wp-footer`, `/wp-section`, `/wp-seed` |
| `demo/.yolo-manifest.json` | `/wp-yolo` | `/wp-yolo` |
