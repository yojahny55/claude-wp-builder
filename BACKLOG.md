# Backlog

Product backlog for Claude WP Builder. Items are organized by category, prioritized within each section, and tagged with status.

**Status tags:**
- `DELIVERED` — shipped; the item links the files that own the behavior
- `PARTIAL` — some of it shipped; the item names the behavior that is still missing
- `OPEN` — not started
- `BLOCKED` — waiting on an external dependency or decision

The checkbox is the delivery state: `- [x]` means `DELIVERED`, everything else is
unchecked. A `PARTIAL` item is unchecked because the remaining gap is the item.

**Priority:** Items within each section are ordered by priority (highest first).

**Reconciled** on September 18, 2026 against `main`. Every item below was checked
against the command, agent or script that would own it — an item claiming to be open
while the behavior ships reads as a project that does not know what it has built.
Larger reworks of delivered behavior are proposals, not backlog items, and are tracked
separately by the maintainer.

---

## Bugs & Fixes

Issues discovered during testing that need to be resolved.

- [ ] **Fix anchor links in SCF URL fields** `OPEN`
  Hash-only links (`#section`) can't be stored in ACF `url` type fields since they require a full URL. Use `text` type for anchor-only links, or validate and prepend the site URL.
  [wp-acf](agents/wp-acf.md) emits `'type' => 'url'` with no anchor-only branch.

- [ ] **Fix desktop breakpoint rules in responsive CSS** `PARTIAL`
  Agents sometimes generate incorrect desktop overrides. Example: `.mobile-nav-footer` should be `display: none` on desktop, `.mobile-nav-links` should use `display: contents` for inline flow. Mobile media query must override both.
  **Gap:** [wp-demo-verify](commands/wp-demo-verify.md) screenshots 7 viewports and catches the result, but nothing in [wp-css](agents/wp-css.md) states the rule, so the defect is detected rather than prevented.

- [ ] **Fix agents being lazy with JavaScript** `PARTIAL`
  Consider adding a dedicated `wp-js` agent that handles JavaScript conversion, enqueueing, and event binding specifically.
  **Gap:** [wp-yolo](commands/wp-yolo.md) Step 4.6 ports every demo script and is the contract that closed the laziness. No dedicated agent exists, and `/wp-section` carries no equivalent step — a single-section build still has no JS contract. See also *WordPress.js agent* under Future Ideas, which is the same request.

- [x] **Fix ACF location rule for front-page.php** `DELIVERED`
  [wp-acf](agents/wp-acf.md) mandates `page_type == front_page` over `page_template == front-page.php`, with the reason: ACF derives `page_type` from `is_front_page()`, so the template-meta rule never matches and the group silently disappears from the editor.

---

## Demo Fidelity

Ensuring the WordPress output matches the demo HTML 1:1 in appearance and content.

- [ ] **Visual regression testing with Playwright** `PARTIAL`
  After each section build, take screenshots at key viewports and compare against the demo. Loop fixes until the section matches the demo visually.
  **Gap:** [demo-verify](bin/demo-verify.mjs) measures layout and motion and captures screenshots; [tailwindify-parity](bin/tailwindify-parity.mjs) compares computed styles during conversion. Neither stores an approved baseline image or diffs pixels against one, so a color or spacing regression passes. Baselines and tolerances are the remaining work.

- [x] **Enforce CSS match from demo** `DELIVERED`
  Transcription mode (`--transcribe`, `/wp-yolo`) makes agents copy the demo's exact declared values instead of re-authoring them — [wp-css](agents/wp-css.md), [wp-template](agents/wp-template.md), [wp-section](commands/wp-section.md). The Layer 1 demo-parity gate in [wp-finalize](commands/wp-finalize.md) blocks delivery on a font or background mismatch.

- [x] **Enforce JS match from demo** `DELIVERED`
  [wp-yolo](commands/wp-yolo.md) Step 4.6 ("Behaviour carry — port ALL of the demo's JavaScript") enumerates the demo's scripts and requires each to be converted, enqueued and bound.

- [x] **Import images into WordPress media library** `DELIVERED`
  `wp media import` plus attachment-ID assignment is contracted in [wp-seed](commands/wp-seed.md), [wp-finalize](commands/wp-finalize.md) and [wp-cli-patterns](skills/wp-cli-patterns/SKILL.md).

