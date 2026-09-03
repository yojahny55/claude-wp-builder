# Command reference

Every slash command the plugin ships, what it needs, what it writes. For *when* to run
them, read [workflows.md](workflows.md). All commands run from the WordPress project root
unless noted.

**Required?** column: **required** on its path · **optional** · **auto** (another command runs
it; manual runs are for re-runs/overrides) · **utility** (any time, any path).

| Command | Path | Required? | Reads | Writes |
|---------|------|-----------|-------|--------|
| [`/wp-create`](#wp-create) | all | optional* | — | `.wp-create.json`, WordPress install, DB, vhost |
| [`/wp-init`](#wp-init) | all | **required** | `.wp-create.json`, `demo/index.html` | theme dir, `.claude/CLAUDE.md` |
| [`/wp-context`](#wp-context) | all | auto / optional | `docs/**` | `.claude/CLAUDE.md` constraints block, `docs/.scope-manifest.json` |
| [`/wp-yolo`](#wp-yolo) | A | **required** | demo folder, `.claude/CLAUDE.md`, scope manifest | everything below it |
| [`/wp-demo`](#wp-demo) | B | required (or polish) | brief | `demo/index.html` |
| [`/wp-polish`](#wp-polish) | B | required (or demo); auto in init | any HTML | `demo/index.html`, `demo/.prepolish/<file>` |
| [`/wp-tailwindify`](#wp-tailwindify) | A, B | auto | `demo/*.html` | Tailwind-native HTML |
| [`/wp-header`](#wp-header) | B | **required** | demo header | `header.php`, nav walker, Header settings fields, CSS |
| [`/wp-footer`](#wp-footer) | B | **required** | demo footer | `footer.php`, Footer fields, CSS |
| [`/wp-section`](#wp-section) | B, C | **required** per section | demo section | `fields/<s>.php`, `template-parts/section-<s>.php`, CSS |
| [`/wp-page`](#wp-page) | B | optional | screenshot | `page-*.php`, `archive.php`, `single.php`, `404.php`, … |
| [`/wp-cpt`](#wp-cpt) | B | optional | demo section hints | CPT registration, fields, archive/single, teaser, `inc/seed/<name>.php` |
| [`/wp-settings`](#wp-settings) | B | optional | `fields/settings.php` | new settings fields |
| [`/wp-seed`](#wp-seed) | B | required for content | demo HTML, `.wp-create.json` | WP pages, media, ACF values, menus |
| [`/wp-finalize`](#wp-finalize) | all | recommended | theme, WP-CLI | report only |
| [`/wp-responsive-check`](#wp-responsive-check) | all | recommended | URL or file | screenshots + report |
| [`/wp-audit`](#wp-audit) | all | optional | theme, WP-CLI | fixes, Rank Math / AIOS config |
| [`/wp-polylang`](#wp-polylang) | all (polylang) | required under `polylang` | WP content | translated posts/terms |
| [`/wp-tailwind-migrate`](#wp-tailwind-migrate) | legacy | optional | plain-CSS theme | Tailwind theme in place |
| [`/wp-cinematic-init`](#wp-cinematic-init) | C | **required** | kit | cinematic theme, `fields/scenes.php`, seeders |
| [`/wp-cinematic-demo`](#wp-cinematic-demo) | C | recommended | brand brief | `<theme>/demo/` |
| [`/wp-cinematic-encode`](#wp-cinematic-encode) | C | required per video | source MP4 | `assets/videos/*`, ACF row |
| [`/wp-cinematic-scene`](#wp-cinematic-scene) | C | required per scene | — | scene repeater row, optional template override |
| [`/wp-cinematic-seed`](#wp-cinematic-seed) | C | required | scenes manifest | scene rows, sample videos |
| [`/wp-debug`](#wp-debug) | utility | — | `.wp-create.json` | offered fixes |
| [`/wp-clone`](#wp-clone) | utility | — | remote site | local install |
| [`/wp-contribute`](#wp-contribute) | contributors | — | this repository | new layer file + its check + doc rows; PR; release |

\* `/wp-create` is optional if WordPress is already running: `/wp-seed` and `/wp-debug` fall
back to a bare `wp` on PATH (run from the WordPress root, languages from `.claude/CLAUDE.md`)
when `.wp-create.json` is absent. Container wrappers need the manifest.

---

## Setup

### `/wp-create`

```
/wp-create --path=/var/www/html/my-project
/wp-create /var/www/html/my-project
```

Detects Docker, DDEV, Lando, wp-env, native Nginx/Apache/Caddy and PHP versions; lets you
choose; downloads WordPress, creates DB, web-server config, SSL, hosts entry; installs a
plugin profile (`starter` = SCF + Rank Math + WP Fastest Cache, `full` adds AIOS, CF7,
WP Mail SMTP, Redirection, Site Kit; custom profiles in `.wp-profiles/` or `~/.wp-profiles/`).
Can adopt an existing install. Writes `.wp-create.json` holding the WP-CLI wrapper
(`wp --path=…`, `docker exec … wp`, `ddev wp`, `lando wp`, `npx wp-env run cli wp`),
environment type and languages.

### `/wp-init`

```
/wp-init [project-name]
/wp-init path/to/mockup.html          # demo-first
/wp-init --template=tailwind|cinematic --i18n=suffix|polylang   # skip those two questions
```

Asks: starter template (`tailwind` default / `cinematic`), custom-fields plugin (`scf`
default / `acf`), i18n strategy (`suffix` default / `polylang`), then project name, slug,
languages, industry. With a demo argument (or an existing `demo/index.html` you confirm) it
infers name/slug/sections from the HTML and runs `/wp-polish` if delimiters are missing.
Copies the starter, replaces `__starter__` / `__STARTER__` / `__STARTER_NAME__`, writes
`.claude/CLAUDE.md`, activates the theme when `.wp-create.json` exists, and runs
`/wp-context` when `docs/` exists. `cinematic` hands off to `/wp-cinematic-init`.

### `/wp-context`

```
/wp-context [docs-path]     # default ./docs
```

Dispatches the `wp-context` agent over spreadsheets, PDFs, markdown, text. Replaces the
`<!-- wp-context:start/end -->` block in `.claude/CLAUDE.md` with `## Project Constraints`
and overwrites `docs/.scope-manifest.json`. Exits 0 with a note when the folder is absent.
Idempotent — re-run after the client changes scope.

---

## Path A

### `/wp-yolo`

```
/wp-yolo <demo-folder> [--yolo | --careful]
```

- default: one checkpoint after normalization, then hands-off
- `--yolo`: no checkpoint
- `--careful`: checkpoint + confirm before each inner page

Refuses without `.claude/CLAUDE.md`; redirects `Template: cinematic` projects to path C.
Phases: normalize (`wp-normalize` → `demo/*.html` + `demo/.yolo-manifest.json`) → scope
reconcile (`docs/.scope-manifest.json`: `theme` builds normally, `idx`/`plugin` becomes a
`/wp-page embed` shell, out-of-scope pages are skipped, in-scope pages with no HTML are
reported) → `/wp-tailwindify` → build (`/wp-settings`, `/wp-cpt` per content type,
`/wp-header`, `/wp-footer`, `/wp-section --transcribe --block --css` per section,
`/wp-page embed` for provider pages) → font carry → `/wp-seed --exclude-slugs <cpt-archives>`
→ CPT seeders → `/wp-finalize` → `/wp-polish` → `/wp-responsive-check` → demo-parity gate
(auto-fixes mechanical drift, blocks otherwise) → report. Never reimplements a builder; it
dispatches the commands above.

---

## Path B

### `/wp-demo`

```
/wp-demo [brief] [--craft|--plain]
/wp-demo iterate
```

Writes `demo/index.html` with `<!-- ============ SECTION: name ============ -->` delimiters.
Uses `frontend-design` and `ui-ux-pro-max` skills when installed. Requires `.claude/CLAUDE.md`.

Before generating, picks **craft** or **plain** mode from `.claude/CLAUDE.md` (including the
Project Constraints section `/wp-context` writes), anything under `docs/`, and
`.wp-create.json`; `--craft`/`--plain` override the inference. The choice is written back as
`demo mode` in `.wp-create.json` so downstream commands do not re-derive it. Craft mode
self-authors `demo/BRIEF.md` (brand rules, audience pain and promise, two or three named
references, vibe words, a per-section feeling curve with one named peak), reads the
`wp-demo-craft` skill for its page grammar and device kit, checks the plan against
`~/.claude/wp-builder/FINGERPRINTS.md` before building (the plan must differ from every prior
row on at least 4 of 6 axes) and wires motion through `data-motion-*` attributes plus the
inlined `motion.js` bundle. Plain mode is the existing single-file demo with no motion
contract.

### `/wp-polish`

```
/wp-polish [path-to-html] [--craft]    # default: demo/index.html in place
```

Detects sections, adds delimiters, normalizes to semantic HTML5, applies BEM classes.
Preserves an unpolished copy of the source document at `demo/.prepolish/<source-filename>`
and never overwrites a copy already there. `--craft` runs a retrofit audit against the
`wp-demo-craft` skill instead of a plain normalize pass, and may recommend restructuring the
page; converting a plain demo to craft is a rebuild, not a polish.

### `/wp-tailwindify`

```
/wp-tailwindify [path/to/demo.html] [--out <path>]
```

Converts CSS-class HTML into Tailwind utilities, keeps delimiters, maps colors to `@theme`
variables. Default output `<demo-dir>/index-tailwind.html`; `--out` equal to the input
converts in place (how `/wp-yolo` uses it, after backing up to `demo/.original/`).

### `/wp-header` · `/wp-footer`

```
/wp-header [screenshot-path]
/wp-footer [screenshot-path]
```

Read the demo's header/footer, dispatch `wp-template` + `wp-css`/`wp-tailwind` + `wp-acf`.
Header: `header.php`, nav walker, menu registration (one location per language under
`suffix`, one per name under `polylang`), language switcher, Header settings tab.
Footer: `footer.php` from the Footer/Contact/Social/Legal settings tabs.

### `/wp-section`

```
/wp-section <name> [screenshot] [--cf7] [--hybrid] [--page <slug>] [--target <template>]
                   [--transcribe] [--block <bem>] [--css <source>]
```

| Flag | Default | Effect |
|------|---------|--------|
| `--page <slug>` | `index` | read the section from `demo/<slug>.html` |
| `--target <template>` | `front-page.php` | where the `get_template_part()` call is injected |
| `--cf7` | auto for `contact`, `contact-us`, `contacto`, `get-in-touch` | wire Contact Form 7: forms per language, branded mail templates, IDs injected, refs in `cf7/`, plus an idempotent `inc/seed/cf7.php` that restores the form body on a fresh database (`$WP eval-file inc/seed/cf7.php`) |
| `--hybrid` | off (implied on cinematic when no `--target`) | cinematic only: add a layout to the `trailing_sections` flex field, template reads `get_sub_field()`, CSS to `cinematic.css`, no page injection |
| `--transcribe` | off | copy the demo's exact declared CSS instead of re-authoring |
| `--block <bem>` | — | unique BEM block to scope every selector (with `--transcribe`) |
| `--css <source>` | — | the demo CSS to transcribe (required with `--transcribe`) |

Emits `fields/<section>.php`, `template-parts/section-<name>.php`, and CSS, in parallel, then
recompiles `assets/css/dist/main.css` on the tailwind template (`bin/tailwind-rebuild.sh`; skipped
when `npm run preview` is running). `/wp-header`, `/wp-footer`, `/wp-page`, `/wp-cpt` and `/wp-yolo` do the same.

### `/wp-page`

```
/wp-page <blog|generic|legal|404|search|embed|custom> [name] [screenshot] [--provider <name>]
```

`name` is required for `custom` and `embed`. `embed` builds a styled shell with a marked
insertion point for a provider shortcode (e.g. an IDX plugin); `--provider` names it.
`legal` also emits `inc/legal-search.php` (required from `functions.php`), which hides
pages using `page-legal.php` from site search only — they stay published and indexable.

### `/wp-cpt`

```
/wp-cpt <name> [--no-teaser] [--from-demo <section-name>]
```

`name` singular lowercase (`team`, `service`). Registers the CPT, generates fields,
`archive-<name>.php`, `single-<name>.php`, a home teaser section (unless `--no-teaser`) and
`inc/seed/<name>.php`. Run the seeder yourself: `$WP eval-file inc/seed/<name>.php`.

### `/wp-settings`

```
/wp-settings <what to add, in plain language>
```

Adds fields/tabs to `fields/settings.php`; under `suffix` adds `_<lang>` variants.

### `/wp-seed`

```
/wp-seed [demo-file.html] [--exclude-slugs <slug,slug>]
```

Uses the WP-CLI wrapper from `.wp-create.json`, or bare `wp` from the WordPress root when absent. Parses the demo by BEM class conventions, creates
pages with matching slugs, sideloads media, fills ACF fields, builds menus, sets the front
page. Under `suffix` fills the primary language and flags untranslated strings; under
`polylang` creates counterpart pages and hands the rest to `/wp-polylang`. Does not create
CPT posts. `--exclude-slugs` prevents a WP Page colliding with a CPT archive slug.

---

## Finish

### `/wp-finalize`

No arguments. Reports (does not fix) escaping, `prefix_get_field()` usage, bilingual
coverage, responsive breakpoints, menus, theme structure; adds WP-CLI runtime checks (pages,
menus, ACF fields, plugins) when `.wp-create.json` exists.

### `/wp-demo-verify`

```
/wp-demo-verify <file-path-or-url> [--positions N]
```

Defaults to `demo/index.html`. Pass a URL to check a converted WordPress page instead, the
only way to prove the demo's motion survived conversion; serve files over HTTP, since a
`file://` page silently falls back on anything it tries to fetch and proves nothing. Walks
each section at N positions (default 6) at 1440x900 and 390x844, plus a reduced-motion pass
at desktop width, then takes full-page screenshots at 375, 576, 768, 1024 and 1440 (this is
what `/wp-responsive-check` now dispatches to). Output lands in `<dir>/.verify/<width>/`:
`findings.json` and one `sheet.png` per width.

Four machine findings: dead scroll (consecutive positions where nothing changed, unless
`demo/BRIEF.md` records it as authored silence), a cue that never reaches full opacity, any
horizontal overflow, and copy clipped by its own hidden-overflow box.

Three exit codes: `0` no machine findings, `1` findings printed, `2` no usable browser. On
exit code 2, fall back in order: the Chrome or Playwright MCP screenshot tools if either is
connected, otherwise ask the user for screenshots at the five viewports.

**A green machine run alone is not a pass.** Open every `sheet.png`, then run the feel check
from `skills/wp-demo-craft/references/feel.md`: scroll the page cold, write one word per
section, and only then diff that felt curve against the one recorded in `demo/BRIEF.md`.
Where they disagree, the page is wrong, not the brief.

### `/wp-responsive-check`

```
/wp-responsive-check <url-or-file-path>
```

Alias, dispatches straight to `/wp-demo-verify $ARGUMENTS`. The 375 / 576 / 768 / 1024 / 1440
px screenshots this command used to cover are one part of what that walk now does; a single
static screenshot per breakpoint cannot show scroll motion, which is why the check moved.

### `/wp-audit`

```
/wp-audit [--security] [--seo] [--a11y] [--performance] [--best-practices] [--all]
          [--report-only] [--security-level basic|recommended|maximum]
```

No category flag = all. Security installs/configures All-in-One WP Security; SEO installs
Rank Math and seeds meta/schema. `--report-only` skips fixes. Lighthouse-style checks need
the optional `web-quality-skills` plugin.

### `/wp-polylang`

```
/wp-polylang <source_lang> <target_lang>     # e.g. es en; one target per run
```

Run from the WordPress root. Installs/activates Polylang, configures both languages,
exports untranslated posts/terms/ACF, translates, imports through translation groups
(`pll_save_post_translations`). Only meaningful under `i18n strategy: polylang`. Known
ceilings: media is copied not translated; ACF reference re-pointing is one level deep.

### `/wp-tailwind-migrate`

```
/wp-tailwind-migrate <theme-path> [--page <slug>]
```

Converts an already-built plain-CSS theme to Tailwind-native in place, look unchanged.
Refuses on a dirty git tree. `--page` migrates one template first.

---

## Path C — cinematic

Details, kit install and encoding rationale: [cinematic-mode.md](cinematic-mode.md).

| Command | Arguments |
|---------|-----------|
| `/wp-cinematic-init` | `[--no-hybrid]` — resolves `cinematic-scroll-kit` (global skill → `./.cinematic-kit/` → vendored copy), calls `/wp-init`, copies `starter-theme/__cinematic__/`, dispatches the `wp-cinematic` agent for `fields/scenes.php`, `fields/trailing-sections.php`, `inc/seed-cinematic.php`, scene fragments |
| `/wp-cinematic-demo` | `[--scenes N=9] [--hybrid] [--brand brief.md]` → `<theme>/demo/index.html` + `demo/assets/` |
| `/wp-cinematic-encode` | `<input.mp4> [--scene N] [--desktop-only] [--mobile-only] [--poster]` → all-keyframe desktop MP4, 9:16 mobile MP4, poster JPG in `assets/videos/`; wires the ACF row when `--scene` given |
| `/wp-cinematic-scene` | `<n|scene-id> [--eyebrow] [--headline] [--body] [--cta "Label|URL"] [--video …]` (+ `-es` variants) → updates the `cinematic_scenes` row; emits `template-parts/cinematic/scene-<id>.php` only for non-default layouts |
| `/wp-cinematic-seed` | `[--manifest path] [--force] [--dry-run]` — idempotent; skips scenes that already have content; sideloads kit sample videos when none pinned |
| `/wp-section <name> --hybrid` | trailing normal section after the reel — see [`/wp-section`](#wp-section) |

---

## Utilities

### `/wp-debug`

```
/wp-debug [issue description]      # e.g. /wp-debug white screen
```

Health, plugins, DB, config, filesystem checks via the WP-CLI wrapper from `.wp-create.json`
(falls back to bare `wp`). Keyword-aware; offers targeted fixes.

### `/wp-clone`

```
/wp-clone --from=ssh://user@host/path --to=/var/www/html/local          # SSH automated
/wp-clone --sql=/tmp/dump.sql --uploads=/tmp/uploads.zip --to=/var/www/html/local   # manual
```

---

## Contributing to the plugin

### `/wp-contribute`

```
/wp-contribute new <command|agent|skill|check> <name>
/wp-contribute check
/wp-contribute pr [--title "..."]
/wp-contribute release [major|minor|patch]     # maintainers
```

Operates on **this repository**, not on a WordPress project — it refuses unless the working
directory is the plugin root. `new` scaffolds a layer file together with the two things a PR
is always missing without it: a grep gate under `tests/checks/` and the README + docs rows.
`check` runs the whole suite plus `bin/doc-sync-check.sh`. `pr` refuses on `main`, re-runs
both gates, then commits (Conventional Commits, no AI attribution), pushes over SSH and opens
the PR in the house format. `release` is the maintainer path: four version references, the
changelog rollup, tag, `gh release`, and verification that the published artifact is live.

Reads `skills/wp-contributing/SKILL.md`, which carries the layer rules, the grep-gate test
style, the frontmatter contract per layer, the two i18n systems, and the stacked-PR merge
order. See [CONTRIBUTING.md](../CONTRIBUTING.md) for the front-door version.

---

## Not commands

`wp-robin` and `wp-aos-animator` are **skills**: describe the task ("fix Robin's stuck bulk
optimization", "add AOS animations to the templates") and Claude loads them. There is no
`/wp-robin` or `/wp-aos-animator` slash command.
