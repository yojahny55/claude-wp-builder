

<div align="center">

# Claude WP Builder

**Demo HTML to production WordPress theme — automated.**

[![Version](https://img.shields.io/badge/version-1.16.0-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)

A Claude Code plugin that turns approved demo HTML into a complete WordPress theme — section by section, with ACF/SCF fields, bilingual support, SEO, and security — all from the command line.

[Quick Start](#installation) | [Workflows](docs/workflows.md) | [Commands](docs/commands.md) | [Architecture](#architecture) | [Cinematic Mode](docs/cinematic-mode.md) | [Contributing](CONTRIBUTING.md) | [Backlog](BACKLOG.md)

</div>

---

### How It Works

You always start from a **demo**: a static HTML page (or folder of pages) that the client
approves first. The plugin then transcribes that demo into a WordPress theme. It never
invents design, so there is no path that begins at WordPress.

```
SETUP    /wp-create (optional)  →  /wp-init  →  /wp-context (optional, auto when docs/ exists)
                                       │
DEMO     have a mockup?   →  /wp-init path/to/mockup.html   (reads it, skips the interview)
         files in demo/?  →  /wp-polish demo/index.html
         nothing yet?     →  /wp-demo  |  /wp-cinematic-demo
                                       │
BUILD    A. /wp-yolo demo/            — whole multi-page demo → theme in one pass (runs B for you)
         B. /wp-header → /wp-footer → /wp-section … → /wp-page … → /wp-seed   (one piece at a time)
         C. /wp-cinematic-init → -encode → -scene → -seed         (scroll-driven video reel)
                                       │
FINISH   /wp-finalize  →  /wp-demo-verify  →  /wp-audit (optional)
```

Full walkthrough of each path, with what is required, optional or automatic:
**[docs/workflows.md](docs/workflows.md)**.

## Installation

### Option 1: Plugin Marketplace (Recommended)

**Step 1 — Add the marketplace:**

```
/plugin marketplace add yojahny55/claude-wp-builder
```

**Step 2 — Install the plugin:**

```
/plugin install claude-wp-builder@claude-wp-builder
```

Or use the interactive UI: run `/plugin`, go to the **Discover** tab, and select **claude-wp-builder**.

### Option 2: Direct from CLI

```bash
claude --plugin-dir /path/to/claude-wp-builder
```

### Option 3: Project-level auto-install

Add to your project's `.claude/settings.json` so all collaborators get it automatically:

```json
{
  "extraKnownMarketplaces": {
    "claude-wp-builder": {
      "source": {
        "source": "github",
        "repo": "yojahny55/claude-wp-builder"
      }
    }
  },
  "enabledPlugins": {
    "claude-wp-builder@claude-wp-builder": true
  }
}
```

## Workflow

**Every path builds from a demo.** The demo is not a step in one recipe, it is the source
of truth the WordPress build transcribes: `/wp-init` reads it to learn the project,
`/wp-yolo` converts it page by page, `/wp-section --transcribe` copies its declared values,
and `/wp-seed` turns its files into WP Pages. There is no path that starts at WordPress.

### Setup (every path)

```
/wp-create --path=/var/www/html/my-project   # optional: local WordPress + .wp-create.json (needed later by /wp-seed)
/wp-init                                     # required: asks template (tailwind, the default | cinematic), fields plugin
                                             #           (scf, the default | acf), i18n strategy (polylang, the default | suffix).
                                             #           Press Enter through all three to take the defaults. Recorded in .claude/CLAUDE.md
/wp-context                                  # optional: reads docs/ (scope sheets, design PDF) → constraints + scope manifest.
                                             #           /wp-init runs it automatically when docs/ exists
```

If you already hold a mockup, pass it straight to `/wp-init` (next section) instead of
running it bare — it will read the project details out of the file rather than asking you.

### Get a demo (every path, before any WordPress work)

Three ways in. Pick the one that matches what you already have.

```
# 1. You already have a mockup (client HTML, a Figma export, anything)
/wp-init path/to/mockup.html    # copies it to demo/index.html, polishes it if it has no
                                # section delimiters, and reads the project name, industry,
                                # colours and fonts OUT of the demo instead of asking you

# 2. You have files already sitting in demo/
/wp-polish demo/index.html      # adds section delimiters, semantic HTML5, BEM classes.
                                # /wp-init also offers to adopt an existing demo/index.html

# 3. You have nothing yet
/wp-init                        # answer the project questions first, it writes .claude/CLAUDE.md
/wp-demo                        # then generate demo/index.html from a brief (needs that file)
/wp-cinematic-demo              # or the video-reel equivalent on the cinematic path
```

Order matters in one direction only: `/wp-demo` needs `.claude/CLAUDE.md`, so it runs
*after* `/wp-init`. Going the other way, when you already hold a mockup, hand it to
`/wp-init` directly and skip the interview.

A multi-page site is the same thing with more files: put every page in `demo/` and Path A
converts the folder in one pass.

### Path A — full demo folder in one pass

**Needs:** a `demo/` folder holding every page of the site, from the stage above. This is
the fastest path when a client sends you a complete multi-page HTML site.

```
/wp-yolo demo/                    # checkpoint after normalization, then hands-off
/wp-yolo demo/ --yolo             # no checkpoint
/wp-yolo demo/ --careful          # confirm each inner page
```

Normalizes every page, reconciles it against `docs/.scope-manifest.json` (IDX/plugin pages
become embed shells, out-of-scope pages are skipped), then drives `/wp-settings` → `/wp-cpt`
→ `/wp-header` → `/wp-footer` → `/wp-section --transcribe` per section → `/wp-seed` →
`/wp-finalize` → `/wp-polish` → `/wp-demo-verify`, and finishes with a demo-parity gate that
auto-fixes mechanical drift and blocks on anything it cannot fix. You run nothing else.

### Path B — step by step

**Needs:** `demo/index.html` from the stage above. Pick this when you want to review each
piece as it is built, or when the site is one page.

```
/wp-header                        # required
/wp-footer                        # required
/wp-section hero                  # required, once per demo section
/wp-section contact               # contact* names wire Contact Form 7 automatically
/wp-page blog|legal|404|search|generic|custom <name>|embed <name>   # optional
/wp-cpt team                      # optional; before any section that lists that type
/wp-settings "add a newsletter URL"   # optional
/wp-seed                          # fills pages, media, fields, menus (needs .wp-create.json)
```

`/wp-demo` picks craft or plain mode from the project's docs (`--craft`/`--plain` override it)
and records the answer as `demo mode` in `.wp-create.json`. Craft mode needs a browser
(`playwright-core` plus Chrome; `demo-verify.mjs --probe` checks both and `/wp-demo` stops on a
missing one), writes `demo/DESIGN.md` from the client docs, `npx designlang@12` and a vendored
catalogue of 64 real-brand DESIGN.md files, classifies the client's domain against a vendored
192-row table to constrain which section roles the composition plan may pick (never the tokens),
and inventories every image, SVG and font under `docs/` into `demo/BRIEF.md` with a role, used
or named with a reason. It builds every section from the plugin's composition library — every
composition's size-based breakpoints are `@container` queries against its own container rather
than the viewport, and its fluid ramps in `clamp()` read `cqi` and track that container too,
except for three: two hero headlines sized against the screen on purpose, and one
root `gap` that cannot be `cqi` because its own rule declares the container — and loops
on `npx -y impeccable@4 detect`, a seven-line critique rubric, and a `demo-verify.mjs` walk
(served over HTTP, not `file://`; `no-engine` and `container-noop` join `dead-scroll` as
blocking findings, `unobserved` and `external-module` stay advisory) for at most three rounds. A
build still failing at the cap writes `demo/FAILED.md` — every failing rubric line, every
outstanding finding, the round count reached — and `/wp-init`, `/wp-section` and `/wp-yolo`
refuse to build a theme from it. Plain mode is the existing single-file demo with no motion
contract, for an admin tool, intranet or catalogue. Nothing paid is involved.

### Path C — cinematic

`/wp-cinematic-init` → `/wp-cinematic-demo` → `/wp-cinematic-encode` per video →
`/wp-cinematic-scene` per scene → `/wp-cinematic-seed`. See [docs/cinematic-mode.md](docs/cinematic-mode.md).

### Finish (every path)

```
/wp-finalize                              # pre-delivery report (never fixes)
/wp-demo-verify http://localhost/site     # scroll-walks the live site, 5 viewports, contact sheet
/wp-audit [--security --seo --a11y --performance --best-practices] [--report-only]
/wp-polylang es en                        # only when i18n strategy is polylang
```

`/wp-responsive-check` still works: it is an alias that runs `/wp-demo-verify`.

### More on the demo

`/wp-polish` normalizes any HTML into a plugin-compatible demo: detects sections, adds
section delimiters, semantic HTML5 and BEM classes. It preserves an unpolished copy of the
source document at `demo/.prepolish/<source-filename>` and never overwrites a copy already there.
Run it on anything you drop into `demo/` yourself; `/wp-init` and `/wp-yolo` also run it for
you when a page arrives without delimiters, since nothing downstream can split a page without them.

`/wp-demo-verify demo/index.html` walks the demo by scrolling it and reports dead scroll,
overflow, cues that never reach full opacity and clipped copy, then hands back a contact
sheet to read. Worth running before the WordPress build, not only after.

### Generated images (optional)

A craft demo needs a photograph for the hero and feature slots. When `docs/` has no
suitable image, `/wp-demo` can generate one — but only if an API key is present in the
environment. **With no key set, nothing is asked and nothing is generated**, and the build
behaves exactly as it always has, so this is opt-in by doing nothing.

Two providers are supported. Set whichever you have:

| provider | variable | what `/wp-demo` offers |
|---|---|---|
| Google (nano banana) | `GEMINI_API_KEY` | `gemini-3.1-flash-image` |
| OpenAI (GPT Image 2.5) | `OPENAI_API_KEY` | `gpt-image-2.5-flare` (fast, cheap) or `gpt-image-2.5-sunburst` (higher quality) |

Those are what the command offers when it asks. Any other model in the same family —
`gemini-3.1-flash-lite-image`, `gemini-3-pro-image` — also works, but only if you write it
into `.wp-create.json` yourself as `"image provider": "google/<model>"`; the model string
is passed through to the API untouched.

Google is recommended, and not only on price: the compositions declare 4:5, 3:2 and 4:3
crops, which Google supports exactly. OpenAI offers three fixed sizes, so every one of
those crops is cropped again after you have paid for the pixels.

#### Where to put the key

The key must be in the environment **before Claude Code starts**. Pick one:

**Per project, and the tidiest.** Add an `env` block to `.claude/settings.local.json`
in your WordPress project — that file is personal and stays out of git (Claude Code adds
it to your global git excludes; if you created it by hand, add it to `.gitignore`
yourself):

```json
{
  "env": {
    "GEMINI_API_KEY": "your-key-here"
  }
}
```

**Per shell, for one session.** Export it, then start Claude Code from that same terminal:

```bash
export GEMINI_API_KEY="your-key-here"
claude
```

**Everywhere, always.** Put the same `export` line in `~/.zshrc` or `~/.bashrc`.

Two things that do **not** work, and one that is a mistake:

- **Exporting inside a running Claude Code session does nothing.** Each command runs in a
  fresh shell, so the variable is gone by the next one. Set it before you start.
- **`.wp-create.json` is not for the key.** It records *which provider* you chose
  (`"image provider": "google/gemini-3.1-flash-image"`), never the key itself.
- **Do not put the key in `.claude/settings.json`** (no `.local`). That file is meant to
  be committed and shared with the team.

#### What it costs, and what it does

`/wp-demo` shows a table before spending anything — one row per image, with the estimated
total — and asks once. That approval covers the whole plan; it does not ask per image. A
typical five-page build is around four images, roughly $0.40. **Those figures are
estimates**: Google publishes no per-image price, and OpenAI bills per token rather than
per image.

Re-runs are free. Each image is keyed by a hash of its prompt, aspect and model, so a
verify round or a second `/wp-demo` reuses what is on disk. Editing a prompt changes the
hash, so it regenerates rather than quietly serving the old picture.

If a slot should use a real client photograph instead, say so when the table is shown —
a real file always wins and is never regenerated.

Generated files land in `demo/assets/img/` beside a `.json` sidecar recording the model,
prompt and date, and are summarised in `demo/BRIEF.md`. Every Google image carries an
invisible SynthID watermark identifying it as AI-generated — worth knowing before these
ship to a client's production site.

`/wp-yolo` never generates images. It uses whatever is already in the demo folder, so the
one command that runs unattended cannot spend money.

## Commands Reference

Full arguments, inputs and outputs per command: **[docs/commands.md](docs/commands.md)**.

| Command | Path | Required? | Description |
|---------|------|-----------|-------------|
| `/wp-create` | all | optional* | Local WordPress environment + `.wp-create.json` |
| `/wp-init` | all | required | Scaffold theme, record template / fields plugin / i18n choices |
| `/wp-context [docs]` | all | auto | Scope + constraints from `docs/` |
| `/wp-yolo <folder>` | A | required | Whole demo folder → theme, seeded and verified |
| `/wp-demo [brief\|iterate]` | all | demo stage | Generate `demo/index.html` from a brief (after `/wp-init`) |
| `/wp-polish [path]` | all | demo stage | Normalize any HTML you already have into a demo |
| `/wp-tailwindify [path]` | A, B | auto | Demo CSS → Tailwind utilities (run by `/wp-init`, `/wp-yolo`) |
| `/wp-header` / `/wp-footer` | B | required | `header.php` / `footer.php` + settings fields |
| `/wp-section <name> [--hybrid]` | B, C | required per section | ACF fields + template part + CSS; `--hybrid` = trailing section after a cinematic reel |
| `/wp-page <type> [name]` | B | optional | blog, legal, 404, search, generic, custom, embed |
| `/wp-cpt <name>` | B | optional | Custom post type + fields + archive/single + seeder |
| `/wp-settings <text>` | B | optional | Extend the settings page |
| `/wp-seed [file]` | B | required for content | Pages, media, fields, menus from the demo |
| `/wp-finalize` | all | recommended | Pre-delivery checklist |
| `/wp-demo-verify <path-or-url> [--positions N]` | all | recommended | Scroll-walk a demo dir or live page, impeccable detector, screenshots per section and viewport, seven-line critique into demo/VERIFY.md |
| `/wp-responsive-check <url>` | all | recommended | Alias, dispatches `/wp-demo-verify` (5-viewport layout check is now one part of what it walks) |
| `/wp-audit [flags]` | all | optional | Security, SEO, a11y, performance, best practices |
| `/wp-polylang <src> <dst>` | all | polylang only | Translate the site through Polylang |
| `/wp-tailwind-migrate <theme>` | legacy | optional | Plain-CSS theme → Tailwind in place |
| `/wp-cinematic-init` | C | required | Cinematic scaffold — kit, theme, ACF scenes |
| `/wp-cinematic-demo` | C | recommended | Scroll-driven HTML demo for client approval |
| `/wp-cinematic-encode` | C | per video | ffmpeg — all-keyframe desktop MP4 + 9:16 mobile |
| `/wp-cinematic-scene` | C | per scene | Author one scene — replaces `/wp-section` on path C |
| `/wp-cinematic-seed` | C | required | Seed every scene from a manifest, idempotent |
| `/wp-debug [issue]` | utility | — | WP-CLI diagnostics and fixes |
| `/wp-clone --from --to` | utility | — | Clone a remote site locally |
| `/wp-robin [wp-root]` | utility | — | Runner for the `wp-robin` skill — install and configure Robin Image Optimizer, unstick the bulk queue, generate missing `.webp` |
| `/wp-aos-animator [theme] [--report-only]` | utility | — | Runner for the `wp-aos-animator` skill — audit, install, enqueue, initialize and seed AOS scroll animations across the templates |
| `/wp-contribute <new\|check\|pr\|release>` | contributors | — | Work on the plugin itself — scaffold a command/agent/skill with its check and doc rows, verify the repo, open the PR |

\* Optional if WordPress is already running: without `.wp-create.json`, `/wp-seed` and `/wp-debug` fall back to a bare `wp` on PATH and the languages in `.claude/CLAUDE.md`.
The `wp-robin` and `wp-aos-animator` skills are invoked through their runner commands,
`/wp-robin` and `/wp-aos-animator`. The skills stay `user-invocable: false` and keep owning the
procedure; the commands only dispatch them.

## Architecture

### Skills (auto-invoked, encode best practices)

| Skill | Purpose |
|-------|---------|
| `wp-theme-standards` | WordPress legacy theme best practices (enqueueing, escaping, hooks, security) |
| `wp-bilingual` | i18n methodology using ACF `_suffix` pattern with transparent helpers |
| `wp-polylang` | Polylang multilingual methodology — one post per language, driven through the `pll_*` API. `/wp-init` asks which model a project uses; the answer is recorded as `i18n strategy` in its `.claude/CLAUDE.md` and every downstream command branches on it |
| `wp-css-system` | CSS design system: custom properties, BEM naming, scales. Read by the `wp-css` agent, which handles the plain-CSS parts of every section |
| `wp-tailwind-system` | Tailwind authoring conventions — the utility-first decision ladder and file layout (the default template) |
| `wp-demo` | Demo HTML creation methodology |
| `wp-demo-craft` | Reference-first design floor for premium demos: a client DESIGN.md, a composition library, a motion budget and a render-verified loop |
| `wp-responsive` | Mobile-first responsive patterns, fluid typography, touch targets |
| `wp-cli-patterns` | WP-CLI best practices for all agents (saves tokens vs PHP generation) |
| `wp-aos-animator` | AOS scroll animation installer — audits, enqueues, initializes, and seeds animations across templates. Run through `/wp-aos-animator` |
| `wp-robin` | Robin Image Optimizer fixer — installs, configures, unsticks bulk optimization, generates .webp files. Run through `/wp-robin` |
| `wp-environments` | Environment detection and the WP-CLI wrapper every command runs through |
| `wp-audit-standards` | Audit criteria, severity definitions, report schema and quality thresholds for the `wp-audit-*` agents |
| `wp-audit-seo-standards` | Rank Math configuration reference, schema JSON-LD templates, meta patterns and SEO seeding commands |
| `wp-audit-geo-standards` | GEO and AI-agent-readiness reference — the ORA/is-agentic check catalog, applicability by site type, AI crawler allowlist, llms.txt/well-known specs, GEO citability rubric and WordPress implementation templates |
| `wp-contributing` | Contributing to this plugin — the layer rules, the grep-gate test style, and the PR and release rituals |

### Agents (specialized subagents dispatched by commands)

| Agent | Role |
|-------|------|
| `wp-template` | PHP/WordPress template specialist — generates template parts, pages, header, footer |
| `wp-css` | CSS design system specialist — BEM naming, custom properties, responsive |
| `wp-tailwind` | Tailwind specialist — demo conversion and section authoring on the `template=tailwind` path, replacing `wp-css` |
| `wp-acf` | ACF/SCF field architect — programmatic field definitions with bilingual support |
| `wp-cf7` | Contact Form 7 specialist — forms per language, branded mail templates, and the seeder that carries the form body |
| `wp-normalize` | Demo-folder analyzer — turns an arbitrary multi-page site into the canonical delimited demo plus a build manifest |
| `wp-context` | Project-docs analyzer — reads `docs/` and extracts constraints plus an actionable scope manifest |
| `wp-cinematic` | Cinematic scroll specialist — scene fields, template parts and scroll-engine wiring for the `__cinematic__` starter |
| `wp-audit-security` · `wp-audit-seo` · `wp-audit-a11y` · `wp-audit-performance` · `wp-audit-practices` | The five `/wp-audit` judgment auditors — code scanning, structured data, WCAG 2.1 AA, Core Web Vitals, WordPress standards |
| `wp-audit-aios` · `wp-audit-rankmath` | The two mechanical audit installers — All-in-One WP Security and Rank Math, configured via WP-CLI |

### Starter Theme

Minimal boilerplate copied by `/wp-init`. Includes:

- **i18n layer** — `prefix_get_field()`, `prefix_get_repeater()`, `prefix_t()`, `prefix_e()`, language detection (URL → cookie → browser → default)
- **Settings page** — Tabs: General, Header, Footer, Contact, Address, Social, Legal, Designer, Spanish Translations
- **CSS foundation** — Reset, custom property placeholders (colors, spacing, typography, shadows), utilities
- **JS base** — Language switcher, mobile nav, scroll animations, sticky header
- **ACF auto-loader** — `fields/*.php` files loaded automatically via `acf/init` hook

Placeholder tokens (`__starter__`, `__STARTER__`, `__STARTER_NAME__`) are replaced with the project name/slug during init.

## Conventions

### Field Naming

| Pattern | Example |
|---------|---------|
| Field names | `<section>_<element>` → `hero_title` |
| Repeaters | `<section>_<plural>` → `services_cards` |
| Subfields | `<element>` (no prefix) → `title`, `icon` |
| Field keys | `field_<section>_<element>` → `field_hero_title` |
| Group keys | `group_<section>` → `group_hero` |
| Bilingual | Append `_<lang>` → `hero_title_es` |

### CSS

- Custom properties for all design tokens (never hardcode)
- BEM naming: `.block__element--modifier`
- Mobile-first: base styles for mobile, `min-width` media queries for larger
- Section delimiters: `/* ============ Section: Hero ============ */`

### Templates

- Always use `prefix_get_field()`, never raw `get_field()`
- Fallback pattern: `$value = prefix_get_field('field') ?: 'Default';`
- All output escaped: `esc_html()`, `esc_url()`, `esc_attr()`

## Local Development

The `/wp-create` command supports multiple environment types:

| Environment | How |
|-------------|-----|
| **Docker** (default) | Ships docker-compose template with WordPress, Nginx/Apache, MariaDB, phpMyAdmin, Mailpit |
| **DDEV** | Generates `.ddev/config.yaml` |
| **Lando** | Generates `.lando.yml` |
| **wp-env** | Generates `.wp-env.json` |
| **Native Nginx** | Generates vhost + SSL cert + hosts entry |
| **Native Apache** | Generates vhost + SSL cert + hosts entry |
| **Native Caddy** | Generates Caddyfile (auto-SSL) |

**Plugin profiles** install common plugins in one WP-CLI call:
- `starter` — SCF, Rank Math SEO, WP Fastest Cache
- `full` — SCF, Rank Math SEO, WP Super Cache, All-in-One WP Security, CF7, WP Mail SMTP, Redirection, Site Kit
- Custom profiles from `.wp-profiles/` or `~/.wp-profiles/`

**Project manifest** (`.wp-create.json`) stores all config and is read by all commands/agents for WP-CLI wrapper, language config, and environment type.

## Audit & Quality

The `/wp-audit` command runs a comprehensive audit across 5 categories and offers to auto-fix issues.

### Categories

| Flag | Category | Plugin Integration |
|------|----------|--------------------|
| `--security` | Security hardening, code scanning | All-in-One WP Security |
| `--seo` | SEO optimization, schema, meta data | Rank Math SEO |
| `--a11y` | WCAG 2.1 AA accessibility | — |
| `--performance` | Core Web Vitals, caching, assets | — |
| `--best-practices` | WordPress coding standards | — |

### Three-Tier Audit

- **Tier 1 (always):** Code analysis via file scanning
- **Tier 2 (with WP-CLI):** Runtime checks, plugin configuration
- **Tier 3 (with web-quality-skills):** Lighthouse-style browser audits

### Usage

```bash
/wp-audit                    # Run all categories
/wp-audit --security --seo   # Run specific categories
/wp-audit --report-only      # Report without fixing
/wp-audit --security-level maximum  # Set AIOS security level
```

### Optional Dependencies

- [Rank Math SEO](https://wordpress.org/plugins/seo-by-rank-math/) — auto-installed for SEO audits
- [All-in-One WP Security](https://wordpress.org/plugins/all-in-one-wp-security-and-firewall/) — auto-installed for security audits
- [web-quality-skills](https://github.com/addyosmani/web-quality-skills) — optional Claude Code plugin for Lighthouse-style audits

## Tech Stack

- **WordPress** legacy theme (no blocks, no FSE)
- **ACF/SCF** for custom fields (programmatic, one file per section)
- **Tailwind CSS 4** starter (`@wordpress/scripts` build, BEM blocks for sections) — a plain-CSS `basic` path remains for older themes
- **Vanilla JS** (no frameworks); the cinematic starter adds the `cinematic-scroll-kit` scroll engine
- **Bilingual** via Polylang (default — real `/es/` URLs, hreflang, per-language meta) or field suffixes (opt-in at `/wp-init`, no SEO value for the second language)

## External Dependencies

The `/wp-demo` command works best with these skills installed. All other commands work independently.

| Skill | Repository | Install |
|-------|-----------|---------|
| `frontend-design` | [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins) | `/plugin install frontend-design@anthropics-claude-code` |
| `ui-ux-pro-max` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` |

## Roadmap

See [BACKLOG.md](BACKLOG.md) for the full product backlog. Key areas of active development:

- Visual regression testing with Playwright (demo vs WordPress comparison)
- Multi-page demo support and custom post type auto-detection
- JavaScript specialist agent for sliders, animations, and interactivity
- ~~Tailwind CSS starter theme and build pipeline integration~~ ✓ shipped in v1.4.0
- ~~Cinematic scroll-driven starter theme (WebCodecs scrub, ffmpeg encode pipeline)~~ ✓ shipped in v1.5.0

## Contributing

We welcome contributions from everyone. Whether you found a bug while building a real site, want to improve an agent, or have an idea for a new command — we'd love your help.

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to report bugs and suggest improvements
- Development setup and project structure
- Pull request guidelines and review process
- AI-assisted contribution policy

## Support

If this plugin saves you time building WordPress sites, give it a star — it helps others find it.

[![GitHub stars](https://img.shields.io/github/stars/yojahny55/claude-wp-builder?style=social)](https://github.com/yojahny55/claude-wp-builder)

<!-- Uncomment when the repo has 10+ stars for a meaningful chart:
## Star History
[![Star History Chart](https://api.star-history.com/svg?repos=yojahny55/claude-wp-builder&type=Date)](https://star-history.com/#yojahny55/claude-wp-builder&Date)
-->

## License

[MIT](LICENSE) - Yojahny

---

<div align="center">

Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

</div>
