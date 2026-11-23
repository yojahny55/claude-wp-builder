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

**Reconciled** on November 23, 2026 against `main` at v1.40.0. Every open and partial
item was checked against what 1.40.0 shipped. Delivered and marked so: `/wp-maintenance`, the
blog language field, legal page drafts, WebP on upload and the WebP migration of an existing
library, the theme screenshot, and the `wp-js` agent. Moved forward but still partial: the
visual QA loop (`/wp-section --visual` loops on `section-diff.mjs`; `/wp-yolo` does not pass
it), WooCommerce N01 (piece 2 of 8, the enquiry channels), and multi-platform support is
closed at phase 1 (the exporter; phase 2 was declined). The craft-family item stays partial until the
next real craft demo. The full pass against
the command, agent or script that would own each item was last made at v1.31.0. An item
claiming to be open while the behavior ships reads as a project that does not know what it
has built.
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

- [x] **Theme language survives a page cache** `DELIVERED`
  Both starters' `inc/i18n.php` ([tailwind](starter-theme/__tailwind__/inc/i18n.php), [cinematic](starter-theme/__cinematic__/inc/i18n.php)) send `Vary: Accept-Language, Cookie` and `nocache_headers()` on language-negotiated responses, read `Accept-Language` q-values (`fr,es;q=0.9` is Spanish) and share one rule for an unknown `?lang`. [theme-i18n-request-lang](tests/checks/theme-i18n-request-lang.sh) guards it.

- [x] **Language attribute on the front end only** `DELIVERED`
  The `language_attributes` filter in both starters' `inc/i18n.php` ([tailwind](starter-theme/__tailwind__/inc/i18n.php), [cinematic](starter-theme/__cinematic__/inc/i18n.php)) returns early in wp-admin and on the login screen, so they keep the site's own `lang`. [theme-i18n-request-lang](tests/checks/theme-i18n-request-lang.sh) guards it.

- [x] **Cinematic language switcher under Polylang** `DELIVERED`
  [`nav.php`](starter-theme/__cinematic__/template-parts/cinematic/nav.php) renders the rows of `__starter___lang_switcher()`: `?lang=` links in the suffix model ([i18n.php](starter-theme/__cinematic__/inc/i18n.php)), `pll_the_languages()` in the [Polylang variant](starter-theme/_i18n-variants/__cinematic__.php), so the link reaches the translated page. Measured before and after at 1440 and 390: no visual change. [starter-i18n-switcher-strings](tests/checks/starter-i18n-switcher-strings.sh) guards it.

- [x] **Tailwind starter strings follow the page language** `DELIVERED`
  The skip link, menu `aria-label`, 404 copy and footer in the tailwind starter ([header.php](starter-theme/__tailwind__/header.php), [404.php](starter-theme/__tailwind__/404.php)) read the starter's string table through `__starter___e()` / `__starter___t()` instead of gettext. Measured: only the focused skip link's width changes in Spanish, with its longer text. [starter-i18n-switcher-strings](tests/checks/starter-i18n-switcher-strings.sh) guards it.
  Later the post, search and archive templates (`search.php`, `single.php`, `template-parts/content*.php`, `inc/template-tags.php`) and the cinematic skip link, menu `aria-label`s, 404, index and post navigation followed: no front-end template of either starter uses gettext now, only the wp-admin menu-location labels. Measured: no style changes; Spanish text is wider, and two titles wrap to a second line at 390.

- [x] **Fix anchor links in SCF URL fields** `DELIVERED`
  [wp-acf](agents/wp-acf.md) rule 19 sends hash-only and site-path links to a `text` field, keeps `url` for absolute addresses, and shows the seed call. [acf-anchor-links](tests/checks/acf-anchor-links.sh) guards it.

- [x] **Fix desktop breakpoint rules in responsive CSS** `DELIVERED`
  [wp-css](agents/wp-css.md) states the rule under *Mobile-First Responsive Design* with the `display: none` / `display: contents` example, requires the list-and-confirm pass before returning the file, and repeats it as rule 14. [css-desktop-overrides](tests/checks/css-desktop-overrides.sh) guards it.

- [x] **Fix agents being lazy with JavaScript** `DELIVERED`
  Consider adding a dedicated `wp-js` agent that handles JavaScript conversion, enqueueing, and event binding specifically.
  [wp-yolo](commands/wp-yolo.md) Step 4.6 ports every demo script on a full build, and [wp-js](agents/wp-js.md), dispatched by [wp-section](commands/wp-section.md) Step 6.4, gives a single-section build the same contract. See *WordPress.js agent* under Future Ideas, the same request.

