# Workflows

How to get from "nothing" to a working WordPress theme, on each of the three paths the
plugin supports. Every path shares the same two setup commands and the same three
finishing commands; only the middle differs.

```
SETUP           /wp-create (optional)  →  /wp-init  →  /wp-context (optional)
                                              │
BUILD      ┌──────────────────────────────────┼──────────────────────────────┐
           │ A. Full demo folder              │ B. Step by step              │ C. Cinematic
           │    /wp-yolo <folder>             │    /wp-demo | /wp-polish     │    /wp-cinematic-*
           │    (runs everything below)       │    /wp-header /wp-footer     │    see cinematic-mode.md
           │                                  │    /wp-section … /wp-page …  │
           │                                  │    /wp-seed                  │
           └──────────────────────────────────┴──────────────────────────────┘
FINISH          /wp-finalize  →  /wp-responsive-check  →  /wp-audit (optional)
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

## Path A — Full demo folder → site with `/wp-yolo`

**Use when** you have a complete, approved multi-page HTML site (a folder of `*.html` plus
`css/`, `img/`, fonts) and want the whole theme in one pass.

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

### B1. Get a demo — *required, pick one*

```
/wp-demo                 # generate demo/index.html from a brief (asks for one if omitted)
/wp-demo iterate         # re-read the existing demo and iterate
/wp-polish path/to/mockup.html   # normalize a mockup you already have into demo/index.html
```

`/wp-demo` uses the `frontend-design` and `ui-ux-pro-max` skills when installed.
`/wp-polish` adds section delimiters and BEM classes; it preserves an unpolished copy of the
source document at `demo/.prepolish/<source-filename>` and never overwrites one already there.
Send the demo to the client here — everything after this transcribes it.

`/wp-tailwindify` is **auto** (run by `/wp-init` and `/wp-yolo`); run it by hand only to
convert a demo outside those flows.

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
/wp-page legal           # privacy + terms with ACF fields
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
`/wp-cpt` emitted: `$WP eval-file inc/seed/<name>.php`.

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
| `/wp-responsive-check <url-or-file>` | recommended | Screenshots at 375/576/768/1024/1440 and flags layout issues. Works on the demo file or the live URL. `/wp-yolo` runs it. |
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
