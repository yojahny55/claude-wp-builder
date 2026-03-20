# Backlog

Product backlog for Claude WP Builder. Items are organized by category, prioritized within each section, and tagged with status.

**Status tags:**
- `NEW` — Not started
- `IN PROGRESS` — Actively being worked on
- `DONE` — Completed (kept for reference until next cleanup)
- `BLOCKED` — Waiting on external dependency or decision

**Priority:** Items within each section are ordered by priority (highest first).

---

## Bugs & Fixes

Issues discovered during testing that need to be resolved.

- [ ] **Fix ACF location rule for front-page.php** `NEW`
  Use `page_type == front_page` instead of `page_template == front-page.php`. The front-page template is auto-used by WordPress and never appears as a selectable template, so ACF fields don't show up.

- [ ] **Fix anchor links in SCF URL fields** `NEW`
  Hash-only links (`#section`) can't be stored in ACF `url` type fields since they require a full URL. Use `text` type for anchor-only links, or validate and prepend the site URL.

- [ ] **Fix desktop breakpoint rules in responsive CSS** `NEW`
  Agents sometimes generate incorrect desktop overrides. Example: `.mobile-nav-footer` should be `display: none` on desktop, `.mobile-nav-links` should use `display: contents` for inline flow. Mobile media query must override both.

- [ ] **Fix agents being lazy with JavaScript** `NEW`
  Agents sometimes skip or incorrectly convert JS from demos. Consider adding a dedicated `wp-js` agent that handles JavaScript conversion, enqueueing, and event binding specifically.

---

## Demo Fidelity

Ensuring the WordPress output matches the demo HTML 1:1 in appearance and content.

- [ ] **Enforce CSS match from demo** `NEW`
  Agents must carry over all CSS from the demo — not approximate or simplify it. The generated section CSS should reproduce the demo layout exactly. Add a post-generation comparison step.

- [ ] **Enforce JS match from demo** `NEW`
  If the demo uses JavaScript (sliders, animations, toggles), the agents must convert, enqueue, and integrate those scripts into the WordPress theme using `wp_enqueue_script`.

- [ ] **Import images into WordPress media library** `NEW`
  During `/wp-section`, `/wp-header`, `/wp-footer`: import demo images via `wp media import`, then populate the corresponding SCF image fields with the imported attachment IDs. Agents must not lazy-load placeholder images.

- [ ] **Seed SCF fields with demo content** `NEW`
  Every section build should seed the SCF fields with the actual demo text, links, and images — not just provide fallback values. Use `$WP eval "update_field(...);"` after field generation.

- [ ] **Load fonts from the demo** `NEW`
  Detect which fonts the demo uses (Google Fonts, self-hosted, system), download or enqueue them, and add proper `@font-face` declarations and preload hints.

- [ ] **Detect and support Tailwind CSS** `NEW`
  If the demo HTML uses Tailwind utility classes, detect this during `/wp-demo` or `/wp-polish` and set up a Tailwind build pipeline in the theme instead of converting to vanilla CSS.

- [ ] **Visual regression testing with Playwright** `NEW`
  After each section build, take screenshots at key viewports and compare against the demo. Loop fixes until the section matches the demo visually. Could be a new `/wp-test` command or integrated into `/wp-section`.

- [ ] **Post-finalize demo comparison** `NEW`
  Add a check to `/wp-finalize` that compares the live WordPress output against the original demo HTML — flagging CSS, content, or layout differences.

---

## Content Seeding & Pages

Improving how content is created, organized, and populated.

- [ ] **Multi-page demo support** `NEW`
  Detect if the demo has multiple HTML pages (services.html, about.html, etc.). Generate corresponding WordPress pages, templates, and navigation for each. Support multi-page demos in `/wp-init` and `/wp-section`.

- [ ] **Custom post types from demo structure** `NEW`
  If a demo has repeated entity pages (e.g., individual services), auto-detect and create a custom post type with SCF fields, archive template, and single template. Register the CPT, build the list page, and build the single template.

- [ ] **Auto-trigger `/wp-page blog` for blog sections** `NEW`
  When `/wp-section blog` is built, automatically run `/wp-page blog` to generate `archive.php`, `single.php`, and blog-specific templates.

- [ ] **Legal pages: create and seed content** `NEW`
  `/wp-page legal` should create the actual WordPress pages (Privacy Policy, Terms of Service, Cookie Policy) and seed them with industry-appropriate content based on the site info from CLAUDE.md.

- [ ] **Blog language field** `NEW`
  Add an SCF field to blog posts for selecting the post language. Archive/listing templates should filter posts by the active language.

- [ ] **Generate site tagline** `NEW`
  During `/wp-init` or `/wp-demo`, generate a tagline from the demo content or ask the user if unclear. Set it via `$WP option update blogdescription`.