- [x] **Fix ACF location rule for front-page.php** `DELIVERED`
  [wp-acf](agents/wp-acf.md) mandates `page_type == front_page` over `page_template == front-page.php`, with the reason: ACF derives `page_type` from `is_front_page()`, so the template-meta rule never matches and the group silently disappears from the editor.

---

## Demo Fidelity

Ensuring the WordPress output matches the demo HTML 1:1 in appearance and content.

- [x] **Security baseline and template contracts in both starters** `DELIVERED`
  Both starters ship `inc/security.php`, and [theme-template-check.mjs](bin/theme-template-check.mjs)
  gates ABSPATH guards, compiled classes and widget scripts behind [`/wp-finalize`](commands/wp-finalize.md)
  Check 4 and the practices audit. Check: [baseline](tests/checks/starter-security-baseline.sh).
  Shipped in v1.28.0.

- [ ] **A craft build commits to one aesthetic family, and the commitment is measured** `PARTIAL`
  Every "generic" note on a craft demo describes a page that chose no family — charcoal, one accent, air. v1.27.0 made the choice binding: [families.md](skills/wp-demo-craft/references/families.md) gives each of the seven families its type, palette, surfaces, motion, sequence and an **Avoid** list; [wp-demo](commands/wp-demo.md) 5.4 records the choice under `## Family` in `BRIEF.md` before the first section and hands the Avoid list to the verify critique; [SKILL.md](skills/wp-demo-craft/SKILL.md) lists a hit among the ship blockers.
  [`bin/family-lint.mjs`](bin/family-lint.mjs) now measures the three Avoid items visible in CSS (`backdrop-filter` glass, a radius over 12px on a bordered box, more than one saturated hue) and `/wp-demo` hands its report to the critique, which names each finding a hit or the family's deliberate exception in `demo/VERIFY.md`; it never blocks ([family-lint](tests/checks/family-lint.sh)).
  **Gap:** the gate has not yet run on a real client build: running `/wp-demo` on the project whose demo prompted this and reading `demo/VERIFY.md` is the owner's call, because a craft run is paid and judged by eye.

- [ ] **Visual regression testing with Playwright** `PARTIAL`
  After each section build, take screenshots at key viewports and compare against the demo. Loop fixes until the section matches the demo visually.
  **Gap:** baselines, tolerances and an approval step now exist, but only over the motion fixtures. [visual-baselines](tests/checks/visual-baselines.sh) renders inside a pinned Playwright container, diffs against committed PNGs at a 0.1% tolerance and prints the percentage on every shot; [baseline-approval](tests/checks/baseline-approval.sh) requires a `baseline: <why>` subject on any commit that changes them. The comparison I06 actually names — a built section against the demo it came from — now has a tool, [section-diff.mjs](bin/section-diff.mjs), and a loop that acts on it in `/wp-section --visual` (*Playwright-based visual QA loop* below). The fixtures here are geometric, so these baselines see layout move and would not see a colour or font change. [`bin/style-diff.mjs`](bin/style-diff.mjs) adds before/after computed-style regression on a real page, which does see colour and font, but it is not the section-versus-demo loop.

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

- [x] **Auto-trigger `/wp-page blog` for blog sections** `DELIVERED`
  [wp-section](commands/wp-section.md) Step 6.7 runs [wp-page](commands/wp-page.md) `blog` after a `blog`, `journal`, `news` or `posts` section, by reading the command rather than copying it. It is skipped under `--no-blog-page`, under `--transcribe` (the `/wp-yolo` walk, which runs `/wp-page blog` once itself), on a cinematic project (`/wp-page` has no cinematic CSS route), when the theme already has the card template `/wp-page blog` writes, and when `archive.php` or `single.php` exists and the operator does not confirm the overwrite. [section-blog-page](tests/checks/section-blog-page.sh) pins the step and the three facts its skips rest on.

- [x] **Legal pages: create and seed content** `DELIVERED`
  [wp-page](commands/wp-page.md) `legal` generates the template and then ([legal.md](skills/wp-page-run/references/legal.md) § Create and seed the legal pages) drafts the Privacy Policy, Terms and Cookie Policy from what the project records — `.claude/CLAUDE.md`, the `store` block, the active plugins — with every unrecorded fact left as `[[pending: …]]`. [legal-pages.php](skills/wp-page-run/scripts/legal-pages.php) creates them as drafts on the Legal Page template, fills WordPress's own unfilled privacy draft, never touches a page someone already wrote, and sets `wp_page_for_privacy_policy` only when it points at no page. Nothing is published. [legal-pages](tests/checks/legal-pages.sh) pins the contract; [legal-pages-integration](tests/checks/legal-pages-integration.sh) runs the script against the WordPress fixture.