- [x] **Seed SCF fields with demo content** `DELIVERED`
  [wp-seed](commands/wp-seed.md) fills fields with the demo's real text, links and imported attachment IDs via `update_field()`.

- [x] **Post-finalize demo comparison** `DELIVERED`
  [wp-finalize](commands/wp-finalize.md) runs a 3-layer demo-parity gate — static theme files, WP-CLI when WordPress is reachable, and rendered output. Every Layer 1 check is critical and a FAIL blocks delivery.

- [x] **Load fonts from the demo** `DELIVERED`
  [wp-init](commands/wp-init.md) Step 4.5 (Font carry) self-hosts every family the theme names, Google Fonts included. The starter's default token is a system stack, so no build names a font it has not carried.

- [x] **Detect and support Tailwind CSS** `DELIVERED`
  `__tailwind__` starter theme with a Tailwind CSS v4 build pipeline, `/wp-tailwindify` for CSS-to-Tailwind conversion, and template selection in `/wp-init`. Shipped in v1.4.0.

---

## Content Seeding & Pages

Improving how content is created, organized, and populated.

- [ ] **Auto-trigger `/wp-page blog` for blog sections** `OPEN`
  When `/wp-section blog` is built, automatically run `/wp-page blog` to generate `archive.php`, `single.php`, and blog-specific templates. The page type exists; the dispatch from `/wp-section` does not.

- [ ] **Legal pages: create and seed content** `PARTIAL`
  **Gap:** [wp-page](commands/wp-page.md) generates the `legal` template, and [wp-finalize](commands/wp-finalize.md) treats a stub privacy page as a trust gap rather than a pass. Neither creates the Privacy Policy / Terms / Cookie Policy pages nor seeds industry-appropriate content from the project's `CLAUDE.md`.

- [ ] **Blog language field** `OPEN`
  Add an SCF field to blog posts for selecting the post language; archive templates filter by the active language. Note this only applies under `i18n strategy: suffix` — the Polylang model already carries language per post.

- [ ] **Placeholder content for empty elements** `PARTIAL`
  **Gap:** [wp-finalize](commands/wp-finalize.md) refuses `href="#"` in delivered markup and flags a stub privacy page. Nothing seeds obvious placeholder values for social icons or phone numbers when the demo has none, so those elements are simply absent rather than flagged in the report.

- [x] **Multi-page demo support** `DELIVERED`
  [wp-normalize](agents/wp-normalize.md) splits an arbitrary multi-page site into the canonical demo format; [wp-yolo](commands/wp-yolo.md) and [wp-seed](commands/wp-seed.md) generate the corresponding pages, templates and navigation.

- [x] **Custom post types from demo structure** `DELIVERED`
  [wp-cpt](commands/wp-cpt.md) registers the CPT and generates fields, archive, single, an optional teaser query-section and a seed helper. `--from-demo <section-name>` derives it from a demo section.

- [x] **Generate site tagline** `DELIVERED`
  [wp-init](commands/wp-init.md) Step 9 (Site Identity) writes `blogname` and `blogdescription` from the demo-extracted or prompted tagline. Under `i18n strategy: polylang` the secondary language is left to `/wp-polylang`, which exports both as registered strings.

---

## Workflow & UX Improvements

Making the command flow smoother and more guided.

- [ ] **Section list command** `PARTIAL`
  **Gap:** [wp-init](commands/wp-init.md) parses the delimiters and prints the detected sections as part of its own run. There is no standalone command or flag that lists them without initializing a theme.

- [ ] **Screenshot generation with Playwright** `PARTIAL`
  **Gap:** [wp-finalize](commands/wp-finalize.md) checks that `screenshot.png` exists, and both starters ship one. Nothing regenerates it at 1200x900 from the built homepage, so a delivered theme's preview image is the starter's, not the site's.

- [ ] **Maintenance mode command** `OPEN`
  New `/wp-maintenance` command to enable/disable maintenance mode — either via a custom template or by installing a maintenance plugin via WP-CLI.

