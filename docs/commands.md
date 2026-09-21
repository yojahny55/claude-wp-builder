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
| [`/wp-demo`](#wp-demo) | all | demo stage | brief, `.claude/CLAUDE.md` | `demo/index.html` |
| [`/wp-polish`](#wp-polish) | all | demo stage; auto in init and yolo | any HTML | `demo/index.html`, `demo/.prepolish/<file>` |
| [`/wp-tailwindify`](#wp-tailwindify) | A, B | auto | `demo/*.html` | Tailwind-native HTML |
| [`/wp-header`](#wp-header) | B | **required** | demo header | `header.php`, nav walker, Header settings fields, CSS |
| [`/wp-footer`](#wp-footer) | B | **required** | demo footer | `footer.php`, Footer fields, CSS |
| [`/wp-section`](#wp-section) | B, C | **required** per section | demo section | `fields/<s>.php`, `template-parts/section-<s>.php`, CSS |
| [`/wp-page`](#wp-page) | B | optional | screenshot | `page-*.php`, `archive.php`, `single.php`, `404.php`, … |
| [`/wp-cpt`](#wp-cpt) | B | optional | demo section hints | CPT registration, fields, archive/single, teaser, `inc/seed/<name>.php` |
| [`/wp-settings`](#wp-settings) | B | optional | `fields/settings.php` | new settings fields |
| [`/wp-seed`](#wp-seed) | B | required for content | demo HTML, `.wp-create.json` | WP pages, media, ACF values, menus |
| [`/wp-finalize`](#wp-finalize) | all | recommended | theme, WP-CLI | report only |
| [`/wp-demo-verify`](#wp-demo-verify) | all | recommended | URL or file | `.verify/` screenshots, contact sheet, findings |
| [`/wp-responsive-check`](#wp-responsive-check) | all | alias | URL or file | runs `/wp-demo-verify` |
| [`/wp-audit`](#wp-audit) | all | optional | theme, WP-CLI | fixes, Rank Math / AIOS config, `inc/agentic.php` |
| [`/wp-polylang`](#wp-polylang) | all (polylang) | required under `polylang` | WP content | translated posts/terms |
| [`/wp-tailwind-migrate`](#wp-tailwind-migrate) | legacy | optional | plain-CSS theme | Tailwind theme in place |
| [`/wp-cinematic-init`](#wp-cinematic-init) | C | **required** | kit | cinematic theme, `fields/scenes.php`, seeders |
| [`/wp-cinematic-demo`](#wp-cinematic-demo) | C | recommended | brand brief | `<theme>/demo/` |
| [`/wp-cinematic-encode`](#wp-cinematic-encode) | C | required per video | source MP4 | `assets/videos/*`, ACF row |
| [`/wp-cinematic-scene`](#wp-cinematic-scene) | C | required per scene | — | scene repeater row, optional template override |
| [`/wp-cinematic-seed`](#wp-cinematic-seed) | C | required | scenes manifest | scene rows, sample videos |
| [`/wp-adopt`](#wp-adopt) | utility | — | a running WordPress root | `.wp-create.json` (`origin: adopted`), `.claude/CLAUDE.md` block |
| [`/wp-debug`](#wp-debug) | utility | — | `.wp-create.json` | offered fixes |
| [`/wp-clone`](#wp-clone) | utility | — | remote site | local install |
| [`/wp-anonymize`](#wp-anonymize) | utility | — | cloned database | anonymised database |
| [`/wp-robin`](#wp-robin) | utility | — | target WordPress root | Robin settings, queue rows, `.webp` files |
| [`/wp-s3`](#wp-s3) | utility | — | bucket, region, media URL, credentials | `s3-config.php`, the `require` in `wp-config.php`, the endpoint mu-plugin |
| [`/wp-s3-media`](#wp-s3-media) | utility | — | a configured WordPress root | `wp-content/uploads` moved, and verified |
| [`/wp-aos-animator`](#wp-aos-animator) | utility | — | theme templates | `vendors/aos/`, `functions.php` enqueue, JS init, `data-aos` attributes |
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
/wp-init --template=tailwind|cinematic --i18n=polylang|suffix   # skip those two questions
```

Asks: starter template (`tailwind` default / `cinematic`), custom-fields plugin (`scf`
default / `acf`), i18n strategy (`polylang` default / `suffix`), then project name, slug,
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
→ CPT seeders → `/wp-finalize` → `/wp-polish` → `/wp-responsive-check` → `/wp-audit --all`
→ demo-parity gate
(auto-fixes mechanical drift, blocks otherwise) → report. Never reimplements a builder; it
dispatches the commands above.

---

## The demo (every path)

Every path converts a demo, so one of these runs before any WordPress work. Which one
depends on what you already have: a mockup goes to `/wp-init path/to/mockup.html` (it reads
the project out of the file, see [`/wp-init`](#wp-init)); files you dropped into `demo/`
go through `/wp-polish`; starting from nothing, `/wp-init` then `/wp-demo`. The one ordering
rule: `/wp-demo` needs `.claude/CLAUDE.md`, so it runs after `/wp-init`.

### `/wp-demo`

```
/wp-demo [brief] [--craft|--plain]
/wp-demo iterate
```

Writes `demo/index.html` with `<!-- ============ SECTION: name ============ -->` delimiters.
Uses `frontend-design` and `ui-ux-pro-max` skills when installed. Requires `.claude/CLAUDE.md`.

Before choosing craft or plain, `/wp-demo` runs the `wp-research` agent, which
identifies the client's web presence and 3–5 comparable competitors and writes
`demo/RESEARCH.md`. It asks once to confirm the business it found. Answering
"wrong business" keeps the research and drops the identity; declining records
`"research": "none"` in `.wp-create.json` and is never asked again. An existing
`demo/RESEARCH.md` is reused — delete it to refresh.

Before generating, picks **craft** or **plain** mode from `.claude/CLAUDE.md` (including the
Project Constraints section `/wp-context` writes), anything under `docs/`, and
`.wp-create.json`; `--craft`/`--plain` override the inference. The choice is written back as
`demo mode` in `.wp-create.json` so downstream commands do not re-derive it. Craft mode
self-authors `demo/BRIEF.md` (brand rules, audience pain and promise, two or three named
references, vibe words, a per-section feeling curve with one named peak), reads the
`wp-demo-craft` skill for its page grammar and device kit, checks the plan against
`~/.claude/wp-builder/FINGERPRINTS.md` before building (the plan must differ from every prior
row on at least 4 of 6 axes), and inventories every image, SVG and font under `docs/` into
`demo/BRIEF.md` with a role — used, or named with a reason, so a client asset does not sit
unused while the build reports it as owed.

On the craft path it also queries the `wp-design-library` MCP server per role when the server is registered and cites the entries it used under `## References` in `demo/BRIEF.md`; without the server it writes `References: library unavailable` and continues.

Craft mode also classifies the client's domain against the vendored 192-row table in
`skills/wp-demo-craft/references/domains/domains.csv` — two distinct keyword hits to match,
`unclassified` below that — and records the result in `.wp-create.json` under `"domain"`, which
`/wp-yolo` reads rather than re-deriving. The match folds its `page_pattern` and
`considerations` into the brief as stated constraints and every composition-plan row cites the
domain signal that justified it; it never touches tokens.

Motion is wired through `data-motion-*` attributes only, and the engine has two halves, both
inlined into the demo: `motion.js` in a `<script type="module">` block, and
`utilities/motion.css` in a `<style>` block. The stylesheet carries the `reveal` device wherever
the browser supports `animation-timeline: view()` and the reader has not asked for reduced
motion; `motion.js` yields that device there and runs every other one. Without the stylesheet a
demo in a modern browser reveals nothing. Sections are built from the composition library, whose
size-based breakpoints are `@container` queries against each composition's own container rather
than the viewport, and the fluid ramps in `clamp()` read `cqi` against that same container — of the
three that stay `vw`, two are sized against the screen on purpose and the third cannot be `cqi`
at all — its rule is the element declaring `container-type`, and an element never matches a
container query against the container it establishes itself. Each carries a comment saying which.
Plain mode is the existing single-file demo with no motion contract.

Each round of the craft loop runs `/wp-demo-verify demo/` — served over HTTP, not `file://` —
for the `impeccable detect` gate and a machine walk. `no-engine` (a page with zero `data-motion`
devices) and `container-noop` (a dead `@container` rule) join `dead-scroll` as findings that fail
the round; `unobserved` (a section the walk could not read) and `external-module` (a module
script that would silently fail to boot if the demo were opened as `file://`) are advisory and do
not. Three rounds still failing writes `demo/FAILED.md` — every failing rubric line, every
outstanding finding, the round count reached — and `/wp-init`, `/wp-section` and `/wp-yolo` stop
on it rather than building a theme from an unverified demo.

Craft mode can also **generate the images** a composition declares but `docs/` does not
supply (`hero-split`, `hero-bleed`, `feature-zigzag`). This is opt-in by environment: with
neither `GEMINI_API_KEY` nor `OPENAI_API_KEY` set, nothing is asked and nothing is
generated. With a key present and slots uncovered, Step 5.5 asks once which provider to
use, records the answer in `.wp-create.json` as `"image provider"` (a decline is recorded
as `"none"` and is not re-asked), shows a cost table, and generates on a yes. The key is
read from the environment in-process only — never a CLI argument, never written to
`.wp-create.json`, never logged. A missing key stops the build naming the variable to
export rather than falling back to a placeholder. See **Generated images** in the README
for where to set the variable. Plates are content-hashed on prompt, aspect and model, so a
verify round never re-bills, and an edited prompt regenerates instead of serving a stale
image. `/wp-yolo` never generates; it consumes plates already on disk.

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

---

## Path B

Builds the theme one piece at a time from `demo/index.html`.

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

Eight machine findings, six blocking and two advisory. Blocking: `dead-scroll` (a
`pin`/`pan`/`kinetic`/`wipe`/`drift` section where consecutive sampled positions show nothing
moved — including nothing samplable at all, the `file://`-blocked-engine case — or a
`reveal`-only section whose child does not move between just-below-the-fold and fully-entered,
unless `demo/BRIEF.md` records the silence as authored), `no-engine` (a page carrying zero
`data-motion` devices — counted document-wide, so a plain `<section>` on a page that does move
reports nothing at all), `container-noop` (an `@container` rule whose subject has no ancestor
declaring `container-type`, so the rule never applies — collected at any nesting depth, including
inside `@media`, `@supports` and `@layer`), `cue-never-peaks` (a cue that never
reaches full opacity), `overflow` (horizontal), and `clipped-copy` (copy clipped by its own
hidden-overflow box). Advisory — printed with `[advisory]`, written to `findings.json` with
`"advisory": true`, never raise the exit code: `unobserved` (a section whose own devices the walk
could not read — counted inside that section's subtree, so a section carrying only pointer
devices reports this instead of `dead-scroll`; the harness still cannot tell it apart from a
section that truly does not move) and
`external-module` (a `<script type="module">` that would silently fail to boot under `file://`
instead of the HTTP server this walk uses). The craft loop in `/wp-demo` treats the six blocking
kinds as round failures and writes `demo/FAILED.md` at the three-round cap; `unobserved` and
`external-module` never do.

Four exit codes: `0` no blocking findings (zero findings, or advisory only), `1` a blocking
finding was printed, `2` no usable browser, `3` the walk itself crashed (not a findings report).
On exit code 2, fall back in order: the Chrome or Playwright MCP screenshot tools if either is
connected, otherwise ask the user for screenshots at the five viewports. On exit code 3, report
the crash rather than reading the run as clean.

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
/wp-audit [--security] [--seo] [--a11y] [--performance] [--best-practices] [--geo]
          [--usability] [--all] [--report-only] [--report md|html|both] [--report-lang en|es]
          [--suite] [--pages <list|auto|none>]
          [--host <public-url>] [--security-level basic|recommended|maximum]
```

No category flag = all. Security installs/configures All-in-One WP Security; SEO installs
Rank Math and seeds meta/schema. `--report-only` skips fixes. Lighthouse-style checks need
a browser automation tool; without one they report `UNMEASURED` and every file-scan check
still runs.

`--report` writes the run as a dated deliverable under `.wp-audit/` — `informe-<date>.md`
to work with and version, and `informe-<date>.html`, a single self-contained file that
opens with a double click, forwards as an attachment and prints to PDF. It is written
before the fix phase, always: the dated report is the baseline the next audit is measured
against, and a run that fixes first has no before to compare with. A machine sidecar goes
beside them, and the next report opens with resolved / new / still failing against it — by
finding identity, not by count, so fixing one issue and finding another no longer reads as
no change.

`--usability` audits whether a person can use the site — the categories the other six
auditors do not own: forms and data entry, navigation and task flow, links followed rather
than inferred, hover and active states, rendered line length per breakpoint, and whether
the logo and the type scale hold still between templates. `wp-audit-ux` owns it and
`skills/wp-audit-ux-standards/SKILL.md` holds the `UX-NNN` catalog. Contrast, focus and
target size are not here: they are `wp-audit-a11y`, and two codes for one defect inflate
every count.

It is the one auditor whose scope is a list of URLs rather than the theme directory, so
`--pages` fixes that list. `auto` derives it from the manifest, the primary menu, the
sitemap or the home page's links, in that order, and always adds the 404 and any page with
a form — a third of the catalog lives on those two and no ranking finds them. The list is
capped at eight pages, one per template, and the cap is printed. **A page-level criterion
with no page list reports `UNMEASURED`, never `PASS`**, because an audit that measured
nothing and printed no failures reads exactly like a clean site.

With a page list the report scores: criteria passed over criteria that applied, per page
and overall. `N/A` and `UNMEASURED` are both excluded from the denominator and reported
beside it — the first because a site is not worse for lacking a feature it never had, the
second because it is work outstanding and folding it into either side hides it.

`--suite` runs the browser half of the audit as a generated Playwright project instead of
depending on a browser tool being present in the session — axe-core for accessibility,
Lighthouse for the desktop and mobile scores and Core Web Vitals, and the criteria that
only exist in a rendered page: contrast as measured, line width per breakpoint, a form's
validation, a link followed rather than inferred. It scaffolds `.wp-audit/suite/` from
`templates/audit-suite/` and installs the dependencies once per machine into a shared
cache, so the second audit on a machine is not as expensive as the first. Without Node or
npm it skips cleanly and Tier 3 reports `UNMEASURED`, which is what an absent browser tool
already did.

Its `audit.config.js` is written once and then left alone: it carries the selectors
somebody inspected the real DOM to find, and a scaffold that overwrote it every run would
re-measure a different site without saying so.

Where a measured finding and a code finding describe the same **check and the same
resource**, the measurement wins and the superseded source is noted in its evidence —
otherwise one defect is reported twice and every count is inflated. This is not done by
hand: `bin/audit-report.mjs --merge` folds the suite's run file into the agents' and prints
how many collided. A shared check with a *different* resource is two real findings — a
contrast failure measured on `/contact/` and one in a stylesheet rule no audited page uses
are not the same defect, and the second is the one nobody would find again.

Its plan gives every row an owner, which is the column that answers how much of the work
is yours: `code` is a theme file and **travels with the commit**; `setting` is a WordPress
option, a plugin's configuration or a server rule, applied here with WP-CLI and **left
behind by the commit**, so it is a step to repeat on staging and production where there is
no WP-CLI; `content` needs a person to write a text; `manual` needs judgment or an external
tool. `--report-lang` picks the language of the document, since a client reads it and not
the person who ran the audit.

`--geo` audits Generative Engine Optimization and AI-agent readiness. It detects the site
type first — content, local business, merchant or SaaS — and gates each check on that, so a
shop's payments codes and a SaaS's API codes are reported `N/A` rather than failed. The
`wp-audit-geo` agent runs the code-only checks, then scores the live site's ORA layers
against the public is-agentic report and maps the failed checks back to GEO codes. Only a
returned report yields a score. A project whose manifest holds a development URL — every
project developed locally — cannot be scanned at that address, so pass the public one with
`--host <public-url>`; the flag changes only what the scanner reads, never what WP-CLI talks
to. An unreachable host is reported `UNMEASURED — configuration`, distinct from a host that
simply has no report yet, because the first has a fix and the second does not. Auto-fixable findings go to the `wp-agentic-surfaces` fixer;
off-site findings and merchant payment protocols are advisory and left alone. `/wp-yolo`
runs `/wp-audit --all --geo` and the same scan in its finish phase.

Every run starts by reconciling `.wp-create.json` against the site rather than trusting it.
Installed plugins, PHP version, web server and Lighthouse-tier availability are re-measured
and any drift is reported; `categories_run` is read back and diffed against the categories
this version offers, so a category that shipped after the project was built is surfaced as
`NEVER RUN` instead of sitting unexecuted behind an audit record that still looks complete;
a record older than 90 days is flagged stale, and findings that were found and never fixed
are re-opened rather than forgotten. A recorded decision that is missing — `i18n strategy`,
`demo mode` — is reported as an unknown with whatever the site actually shows, never
silently defaulted: a Polylang site classified `suffix` by a fallback takes the wrong branch
in every downstream command.

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

### `/wp-adopt`

```
/wp-adopt [wordpress-root] [--wrapper="docker exec <container> wp --allow-root"]
```

Registers a site that was not built with `/wp-create`, for example a client site on a
commercial theme or an inherited install. It runs one read-only WP-CLI probe, proposes the
values below, and has the operator confirm them:

- the wrapper;
- the code scope: which code is the site's own and editable, and which is vendor code and
  read-only;
- the plugin stack: SEO, security, fields, multilingual, builder, cache;
- the function prefix.

Then it writes `.wp-create.json` with `"origin": "adopted"` and the generated block in
`.claude/CLAUDE.md`. Nothing on the site changes.

`/wp-audit`, `/wp-debug` and `/wp-clone` offer adoption themselves when they find no manifest.
On an adopted site:

- `/wp-audit` audits the editable code and the read-only code, but never fixes read-only
  code.
- It does not offer Rank Math or AIOS when the site already runs another SEO or security
  plugin.

This command is not `/wp-create`'s Adopt Mode, which reconfigures the environment.

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

### `/wp-anonymize`

```
/wp-anonymize --dry-run              # count everything, change nothing
/wp-anonymize                        # rewrite the catalog
/wp-anonymize --keep-user=yojahny    # name the account that stays logged-in-able
```

The opt-in remedy for the live customer records a clone carries. `/wp-clone` isolates mail,
cron and indexing, but the database it imported holds real people from the moment the import
finishes.

Refuses to run unless `wp-content/mu-plugins/00-clone-isolation.php` is present — the marker
`/wp-clone` Step 5.5 writes — and that gate takes no `--force`, the only refusal in the
plugin that does not. Backs up to `~/.wp-clone-backups/` on every run and stops if the export
fails, because there is no undo.

Rewrites a named catalog: `wp_users`, `wp_usermeta` billing and shipping keys, comment author
rows including the IP, and WooCommerce order addresses on both the postmeta and HPOS layouts.
Replacements are deterministic and land in `example.invalid`, a TLD RFC 2606 reserves so it
can never resolve. Order totals, dates, statuses and quantities are preserved — they carry no
identity and they are what the clone exists to debug.

Every table outside the catalog is reported by name and row count under *Not examined*, and
residue found by the verification pass is reported as a failure rather than beside a success
summary.

### `/wp-robin`

```
/wp-robin                       # auto-detect the WordPress root by walking up from here
/wp-robin /path/to/wordpress    # target an explicit root
```

Runner for the `wp-robin` skill. Reads
[`skills/wp-robin/SKILL.md`](../skills/wp-robin/SKILL.md), checks the database client and webp
converter it requires, then runs the skill's bundled `scripts/robin-fix.sh` with `WP_ROOT` set
to the resolved root. Installs and configures Robin Image Optimizer, unsticks items frozen in
`processing`, registers missing attachments, generates absent `.webp` files locally and syncs
the queue so the plugin recognizes them. The command dispatches; the skill and its script own
every step.

### `/wp-s3`

```
/wp-s3 /path/to/wordpress            # install and configure S3 Uploads
/wp-s3 /path/to/wordpress --revert   # take the site back off S3
```

Runner for the `wp-s3` skill. Reads [`skills/wp-s3/SKILL.md`](../skills/wp-s3/SKILL.md),
asks first whether the site sells downloadable products — the one case the plugin has no
clean answer for — then collects the bucket, region, media URL, optional endpoint and
credentials and runs the skill's bundled `scripts/s3-setup.sh`. That script installs
S3 Uploads with its `vendor/` tree, writes `s3-config.php` at `0640`, hooks it into
`wp-config.php` behind a backup, and installs the mu-plugin that points the plugin at an
S3-compatible endpoint. It deliberately does **not** activate the plugin and moves no
media: `/wp-s3-media` is the next step. The secret is passed in the environment, never as an
argument. `--revert` runs `scripts/s3-revert.sh`, which brings the media back to disk
*before* removing the configuration and deletes nothing in the bucket. The command
dispatches; the skill and its scripts own every step.

### `/wp-s3-media`

```
/wp-s3-media upload /path/to/wordpress --dry-run   # what would move
/wp-s3-media upload /path/to/wordpress             # migrate the library to the bucket
/wp-s3-media download /path/to/wordpress           # bring the bucket to disk
```

Runner for the `wp-s3` skill. Reads the connection out of the site's own `s3-config.php` and
runs the skill's bundled `scripts/s3-media.sh`, which mirrors `wp-content/uploads` in either
direction excluding logs, caches and the image optimizer's originals. Neither direction ever
passes `--overwrite` or `--remove`, so a file already on the other side is refused and
reported rather than replaced. The transfer is then verified by result, not by report: the
client has been measured exiting `0` after writing 7 of 38 objects and printing its summary
table against a stopped backend, so `scripts/verify-transfer.py` lists both sides and
compares names and sizes. On a server authenticating with an IAM role there is no key pair
to sign with, and the script stops and prints the two ways forward rather than guessing.

### `/wp-aos-animator`

```
/wp-aos-animator                                        # whole active theme
/wp-aos-animator <theme-path> template-parts/section-*.php   # scoped to specific templates
/wp-aos-animator --report-only                          # audit only, writes nothing
```

Runner for the `wp-aos-animator` skill. Reads
[`skills/wp-aos-animator/SKILL.md`](../skills/wp-aos-animator/SKILL.md) and sequences its
audit → install → enqueue → init → animate pipeline, dispatching one subagent per template for
the animate phase. `--report-only` stops after the audit, the same contract as `/wp-audit`'s
flag. Intended for **plain** demos: a craft project already carries GSAP motion in its theme
bundle, so the command asks before adding a second motion system.

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

## The action skills

`wp-robin`, `wp-aos-animator` and `wp-s3` are the plugin's only skills that perform work
rather than inform. Like every skill here they are `user-invocable: false`, so they are
invoked through their runner commands — [`/wp-robin`](#wp-robin),
[`/wp-aos-animator`](#wp-aos-animator), and [`/wp-s3`](#wp-s3) with
[`/wp-s3-media`](#wp-s3-media). The commands parse arguments and dispatch; the skills keep
owning the procedure. Describing the task in plain language still works and loads the same
skill.