- [x] **Blog language field** `DELIVERED`
  Under `i18n strategy: suffix` (or no recorded strategy), [wp-page](commands/wp-page.md) `blog` installs the fixed [blog-language.php](templates/blog-language/blog-language.php) as `inc/blog-language.php` ([blog.md](skills/wp-page-run/references/blog.md) § Blog language): a `post_language` select on posts, built from the theme's supported languages, and a `pre_get_posts` filter that lists the visitor's language plus every post with no language on the blog index, post archives and search. A post with no language is listed in every language, so an existing blog lists what it listed before. Polylang projects skip it. [blog-language-field](tests/checks/blog-language-field.sh) runs the template against stubbed queries.

- [x] **Placeholder content for empty elements** `DELIVERED`
  [wp-finalize](commands/wp-finalize.md) refuses `href="#"` in delivered markup and flags a stub privacy page. Check 7 item 12 ([wp-cli-runtime.md](skills/wp-finalize-run/references/wp-cli-runtime.md)) lists every empty social, phone, email and address setting under **Content pending** in the report, never as a FAIL. It flags rather than seeds: an invented phone number or profile link is one a client can ship by mistake. [wp-finalize-content-pending](tests/checks/wp-finalize-content-pending.sh) runs the snippet against stubbed ACF.

- [x] **Multi-page demo support** `DELIVERED`
  [wp-normalize](agents/wp-normalize.md) splits an arbitrary multi-page site into the canonical demo format; [wp-yolo](commands/wp-yolo.md) and [wp-seed](commands/wp-seed.md) generate the corresponding pages, templates and navigation.

- [x] **Custom post types from demo structure** `DELIVERED`
  [wp-cpt](commands/wp-cpt.md) registers the CPT and generates fields, archive, single, an optional teaser query-section and a seed helper. `--from-demo <section-name>` derives it from a demo section.

- [x] **Generate site tagline** `DELIVERED`
  [wp-init](commands/wp-init.md) Step 9 (Site Identity) writes `blogname` and `blogdescription` from the demo-extracted or prompted tagline. Under `i18n strategy: polylang` the secondary language is left to `/wp-polylang`, which exports both as registered strings.

---

## Workflow & UX Improvements

Making the command flow smoother and more guided.

- [x] **`/wp-status`: what step comes next** `DELIVERED`
  [wp-status](commands/wp-status.md) runs [wp-status.mjs](bin/wp-status.mjs), read-only: it reads `.wp-create.json`, `.claude/CLAUDE.md`, `demo/` (including `FAILED.md`), the build ledger and the audit ledger, and ends with `Next: <command> - <reason>`; `--json` gives the same report to scripts. [wp-status](tests/checks/wp-status.sh) guards it.

- [x] **`/wp-backup` and `/wp-restore`** `DELIVERED`
  [wp-backup](commands/wp-backup.md) runs [wp-backup.sh](bin/wp-backup.sh): a verified database dump (SQL header and footer, atomic rename) plus the uploads archive, in a private folder outside the WordPress root, with sha256 sums and counts in `backup.json`. [wp-restore](commands/wp-restore.md) runs [wp-restore.sh](bin/wp-restore.sh): verifies the sums, takes a pre-restore copy and fails unless site URL, table count and post count match afterwards. [wp-update](commands/wp-update.md), [wp-clone](commands/wp-clone.md) and [wp-anonymize](commands/wp-anonymize.md) call it instead of exporting by hand. [wp-backup-restore](tests/checks/wp-backup-restore.sh) guards it.

- [x] **Section list command** `DELIVERED`
  [`/wp-section --list`](commands/wp-section.md) runs [`bin/demo-sections.mjs`](bin/demo-sections.mjs), which lists every page's sections with the slug `/wp-section` takes, the line range and whether the theme already has the template part, without a manifest or theme. It also reports the delimiter defects that make the builders misread a demo (unclosed, stray or mismatched END, nested, duplicate, none at all) and exits 1 on any. [demo-sections](tests/checks/demo-sections.sh) runs it on a fixture.

- [x] **Screenshot generation with Playwright** `DELIVERED`
  [theme-screenshot.mjs](bin/theme-screenshot.mjs) captures the built homepage at 1200x900 in an existing Chrome, with reduced motion and the fonts loaded, into the theme's `screenshot.png` through a temporary file; it keeps a real preview unless `--force`, and a failing page or a missing browser never touches the file. [wp-yolo](commands/wp-yolo.md) Phase 3 runs it after the CSS rebuild, and [wp-finalize](commands/wp-finalize.md) Check 4 ([theme-structure.md](skills/wp-finalize-run/references/theme-structure.md)) fails a theme with no screenshot or still carrying the tailwind starter's 1x1 placeholder, with the command as the fix. [theme-screenshot](tests/checks/theme-screenshot.sh) runs it against a local page.

