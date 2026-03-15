# Changelog

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
