# Changelog

## [Unreleased]

### Added
- **Cinematic starter theme** (`starter-theme/__cinematic__/`): scroll-driven WordPress theme scaffold with persistent video stage, N scene blocks, mobile autoplay-loop fork, `prefers-reduced-motion` guard, hamburger menu, and motion-toggle. Hand-author safe runtime layer (`cinematic-loader.php`, `scenes-renderer.php`, base CSS, engine JS vendored from cinematic-scroll-kit).
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