- [x] **Verify form delivery end to end** `DELIVERED`
  [wp-cf7-delivery](tests/checks/wp-cf7-delivery.sh) creates a real CF7 form in the WordPress fixture, serves the site, and posts to CF7's own REST endpoint: a valid submission is accepted and its mail captured by a `pre_wp_mail` sink with the right recipient and an interpolated body, and a submission missing a required field is refused and sends nothing.

- [x] **Walk the default-motion branch** `DELIVERED`
  [motion-devices](tests/checks/motion-devices.sh) now drives both paths. Under default motion it loads the real pinned GSAP from `node_modules` and asserts the rail's transform tracks scroll and that the JS `reveal` branch hides its children and then shows them — reached by forcing `CSS.supports('animation-timeline', …)` to report false, since every browser the suite can run supports it and the CSS engine would otherwise take over.

- [x] **Broken-site corpus with expected audit findings** `DELIVERED`
  A fixture site seeded with known defects and a file of the findings an audit should report, so a test can fail because an audit *missed* a defect. [seeded-defects](tests/fixtures/seeded-defects/) ships a theme and plugin with 11 marked defects and `expected-findings.json`; [provision.sh](tests/fixtures/wp/provision.sh) installs them with `WP_FIXTURE_SEEDED=1`, without their `SEEDED` markers, on a core verified against its checksums. [The check](tests/checks/seeded-defects.sh) validates the corpus offline, compares a committed `recorded-findings.json` in CI (with negative cases), and compares a real run through `SEEDED_FINDINGS`, counting a code folded under `also_affects` as fired. A live report-only `/wp-audit` over the five code domains reported 11 of 11. What that run exposed in the agent report contract is fixed in [audit-schema.mjs](bin/lib/audit-schema.mjs) and the dispatch skeleton. CI still runs no live audit: see `docs/known-ceilings.md`.

- [x] **Maintenance mode command** `DELIVERED`
  [wp-maintenance](commands/wp-maintenance.md) turns maintenance mode on and off with a theme-owned switch instead of a plugin: it copies [maintenance.php](templates/maintenance/maintenance.php) into `inc/maintenance.php`, and the `<prefix>_maintenance` option makes the theme answer `503` with `Retry-After` to visitors who cannot `edit_posts`, anonymous REST included. Stores use the same switch; WooCommerce's coming-soon mode stays launch state and is only reported. [The check](tests/checks/wp-maintenance.sh) runs the template against stubbed WordPress.

- [x] **Favicon command** `DELIVERED`
  [wp-favicon](commands/wp-favicon.md) takes one square image, writes the 16, 32, 180, 192 and
  512 px PNGs, `favicon.ico` and `site.webmanifest`, and sets `site_icon` through WP-CLI. Check:
  [favicon](tests/checks/wp-favicon.sh).

- [x] **Suggest next command after each step** `DELIVERED`
  [wp-header](commands/wp-header.md) and [wp-section](commands/wp-section.md) end by naming the next command to run.

- [x] **Suggest `/wp-polish` from `/wp-init`** `DELIVERED`
  [wp-init](commands/wp-init.md) runs `/wp-polish` when the demo has no section delimiters, and also when some sections appear to be missing them.

- [x] **Git integration in `/wp-init`** `DELIVERED`
  [wp-init](commands/wp-init.md) Step 9.5 runs `git init` and writes a `.gitignore`; Step 9.6 adds `.wp-create.local.json` so generated credentials are never committed.

---

## Agent Quality

Improving the reliability and output quality of agents.

- [x] **Rank Math agent runs on sonnet** `DELIVERED`
  [wp-audit-rankmath](agents/wp-audit-rankmath.md) runs on sonnet, and the code of its long steps lives in `skills/wp-audit-seo-standards/references/` (`rankmath-*.md`), with the agent keeping each step's condition, rules and a pointer. [model-routing](tests/checks/model-routing.sh) guards the tier.

- [x] **Audit and fix sites this plugin did not build** `DELIVERED`
  [`/wp-adopt`](commands/wp-adopt.md) writes a manifest for an existing install through
  [`wp-config.mjs adopt`](bin/wp-config.mjs), splitting code into the site's own and vendor
  by the update transients and making the operator confirm every path. [`/wp-audit`](commands/wp-audit.md)
  then audits vendor code but never edits it, and reads the site type and whether it is a
  local clone before any category runs, so a staging copy is not scored as a live site.
  An opt-in `/wp-adopt` step publishes the adopted site to a git remote, and
  [`/wp-update`](commands/wp-update.md) runs backed-up, verified updates.
  Check: [wp-adopt](tests/checks/wp-adopt.sh). Shipped in v1.28.0.