- [ ] **Placeholder content for empty elements** `NEW`
  When demo sections have placeholder-like content (social network icons without real URLs, phone numbers), seed with obvious placeholder values and flag them in the finalize report.

---

## Workflow & UX Improvements

Making the command flow smoother and more guided.

- [ ] **Suggest next command after each step** `NEW`
  After `/wp-header` completes, suggest: "Next: Run `/wp-section hero` for the first section." After each section, suggest the next one based on demo order.

- [ ] **Section list command** `NEW`
  Add a command (or flag on `/wp-init`) that parses the demo and lists all detected sections with their names and content summary, so the user knows what to build.

- [ ] **Suggest `/wp-polish` from `/wp-init`** `NEW`
  If `/wp-init` detects an existing demo that doesn't follow the section delimiter format, suggest running `/wp-polish` before proceeding to `/wp-header`.

- [ ] **Git integration in `/wp-init`** `NEW`
  Offer to initialize a git repo, create `.gitignore` (excluding `node_modules`, `.wp-create.json` secrets), and make an initial commit after theme scaffolding.

- [ ] **Maintenance mode command** `NEW`
  New `/wp-maintenance` command to enable/disable maintenance mode — either via a custom template or by installing a maintenance plugin via WP-CLI.

- [ ] **Favicon command** `NEW`
  New `/wp-favicon` command that takes any image, generates all required favicon sizes (16x16, 32x32, 180x180, 192x192, 512x512), creates `favicon.ico`, generates `site.webmanifest`, and sets the site icon via `$WP option update site_icon`.

- [ ] **Screenshot generation with Playwright** `NEW`
  Auto-generate `screenshot.png` (1200x900) for the theme by taking a Playwright screenshot of the homepage after all sections are built.

---

## Agent Quality

Improving the reliability and output quality of agents.

- [ ] **SCF field labels in site primary language** `NEW`
  When the site's primary language is Spanish (or other non-English), SCF field labels, tab names, and instructions should be in that language — not hardcoded English.

- [ ] **Logo from demo path** `NEW`
  During `/wp-header` or `/wp-init`, extract the logo image from the demo HTML, import it into WordPress media library, and set it in the SCF settings fields.

- [ ] **Menu creation and assignment** `NEW`
  After `/wp-header`, auto-create WordPress navigation menus from the demo nav links and assign them to registered menu locations (primary, footer, per-language).

- [ ] **CF7 dynamic site info** `NEW`
  Ensure CF7 email templates use the `%%placeholder%%` filter to render site info (phone number, email, address) from SCF settings — not hardcoded values.

- [ ] **CF7 email styling** `NEW`
  Improve CF7 email templates using the `frontend-design` skill for better visual design, brand colors, and responsive layout.

---

## Environment & Configuration

Server setup, permissions, and WordPress configuration.

- [ ] **Set `FS_METHOD` to `direct`** `DONE` *(handled by `/wp-audit --security`)*
  Write `define('FS_METHOD', 'direct');` to `wp-config.php` during `/wp-create` or audit.

- [ ] **Fix file/folder permissions** `DONE` *(handled by `/wp-audit --security`)*
  Ensure `wp-content/uploads/`, `wp-content/plugins/`, and `wp-content/upgrade/` have correct ownership (`apache:apache` or `www-data:www-data`) and permissions (755).

- [ ] **CSS optimization: per-page enqueueing** `DONE` *(handled by `/wp-audit --performance`)*
  Don't load all CSS in a single file. Use conditional `wp_enqueue_style` per page template.

- [ ] **Replace Yoast SEO with Rank Math** `DONE` *(v1.3.0)*
  Plugin profiles updated. Rank Math auto-configured by `/wp-audit --seo`.

- [ ] **Security & audit command** `DONE` *(v1.3.0)*
  `/wp-audit` command with security, SEO, accessibility, performance, and best practices categories.

---

## Future Ideas

Longer-term features and exploration areas.

- [ ] **Playwright-based visual QA loop** `NEW`
  After building each section, take a screenshot, compare to the demo screenshot using pixel diff, and iterate fixes until the diff is below a threshold. Could integrate with the `e2e-runner` agent.

- [ ] **WordPress.js agent** `NEW`
  A dedicated JavaScript specialist agent for handling sliders (Swiper, Splide), animations (GSAP, AOS), form validation, and interactive components — converting demo JS to properly enqueued WordPress scripts.

- [ ] **Multi-platform support** `NEW`
  Explore supporting Cursor, Gemini CLI (Codex), and other AI coding tools alongside Claude Code. The plugin architecture (markdown commands/agents/skills) may be adaptable.

- [ ] **Tailwind build integration** `NEW`
  For Tailwind-based demos, set up `tailwind.config.js`, PostCSS, and a build script in the theme. Detect Tailwind classes in demo HTML and preserve them instead of converting to vanilla CSS.

---

> **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, suggest improvements, and submit pull requests.
