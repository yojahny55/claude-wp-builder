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

**Reconciled** on September 19, 2026 against `main` at v1.24.0. Every item below was
checked against the command, agent or script that would own it — an item claiming to be
open while the behavior ships reads as a project that does not know what it has built.
Larger reworks of delivered behavior are proposals, not backlog items, and are tracked
separately by the maintainer.

That date is now checked mechanically. The first reconciliation went stale in a single
day: three releases shipped a clone anonymiser, resumable builds, a findings ledger, ACF
nesting and a WordPress fixture, and not one of them appeared here. Reconciling by hand
and remembering to do it again is the same arrangement that produced the drift, so
`tests/checks/backlog-freshness.sh` fails when the newest release in `CHANGELOG.md` is
dated after the line above. It cannot tell whether the reconciliation was any good — only
that one happened.

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
  **Gap:** baselines, tolerances and an approval step now exist, but only over the motion fixtures. [visual-baselines](tests/checks/visual-baselines.sh) renders inside a pinned Playwright container, diffs against committed PNGs at a 0.1% tolerance and prints the percentage on every shot; [baseline-approval](tests/checks/baseline-approval.sh) requires a `baseline: <why>` subject on any commit that changes them. What is still missing is the comparison I06 actually names — a built section against the demo it came from — which needs a generated site, the same gap the audit corpus waits on. The fixtures here are geometric, so these baselines see layout move and would not see a colour or font change.

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
  When `/wp-section blog` is built, automatically run `/wp-page blog` to generate `archive.php`, `single.php`, and blog-specific templates. [wp-page](commands/wp-page.md) already builds the blog page type; the dispatch from [wp-section](commands/wp-section.md) does not exist.

- [ ] **Legal pages: create and seed content** `PARTIAL`
  **Gap:** [wp-page](commands/wp-page.md) generates the `legal` template, and [wp-finalize](commands/wp-finalize.md) treats a stub privacy page as a trust gap rather than a pass. Neither creates the Privacy Policy / Terms / Cookie Policy pages nor seeds industry-appropriate content from the project's `CLAUDE.md`.

- [ ] **Blog language field** `OPEN`
  Add an SCF field to blog posts for selecting the post language; archive templates filter by the active language. Note this only applies under `i18n strategy: suffix` — the Polylang model already carries language per post. No owner exists: [wp-acf](agents/wp-acf.md) would emit the field and [wp-page](commands/wp-page.md) the archive filter, and neither does today.

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

- [x] **Verify form delivery end to end** `DELIVERED`
  [wp-cf7-delivery](tests/checks/wp-cf7-delivery.sh) creates a real CF7 form in the WordPress fixture, serves the site, and posts to CF7's own REST endpoint: a valid submission is accepted and its mail captured by a `pre_wp_mail` sink with the right recipient and an interpolated body, and a submission missing a required field is refused and sends nothing.

- [x] **Walk the default-motion branch** `DELIVERED`
  [motion-devices](tests/checks/motion-devices.sh) now drives both paths. Under default motion it loads the real pinned GSAP from `node_modules` and asserts the rail's transform tracks scroll and that the JS `reveal` branch hides its children and then shows them — reached by forcing `CSS.supports('animation-timeline', …)` to report false, since every browser the suite can run supports it and the CSS engine would otherwise take over.

- [ ] **Broken-site corpus with expected audit findings** `OPEN`
  A fixture site seeded with known defects and a file of the findings an audit should report. Without it no test can fail because an audit *missed* a defect — the ceiling CLAUDE.md records for the whole audit family. No owner exists yet; it would build on [provision.sh](tests/fixtures/wp/provision.sh), which already stands up a disposable WordPress for the translation and CF7 suites.

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

- [x] **Continuous integration** `DELIVERED`
  [ci.yml](.github/workflows/ci.yml) runs every contract check, `node --check`, a version-pinned `php -l` (7.4, with `__cinematic__` at 8.0) and [doc-sync-check](bin/doc-sync-check.sh) on every pull request. Shipped in v1.19.0.

- [x] **Disposable WordPress fixtures** `DELIVERED`
  [provision.sh](tests/fixtures/wp/provision.sh) builds a pinned WordPress with Polylang and SCF against a CI service container or a local docker container, and [wp-polylang-integration](tests/checks/wp-polylang-integration.sh) runs the ACF translation path inside it and tears it down. Skips unless `WP_FIXTURE=1`. Shipped in v1.22.0.

- [x] **Anonymise a clone's customer records** `DELIVERED`
  [wp-anonymize](commands/wp-anonymize.md) replaces a named catalog with deterministic fakes in a reserved TLD, refuses to run on anything it cannot prove is a clone, and reports every table it did not examine. Shipped in v1.21.0.

- [x] **Resumable builds** `DELIVERED`
  [wp-yolo](commands/wp-yolo.md) `--resume` continues an interrupted build from a ledger at `demo/.yolo-progress.json`, skipping a unit only when the ledger records it and its artifact is still on disk. Shipped in v1.21.0.

---

## Future Ideas

Longer-term features and exploration areas.

- [ ] **Playwright-based visual QA loop** `OPEN`
  Screenshot each built section, pixel-diff it against the demo, and iterate until the diff is below a threshold. This is the loop; *Visual regression testing* above is the baseline infrastructure it needs first, and [visual-baselines.sh](tests/checks/visual-baselines.sh) is now half of that. No owner exists for the loop itself.

- [ ] **WordPress.js agent** `OPEN`
  A dedicated JavaScript specialist for sliders (Swiper, Splide), animations (GSAP, AOS), form validation and interactive components. No such agent exists; the nearest owner is [wp-yolo](commands/wp-yolo.md) Step 4.6, which ports demo scripts inline. Same request as *Fix agents being lazy with JavaScript* above — that item records what already ships.

- [ ] **Multi-platform support** `OPEN`
  Explore supporting Cursor, Gemini CLI (Codex), and other AI coding tools alongside Claude Code. The plugin architecture (markdown commands/agents/skills) may be adaptable.

- [x] **Tailwind build integration** `DELIVERED`
  The `__tailwind__` starter ships `package.json` and the Tailwind v4 build; [wp-tailwindify](commands/wp-tailwindify.md) converts a demo's CSS and [wp-tailwind-migrate](commands/wp-tailwind-migrate.md) migrates an existing theme. Duplicate of *Detect and support Tailwind CSS* above.

---

> **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, suggest improvements, and submit pull requests.