- [x] **Security audit reaches what the plugin counts could not** `DELIVERED`
  [wp-audit-security](agents/wp-audit-security.md): SEC-039 paid WooCommerce downloads
  reachable without a purchase; SEC-040 payment-gateway credentials stored at rest, keys
  classified by segment and `merchant_key` rated CRITICAL; SEC-041/042/043 plugin inventory
  deeper than the counts. [wp-audit-performance](agents/wp-audit-performance.md): PERF-036..064
  give database bloat a threshold instead of a report. Every snippet is run by its check, not
  grepped — [gateway](tests/checks/audit-gateway-credentials.sh),
  [inventory](tests/checks/audit-plugin-inventory.sh), [download](tests/checks/audit-woo-download-protection.sh),
  [bloat](tests/checks/audit-db-bloat.sh). Shipped in v1.28.0.

- [x] **Verification runs in Firefox as well as Chromium** `DELIVERED`
  [demo-verify.mjs](bin/demo-verify.mjs) drives an existing Playwright Firefox beside Chromium
  instead of installing its own browser, and [css-contour-lint.mjs](bin/css-contour-lint.mjs)
  is the static cross-engine companion for the rules one engine renders and the other does
  not. Checks: [engines](tests/checks/demo-verify-engines.sh), [contour](tests/checks/css-contour-lint.sh).
  Shipped in v1.28.0.

- [x] **Run the browser audit as a suite instead of asking the session for a browser** `DELIVERED`
  [`/wp-audit --suite`](commands/wp-audit.md) scaffolds and runs
  [templates/audit-suite](templates/audit-suite/) through
  [bin/audit-suite.sh](bin/audit-suite.sh) — axe-core, Lighthouse desktop and mobile, three
  engines — and [scripts/to-run.js](templates/audit-suite/scripts/to-run.js) converts its
  results into the run file [bin/audit-report.mjs](bin/audit-report.mjs) renders. The
  template is vendored with its provenance and compared by
  [audit-suite-sync](tests/checks/audit-suite-sync.sh); the install is shared per machine;
  the overlap with the agents' own findings is resolved by measurement beating inference.

- [x] **Usability criteria: the categories no auditor owns** `DELIVERED`
  [wp-audit-ux](agents/wp-audit-ux.md) audits forms and data entry, navigation and task
  flow, links followed rather than inferred, interactive feedback, legibility and visual
  identity, against the `UX-NNN` catalog in
  [wp-audit-ux-standards](skills/wp-audit-ux-standards/SKILL.md). Contrast, focus and target
  size stay with [wp-audit-a11y](agents/wp-audit-a11y.md). Held by
  [audit-usability-scope](tests/checks/audit-usability-scope.sh).

- [x] **Audit a list of pages, not only the theme** `DELIVERED`
  [`/wp-audit --pages`](commands/wp-audit.md) Step 2.7 derives the scope from the manifest,
  the menu, the sitemap or the home page, adds the 404 and the form page, caps at eight and
  says it capped. A page-level criterion with no page list reports `UNMEASURED` rather than
  passing, and `N/A` and `UNMEASURED` are both excluded from the denominator so the score
  reflects what the site was meant to do.

