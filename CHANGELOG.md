# Changelog

## [Unreleased]

### Added
- **Polylang as a first-class translation model, selectable at scaffold time.** `/wp-init` now asks which i18n strategy a project uses and records the answer as `i18n strategy` in its `.claude/CLAUDE.md`; `_suffix` remains the Enter-key default so existing projects and non-interactive callers are unaffected. Choosing Polylang installs and activates the plugin, creates the languages through the same `pll-setup.php` the retrofit command uses, assigns the primary language to existing content, and swaps in a per-template Polylang variant of `inc/i18n.php`. Every downstream step branches on the recorded strategy: `/wp-seed` builds a counterpart page per language from the demo's own secondary-language copy and hands the remainder to `/wp-polylang`, `/wp-header` registers one menu location per name and renders `pll_the_languages()`, the `wp-acf` agent stops emitting `_<lang>` duplicate fields outside the settings group, and `/wp-yolo` passes the strategy through and gates on the verifier.
- **`/wp-polylang`**: retrofit an existing site into a second language through the `pll_*` API — export to a manifest, translate, import, verify. Handles posts, terms, menus, attachments, ACF/SCF fields including repeaters, groups and flexible content, and re-points internal links and reference fields at their translated targets.

### Fixed
- **`/wp-polylang` import no longer corrupts real content.** Payloads handed to WordPress are slashed, so backslashes survive a round trip instead of being stripped once per cycle; a manifest naming the wrong `target_id`, another site's `site_url`, or one menu as both source and target is refused instead of overwriting live content; a child whose parent has no counterpart stays dirty for the next run instead of being permanently stranded at the site root; term hierarchies survive re-import; a trashed counterpart is detected instead of reading as fully translated; and an editor's own reference-field values are no longer re-derived away on every import.
- **`wp-bilingual` skill no longer claims the plugin does not support Polylang**, and now routes to the right skill based on the project's recorded strategy.
- **`/wp-init` no longer offers a starter template that does not exist.** "Basic Starter" was option 1 *and* the Enter-key default while `starter-theme/__starter__/` had been removed as superseded by Tailwind, so the most likely path through the command copied a missing directory. Tailwind is now the default, `basic` is accepted as an alias, and `tests/checks/wp-init-templates.sh` compares the command against the filesystem so it cannot rot again.

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