- [ ] **Favicon command** `OPEN`
  New `/wp-favicon` command that takes any image, generates all required favicon sizes (16x16, 32x32, 180x180, 192x192, 512x512), creates `favicon.ico`, generates `site.webmanifest`, and sets the site icon via `$WP option update site_icon`.

- [x] **Suggest next command after each step** `DELIVERED`
  [wp-header](commands/wp-header.md) and [wp-section](commands/wp-section.md) end by naming the next command to run.

- [x] **Suggest `/wp-polish` from `/wp-init`** `DELIVERED`
  [wp-init](commands/wp-init.md) runs `/wp-polish` when the demo has no section delimiters, and also when some sections appear to be missing them.

- [x] **Git integration in `/wp-init`** `DELIVERED`
  [wp-init](commands/wp-init.md) Step 9.5 runs `git init` and writes a `.gitignore`; Step 9.6 adds `.wp-create.local.json` so generated credentials are never committed.

---

## Agent Quality

Improving the reliability and output quality of agents.

- [ ] **Logo from demo path** `OPEN`
  [wp-header](commands/wp-header.md) reads the logo from the settings field with a `get_bloginfo('name')` fallback, but nothing extracts the logo image from the demo HTML, imports it, and populates that field — so the fallback is what a fresh build shows.

- [x] **SCF field labels in site primary language** `DELIVERED`
  [wp-acf](agents/wp-acf.md) requires group titles, tabs and instructions in the project's primary language, never mixed, and orders them to match the page.

- [x] **Menu creation and assignment** `DELIVERED`
  [wp-seed](commands/wp-seed.md) creates the menus, assigns them with `wp menu location assign`, and writes the per-language Polylang `nav_menus` mapping — including the `nav_menu_locations` theme_mod that Polylang itself never sets.

- [x] **CF7 dynamic site info** `DELIVERED`
  [wp-cf7](agents/wp-cf7.md) renders `%%site_logo%%`, `%%contact_email%%`, `%%contact_phone%%` and `%%copyright%%` from settings at render time.

- [x] **CF7 email styling** `DELIVERED`
  [wp-cf7](agents/wp-cf7.md) generates branded admin and confirmation templates using the `frontend-design` skill.

---

## Environment & Configuration

Server setup, permissions, and WordPress configuration.

- [x] **Set `FS_METHOD` to `direct`** `DELIVERED`
  Handled by `/wp-audit --security`.

- [x] **Fix file/folder permissions** `DELIVERED`
  `wp-content/uploads/`, `plugins/` and `upgrade/` ownership and permissions, handled by `/wp-audit --security`.

- [x] **CSS optimization: per-page enqueueing** `DELIVERED`
  Handled by `/wp-audit --performance`.

- [x] **Replace Yoast SEO with Rank Math** `DELIVERED`
  Plugin profiles updated; Rank Math auto-configured by `/wp-audit --seo`. Shipped in v1.3.0.

- [x] **Security & audit command** `DELIVERED`
  `/wp-audit` with security, SEO, accessibility, performance, GEO and best-practices categories. Shipped in v1.3.0.

---

## Future Ideas

Longer-term features and exploration areas.

- [ ] **Playwright-based visual QA loop** `OPEN`
  Screenshot each built section, pixel-diff it against the demo, and iterate until the diff is below a threshold. This is the loop; *Visual regression testing* above is the baseline infrastructure it needs first.

- [ ] **WordPress.js agent** `OPEN`
  A dedicated JavaScript specialist for sliders (Swiper, Splide), animations (GSAP, AOS), form validation and interactive components. Same request as *Fix agents being lazy with JavaScript* above — that item records what already ships.

- [ ] **Multi-platform support** `OPEN`
  Explore supporting Cursor, Gemini CLI (Codex), and other AI coding tools alongside Claude Code. The plugin architecture (markdown commands/agents/skills) may be adaptable.

- [x] **Tailwind build integration** `DELIVERED`
  The `__tailwind__` starter ships `package.json` and the Tailwind v4 build; [wp-tailwindify](commands/wp-tailwindify.md) converts a demo's CSS and [wp-tailwind-migrate](commands/wp-tailwind-migrate.md) migrates an existing theme. Duplicate of *Detect and support Tailwind CSS* above.

---

> **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, suggest improvements, and submit pull requests.