- [x] **SCF field labels in site primary language** `DELIVERED`
  [wp-acf](agents/wp-acf.md) reads the primary language from `.claude/CLAUDE.md` and writes every string the editor reads — group title, tabs, field labels, instructions, `button_label`, `message` — in it, with a worked Spanish-primary example. `key`, `name` and the language suffix stay English, because a `name` is the meta key. Held by [acf-editor-language](tests/checks/acf-editor-language.sh). This entry read DELIVERED from the reconciliation of September 19, 2026 while the agent file said nothing of the kind; closing [#3](https://github.com/yojahny55/claude-wp-builder/issues/3) is what made it true.

- [x] **Menu creation and assignment** `DELIVERED`
  [wp-seed](commands/wp-seed.md) creates the menus, assigns them with `wp menu location assign`, and writes the per-language Polylang `nav_menus` mapping — including the `nav_menu_locations` theme_mod that Polylang itself never sets. v1.26.0 added the only assertion that can see whether it worked: an HTTP request counting menu items per language. Polylang replaces that theme_mod in a **frontend** filter, so `get_nav_menu_locations()` under WP-CLI prints correct ids for a site serving no navigation at all — which is how a 16-page delivery shipped with no nav links on any page.

- [x] **CF7 dynamic site info** `DELIVERED`
  [wp-cf7](agents/wp-cf7.md) renders `%%site_logo%%`, `%%contact_email%%`, `%%contact_phone%%` and `%%copyright%%` from settings at render time.

- [x] **CF7 email styling** `DELIVERED`
  [wp-cf7](agents/wp-cf7.md) generates branded admin and confirmation templates using the `frontend-design` skill.

---

## Environment & Configuration

Server setup, permissions, and WordPress configuration.

- [x] **One documented table of tool exit codes** `DELIVERED`
  [exit-codes.mjs](bin/lib/exit-codes.mjs) declares what each `bin/*.mjs` tool returns (`COMMON` for new tools) and [docs/exit-codes.md](docs/exit-codes.md) lists it, without renumbering. [exit-code-table](tests/checks/exit-code-table.sh) fails when a tool exits with an undeclared code or the table and the doc drift apart.

- [x] **`impeccable` follows its latest release** `DELIVERED`
  Every call is `npx -y impeccable@latest`, and [composition-gate](bin/composition-gate.sh) exits 1 on detector output it does not understand instead of passing it. [wp-craft-composition-gate](tests/checks/wp-craft-composition-gate.sh) and [wp-craft-detect](tests/checks/wp-craft-detect.sh) guard it and fail on any numeric `impeccable@` pin.

- [ ] **WooCommerce stores (N01)** `PARTIAL`
  Piece 1 of 8, the foundation, is delivered: three store profiles, the `store` block,
  [`/wp-woo-setup`](commands/wp-woo-setup.md) with its [setup script](skills/wp-woocommerce/scripts/woo-setup.php),
  and [`store-kit`](plugins/store-kit/store-kit.php), proven by
  [the integration check](tests/checks/wp-woo-setup-integration.sh). The audit already reads
  the store tier, detects a merchant by active plugin, and checks paid downloads (SEC-039) and
  gateway keys at rest (SEC-040); a shopper-flow regression suite ([check](tests/checks/audit-regression-suite.sh)) now proves search, cart and checkout survive a change; a store-specific audit pass is still to come. Piece 2, theme integration, is delivered:
  `/wp-woo-setup` Step 6.5 installs [a fixed enquiry file](templates/store/store-enquiry.php)
  into a catalog store's theme, which adds the WhatsApp number, message and enquiry form to the
  settings page and renders the filled ones on product pages while catalog mode is on
  ([check](tests/checks/store-enquiry.sh), [on a real store](tests/checks/store-enquiry-integration.sh)). Piece 3 has its first half: a demo's store pages are `role: store`
  with their WooCommerce surface in the [`/wp-yolo`](commands/wp-yolo.md) manifest
  ([wp-normalize](agents/wp-normalize.md)), so no WP Page or section build collides with
  WooCommerce's own pages, and every demo link to them is reported for review
  ([check](tests/checks/store-demo-pages.sh)). Of its second half, the theme base is delivered:
  `/wp-woo-setup` Step 6.6 installs [WooCommerce support](templates/store/store-theme.php) and
  [a store-only stylesheet](templates/store/store.css) in the theme's tokens into a new store's
  tailwind theme, or an existing one with `--store-theme`
  ([check](tests/checks/store-theme.sh), [on a real store](tests/checks/store-theme-integration.sh));
  and so is the demo's own store styling: [`/wp-yolo`](skills/wp-yolo-run/references/store-layer.md)
  installs that base and has `wp-css` write the demo's store pages into its `Section: Store demo`
  on [WooCommerce's selectors](skills/wp-woocommerce/references/store-selectors.md)
  ([check](tests/checks/store-demo-layer.sh)), and so is the header cart link: Step 6.6 also
  installs [a fixed template part](templates/store/store-cart.php) that `/wp-header` calls on a
  `store` or `full` store, with the server's count refreshed from the Store API on WooCommerce's
  cart events ([check](tests/checks/store-cart.sh)); and the demo's links to its store pages
  are rewired: `/wp-seed --store-pages` adds menu items and fills link fields with
  [WooCommerce's own pages](skills/wp-woocommerce/scripts/store-links.php)
  ([check](tests/checks/store-links.sh), [on a real store](tests/checks/store-links-integration.sh)).
  Piece 3 is delivered. Piece 4 has its first half: a demo's products are extracted into the
  manifest's `products[]` and created by `/wp-seed --products` with
  [WooCommerce's own classes](skills/wp-woocommerce/scripts/product-seed.php), simple or
  External, owned field by field, with options left as a draft for review
  ([check](tests/checks/product-seed.sh), [on a real store](tests/checks/product-seed-integration.sh)).
  Not started, each its own spec: `/wp-woo-verify`, the store audit and launch step, the Polylang
  bridge, subscriptions, bookings.

- [x] **One unexplained integration failure in store setup** `DELIVERED`
  [The integration check](tests/checks/wp-woo-setup-integration.sh) failed once at "setup
  overwrote the client's shipping cost", during a mutation run that cannot reach that
  assertion; it was not reproduced in 4+ full runs or 12 targeted loops. The assertion now
  prints the cost it read and setup's output, so a recurrence explains itself. Watch it in CI.
  As of October 5, 2026 it has not recurred: none of the last 60 CI runs failed on it. Close
  this after a further month without a recurrence.
  Closed on November 22, 2026: none of the 611 CI runs since October 5 failed on it (the one
  failed `WordPress integration` job in that window, on October 22, was an unrelated SEC-040
  snippet extraction on a refactor branch). The assertion keeps its diagnostics, so a
  recurrence still explains itself.

- [x] **Docker environments get no nginx config** `DELIVERED`
  [`templates/docker/nginx.conf.tpl`](templates/docker/nginx.conf.tpl) is rendered by
  [`/wp-create`](skills/wp-create-run/references/env-templates.md) Step 4.3 to the
  `docker/nginx.conf` that [`docker-compose.yml.tpl`](templates/docker/docker-compose.yml.tpl)
  mounts, with the native deny list (`woocommerce_uploads` included), backed up on overwrite and
  served by a real nginx in `tests/checks/docker-nginx-config.sh`.

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

- [x] **Playwright-based visual QA loop** `DELIVERED`
  Screenshot each built section, pixel-diff it against the demo, and iterate until the diff is below a threshold. The measurement exists: [section-diff.mjs](bin/section-diff.mjs) finds a section in the demo by its delimiter and in the built page by the same root class (or `--selector`), captures both at each viewport with motion settled, compares them with pixelmatch over the shared area, checks the width and height difference apart, refuses an ambiguous selector, and writes demo, site and diff images; [section-diff](tests/checks/section-diff.sh) runs it on fixtures. [`/wp-section --visual`](commands/wp-section.md) runs it in a loop ([Step 6.6](skills/wp-section-run/references/visual-check.md)): a viewport over tolerance goes back to the section's CSS agent with the demo, site and diff images, which fixes only that section's rules with the demo's declared values, at most three rounds and only while the difference keeps shrinking; [section-visual-loop](tests/checks/section-visual-loop.sh) pins it. A full build gets the same loop with [`/wp-yolo --visual`](commands/wp-yolo.md): once the pages are seeded and before `/wp-finalize`, it measures every section it built, one at a time ([visual-pass](skills/wp-yolo-run/references/visual-pass.md)), and reports what stays over tolerance without blocking the run; [wp-yolo-visual](tests/checks/wp-yolo-visual.sh) pins it. It is opt-in, so a run without the flag still relies on the computed-style parity gate alone.

- [x] **WordPress.js agent** `DELIVERED`
  [wp-js](agents/wp-js.md) ports one demo section's script — carousels, galleries, tabs, accordions, filters, form checks — into `assets/js/src/sections/<slug>.js`: no-op without its markup, bound to `data-` hooks it adds to the template part (never the CSS's BEM classes), idempotent, guarded, keyboard- and reduced-motion-aware, strings from the localized data object; it reuses the theme's own tabs, accordion and filter modules instead of a second copy, imports a library only when the demo uses it and the theme's `package.json` has it (otherwise `BLOCKED` with the install command), wires the module into `index.js` and rebuilds the bundle. [wp-section](commands/wp-section.md) Step 6.4 dispatches it when a script touches the section; `/wp-yolo` keeps its own Step 4.6, which ports every script once. [wp-js-agent](tests/checks/wp-js-agent.sh) pins the contract.

- [x] **WebP conversion on upload** `DELIVERED`
  [wp-webp](commands/wp-webp.md) `upload on` installs [webp-on-upload.php](templates/webp/webp-on-upload.php) as a must-use plugin: on `wp_handle_upload` and `wp_handle_sideload` at priority 5, before WordPress makes the sizes, it encodes PNG and JPEG with `cwebp` up a quality ladder (plus a lossless candidate for PNG), keeps the first candidate that reaches the PSNR threshold (40 dB) and is smaller than the original, and keeps the original otherwise. Stream-wrapper paths (`s3://`) go through a local temporary copy. It does nothing without `cwebp`, `proc_open` or a WebP-capable image editor, and `status` says which is missing. [wp-robin](skills/wp-robin/SKILL.md) stays for the library uploaded before. [webp-on-upload](tests/checks/webp-on-upload.sh) runs the filter with the real `cwebp`, s3-style wrapper included; [webp-on-upload-integration](tests/checks/webp-on-upload-integration.sh) uploads through WordPress.

- [x] **WebP migration of an existing library** `DELIVERED`
  [`/wp-webp migrate`](commands/wp-webp.md) runs the written procedure ([png-to-webp-conversion](skills/wp-robin/references/png-to-webp-conversion.md)) through [webp-migrate.php](skills/wp-robin/scripts/webp-migrate.php): a database and uploads backup first; `convert` each `image/png` attachment, one at a time and resumable, to a WebP original with WebP sizes, keeping the old files and writing an old-to-new map (an interrupted attachment stops the next run); `replace` every `uploads/<old>` in the prefixed tables, plain and JSON-escaped, unserializing and serializing again, leaving `guid`, transients, sessions and Robin's queue alone and never touching Robin's `<file>.png.webp` names; `verify` that every new file exists and no row names an old one; a served-HTML check; the redirect rule printed for the operator; and `move-aside` of the old files to a folder outside uploads, refused until verify passes. Nothing is deleted. PNG only, single site, local uploads (a stream-wrapper uploads directory is refused). [webp-migrate](tests/checks/webp-migrate.sh) pins the contract; [webp-migrate-integration](tests/checks/webp-migrate-integration.sh) runs the whole procedure on the WordPress fixture.

- [x] **Blocking the REST API in Apache** `DELIVERED`
  [apache-rest-block](skills/wp-environments/references/apache-rest-block.md), linked from [wp-environments](skills/wp-environments/SKILL.md) § 8: a server-context `<If>` that wins whichever vhost answers, matching `/wp-json` (also behind `index.php/` and other `.php` path info) and every key form PHP reads as `rest_route` (percent-encoded letters, `.`, `+`, `[`, NUL), leaving `admin-ajax.php` and Contact Form 7 open. Because WordPress also reads `rest_route` from a POST body Apache never sees, it ships with a `rest_pre_dispatch` mu-plugin and is documented as the outer layer, not the boundary. [apache-rest-block](tests/checks/apache-rest-block.sh) replays the whole table against a throwaway Apache.

- [x] **Verify bulk transfers by result, not by exit code** `DELIVERED`
  Three separate measurements in one project of a tool reporting success without doing the work: a mirror writing 7 of 38 objects and exiting `0`, the same mirror "succeeding" against a stopped backend, and an interactive `cp` alias silently skipping copies that invalidated an A/B measurement. The rule is written down in [wp-contributing](skills/wp-contributing/SKILL.md) (a `transfer-verified:` comment beside every bulk transfer, saying how its result is confirmed), and `tests/checks/transfers-verified-by-result.sh` fails on a shipped script that adds a transfer without one. [wp-backup.sh](bin/wp-backup.sh) counts the uploads archive against the disk and records it, [wp-restore.sh](bin/wp-restore.sh) checks that count before swapping uploads in, and `store-kit-sync.sh`, `audit-suite.sh` and `s3-setup.sh` confirm their copies.

- [x] **Multi-platform support** `DELIVERED`
  Explore supporting Cursor, Gemini CLI (Codex), and other AI coding tools alongside Claude Code. The plugin architecture (markdown commands/agents/skills) may be adaptable. Phase 1 is delivered without changing a command: [export-platform.mjs](bin/export-platform.mjs) writes an `AGENTS.md` index, one Cursor rule per command (attached on request) or Gemini CLI commands (`GEMINI.md` plus TOML, `$ARGUMENTS` as `{{args}}`), with every `${CLAUDE_PLUGIN_ROOT}` path made absolute and a preamble that tells the other agent to do a subagent's work itself, in sequence, and to ask AskUserQuestion's questions in the chat; [export-platform](tests/checks/export-platform.sh) runs all three. Phase 2, taking `Agent`, `AskUserQuestion` and `${CLAUDE_PLUGIN_ROOT}` out of the commands themselves, was declined on November 23, 2026: it rewrites every command and weakens them in Claude Code, the platform the plugin is actually used on, to gain what the exporter already produces at export time. When another platform needs more, the exporter is extended, not the commands.

- [x] **Tailwind build integration** `DELIVERED`
  The `__tailwind__` starter ships `package.json` and the Tailwind v4 build; [wp-tailwindify](commands/wp-tailwindify.md) converts a demo's CSS and [wp-tailwind-migrate](commands/wp-tailwind-migrate.md) migrates an existing theme. Duplicate of *Detect and support Tailwind CSS* above.

---

> **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, suggest improvements, and submit pull requests.
