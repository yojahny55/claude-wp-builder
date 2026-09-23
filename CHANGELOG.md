# Changelog

## [Unreleased]

### Fixed

- **A horizontal-overflow finding did not say what overflowed.** `bin/demo-verify.mjs`
  reported `overflow: true` and nothing else, once per sampled position. On a real
  build the box stretching the page was a 1px `screen-reader-text` span inside a
  carousel card. It is `position: absolute`, and its containing block sat outside
  the carousel's `overflow-x: auto` strip, so the strip never clipped it. It widened
  the document at every width and showed in no screenshot. The row now lists the
  `culprits`: boxes past the right edge that no ancestor clips. It follows the
  containing-block rule for absolute boxes, and `escapes` names the clipping box an
  absolute culprit got past. The walk covers the whole document, so the same culprits
  at every position of every section count as one row per width; `section` is where
  they were first seen. `tests/checks/demo-verify-overflow-culprits.sh` runs the walk
  on an escaping strip and on the same strip with positioned cards.

- **Rank Math modules enabled from WP-CLI ran without their tables.** Writing
  `rank_math_modules` skips the activation that creates `rank_math_404_logs` and
  `rank_math_redirections`, so `404-monitor` and `redirections` ran two failing queries on
  every request. A real build measured TTFB at 1.7-5.8 s, and 0.5-0.7 s once the tables
  existed.
  - `wp-audit-rankmath` Step 2.1 runs `RankMath\Installer::create_tables()` after enabling
    modules and blocks on a missing table.
  - `/wp-audit` reports a module without its table as PERF-060 (CRITICAL).

- **CPT-archive breadcrumbs stayed in the primary language under Polylang.** Rank Math
  builds that crumb from the `register_post_type()` label, which no
  `post_type_archive_title` filter reaches, so `/en/<cpt-plural>/` showed the Spanish
  plural. `wp-audit-rankmath` Step 15b adds a `rank_math/frontend/breadcrumb/items` filter
  that reads the same `plural_<post_type>` string, and falls back to the type's own label
  (on a single, `post_type_archive_title()` is null). The `wp-polylang` skill's
  `post_type_archive_title` example also fell back with `?:` on `prefix_t()`. That function
  returns the key itself when a string is missing, never `''`, so a missing string printed
  the key. It now compares against the key.

- **`--suite` could never run from its managed install.** The shared dependency cache was
  named `node_modules-<key>`. Node resolves a package's own imports from its real path,
  searching only directories literally named `node_modules`, so `@playwright/test` could not
  find `playwright` and every run failed with `MODULE_NOT_FOUND`. The script sent that
  output to `/dev/null` and reported "playwright could not install its browser", so Tier 3
  read as an unavailable browser.
  - The cache leaf is now `<cache>/<key>/node_modules`. An old `node_modules-<key>`
    directory is no longer used and can be deleted.
  - The runner loads the Playwright CLI before using it and prints the real error.
  - The browser install's output is kept and its tail is printed on failure.

- **The accessibility fix drew a second focus indicator.** A11Y-025/026 shipped a bare
  global `:focus-visible { outline }`. On form fields that already had a design focus
  border, the rule added a second indicator on every field. The fix now takes four steps:
  1. Find the components that already style their own focus.
  2. Add a zero-specificity `:where()` ring only where nothing else exists.
  3. Replace a design focus colour that fails 3:1 instead of stacking a ring on it.
  4. Check with `getComputedStyle` before and after that each element shows one indicator.
  The tailwind starter gains that default ring in `base/reset.css`. It sits in the base
  layer at zero specificity, so `.btn`'s `focus-visible:outline-none` (utilities layer)
  wins by layer order. `.btn`'s ring moves from `focus:` to `focus-visible:`, the state
  where the outline is cleared: measured in Chromium at 1440 and 390, rest and keyboard
  focus are unchanged (same box-shadow, colour, size, radius, 76x38 / 62x38), and a mouse
  click no longer draws the ring.

  **The target-size check failed the wrong threshold.** A11Y-028 read CSS for 44x44, which
  is WCAG 2.5.5 (AAA), while the AA criterion 2.5.8 is 24x24. Nav items, footer social icons
  and a breadcrumb home link measured under 24 on a real build and were never reported as
  AA failures. The a11y audit, `wp-audit-standards` and UX-009 now fail below 24x24,
  measured with `getBoundingClientRect()` at desktop and mobile, and treat 44x44 as advice.
  `/wp-header`, `/wp-footer`, the Rank Math breadcrumb CSS, `wp-css` and `wp-responsive`
  reach 24x24 with padding plus an equal negative margin, so the text does not move.

- **A carousel's absolute boxes escaped the strip and scrolled the page sideways.** The
  Carousels rules in `agents/wp-template.md` asked for controls outside the scrolling
  element, but not for positioned cards. The A11Y-032 fix in `agents/wp-audit-a11y.md` adds
  a `screen-reader-text` span, which is `position: absolute`, to every new-tab link,
  including a card's "see more". On a real build the containing block of that span was a
  container above the `overflow-x: auto` strip, so the strip never clipped it. Every
  off-screen card widened the document, at every width from phone to 1920. Cards inside a
  scrolling strip are now `relative`, the A11Y-032 fix says so, and both give the
  `scrollWidth <= clientWidth` check. `tests/checks/carousel-positioned-cards.sh`.

### Added
### Added

- **`/wp-audit` reads the site type and whether it is a local clone before any category
  runs (Step 2.3).** Two blind spots made the audit report on the wrong site. First, checks
  written for a store had no gate: adding any WooCommerce-specific check would fire on a
  generic blog and score it for a cart it never had. The audit now records `site.commerce`
  from `wp plugin is-active woocommerce`, and every commerce check reads `N/A` (out of the
  denominator) on a non-commerce site, so commerce depth can be added without moving a
  generic site's score. Second, a project restored to run locally is deliberately altered —
  dev host in the database, deactivated payment/cache/mail plugins, `DISABLE_WP_CRON`, absent
  object-cache drop-ins, debug logging, media newer than the file backup — and the audit used
  to report those alterations as defects of the site, when they are the price of the copy.
  When the manifest shows a clone (`source: restore`, a `restore.url_origin`, or a non-public
  `wordpress.url`), those conditions are `N/A (local clone)`, suppressed and out of the
  denominator, bounded by one test: would this also be true on production? Live checks
  (response headers, paid-file reachability) now target the production URL — asked for and
  confirmed, defaulting to `restore.url_origin` — and never the clone, whose local server
  answers an `.htaccess` a production nginx ignores and would return a false PASS.
  `tests/checks/audit-site-type-and-clone.sh` pins the gate, the suppression catalog and the
  production-host rule; the methodology is recorded in `skills/wp-audit-standards`.


- **`wp-audit-security` now checks for payment-gateway credentials stored at rest
  (SEC-040).** SEC-005 only greps theme PHP for hardcoded secrets, but a WooCommerce payment
  gateway keeps its live API key, secret and token in the database instead — a serialized
  array in the `wp_options` row `woocommerce_<gateway_id>_settings` — so nothing that scans
  source code could ever see it. That row is exactly what a database dump, staging snapshot
  or cloned copy carries verbatim, which makes a configured gateway's credentials a real leak
  risk on any shared copy of the site. SEC-040 enumerates enabled gateways through
  `WC_Payment_Gateways`, reads each one's settings, and reports CRITICAL when a
  credential-shaped key (`api_key`, `secret_key`, `token`, `publishable_key`, …) is
  non-empty, without ever printing the value itself. It is `N/A` when `site.commerce` is
  `none` (`/wp-audit` Step 2.3), like every other commerce-only check, and it is deliberately
  **not** folded into that same step's local-clone suppression list: a gateway deactivated on
  a clone is a clone artifact and stays suppressed, but the credential still sitting in
  `wp_options` is true of production too and is reported regardless. The fix is manual —
  rotate the key at the processor if the database was ever shared, and scrub the value before
  handing around a cloned copy. `tests/checks/audit-gateway-credentials.sh` pins the check,
  the credential-key list, and the clone-suppression distinction.

- **`/wp-audit` reads the site type and whether it is a local clone before any category
  runs (Step 2.3).** Two blind spots made the audit report on the wrong site. First, checks
  written for a store had no gate: adding any WooCommerce-specific check would fire on a
  generic blog and score it for a cart it never had. The audit now records `site.commerce`
  from `wp plugin is-active woocommerce`, and every commerce check reads `N/A` (out of the
  denominator) on a non-commerce site, so commerce depth can be added without moving a
  generic site's score. Second, a project restored to run locally is deliberately altered —
  dev host in the database, deactivated payment/cache/mail plugins, `DISABLE_WP_CRON`, absent
  object-cache drop-ins, debug logging, media newer than the file backup — and the audit used
  to report those alterations as defects of the site, when they are the price of the copy.
  When the manifest shows a clone (`project.source: "restore"`, a `wordpress.url_origin`,
  or a non-public `wordpress.url`), those conditions are `N/A (local clone)`, suppressed and
  out of the denominator, bounded by one test: would this also be true on production? Live
  checks (response headers, paid-file reachability) now target the production URL — asked
  for and confirmed, defaulting to `wordpress.url_origin` — and never the clone, whose
  local server answers an `.htaccess` a production nginx ignores and would return a false
  PASS.
  `tests/checks/audit-site-type-and-clone.sh` pins the gate, the suppression catalog and the
  production-host rule; the methodology is recorded in `skills/wp-audit-standards`.

- **Security baseline in both starters: `inc/security.php`.** The tailwind starter had
  none, and its `template-functions.php` printed a pingback `<link>`. A full audit of a
  delivered build found XML-RPC and pingbacks on, `/wp/v2/users` and `?author=N` listing
  logins, the file editors open and no security headers. `DISALLOW_FILE_EDIT` lives in
  `wp-config.php`, which is never deployed with the repository, so the theme now does the
  work:
  - XML-RPC off with the method list emptied (pingbacks included), and no RSD link or
    `X-Pingback` header;
  - REST user routes hidden from visitors who cannot `edit_posts`. The gate is not
    `list_users`, because the block editor's author selector needs these routes and an
    Editor has no `list_users`;
  - `?author=N` and author archives answer 404 unless a build opts in with the `<prefix>_author_archives` filter; the byline links to the archive only then;
  - theme and plugin editors blocked through `map_meta_cap`;
  - `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and a conservative
    `Permissions-Policy` sent on `send_headers`, and `X-Powered-By` removed.
  The cinematic starter's partial copy moved out of `inc/performance.php` into the same file.

- **`WP_AUDIT_SUITE_NODE_MODULES`**: point `--suite` at packages the machine already has,
  such as a global install (`npm root -g`), instead of the managed install.
  `PLAYWRIGHT_BROWSERS_PATH` is already respected when set.

- **`bin/theme-template-check.mjs`: template contracts that no build step enforced.**
  `/wp-finalize` Check 4 and the practices audit (WP-016, WP-053, WP-054) run it. It
  checks three things:
  - **abspath**: every theme PHP file carries the quoted `defined( 'ABSPATH' )` guard, and
    the unquoted PHP 8 fatal form fails. The agents already required the guard, and
    sixteen `inc/seed/*.php` files shipped without it anyway.
  - **classes**: on a compiled Tailwind theme, an HTML entity inside a class token fails,
    and so does a utility-shaped token (a variant, an arbitrary value, a utility prefix)
    with no selector in `assets/css/dist/*.css`. A template's
    `group-aria-[expanded=&quot;false&quot;]:rotate-90` compiled to nothing and the icon
    never rotated. BEM classes, `js-*` hooks and plain words are ignored. Classes built at
    runtime are listed as `CANNOT VERIFY` and do not fail the check.
  - **widgets**: `role="tab"`, accordion-trigger or `data-directory` markup requires its
    module (`tabs.js`, `accordion.js`, `directory-filter.js`) in `assets/js/src/index.js`.

- **`/wp-adopt`: audit, debug and clone sites this plugin did not build.** Before this,
  `/wp-audit`, `/wp-debug` and `/wp-clone` required a manifest that only `/wp-create`
  writes, and stopped with "not created by /wp-create" on any site without one. A client
  site on a commercial theme could not be audited at all. The alternative was `/wp-create`'s
  Adopt Mode, which reconfigures the vhost, SSL and options of a site that already worked.
  - `bin/wp-config.mjs adopt` runs one read-only WP-CLI probe and writes a manifest with
    `"origin": "adopted"`. The manifest records:
    - `code_scope.editable`: the child theme, the site's own plugins and mu-plugins;
    - `code_scope.read_only`: the parent theme and plugins an updater maintains;
    - `stack`: the SEO, security, fields, multilingual, builder and cache plugins;
    - the function prefix, inferred from the child theme. `<parent>_child_` wins over the
      vendor's `<parent>_`.
  - The operator confirms the scope and prefix before anything is written.
  - The three commands offer adoption when their gate exits `3`.
  - A created project's generated block, validation and prose supersession are unchanged.

- **Card footers floated at different heights.** A demo card carried `mt-auto` on its link,
  and the generated template dropped it. `wp-template`, `wp-tailwind` and the
  `wp-tailwind-system` skill now say how a card pins its footer: the card is
  `flex flex-col`, with `h-full` in a grid, and the price or CTA block is `mt-auto`. Every
  layout utility from the demo section is carried into the template, never re-derived.

  **Tabs, accordion and directory-filter modules in the tailwind starter.** The starter had
  none. A build's hand-made `tabs.js` only moved the underline marker, with no
  `aria-selected`, no panel switch and no keyboard. Two of its three directories had no
  results count and no "clear filters", because each filter bar was written for its own
  template. The three modules are imported by `index.js`:
  - `tabs.js`: `role=tablist/tab/tabpanel`, `aria-selected` plus `is-active`, the other
    panels hidden, arrow/Home/End keys, and a marker as wide as the active tab's label;
  - `accordion.js`: groups scoped per container, `data-accordion="single|multiple"`. FAQ
    lists open one item at a time; standalone fold blocks are independent and open by
    default;
  - `directory-filter.js`: text and select filters over a rendered list, a results line
    from `data-count-template` that is hidden while unfiltered, and a clear control that
    resets every control and reloads without the URL's filter parameters.
  `/wp-cpt`, `/wp-section`, `wp-template` and `wp-tailwind-system` now point every tab set,
  FAQ and directory at the modules. They also record that a filter's GET name must never be
  a public CPT or taxonomy query var. The string table gains six `directory_*`
  strings: the count and its singular, clear, empty, the search label and the empty option.

  **In-page anchors landed under the sticky header.** Nothing set `scroll-padding-top`, so
  every `#section` link on a build scrolled its heading behind the bar. The tailwind
  starter's `base/reset.css` now pads `html` by `--header-offset` + 1.25rem, and `index.js`
  keeps that variable equal to `#masthead`'s live height while it is sticky or fixed, so
  the desktop and mobile bars each get their own offset. The cinematic starter pads by its
  fixed nav's measured height (88px desktop, 80px mobile) + 20px. `/wp-header` keeps the
  `masthead` id and states the contract.

  **A deleted contact form printed CF7's "Not Found" notice on the page.** The section ran
  the settings-page shortcode through a bare `do_shortcode()`, and the form it named had
  been re-imported under a new id. The tailwind starter's `inc/cf7-helpers.php` gains
  `prefix_contact_form()`: it resolves the form the way CF7 does (hash, post id, title)
  and returns `''` when none exists or CF7 is inactive, and `/wp-section` wraps the
  contact section in its result.

### Changed

- **Versioning the seeders is now the project's decision.** The `wp-cli-patterns` skill
  argued for committing `inc/seed/` without saying it could be otherwise, so a session
  kept re-opening it on a project that had chosen to move its database by hand. The skill
  now keeps versioning as the default, names gitignoring `inc/seed/` as the alternative and
  what it trades away (the scripts that reproduce the content live on one machine), and
  asks for the decision to be written once in the project's `CLAUDE.md`. Seeders still
  belong in `inc/seed/`, never a scratchpad. `tests/checks/wp-cli-patterns-seed-persistence.sh`.

- **`wp-cf7` put `admin_email` in the sender unchecked.** Both `mail.sender` and
  `mail_2.sender` were `blogname <admin_email>`. On a free-mail or foreign domain that fails
  SPF, DKIM and DMARC, and a real build's forms carried CF7's own "sender not in the site
  domain" and "unsafe email without protection" warnings. The agent now computes a sender on
  the site's domain (CF7's own rule), warns on free-mail domains, allows `[your-email]` as a
  recipient only in a protected `mail_2`, runs `WPCF7_ConfigValidator` after every save and
  reports its messages, and adds an SMTP note: configured per environment, credentials never
  in the repository, tested with `wp_mail()` plus the plugin's email log.

- **`/wp-audit` on an adopted site audits vendor code but never edits it, and respects the
  site's stack.**
  - Findings under `code_scope.read_only` are always `Fix: manual`. After each fix agent
    returns, the fix phase checks that nothing under a read-only path changed. An update
    overwrites vendor files, so a fix written there is lost at the next update.
  - Step 4 no longer offers Rank Math beside Yoast or AIOS beside Wordfence.
    `wp-audit-rankmath` and `wp-audit-aios` stop before installing anything when the stack
    names another plugin. Before, the audit offered a second SEO plugin or a second
    firewall as a fix.
  - An adopted site's i18n strategy is measured (`polylang` or `none`) and never falls back
    to `suffix`.

- **Browser verification was Chromium-only and installed its own browser.** `bin/audit-suite.sh`
  ran `playwright install chromium`, which downloads a revision-pinned build and died where
  that is forbidden. Its config declared `firefox` and `webkit` projects that no pass ever
  ran, and `bin/demo-verify.mjs` shot seven widths in one engine.
  - `bin/lib/browsers.mjs` resolves an existing executable (Playwright's caches, the
    revision the loaded playwright-core's `browsers.json` pins first, then the newest, then
    the system Chromium; `WP_BROWSER_*` overrides) and logs the executable and revision it
    chose, naming a mismatch with the pin. Nothing downloads a
    browser any more, and the "run `npx playwright install`" hints are gone.
  - The suite hands the executables to its vendored files through a `--require` preload
    (`bin/lib/pw-executables.cjs`), so they stay byte-identical to upstream. The
    accessibility pass also runs in Firefox and WebKit when they exist, and prints a skip
    notice when they do not.
  - `demo-verify` adds 620 and 1100 to its widths (nine viewports). When a Firefox build
    exists it shoots every viewport in Firefox too and reports each layout box that differs
    from Chromium by more than 2px as an advisory `engine-delta`. `--no-firefox` skips that
    pass.

  **`bin/css-contour-lint.mjs`: contours that differ across engines.** Firefox on Windows
  notches the corners of a 1px `border` with a `border-radius`, and Linux Firefox does not
  reproduce it, so no screenshot here can catch it. The lint flags that pattern on a
  transparent or white control (use `box-shadow: inset 0 0 0 1px`), `drop-shadow` on a
  bordered rounded ring, and a `type="search"` whose native clear button is not hidden
  (Chromium draws it, Firefox never does). CSS is walked by brace depth, so nested rules
  (`&:hover { }`) and rules inside `@media`/`@supports`/`@layer` are each read for their own
  declarations; hsl()/hsla() and space-separated rgb() backgrounds are read as colours; and a
  search field counts as covered only by a hiding rule whose selector reaches it (a global
  `input[type="search"]` rule covers every field, a class-scoped one only fields with that
  class). `/wp-finalize` Check 3 and the practices audit
  (WP-055) run it, and `wp-css-system` and `wp-tailwind-system` state the rules, including
  one custom clear control per search field.

## [1.27.0] - 2026-09-21

### Changed

- **A generated plate is graded to the demo's own palette, and the build no longer
  pastes the world.** An image prompt used to carry the world preamble (if the build
  remembered to paste it), the subject, and the sector's "use" terms — and nothing
  from `demo/DESIGN.md`. A low-key cinematic preamble on a warm-paper editorial demo
  produced a good photograph that belonged on some other page. `bin/image-gen.mjs`
  now composes what is sent: the `## World` block from `demo/BRIEF.md`, the build's
  `SUBJECT`, a `FORMAT` line from the gap's aspect, a `COLOUR` line from `DESIGN.md`'s
  canvas, ink and one accent, and a fixed `NEGATIVE` line (no text, no logos, no UI —
  copy is set in HTML, and a plate carrying letters carries misspelled ones). The
  composed text is what is hashed, so editing the accent regenerates every plate, and
  is recorded on each gap as `prompt_sent` and in the sidecar. The build writes the
  `SUBJECT` and nothing else; the skeleton is in
  `skills/wp-demo-craft/references/image-prompt.md`, adapted from MengTo/Skills'
  `design-first-ui-prompting` (MIT). A missing `DESIGN.md` or `## World` is said
  once and composed without, never refused.
### Added

- **A craft build commits to one aesthetic family, and an Avoid hit is a ship
  blocker.** `uniqueness.md` §6 named seven families by what they read as and who
  earns them, and the interview asked which; nothing downstream could tell whether
  the answer was honoured, and a build that said "brutalist" and shipped a glass
  card had chosen two families — which is to say none, the shape every "generic"
  note describes. `skills/wp-demo-craft/references/families.md` now carries the
  enforceable half for each of the seven: type, palette, surfaces, motion,
  sequence and an **Avoid** list, adapted from the style-lane skills in
  MengTo/Skills (MIT). `/wp-demo` records the family under `## Family` in
  `demo/BRIEF.md` with its Avoid list verbatim before the first section, hands
  that list to the verify critique beside the seven rubric lines, and `SKILL.md`
  lists a hit among the ship blockers. The rubric stays seven lines: an Avoid hit
  is a fail, not a grade. Premium-minimal is recorded only with the client's own
  word for it — it is the family the skill drifts to when nobody chose.

## [1.26.0] - 2026-09-20

### Added

- **A seventh auditor, for the question the other six do not ask: can a person use this
  site?** `/wp-audit --usability` dispatches the new `wp-audit-ux` agent against the
  `UX-NNN` catalog in `skills/wp-audit-ux-standards/SKILL.md` — forms and data entry,
  navigation and task flow, links **followed** rather than inferred, hover and active
  states, rendered line length per breakpoint, and whether the logo and the type scale hold
  still between templates. A form that marks no field as required is valid HTML, escapes
  correctly, loads fast and passes WCAG; six auditors had nothing to say about it.
  Contrast, focus order and target size are deliberately absent from the catalog: they are
  `wp-audit-a11y`, and where a defect is genuinely both, the accessibility code is the one
  reported. Two codes for one defect inflate every count and make the ledger's identity
  useless.
  **It is the first auditor whose scope is a list of URLs**, so Step 2.7 fixes one.
  `--pages auto` derives it from the manifest, the primary menu, the sitemap or the home
  page's links — in that order, stopping at the first that yields pages — and always adds
  the 404 and any page carrying a form, because a third of the catalog lives on those two
  and no ranking finds them. The list is capped at eight, one page per template, and the cap
  is printed: auditing forty pages measures five templates eight times each and produces a
  report nobody acts on.
  Two rules keep the result honest, and both failures are quiet. **A page-level criterion
  with no page list is `UNMEASURED`, never `PASS`** — an audit that measured nothing and
  printed no failures reads exactly like a clean site. And **`N/A` and `UNMEASURED` are both
  excluded from the denominator**, the first because a site is not worse for lacking a
  feature it was never meant to have, the second because it is outstanding work and folding
  it into either side of the fraction hides it. Applicability is decided *before* scoring,
  so an awkward criterion cannot become `N/A` for having been hard to measure.
  Almost every fix in this catalog changes how the site looks, and four of them move
  layout, so the agent measures `getComputedStyle()` and `getBoundingClientRect()` before
  and after, at both widths and on every element carrying the class — not only the one it
  was looking at.

- **The browser half of an audit runs as a suite, not as a hope that the session has a
  browser.** `/wp-audit --suite` scaffolds `.wp-audit/suite/` from the new
  `templates/audit-suite/` — a real Playwright project with axe-core, Lighthouse and three
  engines — runs it against a live URL through `bin/audit-suite.sh`, and converts what it
  measured into the run file `bin/audit-report.mjs` already renders. Tier 3 was gated on
  whether whoever ran the audit happened to have a browser automation tool, so the same
  project measured differently depending on the session and nothing could run unattended.
  The template is vendored from the `web-portal-audit` skill rather than depended on,
  because a plugin that only works when a user-scoped skill is installed works for one
  machine. `VENDORED-FROM.txt` records the source commit and
  `tests/checks/audit-suite-sync.sh` compares the two when the origin is on the machine and
  SKIPs when it is not — CI has never seen it, and a vendored tree has to keep working
  there.
  Three things are enforced rather than documented. The install is **shared**: browsers and
  `node_modules` live in one cache keyed by the template's `package.json`, so a version bump
  installs beside the old copy instead of mutating what other projects are symlinked to, and
  the second audit on a machine is not as expensive as the first. The Lighthouse pass runs
  **alone**, because a score measures the machine as much as the page. And `audit.config.js`
  is written once and then left alone: it holds the selectors somebody inspected the real
  DOM to find, and a scaffold that overwrote it each run would quietly re-measure a
  different site.
  `scripts/to-run.js` is the seam, and it translates rather than re-derives. A criterion
  becomes `UX-046`, an axe rule `A11Y-AXE-*`, a Lighthouse row `PERF-LH-*` — evidence rows
  never become criteria, or the total changes every run. Ownership comes from the suite's
  own four-way classification instead of a second list that would drift within a release,
  and an unmapped one is an error rather than a guess, because guessing `code` turns a
  setting into something the commit is assumed to carry. A `pass` is not a finding and a
  `manual` criterion is neither: it goes to the run's unmeasured list, under its own
  heading, where nobody can read it as a pass.
  Where a measured finding and a code finding describe the same check **and** the same
  resource, the measurement wins and the loser's code is kept as evidence — otherwise one
  defect is reported twice and every count is inflated. `bin/audit-report.mjs --merge` does
  it, rather than a sentence telling somebody to: a rule stated in one step and executed in
  another is a rule nothing applies. A shared check with a different resource stays two
  findings, because a contrast failure measured on a page and one in a rule no audited page
  uses are not the same defect — and the second is the one nobody would find again.
  All three routes now agree on how a finding is identified. The resource convention is
  written down once (`page:/contact/`, `post:412`, `template-parts/hero.php:34`, `site`),
  a page-level finding is one row per page rather than one per occurrence, and the Step 6
  dispatch prompt asks **every** agent for an owner, since the renderer refuses a finding
  that arrives without one.

- **An audit now produces something you can hand over.** `/wp-audit --report md|html|both`
  writes the run to `.wp-audit/informe-<date>.md` and `informe-<date>.html` through the new
  `bin/audit-report.mjs`. The console report is gone with the scrollback and
  `.wp-audit-findings.json` is a working file of check ids, so every audit was run twice:
  once to find the problems and once by whoever wanted to read them. The HTML is a single
  file with no external stylesheet, script or font, because a deliverable is opened offline,
  attached to mail and printed to PDF, and a page that fetches anything renders correctly
  only on the machine that made it.
  **Every finding now names who applies it**, and the four owners exist because of the one
  that gets lost. `code` is a theme file and travels with the commit; `setting` is a
  WordPress option, a plugin's configuration or a server rule, applied here with WP-CLI and
  left behind by the commit — the staging panel has no WP-CLI, so it is a step to repeat
  rather than a fix that shipped; `content` needs a person to write a text; `manual` needs
  judgment or an external tool. Ownership follows what the fix touches, never whether the
  audit could automate it, or `setting` collapses into `code` the moment a fix is
  auto-applied. The renderer refuses a finding without one and exits `1` naming it: a plan
  whose last column is blank looks exactly like a populated one until somebody reads it.
  The report is written **before** the fix phase, always. The dated report is the baseline
  the next audit is measured against, so a run that fixes first has no before to compare
  with, and the user cannot choose what gets touched in their site without seeing the whole
  of it. A machine sidecar is written beside the documents and the next report diffs against
  it by finding identity — resolved, new, still failing — so fixing one issue and finding
  another stops reading as no change. The sidecar is not the ledger: the ledger is the
  project's running history of every finding ever seen, a sidecar is one dated snapshot, and
  the renderer never parses its own Markdown back, because a report edited by hand would
  otherwise rewrite what the next comparison claims happened.

- **A site's media can live in S3.** `/wp-s3` installs S3 Uploads with its `vendor/` tree,
  writes `s3-config.php` at `0640`, hooks it into `wp-config.php` behind a timestamped backup,
  and installs an mu-plugin that points the plugin at an S3-compatible endpoint and does
  nothing on AWS. `/wp-s3-media upload|download` then moves `wp-content/uploads` in either
  direction, reading the connection out of the site's own config so there is no second place
  to keep in sync. `skills/wp-s3/SKILL.md` owns the procedure and `references/aws.md` the
  bucket, CloudFront and IAM side; both commands are runners.
  Four decisions are written down where the next edit will read them, because each looks like
  a simplification. The setup script does **not** activate the plugin and `S3_UPLOADS_AUTOENABLE`
  is `false`: activation must not move a file, and rewriting starts at `wp s3-uploads enable`
  when someone is watching. The secret arrives in the environment and never in `argv`, which
  `ps` shows to every user on the machine. `--revert` downloads the media *before* removing
  the configuration — without `s3-config.php` there is no bucket, region or credential left to
  fetch them with — and renames the config and mu-plugin to `.disabled` rather than deleting
  them. And `/wp-s3` asks about downloadable products before anything else: with the *Redirect*
  method the customer gets the file's public URL, kept private the redirect returns `403`, and
  that has no clean answer with this plugin, so it changes the recommendation rather than the
  configuration.
  The transfer is verified by result rather than by report. The client was measured writing
  **7 of 38 objects and exiting `0`**, and printing its summary table while the backend was
  down, so `scripts/verify-transfer.py` lists both sides and compares names and sizes — an
  upload must account for every local file, a download for every object. Neither direction
  passes `--overwrite` or `--remove`, which is what makes a second run safe and stops a stale
  local copy from burying a newer one in the bucket; the client exits non-zero for each file
  it refuses to clobber, so a refusal is counted and reported and any other `<ERROR>` line
  fails immediately. Trusting the client's own pending-bytes figure instead was tried and is
  wrong in the direction that matters: every byte-identical file already on disk counts as
  pending forever, which made a revert abort with the media half restored.

- **The wp-s3 setup proves the credentials with the plugin still off, and an install is
  finished rather than assumed.** Three defects found by running the scripts against a real
  S3-compatible server. The credential check was `wp s3-uploads verify`, a subcommand the
  plugin registers — and setup leaves the plugin deactivated on purpose, so it answered
  `'s3-uploads' is not a registered wp command` on every first run and exited `1` with the
  five preceding steps already applied; `scripts/check-credentials.php` now lists the bucket
  through the SDK the plugin bundles, which is the same question with the plugin off.
  `composer install` refused the lock file on any PHP without `ext-iconv` — a requirement of
  a polyfill reached only through Symfony's console, never inside WordPress — so the install
  adds `--ignore-platform-req=ext-iconv` when `php -m` does not list it. And a failed
  composer run left the plugin directory behind, which the next run read as "already
  installed": an installed plugin is now `vendor/autoload.php`, not a directory, and a
  half-install is completed instead of configuring a site around a plugin that fatals on
  activation.
  Two more found the same way, both about how the secret travels. The client was handed
  its credentials in `MC_HOST_<alias>`, a URL whose key and secret it does **not**
  percent-decode: measured against a real server, a secret holding `/`, `@`, `+`, `%`, `#`
  or `?` authenticated verbatim and failed once encoded — so the encoding was wrong for
  exactly the secrets it existed for, and AWS generates base64 secret keys where `/` and
  `+` are ordinary. A secret holding `:` could not be expressed in that URL at all. The
  alias now lives in a `0700` configuration directory the script removes on exit, which
  carries every character and still keeps the secret out of `argv`, where `ps` would show
  it. And `s3-config.php` had its credential lines assembled in the shell, so a secret
  holding a single quote closed the PHP string early and `php -l` condemned a file that
  already held the credentials; they are quoted where they are written now.
  Five more came from the reviewer and are worth naming because four of them are about
  what happens **after** something already went wrong. A failed transfer used to return
  before the comparison ran, so the one moment an operator most needs a per-file
  accounting — "how much of it landed?" — was the moment they were denied one; the
  comparison now runs either way and the run still fails. A revert whose `require` block
  had been hand-edited printed a warning and carried on to rename `s3-config.php`, leaving
  a site that requires a file that is no longer there; it now stops with the block to
  remove and touches nothing. `verify-transfer.py` had no timeout, so an unreachable
  endpoint hung forever under `set -e` (300s, `WP_S3_LIST_TIMEOUT` to raise it). Both
  `wp-config.php` rewrites are written to a neighbouring file and renamed, because a
  process killed mid-write left a truncated `wp-config.php` and a white screen. Every `wp`
  call in the revert is guarded now, and the plugin is asked whether it is active exactly
  once: WP-CLI answers a site it cannot read with three lines of its own, and those used to
  land between step 2 and step 4 of a run whose step 1 had already said the plugin was
  inactive. A non-zero exit whose every error was a refused overwrite no longer passes in
  silence either — the run still succeeds, because that is the ordinary repeated transfer,
  but the exit code is printed, since a client that refused three files and then timed out
  on the fourth is indistinguishable from here and only the comparison tells them apart.
  One more the scripts were never going to be asked about: **form attachments no longer
  leave the disk.** `uploads/wpcf7_uploads/` holds what people attached to a form — CVs,
  identity documents, invoices — and it was being mirrored into the bucket, where the only
  thing keeping it unreadable was the bucket policy being written correctly. It joins
  `wc-logs`, `cache`, `wio_backup` and `wrio` in the exclusions, in both directions. New
  installs never write there anyway, because `s3-config.php` redirects both WooCommerce's
  logs and CF7's temporary directory to local paths — but a site migrating in arrives with
  years of them.
  Five more from a second pass over the same scripts, and the first is the one that gave a
  wrong answer with no error anywhere. `read-s3-config.php` matched `define()` textually
  over the whole file, so a line an operator comments out while rotating a bucket or a key —
  the new `define()` written under the old one — was read as the site's configuration. PHP
  keeps the **first** `define()` of a name and ignores every later one, so matching the
  first occurrence is right for code; a comment is not code. Every caller was handed the
  stale bucket while the site served from the new one, and the transfer then verified clean
  against the wrong target. Comments are removed with the PHP tokenizer before anything is
  matched, because a regular expression cannot tell a comment from `//` inside a URL.
  The revert told two different failures the same story: Python exits `3` when the `require`
  block has been hand-edited and `1` on any unhandled exception — a read-only site root is
  the measured one — and the shell read every non-zero status as the first, sending an
  operator with a permissions problem to go and delete a block nobody had touched. Setup
  skipped the install whenever a `vendor/` tree existed, so re-running it with `--version`
  to pin or upgrade was a silent no-op against whatever the previous run left behind; the
  requested version is stamped at install time and a mismatch is now reported by name,
  without replacing a tree that may carry local edits or belong to an active plugin.
  The reviewer's next round found the one thing none of this had asked: **the plugin's own
  code arrived unchecked.** It was a tarball over HTTPS from a tag, unpacked straight into
  `wp-content/plugins/`, and once activated every line of it runs on every request to the
  site. A tag can be moved upstream, and GitHub regenerates those archives, so their digest
  is not stable enough to pin. What is stable is the commit id — the hash of the tree
  itself, which git will not produce from any other content — so the install clones at the
  pinned commit and refuses anything else, naming both ids. Measured: a deliberately wrong
  pin stops the run with nothing installed. Where the pin does not apply — git absent, or a
  `--version` other than the pinned one — the run stops rather than falling back quietly;
  `--unverified-download` takes the tarball, says so, and prints its sha256 so an operator
  who accepts it can at least record what they accepted.
  One from the reviewer, narrower than it looks: `check-credentials.php` asked `empty()`
  of every value it read, and `empty()` reads `'0'` as absent. The bucket and the region
  could never be that, but the key and the secret are arbitrary strings from whatever
  server the site talks to, and a credential rejected as missing is debugged in the wrong
  place. Presence and emptiness are asked separately now.
  Two smaller: the access-key id supplied for the instance-profile fallback stayed in the
  environment for every child process after its secret had been unset, and a value holding
  a line break was accepted by the reader although `--export` writes one `NAME='value'` per
  line and every consumer splits on newlines — it is refused with its name now, rather than
  arriving truncated or missing.
  Two smaller ones: `verify-transfer.py` called an empty remote listing a verified download,
  and the client answers an unknown alias with exit `0` and no output, so "no objects" and
  "could not list" arrived identically — a download that lists nothing now fails. And a
  revert printed one `<ERROR> … Overwrite not allowed` line per file in the normal case where
  every file is still on disk; the refusals stay in the log and are reported as a count.

- **`/wp-audit --seo` now audits a local business as one.** The SEO auditor covered on-page
  markup and Rank Math configuration; for a site whose ranking surface is a business profile,
  a map pack and a set of directory listings, that left the whole local dimension unchecked —
  the only local-aware line in the plugin was a `LocalBusiness` JSON-LD template with nowhere
  to verify it. `SEO-055` through `SEO-063` add the checks, and the new
  `wp-audit-local-standards` skill carries the criteria: the applicability gate, the
  business-type and vertical taxonomies, the NAP normalization rules and the location-page
  sampling gates.
  Three things are written down because each one is a way the check goes wrong. The
  applicability gate runs first and demands two independent signals, since a `tel:` link in a
  footer is as common on a brochure site as on a dentist's; the business type is resolved
  before the address checks, because a service-area business has no street address by design
  and reporting one as missing is a false critical; and NAP values are normalized before
  comparison, or `+34 900 00 00 00` and `900000000` are reported as a discrepancy and the
  check gets muted. Under the `suffix` i18n strategy every `_<lang>` variant of the
  options-page fields is compared too — an address correct in one language and stale in the
  other is a real defect, not a translation artifact.
  `SEO-063` is CRITICAL alone among them: an `aggregateRating` no review data backs is
  structured-data spam and risks a manual action. `SEO-056` and `SEO-061` are reported and
  never auto-applied, because both change rendered markup.
- **A decorative CSS background below the fold is deferred.** `background-image` has no
  `loading` attribute, so every background a template prints is downloaded with the first
  paint however far down the page it sits. On a real build four of them — a footer band, a
  map panel and two decorative sections, 120–320KB each — were 2.3MB of a 3.7MB first paint.
  `prefix_lazy_background_attr( $url, $idle = false )` in the `__tailwind__` starter returns
  the declaration in a data attribute instead of a style value, the bundle paints it through
  an IntersectionObserver with 600px of forward margin, and
  `prefix_print_lazy_background_noscript()` repeats every held-back declaration inside a
  `<noscript><style>` block on `wp_footer`, so a visitor with JavaScript disabled sees the
  same page. `agents/wp-template.md` forbids it on the hero: that one is the LCP element, and
  deferring it moves the largest paint later by whatever the observer waits. `PERF-057` finds
  the defect in a theme this plugin did not build.
  Two failures are written down where the next edit will read them, because both look like
  cleanups: the key travels in a data attribute and not in `id`, since these sections usually
  carry one already and an HTML parser drops the second one — leaving the noscript rule
  selecting nothing while the page still looks correct with JavaScript on; and the painter
  tests `document.readyState` before trusting a `load` listener, because a deferred bundle on
  a cached page runs after that event has fired and the listener alone is never called.
- **`PERF-058` reports a theme that serves its own JavaScript unminified, and the fix is one
  filter.** A hand-written theme — the common case in an audit, with no bundler and one
  `wp_enqueue_script()` per file — ships `assets/js/*.js` as written; on a real build that was
  55.4KB where the minified set is 23.3KB. The criterion sums the unminified bytes rather than
  flagging a single small file, checks both twin shapes (`<name>.min.js` and
  `assets/js/min/<name>.js`) so a theme that already has the fix is not reported, and exempts a
  bundled theme, whose build minifies already.
  The fix swaps the URL in a `script_loader_src` filter that tests the twin exists on disk
  first, so no `wp_enqueue_script()` call has to know the build exists and a checkout where the
  build has never run serves the sources instead of 404ing every script. The rejected
  alternative — rewriting every enqueue call to a `.min.js` path — is named in the fix, with
  the reason. And the trap goes into the project's own `.claude/CLAUDE.md`, because it is
  silent: once the twin exists, editing a source file under `assets/js/` changes nothing the
  site serves. The page loads, the console stays clean, the old behaviour persists, and reading
  the source confirms a change that is not live — so the build runs in the same pass as the
  edit, and the theme version constant is bumped so the rebuilt file is not served from cache.
- **`PERF-059` reports a self-hosted family that carries scripts the site never writes.**
  `PERF-023` flagged a woff2 over 100KB and said nothing about why it was that size. A family
  downloaded as one file per weight carries every script its designer shipped, so a site
  written in one Latin language pays for Cyrillic, Greek and Vietnamese on every first paint
  and renders none of it: eight faces were 442KB on a real build, 263KB after subsetting, and
  141KB off the home page. The criterion reads each file's `cmap` rather than guessing from
  the name, sums the weight the first paint actually requests, and exempts a face carried with
  Google's own `unicode-range` blocks — which is what `/wp-init` Step 4.5 produces, so the
  finding cannot fire on a theme this plugin scaffolded.
  The fix subsets with `pyftsubset`, keeps `--layout-features='*'` (a subset without kerning
  and ligatures renders visibly worse at the same glyph coverage — a regression wearing the
  shape of a saving), and **verifies coverage against the site's own text before replacing a
  file**, treating a missing glyph as a refusal rather than a warning. That check is the
  reason this is safe to auto-fix: a missing glyph does not error, the browser silently falls
  back for that one character, and the result is a font that is "slightly off" on one page
  with nothing to point at. The fix also says where the text sample has to come from — ACF/SCF
  field values and term names are not in `post_content` — and that the original family must be
  kept, because a subset cannot be widened back into one.
- **`WP-051` catches an action name the browser sends that WordPress has no hook for.**
  `admin-ajax.php` dispatches on `action` and the hook is `wp_ajax_<action>`, so a theme that
  localizes the *callback's* name sends something nothing is listening for: the endpoint answers
  `400` with `0`, the page renders, the console shows one failed request and the feature is dead.
  On one audited theme all four filter UIs — a document library, a gallery, a news list and a
  taxonomy archive — had been dead this way, because the localized names carried the theme prefix
  the `add_action()` calls did not. The procedure collects both sides (a grep over one of them can
  never see a mismatch), confirms each name against the real endpoint with one `curl` before
  reporting, files it CRITICAL, and rejects the tempting fix of renaming the hook to match the
  message — that changes a public contract any other script may already use. A front-end handler
  registered without `wp_ajax_nopriv_`, and a `check_ajax_referer()` no localized nonce feeds,
  fold into the same finding.
- **`WP-052` catches a section printed for a record that no longer exists.** `WP-048` resolves IDs
  that point at posts; these point into a plugin's own table — a poll, a form, a slider — where
  `get_post()` sees nothing and the orphan sweep cannot reach them. The page then prints a bare
  `[poll id="12"]` as text, or an empty band whose heading and padding still render. The fix
  guards the whole section rather than the shortcode alone, and the two wrong remedies are named:
  hiding it with CSS leaves the data broken and a gap in the layout, and a guard inside a
  container that already has margins is how an empty band ships.
- **Two performance measurements are recorded where an audit will read them.** Neither can be
  re-derived from code, and both cost a session once.
  *A Lighthouse run needs an idle machine.* The same URL, same flags, measured under CPU
  contention and then on an idle machine, read performance 62 with LCP 10,170 ms and 94 with
  LCP 1,580 ms — with no theme change between the two. A contended run is indistinguishable
  from a real regression by inspection, so `wp-audit-standards` now forbids running Lighthouse
  beside anything else, requires a re-measurement before a metric finding is filed, and
  requires both halves of a before/after pair to be measured under the same conditions. A
  search-results spec that looked like it hung completed in 4–7 s once Lighthouse stopped
  competing with it, and the suite went from 4.3 minutes to 1.0.
  *Inline critical CSS, measured and rejected.* The standard advice for a render-blocking
  stylesheet improved FCP from 990 ms to 570 ms and moved LCP the wrong way, 2950 ms to
  3150 ms, because the inline block precedes the hero image on the same connection; the
  above-the-fold-only variant carries less than the first viewport needs and took CLS to 0.139.
  The table is in the skill so the experiment is not repeated blind, with the rule that follows
  from it — when FCP and LCP disagree, LCP decides — and the real cause the breakdown showed
  on that site: 276 ms of element render delay, because the carousel rebuilt its first slide
  and the second paint was the one being measured.
  `agents/wp-audit-performance.md` Step 3 points at both, so the warning arrives before the
  finding is filed rather than after.

### Changed


- **The i18n helper-parity check allows the Polylang variant its own internals.** It
  still requires every helper `i18n.php` defines, and now permits extras when their
  docblock says `@internal` — the Polylang model needs work the suffix model does not,
  and forcing a no-op twin into `i18n.php` would be a lie about symmetry. Both halves
  are mutation-tested. Its function-name pattern also widened from `[a-z_0-9]` to
  `[A-Za-z_0-9]`: a name containing a capital letter was truncated to a prefix of
  itself, which made a renamed helper read as the original.
- **A demo this plugin generated is no longer re-analyzed by `/wp-yolo`.** `/wp-demo`
  now writes `demo/.demo-plan.json` (Step 4.9, both modes) recording what it decided
  while authoring the pages — each page's role, each section's name, `kind`, `cpt` and
  BEM block, and the content types it built teasers and listings for. `wp-normalize`
  reads it and copies those verbatim, skipping the classifier rubric, the contact
  detection and the `review[]` entries that went with them. It had been re-deriving
  the plugin's own decisions from the plugin's own output, with a confidence score
  attached, which is the one case where a classifier can only lose information.
  The plan is trusted **per page and only where it matches the markup** — the section
  names are the join key — so a page added or edited by hand since the demo was
  generated is classified the old way and says which page and why in `review[]`.
  Normalize is still dispatched: it remains the only thing that writes
  `demo/.yolo-manifest.json`, and the plan deliberately carries no field guesses,
  assets, `cssRules`, `fonts` or `backgrounds`, because those are read off the markup
  and a second copy would be a second thing to keep true.
  `tests/checks/wp-demo-plan.sh` pins both halves.
- **The plan carries craft mode's slot names, with two guards.** A composition's
  `{{slots}}` are already field-shaped names `/wp-demo` chose, so `sections[].slots[]`
  records them and `wp-normalize` infers only type and value. Each entry carries a
  `group` (a run of slots that is really one repeater, not N flat fields) and a
  `computed` flag (a value the markup derives — an arc's `stroke-dasharray` against a
  300–850 scale — which must never be offered to an editor as a field). Both come from
  a build that shipped the wrong answer without them. `fields[]` was 52% of a real
  13-page manifest.
- **A demo now declares the controls it fakes.** `.demo-plan.json` grows `inert[]` —
  `{ selector, reason, needs, pages }` per faked control: the language switcher that is
  two `href="#"` links, a search box that filters nothing, a client-side pager the
  server will own. None of that is a defect in a demo; it becomes one the moment a
  builder reads the demo as a specification, which is what `/wp-yolo` does, and nothing
  on disk used to say which was which. `/wp-demo-verify` Step 3.5 grades the
  **declaration** rather than the control — failing `href="#"` itself would fail every
  honest mockup and get routed around with `href="#!"` — and `/wp-yolo` Step 4.6 and
  `/wp-header` read the list as a worklist. It must be written while authoring:
  backfilled from finished markup it degrades into "controls we could not prove were
  wired". On one 16-page build the switcher was wired only because a normalize agent
  happened to file it among forty-eight `review[]` entries, and `/wp-header` now
  refuses to transcribe a demo's switcher markup at all.
  **A `<form>` with `action="#"` or no `action` counts, and is the worse of the two**
  — a dead switcher announces itself on the first click, a dead contact form looks
  like it worked and drops the lead. Writing the list by hand on a real 16-page demo
  found one: a form with a real consent checkbox, honeypot and language select,
  submitting to the page it sat on, on two pages whose markup was byte-identical.
  Grep `action` as well as `href`. And the switcher test keys off the `href` alone:
  a mock switcher carries `hreflang` on both links and `aria-current` on one, exactly
  as a working one does.
- **`review[]` is for decisions, not for restating emptiness.** `wp-normalize` now
  collapses "why is this null" notes into one build note, and keeps *null by design on
  this path* apart from *empty because nothing was found* — the second is a finding
  about the demo. On the build below, "fonts is [] — there is no @font-face anywhere"
  was filed as reassurance that the scan had not failed, and was in fact reporting the
  defect fixed below. An explanatory entry that explains away a real gap is worse than
  no entry.
- **`wp-normalize` verifies the delimiters it reports.** A parallel run reported five
  pages as already delimited around the chrome when none of them were, because nothing
  checked the claim against the bytes. The fast path is now a per-page claim with a
  per-page proof.

- **Tier 3 is gated on a browser, not on a third-party skill package being installed.** The
  audit advertised its third tier as unlocked by an external package, and probed for that
  package's `performance/SKILL.md` on disk to decide. The gate was hollow in both directions.
  Nothing was ever read from that package at run time — every criterion it supposedly
  unlocked (the weight budgets, the Core Web Vitals thresholds, the WCAG 2.2 additions, the
  HTML5 cross-check, the security response headers, the live-site SEO checks) was already
  written into the audit agents, verbatim, under an `If <package> is available` conditional.
  So a machine without it skipped checks the plugin could answer from the theme source alone,
  and reported `Tier 3: not found` for a capability it had all along; a machine with it gained
  nothing but the flag.
  Tier 3 now means what it always described: measurement that needs a loaded page. It is
  gated on a browser automation tool — Playwright MCP, Chrome DevTools MCP or Claude in
  Chrome — and gates only the three Core Web Vitals, which report `UNMEASURED` without one
  instead of being assumed to pass. The checks that a file scan can answer moved to Tier 1
  unconditionally, and the two agents whose "Tier 3" was really *needs the live site*
  (`wp-audit-security` response headers, `wp-audit-seo` robots/sitemap/structured data) now
  say so and gate on a reachable host, the same gate SEC-038 already used.
  The manifest key `audit.web_quality_skills_available` is retired in favour of
  `audit.browser_measurement_available`; Step 2.5b reads the old key when a manifest predates
  the rename, reports it as drift like any other measurement, and writes the current one back.
  Availability is probed once, by the command, and passed down the dispatch prompt as
  `Browser measurement`. No audit agent probes for itself: their `tools:` lists carry
  `Read, Write, Edit, Grep, Glob, Bash` and no MCP tool, so an agent told to look for a
  browser would have been told to do something it cannot do.
  `tests/checks/audit-tier3-browser-gate.sh` asserts both directions, because a check that
  only greps for the new gate is satisfied by deleting the tier. Its first version proved the
  point at its own expense: written as a case-sensitive `grep -rln 'web-quality-skills'`, it
  passed while four references were still live — three agents opened with `**Web-quality
  skills**` and the dispatch prompt still carried `- Web-quality-skills: <available|not
  available>`. A capital letter and a space defeated it. It now matches either separator in
  either case, pins the three MCP tool identifiers that *are* the detection, and pins the
  dispatch line, and each of those assertions was confirmed by breaking the contract and
  watching the check fail.

### Fixed


- **`bin/demo-verify.mjs` can reach a site with a self-signed certificate.** Every
  context and page it opened rejected one, so a `/wp-create` local install — which gets
  HTTPS from its own CA — failed on `ERR_CERT_AUTHORITY_INVALID` at the first
  navigation. `/wp-finalize`, `/wp-polish`, `/wp-responsive-check` and `/wp-audit` all
  forward here, so this was not one gate failing: it was the entire finish-phase suite
  being unavailable on a standard local site, and a real build shipped with none of it
  run. Verified both ways against a self-signed server — the previous version dies at
  navigation, this one completes the walk and reports its findings.
- **`prose` reads the theme's colours instead of the plugin's grey.**
  `@tailwindcss/typography` ships `--tw-prose-body: gray-700` and
  `--tw-prose-headings: gray-900` and applies them to everything inside `.prose`,
  which beats an element that merely inherits. On a light palette it passes
  unnoticed; on a dark one it is grey on near-black — **1.2:1, measured on a
  delivered site's legal and article pages, found by eye.** The starter now binds
  the plugin's sixteen variables to its own role tokens, which is correct for the
  craft aliases too (on a dark craft palette `--color-dark` resolves to the light
  ink). Per-element `prose-headings:` / `prose-a:` modifiers still win, so nothing
  already written changes. `compositions/README.md` also reserves the class name:
  an element called `prose` picks up the plugin's margins, lists and `max-width`
  whatever its colours do.
- **One page's failure no longer destroys a directory walk.** A single
  `page.screenshot` or `page.goto` past its timeout rejected out of
  `demo-verify.mjs`'s page loop, so a 16-page run lost fifteen completed pages and
  wrote no `findings.json` at all — three times on one build, each re-run from zero.
  The page is now recorded as a blocking `page-crashed` finding with the reason, and
  the walk continues. Verified with a page that hangs forever among two good ones:
  before, nothing; after, `page-crashed` on the bad one and real findings on both
  others.
- **CF7 label rows are written on one line.** CF7 runs its form body through
  `wpautop`, so the newline an author naturally puts between a label and its tag
  becomes a `<br>`. Stacked with the control wrap's box and the `<p>`'s UA margin
  that measured ~100px per field — fourteen times on one form, reported by the
  client as broken spacing. 42px per gap against the demo's 0.4rem, closing to 6px
  once the rows were joined. `agents/wp-cf7.md` also now requires shipping the
  bridge stylesheet whenever the demo styles its own form.
- **`page-head` and `offer-table` shipped a root `reveal` that broke their own
  children.** Both compositions animate their direct children from `view()` ranges in
  `section.css` *and* carried `data-motion="reveal"`, which does
  `gsap.set(kids, {opacity, y})` on exactly those elements. Two writers on the same
  properties is a race, and it resolves differently in the two places the CSS lives:
  the demo wins it (`motion.js` inlined, runs before the start keyframe applies) and
  the theme loses it (`initMotion` at `DOMContentLoaded`, by which point it has). So
  the section animates in the demo and freezes at the keyframe's start value in the
  theme — a conversion block stuck at `scale(0.88)` on all 16 pages of a build, and at
  `opacity: 0` on a hard jump to the page bottom, while `/wp-demo-verify` passed that
  demo 66/66. Both READMEs already called the attribute redundant; it was worse than
  redundant. `page-head` is the interior-page floor, so this was on every interior page
  of every craft build. `references/devices.md` states the rule and
  `tests/checks/wp-craft-motion-collision.sh` fails on any direct child of a `reveal`
  root that carries an animation.
- **Rank Math is now proved to emit, not just configured.** New Step 1.6 reads the
  front end for JSON-LD, a meta description, OG tags and a `200` on
  `/sitemap_index.xml`, and refuses to continue on a zero. With
  `rank_math_registration_skip` false the plugin registers no `wp_head` callbacks at
  all, so a site with every module on and 47 general, 114 title and 17 sitemap options
  written emitted nothing — and every admin screen looked healthy.
- **Pages no longer claim to be `Article`s.** `pt_page_default_rich_snippet` is `off`
  (WebPage still emits), `pt_post_default_rich_snippet` stays `article`. Rank Math's
  own default had a pricing table asserting an author and a publish date.
- **Focus keywords are chosen for intent, never for score.** The score is almost
  entirely keyword-driven, so maximising it picks whichever word the page already
  repeats — an automated pass chose `credit`, `crédito` and `contacto` at 14/16 each.
  Also recorded: with no keyword set every keyword-dependent check fails at once,
  which is how 32 records sat at 20/100 with nothing visibly wrong.
- **SCF field-key uniqueness is verified by execution.** Rule 7 said keys must be
  unique and nothing checked; a duplicate key makes one definition win silently and
  the other field never appear. A real build had fourteen, and a regex-based audit
  reported clean on them twice — once because the pattern assumed single spaces around
  `=>`, once because shell quoting mangled it. `agents/wp-acf.md` now walks the
  registered groups and reports duplicates by name, and states the general rule: do
  not audit PHP structure with a regular expression.
- **The blog archive's fields belong on `page_type == posts_page`.** Located on
  `post_type == post` the group renders on every single post and on nothing else, so
  no editor screen ever offers the archive's kicker, title and note — the page prints
  its fallbacks forever and nothing errors.
- **`/wp-finalize` checks that every `t()`/`e()` key resolves.** The helper's last
  fallback returns the key, so an undefined one prints its own name as content: a
  delivery shipped six, including `contact_map_office` on the contact page.
- **`/wp-finalize` sweeps rendered output for escaped markup**, and
  `agents/wp-template.md` requires reading the demo's value before choosing the
  escaper. `esc_html()` on a field whose demo copy is `Every <b>24</b> hours` printed
  the tags on the page, in both languages.
- **`/wp-yolo` passes each section's line range to its template agent.** A craft page
  is ~4,000 lines of which ~3,360 are inlined CSS ahead of the body, so agents handed
  a path burned their context finding 7–34 lines of markup: three of four died with
  "Prompt is too long", one at the words "Now I have everything needed."
- **A translated page now finds its template.** WordPress picks `page-{slug}.php`
  from the slug and a translated page has its own slug, so `/es/nosotros/` looked for
  `page-nosotros.php`, missed, and fell through to `page.php` — which renders editor
  content, and a theme drawing its pages from section parts has none. Correct header,
  correct footer, nothing between them, HTTP 200. The Polylang `inc/i18n.php` variant
  now ships a `template_include` filter mapping a translated page to its
  default-language counterpart's template, so a third language needs no new template
  files. Recorded there too: sharing one slug across languages is **not** the fix and
  is worse — WordPress resolves a page request by slug *before* any language filter
  runs, so `/es/about/` serves the English post, canonical included.
- **`/es/` and `/es/blog/` no longer render the default language's fields.**
  `page_on_front` and `page_for_posts` are options holding one ID, so the front page
  and the posts page are the only two records WordPress does not resolve from the
  request. The helper hops to the counterpart through `pll_get_post()`. Every inner
  Spanish page was already correct, which is what made this read as a content problem.
- **Polylang routing is configured and then verified by request.** `hide_default = 0`
  (with the cost stated plainly: every default-language URL moves to `/en/…`), because
  an unprefixed default has nothing to disambiguate `/es/` against and serves English.
  And `PLL()->model->clean_languages_cache()` after any option or slug change:
  Polylang caches each language's `home_url` on the language term, so `/` 302s to
  itself, and **`wp rewrite flush` does not clear it** — which is why it looks like a
  rewrite problem and does not respond to the rewrite fix.
- **`/wp-seed` verifies menus from the front end, because WP-CLI conceals this one.**
  Polylang replaces the core `nav_menu_locations` theme_mod with its own per-language
  map in a **frontend** filter, which does not run under WP-CLI — so
  `get_nav_menu_locations()` prints correct IDs on a site serving no navigation at
  all. A delivery shipped with no nav links on any of 16 pages and a header that read
  as a deliberate minimal design. Every CLI-based check of this passes on a broken
  site; only an HTTP request sees it.
- **`/wp-polylang` records that an imported string outranks the theme's table.**
  `prefix_t()` asks `pll__()` first, so once a string is in Polylang's store,
  correcting the PHP changes nothing on the page and the edit looks unsaved. A build
  lost a round to this over 27 Spanish strings.
- **Fonts loaded from `fonts.googleapis.com` are now recorded as fonts.**
  `wp-normalize` read only `@font-face`, so a craft demo — which links its families
  rather than declaring them — produced `fonts: []` on every section. `/wp-yolo` Step
  4.5's carry is conditioned on that list, so it carried nothing, and a real build
  shipped a theme naming `"Inter", system-ui` over a demo rendering Archivo and Source
  Sans 3, with an empty `assets/fonts/` and no error anywhere. The `css2` query already
  names the families and weights; they are recorded with `hosted: true`. Step 4.5 also
  no longer believes an empty list: it greps the demo before concluding a demo has no
  fonts, and reports the gap when it finds one.
- **`@theme static` on the craft path.** Tailwind v4 drops a theme variable no utility
  references, and a craft demo's CSS reaches for `var(--color-canvas)` directly — so a
  bare `@theme` compiled an entire craft palette to nothing and the build still
  succeeded. `/wp-init` Step D4 now says which keyword, and why.
- **`footer-columns` no longer emits `href="tel:tel:+1…"`.** The template hardcoded the
  scheme onto `{{phone_href}}` while every other `*_href` slot in the library takes a
  complete href, so a builder filling it correctly produced a doubled scheme on every
  page of a 16-page demo. The slot now takes the whole href, and `fills.json` carries
  the `tel:`.

- **Field labels are written in the site's language, not in English.** The `wp-acf` agent
  generated every editor-facing string in English whatever the project's primary language was,
  so a Spanish-primary build opened on "Content", "Title" and "Leave empty to use English
  version" above Spanish content — and the person filling the page in was not the person who
  ordered the site in English. The agent now reads `- **Primary language:**` from the project's
  `.claude/CLAUDE.md` and writes the group title, tabs, labels, instructions, `button_label` and
  `message` in that language, with a worked Spanish-primary example beside the English one.
  The other half is the one that would have been lost: `key`, `name`, the file name and the
  language suffix stay English and ASCII. A `name` is the meta key — what `prefix_get_field()`
  asks for, what every template and seeding script names, and what the rows in `wp_postmeta` are
  keyed on — so translating one does not rename data, it orphans it, and the field reads empty
  with the content still in the database. And the suffix marks the *secondary* language: on a
  Spanish-primary site `hero_title` holds the Spanish and `hero_title_en` the translation, where
  a hardcoded `_es` would have named a Spanish field as the translation of itself. The agent's
  own two `Espa&ntilde;ol` labels became `'Español'` in the same pass, since whether an HTML
  entity reaches the editor as a letter or as its own source text depends on how the admin
  escapes that string. `tests/checks/acf-editor-language.sh` holds both halves and reads the
  Spanish example as a slice rather than against the whole file — every needle in it also
  appears in the English examples, so a whole-file grep stayed green with the example's field
  name translated. `skills/wp-bilingual/SKILL.md`, `/wp-header` and `/wp-footer` no longer give
  the English wording as the rule. `BACKLOG.md` had carried this as `DELIVERED` since the
  September 19 reconciliation with nothing in the agent behind it.

- **An accessibility fix that swaps a tag is measured before and after.** Half the operable
  fixes replace one element with another — a clickable `<span>` becomes a `<button>` — and none
  of them is markup-only: the browser applies its own styles to the new element, and a reset
  class added to neutralise them ties with the utility classes already there, which source order
  decides in the reset's favour. `<span class="icon-search text-white text-[1.625rem]">` became
  `<button class="btn-reset icon-search text-white text-[1.625rem]">`, `.btn-reset` declared
  `color: inherit` and `font: inherit`, and the icon painted black at 18px instead of white at
  26px. No colour or size value was edited anywhere, the diff read as an accessibility fix, and
  the client found the regression.
  Step 8 of `wp-audit-a11y` now requires `getComputedStyle()` and `getBoundingClientRect()` on
  the real element on both sides of the change, treats a difference as a regression that blocks
  the fix rather than a trade-off to explain, and extends the check to every element sharing the
  class and to both viewports. It also says why the screenshot gate cannot stand in for this: a
  26px icon becoming 18px inside a flex row moves nothing else and falls under the tolerance.
  `wp-css-system` carries the specificity half — a reset class is (0,1,0) like the utilities, so
  the tie goes to whichever comes last, and the DevTools rule list shows both declarations
  applying, which is what makes it invisible. The weightless `:where(.btn-reset)` form and the
  bare-tag reset are given as the two ways out.

- **The `get_field()` pattern test could not see a pattern written the other way.**
  `tests/checks/lib/acf-field-pattern-behavior.php` extracted only a double-quoted literal
  from `find-orphan-acf-ids.php`. Rewriting that pattern as a single-quoted literal — same
  pattern, same behaviour, still valid PHP — made the test print `no preg_match_all()
  pattern literal found` and exit 1, which reads as a broken pattern rather than a test that
  could not read it. That is the exact failure the test was added to prevent, one level up.
  The extractor now takes either quoting style, undoes only the escapes that style defines,
  and is itself checked against six fixtures before it is trusted on the real file.
- **`find-orphan-acf-ids.php` read every `.php` in the theme tree whole.**
  `file_get_contents()` holds the entire file in memory, and a generated or vendored file in
  the same tree can be tens of megabytes. Files above 2 MiB are skipped, and each skip is
  named on STDERR: a quiet skip would drop that file's field reads from the list, so a field
  read only there would be classified `DEAD-DATA` — the same under-report an unusable theme
  path used to produce. Non-regular entries are rejected with `isFile()`.
  `FOLLOW_SYMLINKS` stays off, which is what keeps a symlinked directory out of the walk;
  the comment now says so, since the flag's absence is the behaviour rather than an omission.

## [1.25.0] - 2026-09-19

### Fixed

- **`/wp-seed` no longer deletes a repurposed sample page.** Phase 7 removed WordPress's
  default post, sample page and sample comment with `wp post delete <id> --force
  2>/dev/null || true` — unconditional, permanent, and silent. Turning the sample page into
  About is ordinary, and that line destroyed it on the site's second seed run. Each delete
  is now gated on the record still being an untouched default: the original slug, and a
  `post_modified` still equal to `post_date`. Anything else is reported as kept.
  `tests/checks/wp-seed-default-cleanup.sh` extracts the shipped block and runs it against
  a stub `wp` across five scenarios, because a grep could not have seen this.
- **`/wp-clone` isolates the clone before anything boots WordPress.** The mail-capture
  mu-plugin and `DISABLE_WP_CRON` ran in Step 5.5, *after* the import — and between the two,
  both paths ran `wp search-replace` and `wp rewrite flush` while Path B also ran `wp plugin
  list` and `wp option list`. `rewrite flush` fires `init` with the source site's plugins
  active, so production code executed against a production database before the mail guard
  existed. Both measures are files, need no database and survive the import, so they move to
  a new Step 5.4 ahead of it. `blog_public` stays in 5.5: it is a `wp_options` row the
  import would overwrite. The old check asserted only that isolation preceded Step 6, which
  is why it never saw this.
- **The manifest validator checks types, not only presence.** `wp_cli.wrapper: []` and
  `wordpress.url: {}` satisfied "required" and reached a shell command and a search-replace
  respectively. Every required field must now be a string.
- **A malformed `manifest_version` is refused instead of read as legacy.**
  `Number.isInteger("99")` is false, so a manifest declaring version `"99"` was treated as
  *absent*, absent means version 1, and a future plugin's manifest was offered for migration
  down to this one. A pair of quotes defeated the future-version guard. `versionProblem()`
  is checked by both `validate` and `migrate`.
- **CONTRIBUTING.md stopped advertising "the 38 checks"** (there are 127) and stopped
  describing `bin/` as shell-only. The count is now named as a glob so it cannot go stale
  again, and `tests/checks/contributor-docs.sh` fails on a literal count.

### Changed

- **CI counts a skipped check as skipped.** The contract job aggregated exit 0 and called
  the total PASS, so three checks that decline without an optional dependency —
  `wp-polylang-live.sh`, `craft-kit-sync.sh`, `wp-library.sh` — were counted as measured.
  The summary now reads `PASS=n SKIP=n FAIL=n` and names the skipped ones. They remain
  non-fatal; they are simply no longer counted as coverage.
- **A profile's `tested` key means something.** It was allowed, unvalidated and unread, so
  `tested: 42` passed. It now holds a WordPress version or inclusive range (`6.4`, `6.4.2`,
  `6.0 - 6.6`), and `wp-config.mjs validate-profile <file> <wp-version>` reports every entry
  the installed WordPress falls outside of — reported, not refused, because a plugin outside
  its tested range usually works.
- **A supplied package's failure says which failure it was.** `license_missing` covered a
  licence nobody bought, a zip nobody handed over, and a zip that would not install — three
  different next steps under one word. `package_not_supplied`, `install_failed` and
  `activation_failed` join it; all four still count against the entry's `required` flag.
- **The `/wp-yolo` ledger records what it wrote, and survives the build.** `version: 2` adds
  a `sha256` of each artifact as written, so a resume distinguishes its own output from a
  file edited afterwards and reports the edits as one list with `--skip`/`--rebuild` per
  unit instead of silently replacing them; a `plugin_version` separate from the ledger's
  format version; and a `completed` stamp that replaces deleting the file on success — the
  refusal the deletion used to provide is kept, and the build record now survives for later
  update work. A `--force` rebuild still deletes it.
- **An audit check ID can carry a revision.** `SEC-036@2`. An ID is an address, not a
  version: a project holding `SEC-036` stayed "covered" after SEC-036 was rewritten to look
  for something else. A bare ID means revision 1, so no project's history is invalidated and
  nothing has to be re-tagged.
- **Every open, partial and blocked `BACKLOG.md` entry names an owning implementation or
  says that none exists yet**, enforced by `tests/checks/backlog-ownership.sh`. Five entries
  did neither, and a reader could not tell an incomplete owner from an absent one.

### Added

- **`WP-048` — IDs that outlive the post they point at.** Deleting a post from wp-admin does
  not clear its ID out of the relationship and post-object fields that reference it, so a
  template that iterates the field prints a card with no title, no terms and an empty `href` —
  a visible defect produced by a record that no longer exists. The rule splits its findings:
  an orphan in a field some template reads is WARNING, one in a field nothing reads is INFO.
  That split is the whole point — the audited site had 70 orphans and exactly 1 reached the
  HTML. An ID that resolves to a draft or trashed post is the same defect and is covered too,
  because `get_post_status()` answers `draft` rather than `false` and a trashed post still has
  a permalink.
- **`SEO-054` — menu items that do not navigate.** A `custom` menu item stores its target in
  `postmeta._menu_item_url`, so a broken menu link is invisible to anything that reads the
  theme; the audited site's were in a menu assigned through a widget, which is not even a
  registered location. The check reports `#`, empty, and development-host URLs, and excludes
  items that have children — a `custom` item with `#` and children is a submenu header, and
  without the exclusion the check fires on nearly every menu that has a submenu. The fix is to
  convert the item to a `post_type` item, whose URL derives from `siteurl` at render time,
  rather than to edit the URL of an item that will carry the next host too.
- **Two more scripts in `skills/wp-cli-patterns/scripts/`,** both read-only and both exiting 1
  on a finding so a deploy can gate on them. `find-orphan-acf-ids.php` resolves each field's
  ACF type before treating a value as a post ID — a date field holds `20250910` and a number
  field holds `142`, and skipping that lookup turned 70 real orphans into 248 reported ones.
  `audit-menu-links.php` walks every menu rather than only the assigned locations.
- **Match records by slug, never by ID, and the drafts gotcha that goes with it.** A script
  that runs on one install and then on another cannot match by post ID; IDs are per-install.
  `skills/wp-cli-patterns` now documents the pattern, including that `get_posts()` with
  `'name' => $slug` does not return drafts even with `'post_status' => 'any'` — a lookup that
  works for published pages silently finds nothing the moment the record is a draft, which is
  the state a content script most often has to fix. `post_name__in` with the statuses written
  out is the working form.
- **`/wp-audit` Step 6.10 — every fix is verified against the data that triggered the
  finding.** §6.9 made a *finding* a measurement and nothing said the same of a *fix*. A page
  that still returns 200 after an edit proves the site did not break, not that the defect is
  gone: on the audited site the orphaned ID was in one record's field, and two other pages
  using the same template rendered correctly throughout. The reproducing case is named when
  the finding is written, while the measurement is in hand, and a fix whose case cannot be
  found is `UNVERIFIED` rather than resolved.

## [1.24.0] - 2026-09-19

### Added

- Approved screenshot baselines, with a review step that is a gate rather than a habit.
  `tests/checks/visual-baselines.sh` renders the motion fixtures and compares them to
  committed PNGs, printing how far each one is from its baseline whether it passes or
  fails — 0.1% of pixels is the limit, and a run that is inside it still says by how much,
  because a check that prints only PASS gives a reviewer nothing to judge a borderline
  change with.

  Seven shots: the reduced-motion fallback at two viewports, and the same page at the same
  two scroll positions with the motion engine running and with it stood down. That pairing
  is the point — the first version framed both halves at the top of the page, where the
  sections in question are below the fold, and the two PNGs came out byte-identical. It
  would have passed with the entire reduced-motion path broken.

  Rendering happens inside a pinned Playwright container rather than the runner's own
  Chrome. `motion-devices.sh` asserts on the DOM, which survives a browser upgrade; pixels
  do not, and `ubuntu-latest` ships a Chrome that updates itself. Baselines taken against a
  moving renderer would fail whenever Chrome changed its antialiasing, so "the baseline
  moved" would mean "Chrome moved" more often than it meant a regression — and a gate that
  cries wolf is a gate people mute. `RENDERED-BY.txt` beside the PNGs records which image
  produced them, and the check refuses to compare against a different one.

- `tests/checks/baseline-approval.sh` — a commit that changes `tests/baselines/` must open
  its subject with `baseline: <why>`, and the reason has to be more than the token. I06
  requires that baseline images change only through an explicit review step; this is that
  step, aimed at one specific reflex — a visual check goes red and the fastest way to green
  is to regenerate the PNGs and push. Under that reflex a baseline stops being an approved
  artifact and becomes a record of whatever the code last did, which is worse than having
  none, because it reads as approval nobody gave. What it cannot enforce is that anyone
  looked at the images; no check can.

### Changed

- `tests/fixtures/motion/harness.mjs` now holds the static server and the browser
  resolution ladder that `drive.mjs` and the new `shoot.mjs` both need, instead of a second
  copy in each.

## [1.23.0] - 2026-09-19

### Added

- The motion engine is now driven on **both** paths in a real browser, not one.
  `tests/checks/motion-devices.sh` gains a default-motion pass that loads the real pinned
  GSAP and asserts the engine *works* rather than merely being wired: the `pan` rail's
  transform moves leftwards as the page scrolls, and the JS `reveal` branch hides its
  children and then shows them once they scroll into view.

  That reveal branch was unreachable on any browser this suite can run. Every one supports
  `animation-timeline`, so `cssReveal` is true and the CSS engine takes over — which is
  exactly why CLAUDE.md recorded it as walked by nobody. The fixture forces
  `CSS.supports('animation-timeline', …)` to report false before `motion.js` reads it,
  which is what an older browser reports and the only way in. Nothing else is faked: gsap
  and ScrollTrigger are the pinned builds, served from `node_modules` rather than a CDN,
  because a check that fetches its own engine over the network fails for reasons unrelated
  to the code under test.

  `gsap` is pinned in the root `package.json` beside `playwright-core`. Both are dev
  tooling and neither is shipped into a user's project.

  Seven deliberate regressions across the two paths were each confirmed to fail the check,
  including a `pan` device whose ScrollTrigger is created and never drives anything — wired
  but not working, which is the distinction the whole check exists to make.

- `tests/checks/wp-cf7-delivery.sh` — a contact form is now proved to accept, refuse and
  actually deliver. It creates a real Contact Form 7 form in the WordPress fixture, serves
  the site, and posts to CF7's own REST endpoint: a valid submission must be accepted and
  its mail captured with the right recipient and an interpolated body, and a submission
  missing a required field must be refused **and** send nothing.

  Mail is captured by a `pre_wp_mail` must-use plugin — the same seam `/wp-clone` isolates
  at, chosen for the same reason: it short-circuits core's own send, so nothing escapes
  even if a plugin is reactivated. An SMTP plugin would not do, because core falls back to
  PHP `mail()` and the site keeps sending while merely logging it somewhere nobody looks.

  `agents/wp-cf7.md` contracts the form markup and the branded template, and a grep can
  confirm those contracts are still written down. It cannot notice that a form renders
  perfectly and delivers nothing, which is the failure that costs a client real enquiries
  before anyone sees it. This is the third leg of I06's own completion check.
- `tests/checks/backlog-freshness.sh` — the backlog now has to be reconciled as part of
  cutting a release, and CI says so. The last hand reconciliation went stale in a single
  day: three releases shipped a clone anonymiser, resumable builds, a findings ledger, ACF
  nesting and a WordPress fixture, and `BACKLOG.md` mentioned none of them while claiming
  20 delivered items when the number was 26.

  The check compares the newest dated release heading in `CHANGELOG.md` against the
  `**Reconciled** on` line in `BACKLOG.md` and fails when a release is newer. It cannot
  tell whether a reconciliation was any good — only that one happened, which is the part
  that kept being skipped. Reconciling by hand and remembering to do it again is the
  arrangement that produced the drift.

### Fixed

- `BACKLOG.md` reconciled against `main` at v1.22.0: 30 delivered, 9 partial, 13 open.
  Continuous integration, disposable WordPress fixtures, `/wp-anonymize` and `/wp-yolo
  --resume` are recorded as delivered; the visual-regression item's gap is narrowed to
  baselines and tolerances, now that the browser harness underneath it exists; and three
  gaps these releases named are open items rather than prose — verifying form delivery end
  to end, walking the default-motion branch, and a broken-site corpus with expected audit
  findings.

## [1.22.0] - 2026-09-19

### Added

- The first check that drives a browser. `tests/checks/motion-devices.sh` loads `motion.js`
  in a real Chrome under `prefers-reduced-motion: reduce` and asserts what the `pan` device
  does to the DOM: that it hands the rail back as a scroll region, that the box it makes
  focusable is the one it *measured* as overflowing rather than the one named in the
  markup, that the region is named from the section's own heading, and — the one with no
  visible output at all — that when neither box overflows it attaches nothing, because a
  focusable named region that scrolls nothing is a dead tab stop by another route.

  CLAUDE.md recorded this branch as walked by nobody. Four deliberate regressions were each
  confirmed to fail the check, and closing the fourth found a real gap in the check itself:
  a section that throws is caught by motion.js's own per-section handler and reported with
  `console.warn`, so a device that died left a DOM merely lacking what it would have added,
  and every assertion about what is absent passed for the wrong reason. The driver now
  listens for that.

  A root `package.json` comes with it, pinning the `playwright-core` that
  `bin/demo-verify.mjs` and `bin/composition-preview.mjs` have always imported and that
  nothing declared. It is dev tooling, never shipped into a user's project.
- A disposable WordPress fixture, and the first checks that run inside one.
  `tests/fixtures/wp/provision.sh` builds a pinned WordPress with Polylang and SCF against
  a database from a CI service container or a local docker container, and
  `tests/checks/wp-polylang-integration.sh` runs the ACF translation path inside it and
  tears the whole thing down afterwards. It skips unless `WP_FIXTURE=1`; CI opts in.

  CLAUDE.md had said for a long time that nothing here proves behaviour against a real
  install. This is the first piece of that, and it earned its place immediately — the two
  defects below were both found by its first runs, and neither was reachable by a contract
  grep or by a pure-PHP test.

### Fixed

- `/wp-polylang` could not create a language at all. `pll-setup.php` called
  `PLL()->model->add_language()`, which is defined only on `PLL_Admin_Model` — a subclass
  Polylang instantiates only when `is_admin()` is true, and never under `wp eval-file`,
  which is how the plugin documents running every script in that directory. The guard in
  front of it checked `class_exists( 'PLL_Settings' )`, true in both contexts, so it never
  caught the case. The helper now obtains an admin-capable model explicitly and refuses
  with a readable message if the installed Polylang exposes none.
- The translation writer skipped every write to a brand-new counterpart. It resolved a
  field's definition with `get_field_object( $name, $post_id )` against the **target**, and
  ACF resolves a field name through the hidden `_<name>` reference meta — which a post with
  no value for that field does not have. So the definition came back `false` on exactly the
  posts the writer exists to fill, and every write was reported skipped and dropped. It
  resolves against the source first now, which always has the value, because the payload
  being written was walked out of it.
- ACF reference re-pointing stopped at the top level while the text walk recursed, so a
  nested `link` received a translated title on a URL still pointing at the source language
  — translated-looking and wrong, which is worse than the untranslated link it replaced.
  `pllx_repoint_acf_refs()` now walks the same structure the text pass does, through the
  same `pllx_acf_zip()` traversal and the same layout-by-name rule, and keys its
  `_pll_ref_` ownership meta by dotted path so two references differing only by row keep
  separate records of what the importer last wrote.

- Polylang translation payloads stopped at one level of ACF nesting, so a group inside a
  repeater, or anything below it, was never sent for translation — no error, and a
  counterpart that read as translated because its top-level fields were. `pllx_acf_walk()`
  now recurses to any depth, and a flexible-content row's layout is matched by name through
  the same helper the writer uses, so the two cannot drift on how a row is identified.
- `pllx_acf_write()` resolved a dotted path by counting its dots — one part a plain field,
  two a group, three a repeater row. That was correct only while nesting stopped at one
  level. With nesting walked, `a.b.c` is a repeater row's field when `a` is a repeater and a
  group's group's field when `a` is a group, and the old reading did `(int) 'b'` → `0` and
  wrote the translation into row 0 of a field with no rows. It also had no branch beyond
  three parts and no `else`, so a deeper key wrote nothing and said nothing. Paths are now
  resolved against the field definition, and a path that does not match the structure is
  reported and skipped rather than written to a guessed location.

  The path resolver moved to `pll-lib.php` and touches no WordPress function, so
  `tests/checks/wp-polylang-nesting.sh` executes it: the first check in this suite that
  runs shipped logic rather than grepping a contract. Seven deliberate regressions —
  including reverting the recursion and restoring the dot-count reading — were each
  confirmed to fail it.

  One consequence is recorded rather than fixed: `pllx_repoint_acf_refs()` is still
  top-level only, so a nested `link` now receives a translated title on a URL that still
  points at the source language.

## [1.21.0] - 2026-09-19

### Added

- `/wp-anonymize` — the opt-in remedy for the customer records a clone carries. `/wp-clone`
  isolates mail, cron and indexing, but the database it imported holds live customer data
  from the moment the import finishes, and isolation does nothing about that. The new
  command replaces a named catalog — `wp_users`, `wp_usermeta` billing/shipping keys,
  comment authors including the IP, and WooCommerce order addresses on both the postmeta and
  HPOS layouts — with deterministic fakes in `example.invalid`, a TLD RFC 2606 reserves so
  it can never resolve even if the clone is moved somewhere with no isolation at all.
  Deterministic because a clone exists to reproduce a bug: random per-row values would turn
  one repeat customer into three and take the bug with them. Order totals, dates, statuses
  and quantities are preserved for the same reason.

  It refuses to run on a site it cannot prove is a clone — the isolation mu-plugin must be
  present — and that gate takes no `--force`, the only refusal here that does not. It backs
  up to `~/.wp-clone-backups/` on every run, stops if the export fails, and verifies
  afterwards: residue is reported as a failure and never alongside a success summary.

  Every table outside the catalog is listed by name and row count under *Not examined*. That
  block is the feature. A clone that says "these 14 tables were not looked at" can be handed
  on with an accurate idea of the risk; one that says "anonymised" cannot.
- `/wp-yolo --resume` — an entrypoint that continues an interrupted build instead of
  discarding it. A full run is thirty to fifty dispatches and the better part of an
  hour, and until now a crash, a closed terminal or one failing step threw all of it
  away: the only way to run the command again was from Step 2, which converts
  `demo/*.html` in place and regenerates the manifest the build reads, so a second run
  quietly degraded its own output. `--resume` enters at Step 4 and never runs those
  steps — skipping them is the mechanism, not an optimisation.
- A build ledger at `demo/.yolo-progress.json`, written on every run (not only resumed
  ones) and deleted when a build completes. One entry per dispatch, appended the moment
  the unit returns and written through a temp file, so an interruption loses at most the
  unit it interrupted. A unit is skipped only when the ledger records it **and** its
  artifact is still on disk — a ledger that outlived its files reports a hole as filled,
  so a missing artifact means not-done and is rebuilt and listed as such in the report.
- Drift detection on resume: the ledger digests the manifest and every demo page it
  built from, and a changed input refuses rather than continuing, naming the file, what
  it feeds and how far the previous run got. Building half a theme from one manifest and
  half from another fails nothing downstream — the parity gate measures the built site
  against the demo as it stands now — so the stale half would be wrong and green.
  `--accept-drift` proceeds deliberately and is not implied by `--force`.

  The ledger records work that generates and never work that verifies. `/wp-seed` is
  re-run rather than recorded, because it already owns its own re-entrancy; the Tailwind
  rebuild, `/wp-finalize`, `/wp-polish`, `/wp-responsive-check` and the parity gate are
  re-run because they read the live site, and skipping a measurement would sign off a
  build nobody measured.

## [1.20.0] - 2026-09-19

### Added

- **`/wp-clone` inventories the plugins and themes a clone will be missing, while it can
  still ask the source.** The clone transfers the database and `wp-content/uploads/` and
  nothing else — plugin and theme *files* are never transferred — so the imported database
  activates plugins whose directories are not there. WordPress deactivates each one on load
  and falls back off the missing theme, and Steps 6.4/6.5 then "warned the user": a warning
  with nothing actionable attached, issued after the site was already broken.
  New Step A3.5 runs while the SSH session is open, because afterwards the source is
  unreachable and the local database can report plugin *names* and nothing else. It splits
  what is missing by what the operator can actually do: **recoverable** (on WordPress.org —
  emitted as a version-pinned `wp plugin install` command), **unobtainable** (custom,
  licensed or premium — the clone stays incomplete until someone supplies the files), and
  **unclassified** (the WordPress.org lookup is a network call and it did not complete).
  The third group is not collapsed into the other two: a wrong guess either sends the
  operator to install a different plugin that happens to share a slug, or to ask a client
  for a file they could have downloaded. Plugins already installed locally are silent.
  The inventory is written beside the Step 1.5 backup, outside the project, because it is the
  list the operator works through *after* the clone — once the site is up and visibly missing
  things, by which time the terminal has scrolled. Path B derives the same report from the
  imported database and states that it is the weaker of the two rather than presenting parity.
  Step 6.5 now reconciles against the inventory instead of re-reporting the same missing
  plugins as a fresh discovery.
- **Audit findings have identities, so successive reports are comparable.** `issues_found`,
  `issues_fixed` and `carried_over` were three integers, and three integers cannot answer the
  question every follow-up audit asks: is this the same problem as last time? Fix one issue
  and find a new one and the count is unchanged while the contents changed completely — Step
  2.5e could report "25 carried over" and never say which 25.
  New Step 7.5 keys each finding by **check id + resource** (`SEC-036 : wp_options.siteurl`),
  taken from the evidence Step 6.9 already requires rather than anything newly collected, and
  preferring the record, option or element over a `file:line` — a line-number identity reports
  every finding in a file as resolved-and-new the moment someone adds an import above it.
  Statuses are `new`, `still_failing`, `resolved`, `accepted` and `unmeasured`.
  **`resolved` requires a measurement**: a check that did not run yields `unmeasured`, never
  `resolved`, or a Tier 1 run would mark every Tier 2 finding fixed and the report would show
  a site cleaning itself up by being audited with less access than before. `accepted` is a
  human decision in both directions — the audit never promotes its own finding to it and never
  re-raises one, because re-raising what a client explicitly accepted is how a report stops
  being read. A resolved entry is kept rather than deleted, so a defect that keeps coming back
  stays distinguishable from one never seen before.
  The ledger is its own file, `.wp-audit-findings.json`; `audit.findings_ledger` in the
  manifest is a **pointer**, and `bin/wp-config.mjs` refuses an inlined one or a path that
  climbs out of the project. The manifest is configuration that every command parses on every
  run, while a findings ledger is audit history that grows without bound — one check found 70
  orphan ACF ids on a single site. An absent ledger means "no history", never "nothing ever
  failed", so a first run is not reported as a project with everything resolved.

- **`/wp-seed` no longer reverts an editor's work when it re-seeds a record it owns.**
  Phase 1.5 settled who owns a *record*; nothing settled who owns a *value inside* one, and
  `update_field()` overwrites unconditionally — so re-seeding a page the seeder legitimately
  owns silently reverted every edit made to it in wp-admin since the last run. The
  record-level rule read as though that were already handled.
  Telling an editor's edit from a source change needs one fact that is not in the database:
  what this command wrote last time. `_<prefix>_seeded_digest` now records it as a map of
  field to hash — a digest rather than the value, because detecting *changed* is the whole
  requirement and storing every seeded string twice answers nothing extra. Options-page
  fields keep theirs in an option, the same crossover `wp-acf` already makes for `_<lang>`
  suffixes.
  Each field is then a three-way compare between what WordPress holds, what the last run
  wrote, and what the demo supplies: unchanged-and-demo-differs **updates**,
  unchanged-and-demo-same **skips**, and anything the client has touched is a **conflict**
  that is left alone and reported. A field with **no** recorded digest is also a conflict —
  on a project seeded before this existed that is every field, which makes the first re-seed
  noisy and correct rather than quiet and destructive, since nothing on disk can say whose
  value it holds. Conflicts are never merged: both values are deliberate and picking either
  silently discards work somebody did on purpose. `--force-fields` overwrites them, is not
  implied by `--force` on any other command, and is never the default. The plan reports field
  outcomes separately from record outcomes, because they are owned separately.
- **`/wp-clone` refuses to replace an occupied destination, and backs it up first.** The
  command ran `wp db import` against the destination on both paths with no backup, no
  existence check and no confirmation. A dump carries `DROP TABLE` / `CREATE TABLE`, so the
  import does not merge into the destination database — it replaces it; `rsync` overwrites
  matching paths under `wp-content/uploads/` the same way. The destination is a local
  development site, which is where unpushed work lives: seeded content, ACF values, test
  orders. `/wp-seed` carries an entire ownership model so it never overwrites a client's work
  inside a database, while this replaced the database wholesale with no prompt.
  New Step 1.5, written once and reached from both imports and the uploads sync, positioned
  before each of them. An **empty destination proceeds silently** — a gate that fires on every
  ordinary run is one people learn to click through. An occupied one is **backed up before
  anything is asked**, to `~/.wp-clone-backups/` (outside the project, because a backup under
  `wp-content/` is reached by the next clone's `rsync` and by an `rm -rf` of the project), and
  then named rather than described: site title, content count, what changed most recently and
  when. "47 posts, last modified two hours ago" is a question an operator can answer;
  "overwrite?" is one they can only guess at. `--force` proceeds and **still backs up** — it
  means "I know what is there", not "skip the safety net", and tying the export to the flag
  would remove it from the runs most likely to need it. The backup path is carried into the
  final summary, since Step 1.5 has scrolled away by then.

- **`/wp-clone` isolates the clone before anything loads it.** Every check the command ran
  asked "does it work" — WordPress loads, URLs resolve, an admin exists, the theme is present,
  HTTP answers — and none asked "is it contained". So a clone arrived carrying the source
  site's mail configuration, live payment credentials, production webhook URLs and a due cron
  queue, and the summary closed with "Visit `<local-url>` to verify the site": the page load
  that fires all of it.
  New Step 5.5, which **both** paths now route through and which runs before Step 6 (the first
  thing that loads WordPress): mail is captured to `wp-content/clone-mail.log` by a must-use
  plugin filtering `pre_wp_mail`, `DISABLE_WP_CRON` is set, and `blog_public` goes to `0`. The
  filter is the seam because every sender — core, WooCommerce, Contact Form 7 — reaches it
  through `wp_mail()`; disabling an SMTP plugin instead does not stop sending, since core falls
  back to PHP `mail()`. It returns `true` so callers stay on their success path and the clone
  behaves like the original everywhere except at the wire. A failed isolation **stops** the
  clone rather than warning, because continuing means loading the site it failed to contain.
  Live payment credentials, webhooks and API keys are **reported, not changed**: flipping a
  gateway to test mode would change the behaviour under test, and a store clone often exists
  precisely because a payment bug needs reproducing. The report also states plainly that real
  customer records are now on the machine. The summary always shows what was isolated and what
  remains live, never collapsed on success.

### Fixed

- **`/wp-clone` no longer leaves a production database dump in `/tmp`.** The SSH path
  exported the whole remote database to a fixed path, `/tmp/wp-clone-dump.sql`, on **both**
  machines. It deleted the remote copy and never deleted the local one — so after every clone
  a full production dump (customer records, order rows, password hashes, whatever API keys
  live in `wp_options`) sat in `/tmp` at a predictable name, with default permissions, until
  the machine rebooted.
  The fixed name was two problems at once. A predictable path in a world-writable directory
  on a **production** server is a name an unprivileged local user can wait for. And two clones
  running at once against the same machine shared that one filename: the second export
  overwrote the first, and the first clone then imported the second site's database into its
  own destination with nothing to say so.
  Both ends now use `mktemp`, and both create the dump owner-only — `umask 077` on the remote
  export and `chmod 600` locally, set as the file is created rather than after, since a
  `chmod` afterwards leaves a window in which the whole database already exists at the default
  mode. **Both copies are deleted unconditionally**, the remote one whether or not the
  transfer worked and the local one whether or not the import did: the failing run is the one
  that leaves a dump behind, because nobody tidies up after a command that did not finish.
  Path B's dump is left alone — the operator created it and passed it in with `--sql=`, and
  removing someone's input because the command consumed it is not cleanup — but the summary
  now names it as a full database export still on disk, since silence there leaves a
  production database on the machine with nobody having mentioned it.

## [1.19.0] - 2026-09-18

### Changed

- **The backlog says what has already been built.** All 40 items were checked against the
  command, agent or script that would own them: 20 ship and are now marked `DELIVERED` with a
  link to the owning file, 7 are `PARTIAL` and name the one behavior still missing, and 13 are
  `OPEN`. Six of the delivered items were still tagged `NEW` — multi-page demos, CPTs from demo
  structure, media import, field seeding, menu creation and the Tailwind build — which presented
  a shipped feature set as an unstarted project. The status vocabulary was contradicting itself
  too: five items read `- [ ] … DONE`, an unchecked box tagged done. The checkbox is now the
  delivery state and the tag says which kind.
- **The contributor docs describe the repository that exists.** `CONTRIBUTING.md` told
  contributors to put starter-theme changes in `starter-theme/__starter__/`, a directory removed
  several releases ago; there are two starters, `__tailwind__` and `__cinematic__`, and
  `__starter__` is a placeholder *token* inside their files, not a path. `CLAUDE.md`'s
  "only executable code shipped" list omitted `bin/*.mjs` entirely, so `wp-config.mjs`,
  `demo-verify.mjs`, `tailwindify-parity.mjs`, `image-gen.mjs` and `composition-preview.mjs` —
  several of them load-bearing gates — were invisible in the architecture summary a contributor
  reads first.
- The design library is a caret range, `@yojahny/wp-design-library@^1.0.0`, instead of an exact
  pin. An exact pin had to be edited in `.mcp.json`, the README and a check on every library
  release, so in practice it went stale rather than getting edited: it sat at 0.4.0 through
  0.5.1 and 0.6.0, two versions behind the artifact-record contract, which left the pinned
  server unable to read the corpus it was pointed at. The library is 1.0.0 so a caret works —
  on 0.x a caret cannot cross a minor, which is what made re-pinning by hand unavoidable.

### Added

- **`/wp-seed` resolves every record before it creates one, so a second run stops duplicating
  the site.** The command already declared `_<prefix>_seeded_content` "the marker every seeded
  record carries" and stated that re-running is safe — while Phase 2 ran `wp post create`,
  Phase 3 ran `wp media import` and Phase 6 ran `wp menu create` unconditionally, with no
  lookup and no marker written. Seeding twice produced a duplicate of every page, attachment
  and menu, and the client could not tell which "About" the theme reads. Six seed checks
  existed; none covered a re-run.
  New Phase 1.5 states the three-way rule the later phases now share: a record carrying our
  marker is reused and updated **keeping its ID** (menu items, `page_on_front` and `page_link`
  fields already point at it); a record without the marker belongs to the client and is left
  exactly as it is, reported as a conflict, with no second record created beside it; anything
  else is created, with the marker written by the same command that creates it — a create
  whose marker does not land leaves a record this project can never recognise again.
  Pages resolve by slug, attachments by the source they were imported from
  (`_<prefix>_seeded_source`), menus by name — `wp menu create` never refuses a duplicate name,
  so a second run could fill a menu the theme is not displaying. A plan prints before anything
  writes, and an unchanged re-run shows `create 0 / update 0` with everything under `skip`,
  which is how "re-running is safe" becomes observable instead of asserted.
- **An audit reports checks that shipped after the project last ran their category.**
  `audit.categories_run` answers "has this ever run here", and a category keeps answering yes
  forever while checks are added to it — so a project could carry a green coverage line for
  checks nobody had ever run on it. CLAUDE.md listed that as a known ceiling. Step 2.5d now also
  records `audit.checks_run` (the ids that executed, cumulative, per category) and diffs each
  run category against that category's own agent catalog, naming what is outstanding:
  `SEC-036, SEC-038 have never been measured on this project`.
  The catalogs are read from the six agent files, never from a list stored anywhere else: a
  stored list is a second copy, and a stale second copy would report green coverage for checks
  nobody ran — the exact defect the diff exists to prevent, reproduced by the thing preventing
  it. Passing checks are recorded (a pass that is not recorded is indistinguishable from
  never-run), `UNMEASURED` checks are not (they did not execute, and recording them would be a
  false green nothing later re-opens), and a project with no `checks_run` yet reports its
  per-check history as unknown rather than flagging all 261 checks at once. A partially covered
  category warns; only a never-run category blocks.
  `bin/wp-config.mjs validate` refuses a malformed `checks_run` — a bare string where an array
  belongs would otherwise iterate as characters and report every check as never measured.
- **The development-host sweep reads four tables instead of one.** SEC-036 queried
  `wp_options` alone, which is the table that holds the least of this: on an audited site it
  reported 7 occurrences, and the same needle across `postmeta`, `posts` and `termmeta`
  reported 25. The rows it skipped are the ones that reach the page — a `custom` menu item
  stores its target verbatim in `postmeta._menu_item_url`, so after a push it is a navigation
  link that leaves the live site, and an absolute URL pasted into `post_content` is the same
  defect inside an article body. The sweep now groups its count by table, reports a `guid`
  match separately because WordPress never resolves a `guid` as a URL, and keeps the
  `home`/`siteurl` exclusion. `skills/wp-cli-patterns/scripts/check-dev-host.php` runs the
  same measurement read-only and exits 1 on any hit, so a deploy can gate on it without an
  agent.
- **No update count is reported without a network.** `wp core check-update` and
  `wp plugin list --update=available` never contact `api.wordpress.org`; they read the
  `update_core` and `update_plugins` transients that some earlier background request filled
  in. With no route the refresh fails silently, the stale transient answers, and a count of
  `0` is written into the audit as "no updates pending". On an audited machine the cached
  answer was one pending plugin update; with a route restored it was twelve, and core was a
  minor version behind — the report had to be corrected after it was written. New SEC-038
  reaches the endpoint first and deletes the three update transients before either count is
  read; without the route SEC-032, SEC-033 and SEC-034 are `UNMEASURED`, never a pass. WP-043
  and WP-044 in `agents/wp-audit-practices.md` carry the same gate.

- **CI runs the checks on every pull request** (`.github/workflows/ci.yml`). The only committed
  workflow was the OCR review bot, so nothing mechanical stood between a broken contract and
  `main` — CLAUDE.md said as much ("There is no CI"), and that sentence was load-bearing on
  everyone remembering to run them. Three jobs: all contract checks, **aggregated** so a PR that
  breaks three of them reports three rather than handing back one per round trip; `node --check`
  on `bin/*.mjs` plus `php -l` on all 47 PHP files; and `bin/doc-sync-check.sh`, which has
  shipped for months with nothing ever running it — `tests/checks/wp-contributing.sh` only
  asserts that `/wp-contribute` *mentions* it, so this is the first thing that can catch a
  README command that was never created, or a PR with no CHANGELOG entry, without a human
  remembering to look.
  The PHP lint is pinned to **7.4**, the floor `skills/wp-polylang/scripts/*.php` carry, with
  `starter-theme/__cinematic__/` at the **8.0** it declares in its own `style.css`. The runner's
  default is 8.x, which lints `match`, union types and nullsafe calls clean — all fatal on 7.4 —
  so the default would have been green and wrong. Nothing uses 8.0-only syntax today; adding
  some now fails CI, which makes raising a floor deliberate.
  Disposable WordPress fixtures, the broken-site corpus with expected audit findings and browser
  artifacts are deliberately not here: they need a provisioned WordPress and a pinned stack, and
  a half one would make the green light mean less than it does.
- **`tests/checks/contributor-docs.sh`** — every repo path the contributor-facing docs name must
  exist. A path in prose is just prose: the repo can be reorganised and the sentence describing it
  stays green forever, which is how `starter-theme/__starter__/` survived its own directory. The
  check reads backtick paths (restricted to this repo's top-level directories, first token only,
  so an invocation like `bin/demo-verify.mjs --probe` resolves) and every relative markdown link
  target in `CLAUDE.md`, `CONTRIBUTING.md` and `BACKLOG.md` — the last because the reconciled
  backlog's evidence *is* its links, and a rotted one turns a delivered item back into a claim.
  Globs and `<placeholder>` spans describe a shape and are skipped.
- **A craft build studies an entry's motion clip instead of inferring motion from its strip.**
  When a consulted `wp-design-library` entry carries `motion.clips`, `/wp-demo` sub-step 3.6 now
  calls `get_motion` and reads the timestamped frames it returns as images; a strip shows what a
  section is made of, never how it moves. The tool's own ceiling travels with the instruction —
  a video URL alone does not provide video understanding — so a clip is cited only when its
  frames were read.
- **The motion vocabularies are mapped, including where they do not meet.** Ten library device
  names map one to one onto the `data-motion` contract; `stagger` and `count` are modifier
  attributes rather than devices; `marquee`, `stack` and `tabs` have no expression at all and are
  built by hand with a reason in `demo/BRIEF.md`. `tests/checks/wp-library-motion.sh` pins the
  mapping against `references/devices.md`, so the claim cannot go stale silently.

- **Performance and accessibility audits now measure instead of guessing.**
  `agents/wp-audit-performance.md` gains PERF-054/PERF-055: the real LCP element
  is found per template with a `PerformanceObserver` on
  `largest-contentful-paint`, not assumed to always be the hero — a directory or
  archive grid can put its LCP on a first-row card, and a blanket
  `loading="lazy"` below the fold then defers exactly the element the page is
  judged on. PERF-055 checks the preloaded font file actually matches the
  weight the LCP text renders in, instead of preloading "the first N files"
  found on disk. `agents/wp-audit-a11y.md` gains A11Y-031 (overlays/drawers need
  a real focus trap, not just initial focus, and must return focus on close),
  A11Y-032 (`target="_blank"` links need a screen-reader "opens in a new tab"
  notice), A11Y-033 (a horizontally-scrollable region needs `tabindex="0"` plus
  an accessible name), and A11Y-034 (a cross-engine `cursor` sweep must not read
  WebKit's `auto` — its UA default for an undeclared pointer — as "no pointer"
  when other engines agree it is one). A11Y-004's non-text-contrast check now
  requires computing a focus ring's contrast against the background it actually
  sits on, not a single assumed page ground.
- **`wp-aos-animator` closes two seams found by scrolling a real build past its
  first entrance.** `aos.css` rewrites `transition-property`/`-duration`/`-delay`
  on any element that still carries `data-aos`, for as long as the attribute
  stays — silently breaking a hover-lift card's or a color-fading button's own
  transition long after the entrance finished. The skill's init module now
  strips the AOS attributes once an element's entrance transition ends. AOS also
  measured trigger points at `DOMContentLoaded`, before web fonts and images
  reflow the layout, so a block that moves afterward could end up permanently
  below a stale trigger with `once: true`; the module now calls `AOS.refresh()`
  again on `load`, and reveals anything already on screen at that point instead
  of waiting for a scroll that may never come. The skill now also says to
  animate the above-the-fold LCP candidate with a fast plain `fade` rather than
  skip it outright — a small, deliberate LCP cost instead of a static-looking
  first screen.
- **`wp-agentic-surfaces`: a named search indexer could receive the markdown 404 body —
  cloaking.** The "is this a non-browser agent" UA sniff (`bot|crawl|spider|agent|…`)
  matches "Googlebot" on `bot` alone, and a real SEO audit found the theme's designed 404
  replaced by a markdown response for Google's own crawler: a browser and a named
  indexer got different content on the same URL. Named search indexers (Googlebot,
  Bingbot, Slurp, Baiduspider, YandexBot, Applebot, …) are now matched and excluded
  *before* the generic pattern and always get the human HTML; Applebot-Extended (a
  distinct UA, the AI-training crawler already allowlisted in Step 4) is unaffected.
  Step 5's verification now fetches the 404 impersonating Googlebot and fails if the
  response is `text/markdown`.
- **`wp-agentic-surfaces`: `Content-Signal` was written as a robots.txt directive; the
  spec defines it as an HTTP response header.** No robots.txt grammar recognises a bare
  `Content-Signal:` line, so a linter (Lighthouse included) reports the *whole file*
  invalid over that one line, costing the SEO score of every page and burying any real
  robots.txt error behind a self-inflicted one. It now ships on the existing
  `send_headers` action next to the RFC 8288 `Link` header, and is left in robots.txt
  only as a comment; the physical-robots.txt writer (Step 4) and its verification
  (Step 5) match.
- **`wp-audit-rankmath`: theme JSON-LD sharing an `@id` with Rank Math's own graph must
  be merged through `rank_math/json_ld`, never echoed as a second `<script>`.** Two
  blocks sharing an `@id` merge into one entity per the JSON-LD spec, but any validator
  or audit that counts `@type` occurrences reads two `Organization` nodes — which is how
  a real portal audit reported it. New Step 4.7 merges the theme's real business data
  (address, contactPoint, sameAs — none of which Rank Math itself collects) into Rank
  Math's node by matching `@id`, reading `knowledgegraph_type` to resolve the fragment
  rather than assuming a value. Step 8.5's duplicate-schema check now recommends the
  merge path instead of blind removal, which would have lost that data rather than
  de-duplicated it.
- **`wp-audit-rankmath`: search results had no noindex step.** `/?s=<term>` and its
  pretty form both answered `200` as `index, follow` with a canonical — two indexable
  URLs for the same slice of content. New Step 4.6 sets `noindex, follow` on
  `is_search()` via `rank_math/frontend/robots` and leaves canonical removal to Rank
  Math's own noindex behaviour rather than forcing one.
- **`wp-audit-rankmath`: per-page SEO seeding skipped every taxonomy term.** Step 8
  looped `get_posts()` only, so a site's term archives were left on the global title
  template with no description at all — worse than a post, which can at least fall back
  to excerpting `post_content`; a term has none. Step 8 now also seeds
  `rank_math_title`/`rank_math_description`/`rank_math_focus_keyword` as term meta over
  every public taxonomy.
- **`wp-audit-rankmath`: the og:image default could carry a URL with no attachment ID,
  and `knowledgegraph_type` silently degrades on an out-of-range value.** Rank Math does
  not print `og:image` unless `open_graph_image_id` is a real attachment; the old
  fallback to the theme screenshot always left that at `0` (and the screenshot is the
  editor preview, not a stable share-card URL). Step 6 now requires a real attachment
  and warns instead of silently producing no tag. `knowledgegraph_type` accepts only the
  literal `'person'`/`'company'` — a plausible-looking `'organization'` falls back to
  `'person'` with no warning, describing a company as a human in its own JSON-LD. Step 4
  now documents the two legal values and verifies the option landed as one of them.
- **`wp-audit-rankmath`: a theme's own `<meta name="description">` fallback could
  duplicate Rank Math's tag.** Gating the fallback only on "is an SEO plugin active" is
  not enough — Rank Math can be active and still emit nothing on a specific route (an
  unconfigured template, a page type with no post/term to hold meta). Step 8.5 now
  checks for a hardcoded theme description tag and for more than one rendered on the
  home page, and recommends gating the theme's tag on the *current object's own*
  `rank_math_description`/`rank_math_title` being empty, not on plugin presence alone.
- **`wp-audit-rankmath`: a sideloaded site icon could be silently turned into WebP.** An
  unrelated image-optimizer plugin that filters `image_editor_output_format` globally
  runs on every sideload, including a favicon import, and WordPress then points
  `apple-touch-icon` at a file iOS does not read as a touch icon. Step 6 now imports the
  site icon (when `site_icon` is empty) with that filter explicitly disabled around the
  sideload, and verifies the stored file is still a PNG.
- **`/wp-polylang`'s menu import wrote the per-language override and nothing else.**
  Polylang's own frontend filter only substitutes a location's value inside the core
  `nav_menu_locations` theme_mod — it never adds one. A location assigned only through
  the `polylang` option (what `pll-import.php`'s menu branch did, and what `/wp-seed`'s
  own Polylang phase still does for the primary language) left that theme_mod empty, so
  `wp_nav_menu()` fell through to its hard-coded fallback for EVERY language — the
  fallback can look right by coincidence in the default language, which is what hid it.
  Both scripts now register the location the normal way before writing the override.
  Separately, the Polylang i18n variant's string helper asked the registry for a
  hardcoded `'en'` value; a project whose registered source is a different primary
  language never matched, so `pll__()` silently no-op'd and a client's edits under
  Languages > Strings were discarded. It now resolves the source through the project's
  own `DEFAULT_LANG` constant.
- **A taxonomy term's own custom fields never reached its translation.** `/wp-polylang`
  carries a post's fields, content and ACF payload across, but a term's fields are a
  separate storage surface `pll_save_term_translations()` does nothing for — a repeater
  or a plain field attached to a term came out blank on the counterpart, with no error.
  The export and import scripts now walk and write a term's ACF/SCF fields the same way
  they already did for posts, through the `"<taxonomy>_<term_id>"` context string both
  plugins accept in place of a post id.
- **A CPT's or taxonomy's rewrite base, registered once in PHP, was never documented as
  untranslatable.** Free Polylang prefixes and translates a post's or term's slug but
  never the static path segment ahead of it — there is no per-language value to
  translate, since the base is a PHP literal, not stored content. `skills/wp-polylang/SKILL.md`
  now documents the two-halves pattern (extra rewrite rules per translated base, plus a
  link filter that swaps it) and the rule that decides which base to print: the language
  already in the URL, never the current reader — getting that backwards breaks the very
  links Polylang itself builds for the other language (the hreflang pair, the switcher).
- **`/wp-seed` had nowhere to send an options-page `page_link` field.** A demo never
  supplies copy for a legal-links column (privacy policy, terms, FAQ), so those fields
  shipped empty or pointed at whatever draft page WordPress created on install — a 404
  with nothing in the UI to say so. A new phase creates a clearly-marked placeholder page
  per language for each one, safe to re-run without overwriting a client's real page.
  Templates that print one of these fields now have a documented guard: a `page_link`
  keeps pointing at its page after that page is unpublished, and printing it regardless
  serves a broken link silently.
- **Non-trivial seed scripts had no documented home.** A whole content pass written as
  throwaway files in a session's scratchpad survives only as long as the session does —
  the records land in the database and stay; the code that reproduces them does not.
  `skills/wp-cli-patterns/SKILL.md` now says where that logic belongs (`inc/seed/`, data
  in `inc/seed/data/`), and defines the marker-meta and stable-key convention a re-run
  needs to update existing records in place instead of duplicating them, without ever
  overwriting a client's own edit.

- **Every command that reads `.wp-create.json` now validates it first.** The twelve
  consuming commands (`/wp-create`, `/wp-init`, `/wp-yolo`, `/wp-seed`, `/wp-section`,
  `/wp-demo`, `/wp-audit`, `/wp-finalize`, `/wp-clone`, `/wp-debug`, `/wp-robin`,
  `/wp-aos-animator`) gain a byte-identical gate block that runs `wp-config.mjs validate`
  and branches on its exit code (`0` continue, `1` stop and report, `2` migrate then
  continue, `3` no manifest). `/wp-create` runs its gate after Step 5 writes the manifest,
  since creating it is that command's own job; `/wp-clone` runs its gate after `/wp-create`
  has been dispatched as a sub-step, for the same reason. Covered by the new
  `tests/checks/wp-config-gate.sh`. `README.md` documents `bin/wp-config.mjs`'s
  subcommands, and `CLAUDE.md` records three ceilings: the gate only binds commands whose
  gate line survives, a tested plugin-version range is a claim nothing keeps honest, and
  `.wp-create.local.json` is unencrypted, not just unshared.
- **Fix: four contracts Task 6 shipped were pinned by no test of their own.**
  `tests/checks/wp-create-profile-enforcement.sh` now asserts (with a project-root-specific
  path, not just the filename) that `/wp-init` Step 9.6 gitignores
  `.wp-create.local.json` at `${PROJECT_PATH}`, not at `<theme-dir>`; that Step 4.10's
  `validate-profile` call carries its own `**Validation:**`/`**On failure:**` block; and
  that Step 5's manifest template — not just Step 4.10's prose — carries
  `plugins.resolved`/`plugins.degraded`. `tests/checks/audit-lifecycle.sh` now asserts
  `commands/wp-audit.md` states `manifest_version` 3 as current and widens the absent
  bucket to `absent or < 3`. All four were mutation-proven to fail red when the
  underlying fix is reverted.

- **`node bin/wp-config.mjs validate-profile <file>` validates a plugin profile before
  `/wp-create` installs anything from it.** Profiles load from three places —
  `templates/profiles/`, the project's `.wp-profiles/*.json`, and `~/.wp-profiles/*.json`
  — and the last two are user-authored, which is what makes structure validation worth
  having. `validateProfile()` in `bin/lib/manifest.mjs` rejects a duplicate plugin slug,
  an unknown key on a plugin entry, a `source` outside `"wordpress.org"`/`"supplied"`,
  a `requires` edge pointing at a plugin the profile does not list, and a `conflicts`
  edge pointing at one it does — all named in the message, and all before Step 4.10 has
  activated a single plugin. Plugin entries gain three optional fields: `requires:
  string[]`, `conflicts: string[]`, `source: 'wordpress.org' | 'supplied'`; both shipped
  profiles (`templates/profiles/full.json`, `templates/profiles/starter.json`) now mark
  every entry `"source": "wordpress.org"`. Exit codes match the existing `validate`
  contract: `0` ok, `1` invalid, `3` file not found. Covered by
  `tests/checks/wp-profiles.sh` and fixtures under `tests/fixtures/profiles/`.
- **Fix: a user-authored profile with a non-array `requires`/`conflicts` (e.g.
  `"requires": 5`) no longer crashes `validate-profile` with a raw Node stack trace.**
  `validateProfile()` now reports it as an ordinary validation problem naming the entry
  and the key, instead of iterating a non-iterable and throwing. `required` is now
  type-checked too: a present-but-non-boolean value (e.g. `"required": "false"`) is
  rejected, and the shipped-profile `required`-count check in `tests/checks/wp-profiles.sh`
  compares with `=== true` rather than truthiness, closing the same gap on both sides. A
  plugin `slug` must already be lowercase and trimmed — `validateProfile()` rejects a
  slug that isn't, naming the canonical form, rather than silently normalising it. Fixture
  coverage extended to the remaining `validateProfile` branches (`conflicts`, unknown key,
  bad `source`, a non-object entry, a missing `slug`, a missing `name`, a non-array
  `plugins`, a non-array `requires`, a non-boolean `required`, a non-canonical `slug`) —
  the last two were themselves initially unguarded: disabling either check left the full
  suite green, so each now has its own fixture proven to fail red when that check alone
  is disabled.
- **Fix: `wp-config.mjs` no longer echoes `JSON.parse`'s own error message when a manifest,
  local-secrets file or profile fails to parse.** That message can embed up to ~20 raw
  bytes of the file's own content as a quoted snippet — a real leak path for
  `.wp-create.local.json`, which holds secrets. `loadManifest`, `loadLocal` and
  `cmdValidateProfile` now report only the file and, when the parser states one, the
  position — never the parser's message text.
- **`bin/wp-config.mjs` and `bin/lib/manifest.mjs` — one validator for `.wp-create.json`,
  the manifest roughly thirty commands, agents and skills read with no writer contract
  until now.** `node bin/wp-config.mjs validate <project-path>` checks the required fields,
  the `"demo mode"` and `"i18n strategy"` values, and the manifest version, so a malformed
  or missing manifest fails once, early, instead of thirty different ways deep inside
  whichever command happens to read it first. Exit codes are fixed and are the contract:
  `0` ok, `1` invalid/refused, `2` migration available, `3` no manifest. Covered by
  `tests/checks/wp-config-validate.sh` and fixtures under `tests/fixtures/manifests/`.
- **`node bin/wp-config.mjs migrate <project-path>` moves a pre-version manifest forward
  without re-deciding it.** A legacy project's `"i18n strategy"` lives only as a prose
  line in its `.claude/CLAUDE.md` — the new `migrateManifest()` reads that line instead
  of falling back to the documented default, and only falls back (`suffix`/`plain`) when
  the line itself is absent. Unknown keys are preserved, a future `manifest_version` is
  refused and left untouched, the pre-migration file is backed up as
  `.wp-create.json.v<n>.bak` (never `.wp-create.json.bak`, which `/wp-create` already
  owns), and re-running migrate on an up-to-date manifest is a no-op — asserted by
  comparing the whole project directory's file listing before and after, not just the
  manifest's own bytes, so a regression that leaves a stray backup behind is caught too.
  Covered by `tests/checks/wp-config-migrate.sh` and the `legacy-v1`/`future` fixtures.
- **`node bin/wp-config.mjs render-context <project-path>` renders the project's
  `.claude/CLAUDE.md` context block from `.wp-create.json` — the manifest, not the
  prose, is now the source of truth.** `i18n strategy` alone is read out of that prose
  in 17 places across agents; those readers are unchanged, but the block they read is
  now generated between `<!-- wp-create:begin -->` / `<!-- wp-create:end -->` markers,
  so the two files cannot disagree. Text outside the markers is the operator's and is
  never touched; rendering twice is a no-op. `migrate` calls `render-context` as its
  last step. `validate` gains a drift finding: a hand-edited block is reported (exit
  `1`, naming `wp-create:begin`) and never silently overwritten — an operator who
  edited it meant something. Covered by `tests/checks/wp-config-context.sh`.
- **Fix: a malformed marker pair (an orphan BEGIN with no END, an END before a
  BEGIN, or more than one of either) is now refused, not guessed at.** The first
  cut of `spliceContext` treated anything other than a clean single pair as "absent"
  and appended past it — an orphan BEGIN left the operator's own text stranded
  after it, and the very next `render-context` (the exact remedy `validate`
  recommended) paired that orphan with the real END and deleted everything
  between them; an END appearing before a BEGIN in operator prose took the append
  branch on every call, growing a new duplicate block each time. `render-context`
  and `validate` now both refuse and exit `1` naming the malformed state and
  telling the operator to fix the markers by hand, writing nothing. `contextDrift`
  reports a malformed file as its own finding, distinct from ordinary drift.
  Covered by four new cases in `tests/checks/wp-config-context.sh`.
- **`node bin/wp-config.mjs get <project-path> <key>` — one way for every consumer to
  read a manifest value, secrets included.** `/wp-init` writes a project's `.gitignore`
  as `node_modules/`, `.DS_Store`, `*.log`, so `.wp-create.json` — database password
  included — was committable into a client's repository by default. `get` resolves the
  two recognised secrets (`db_password`, `admin_password`) in order **environment →
  `.wp-create.local.json` → manifest**; the manifest rung still works for a project that
  has not moved its secret out, but it warns every time it wins that the value came from
  a legacy, committable location. A fixed alias table (`i18n-strategy`, `demo-mode`, plus
  the dotted paths `theme.slug`, `project.slug`, `plugins.profile`, `languages.primary`,
  `wp_cli.wrapper`) addresses the two space-spelled manifest keys a dotted path cannot
  reach. Covered by `tests/checks/wp-config-secrets.sh`.
- **Fix: `get database.password` and `get wordpress.admin_password` no longer read the
  secret straight out of the manifest, bypassing the resolution order above.** Those
  dotted paths equal a secret's own `manifestPath`, so the generic key lookup reached
  them directly — no environment or `.wp-create.local.json` check, and no legacy
  warning, even with the corresponding environment variable set. `getKey` now refuses
  a key that names a secret's manifest path (exit `1`, nothing on stdout, naming the
  secret alias to use instead — `db_password` / `admin_password`) rather than rerouting
  it, so there is exactly one way to read a secret. `resolveSecret` also gained the
  `typeof value === 'object'` guard `getKey` already had (an object at a secret's path
  is refused, not printed) and switched its three presence checks from truthy to
  `!== undefined && !== null`, so an explicitly empty secret — a real local-dev
  configuration — resolves as itself instead of cascading past it to "no value found".
  Covered by four new cases in `tests/checks/wp-config-secrets.sh`; the existing
  alias-table case was also rewritten against a fixture value that differs from
  `getKey`'s own fallback, since the fallback previously matched the fixture by
  coincidence and let a broken alias mapping pass unnoticed.
- **Fix: a suffixed path under a secret's manifest path — `database.password.length`,
  `database.password.constructor.name` — still bypassed the refusal above.** The
  refusal was an exact string match against `manifestPath`, so a key that merely
  *started with* it fell through to the generic dotted-path reader, which keeps
  walking past the string onto its own JS properties: `.length` returned the
  secret's exact character count, `.constructor`/`.constructor.name` its type.
  Same bypass as before — no warning, exit `0` — for a narrower slice. `getKey`
  now refuses a key equal to a secret's manifest path *or prefixed by it plus a
  dot*, and rejects a function the same way it already rejects an object, so a
  suffixed non-secret path can't return a prototype method either. Covered by
  three new cases in `tests/checks/wp-config-secrets.sh`.
- **`/wp-create` now matches the validator Tasks 1-5 built, instead of documenting the
  behavior the validator replaced.** Step 4.10 no longer treats every plugin failure the
  same way: it validates the profile first (`wp-config.mjs validate-profile`), installs
  one plugin at a time, and branches on that plugin's `required` flag — a required
  plugin that fails to install or activate stops the build and names the blocked
  workflow, an optional one warns and is recorded in `plugins.degraded`; a successful
  install is recorded in `plugins.resolved`. A `"source": "supplied"` plugin is never
  fetched from WP.org, and a required one that has no supplied zip is `license_missing`,
  which blocks the same as any other required failure. The `.wp-create.json` manifest
  example is bumped to `manifest_version: 3` and **no longer carries the database
  password** — DB and admin passwords are generated per project (16 random characters)
  and written to `${PROJECT_PATH}/.wp-create.local.json` instead, resolved through
  `wp-config.mjs get` (environment → local file → manifest). `/wp-init` adds
  `.wp-create.local.json` to the **project root's** `.gitignore` (Step 9.6). Covered by
  the new `tests/checks/wp-create-profile-enforcement.sh`.
- **Fix: the `.gitignore` entry above protected nothing.** It was written to
  `<theme-dir>/.gitignore` — the theme's own git repo, rooted below
  `${PROJECT_PATH}` — while `.wp-create.local.json` lives at the project root, a
  sibling of `.wp-create.json`. A repo cannot ignore a path outside itself
  (`git check-ignore -v` on it there fails `fatal: ... is outside repository`), so a
  project root that is itself versioned — a normal delivery pattern — committed the
  database and admin passwords in cleartext, exactly what this manifest_version 3
  change exists to prevent. `/wp-init` gains Step 9.6, which writes the ignore line
  to `${PROJECT_PATH}/.gitignore` (creating it if absent) independently of the
  theme's own `.gitignore` from Step 9.5, which is left untouched. `/wp-create`'s
  Step 5 note now says which `.gitignore` and states the write as an imperative
  ("write them to `${PROJECT_PATH}/.wp-create.local.json` immediately"), not deferred
  to the manifest step, since the credentials are already in use by Step 4.3/4.9 and
  an un-persisted value can't survive a retry after a later critical step fails.
  `Step 4.10`'s `validate-profile` call gained the `**Validation:**`/`**On failure:**`
  block every sibling step already has, and the Step 5 manifest template now shows
  `plugins.resolved`/`plugins.degraded` alongside `installed`, matching what Step
  4.10 actually records. `/wp-audit`'s own `manifest_version` references (Step 2.5a's
  table, its own `audit` reconciliation example) are bumped to `3`, and the "absent"
  bucket widens to "absent or `< 3`" — the previous "current is `2`, stop above `2`"
  table would otherwise treat a project this task's `/wp-create` just created as
  newer-than-understood and refuse to reconcile it.

- **Four theme-code rules an audit of a real theme found missing or mis-severed.**
  `WP-030` named only the visible-text case, so the fix for an `_e()` inside `placeholder=`
  was `esc_html_e()` — which escapes for the document body, not the attribute, and broke four
  attributes on the audited theme. The check now maps each context to its escaper, covers the
  `echo __()` form, warns that a regex sweep cannot see the context and so picks the wrong
  escaper at scale, and states that this is WARNING and not CRITICAL: the vector needs a
  hostile `.mo` inside `languages/`, and whoever can write there can already write PHP.
  Reporting it as an exploitable hole inflates the audit.
- **`WP-049` — a conditional `require` of a file whose functions are called unconditionally.**
  One `inc/` file loaded under `if ( is_readable( ... ) )` while the rest were required
  directly. It reads as a precaution and is the opposite of one: the guarded file also held
  the breadcrumb helper that the always-loaded template-tags file called with no
  `function_exists()`, so a missing file would have fataled about nineteen templates instead
  of degrading. CRITICAL. The rule names both correct resolutions — drop the guard, or guard
  every call site — because half of this is not a fix.
- **`WP-050` — an argument key `WP_Query` never reads.** `'status' => 'publish'` instead of
  `'post_status'`. `WP_Query` ignores an unrecognised key without warning, and the default
  made the results look right, which is why it survives both review and testing; it breaks the
  day someone previews as a logged-in user. The rule carries the mapping from the plausible
  wrong key to the real one.
- **`WP-051` — `get_the_terms()` iterated without a guard.** It returns an array, `false`, or a
  `WP_Error`, so a bare `foreach` fatals on two of the three. The rule requires both tests and
  fixes their order — `empty()` on a `WP_Error` is `false` and lets it through — and excludes
  `wp_list_pluck()`, which checks `is_array()` internally and was wrongly flagged on the same
  audited theme.

### Fixed

- **`/wp-yolo` refuses to normalize a demo it has already converted, instead of silently
  shipping a degraded theme.** `wp-normalize` derives `cssRules`, `fonts` and `backgrounds`
  from the declarations and `@font-face` rules in the demo's markup; Step 2.6's Tailwind
  conversion strips both — the `<style>` blocks and the project stylesheet `<link>` whose
  rules it absorbed. A second `/wp-yolo` therefore normalized markup that no longer held any
  of it and wrote an emptied manifest. Nothing failed: Step 2.6 correctly skipped the pages as
  already-native, and Step 4.5's font carry and `/wp-finalize`'s Layer 1 parity gate then read
  the gutted manifest and passed over nothing, so the run reported success and the theme
  shipped with no carried fonts and no background parity.
  Step 2 now checks for `demo/.original/` — which exists only if a conversion has run — before
  dispatching normalize, and stops with the restore command. **`--force` does not bypass it:**
  `--force` discards the built theme and says nothing about the demo, so letting it through
  would produce the same degraded build with the operator believing they had chosen it. The
  workaround was already documented, in Step 3's abort branch three steps away from the
  command that triggers the problem, which is a workaround nobody applies.

- **A CSS `background-image` served the original PNG/JPG on an optimized library.** Robin
  Image Optimizer's default delivery mode, `picture`, rewrites `<img>` tags only, and the
  `__tailwind__` starter's own HTML rewrite looked for the sibling WordPress writes
  (`foto.webp`) but not the one Robin and most bulk optimizers write (`foto.png.webp`) — so
  on a Robin-optimized site it matched nothing and every background kept its original bytes.
  Both names now resolve through one helper, `prefix_webp_sibling_url()`, which the buffer
  uses. The starter also gains `prefix_background_image( $url )`: it prints the plain
  `url()` first and an `image-set()` naming the sibling second, so a browser without
  `image-set()` keeps the background, and each browser requests the URL it understands,
  which is safe behind a full-page cache. `agents/wp-template.md` requires it for any
  background a template prints, the `wp-robin` skill documents the three delivery modes with
  the page-cache caveat on `url` and the nginx/Apache rule for a background declared in a
  stylesheet, and `wp-audit-performance` gains PERF-056 for an uploads background whose
  sibling exists but is never served. The helper percent-encodes the characters `esc_url()`
  passes through but CSS reads as syntax, so a filename carrying a parenthesis or a
  semicolon — which reaches disk on any library moved by rsync rather than through
  `wp_handle_upload()` — cannot close the `url()` token or inject a second declaration; a
  URL with a parent segment is refused before `file_exists()` runs; and the buffer leaves
  the helper's own two URLs alone, since rewriting the fallback would hand a browser
  without `image-set()` a WebP in its place. `tests/checks/webp-css-backgrounds.sh` now
  runs the code against a fixture library instead of only grepping for the contract. The
  buffer's pattern also carries a `(?!\.webp)` look-ahead: its lazy quantifier stops at the
  first extension, so it used to match the `foto.png` inside an existing `foto.png.webp`
  URL and rewrite it to `foto.png.webp.webp` — a 404 on any page already printing a
  sibling URL, which on a Robin-optimized library is every page the helper touches.
- `wp-robin`: the webp sync step now converts sizes added after the first run. It used to
  pick only attachments with no webp rows at all, so a size registered later and generated
  with `wp media regenerate` was never converted. Each attachment's files on disk are now
  compared against its webp rows, entries the attachment already owns are skipped instead of
  duplicated under the collision hash, and the final "remaining" count uses the same rule.
- `wp-robin`: the script checks that uploads is writable before converting and stops with the
  cause, instead of printing one "conversion failed" line per size when the directory belongs
  to the web server user. The skill's troubleshooting table gains that row and one for a
  missing `wp_rio_process_queue` table after a WP-CLI activation.

- **`/wp-demo-verify` no longer reads full-resolution contact sheets into the
  orchestrator's context.** `bin/demo-verify.mjs`'s contact sheet was a single
  full-page PNG of the whole walk's frames, and Step 4 told the model to read it
  directly — an image Read stays in context and is re-billed on every later call
  until compaction, and a real verify session read 14.6MB of these in one run.
  The script now also writes `sheet.jpg` next to each `sheet.png` (same grid,
  downscaled to 1000px wide, quality 70); `sheet.png` stays at full resolution on
  disk for a human, but the command now points the critique step at the JPEG.
  Past ~3 sheets — any directory walk of more than a couple of pages —
  `/wp-demo-verify` now dispatches the critique to a `sonnet` subagent per page
  (or batch) instead: the subagent reads the sheets and returns only the
  pass/fail rows, so the images never enter the orchestrating conversation at
  all. Same guidance carried into `skills/wp-demo-craft/references/verify.md`,
  which restates the step.
- **The starters now meet the rules their themes are held to.** Every PHP file in
  `starter-theme/` opens with the ABSPATH guard that `agents/wp-template.md` requires of a
  theme. The cinematic starter gets the two loader fixes the tailwind one already had:
  the `pre_handle_404` sitemap guard, and the Local JSON export restoring the `ID` key
  that `acf_prepare_field_group_for_export()` strips. The tailwind `__starter___t()`
  falls back to the primary language before English. The tailwind starter's
  `[aria-disabled="true"]` reset rule is now scoped to actual controls (button, input,
  select, textarea, a, summary, `[role=button|option|tab]`) instead of every element
  carrying the attribute — `cursor` inherits, so an unscoped rule on a container used
  only to announce state (a disabled tab panel, a busy section) took the pointer
  affordance away from still-interactive descendants.
  The starter's `template-parts/header/navigation.php` asked for a `primary` menu
  location that `inc/theme-setup.php` never registers (only `primary-<lang>`), so the
  default nav rendered nothing; it now asks for the current language's location, and the
  same example in `agents/wp-template.md` is fixed. The starter footer no longer prints a
  placeholder designer credit linking to `example.com`.
  `tests/checks/starter-bootstrap-lock-and-sitemap.sh` pins the loader fixes;
  `tests/checks/tailwind-starter.sh` still pins `cursor: pointer` restored and
  `input[type="submit"]` covered.
- **Checks that pinned less than their contract.** `audit-findings-measured.sh` now
  greps the per-finding evidence sentence rather than the word "evidence", and fails
  clearly when no audit agent matches. `finalize-brand-surface.sh` pins both halves of
  the login-branding check, the hook and the seed file. `wp-polylang.sh` no longer
  depends on array alignment. `tailwind-starter.sh` strips CSS comments non-greedily
  with perl. `tailwindify-parity.mjs` skips `node_modules`, `vendor`, `dist`, `build`
  and `.git` when it collects breakpoints, and now `lstat`s instead of `stat`s so a
  symlinked directory (the demo trees genuinely carry them) is never recursed into,
  with a realpath dedupe as a second guard against a loop. The walk stops at depth 8
  and skips stylesheets over 2 MB, and `--list-breakpoints` prints what it collected
  without a browser, which `tests/checks/tailwindify-parity.sh` now runs on a fixture
  (both media-query forms, skipped `node_modules`/`dist`, a looping and an outward
  symlink).

- **Every user-visible literal is a translation key, not only field content.**
  `agents/wp-template.md` forbade raw `get_field()` and showed `prefix_e()` once, which
  covered the CONTENT and nothing the template says on its own behalf. A bilingual build
  therefore shipped with every ACF field translated and its secondary-language directory
  pages still rendering the filter bar, the composed `alt` text and the empty-state message
  in the primary language: none of it came from a field, so none of it looked like content.
  The i18n section now names where those literals hide — controls, placeholders, empty
  states, button text, `alt`, `aria-label`, `sprintf()` patterns — and Rule 11 states it.
- **A control the demo drew is not a control the data can answer.** A static demo's filter is
  coherent by construction: its options and its cards are the same mock values. Transcribed
  literally onto real posts, that option set becomes a claim about data — a select whose only
  value matches no record, so choosing it empties the grid. The `/wp-section` transcription
  overlay now carves controls out of the fidelity mandate (markup and values are copied; an
  option set is derived from the real terms), and `agents/wp-template.md` Rule 12 requires a
  control nothing backs to be dropped and NAMED in the summary, rather than shipped dead. The
  demo's empty-state and "no more results" strings fall under the same carve-out: wording to
  translate and behaviour to re-derive, not constants to copy.
- **A finding is the output of a command that ran in this run.** `/wp-audit` §2.5b already
  said "measure, do not trust" about the environment; the agents' own findings had no such
  rule, and two shapes reached real reports — a duplicate meta description asserted from
  reading two code paths on a page that emits one, and "the site has no posts" carried over
  from a stale input on a site with twenty. New §6.9 requires an evidence line per finding,
  defines `UNVERIFIED` for what the tier cannot reach, and makes the aggregator drop and
  report evidence-free findings by agent. All eight `wp-audit-*` agents carry the rule.
- **Seeding may invent a biography; it may not invent a real person's account.** `/wp-seed`
  Phase 4.5 covers the fields no demo answers: nothing handle-shaped or externally
  resolvable is generated (those stay empty and the templates already guard them), generated
  emails and phones follow one shape site-wide so a wrong one is visible, every invented
  record carries the seeded marker, and the phase ends with a list of what was invented, by
  field and count, for the client to replace. Two real defects motivated it: a phone a digit
  short of every other on the site, and a social URL built from a different person's handle,
  so a fictional record linked a real stranger.
- **Tailwind's `max-*` variants are EXCLUSIVE; a plain-CSS demo's `max-width: Npx` is
  INCLUSIVE.** `max-width: 768px` in a demo matches width 768 itself; Tailwind 4's
  `max-md:` compiles to `width < 768` and does not — every converted breakpoint was 1px
  off at exactly the two widths a desktop-first demo declares most, 768 and 1024.
  `skills/wp-tailwind-system/SKILL.md` and `agents/wp-tailwind.md` now state the N+1
  rule (`max-width: Npx` → `max-[N+1px]:`, or a `--breakpoint-*` redeclared to `N+1`;
  `min-width` needs no adjustment) with a worked example at the round numbers that hit
  this. `bin/tailwindify-parity.mjs` now also reads every `max-width`/`min-width` value
  out of the ORIGINAL demo's own CSS and samples those exact pixel widths, on top of
  `--widths` — 1440 and 390 never land on the one width where the off-by-one is visible.

- **A hand-written CSS file imported with no cascade layer beats every Tailwind
  utility, regardless of specificity or source order — and this shipped in the
  `__tailwind__` starter itself.** `base/reset.css` duplicated two declarations
  Preflight already sets (`box-sizing: border-box`, `img { max-width: 100% }`) as
  plain, unlayered CSS; on a real build the duplicate clamped a button to a fraction of
  its design size and clipped a slider arrow deliberately overhanging its button. The
  starter's `main.css` now imports every default file with its matching layer —
  `layer(base)`, `layer(components)`, `layer(utilities)` — and `base/reset.css` no
  longer duplicates what Preflight covers. `skills/wp-tailwind-system/SKILL.md`,
  `agents/wp-tailwind.md` and the five commands that register a new `@import`
  (`wp-section`, `wp-header`, `wp-footer`, `wp-page`, `wp-cpt`) now require the same
  `layer()` declaration on every file a later build step adds.

- **Preflight does not set `cursor`, and the starter's own reset never restored it.**
  Tailwind v4 leaves every button on the UA default (`default`, not `pointer`). The
  `__tailwind__` starter's `base/reset.css` now restores it, scoped past a literal
  `<button>` to `summary`, `[role="button"]`, `[role="option"]`, `[role="tab"]` and a
  form's `input[type="submit"|"button"|"reset"]` — Contact Form 7 and WordPress's own
  comment form render their submit this way, and `button { cursor: pointer }` alone
  never reaches it — paired with `:disabled` / `[aria-disabled="true"]` back to
  `default`.
- **`agents/wp-acf.md` — the front page's own location rule never matched a hierarchy-rendered
  front page.** `page_template == front-page.php` only matches when a page's
  `_wp_page_template` meta is literally set to that filename; a page chosen as the front page
  through Settings → Reading keeps that meta at `default`, so its field group silently
  disappeared from the editor while its fields kept rendering on the front end. Switched to
  `page_type == front_page`, which ACF derives from `is_front_page()` instead. Also: every
  group now gets a `menu_order` equal to its section's position on the page (groups defaulted
  to 0 and stacked in load order, not page order) with numbered, single-language titles; and
  when the demo shows the same content twice at different lengths for different purposes (a
  card excerpt, a full bio), that is modeled as two fields from the start instead of one field
  serving both and breaking in both directions.
- **`agents/wp-template.md` — six contract gaps a real bilingual build's own defect list
  turned up.** The ABSPATH guard read as a template-parts rule, so full page/single/archive/
  taxonomy templates and `inc/` includes shipped without it; archive/directory queries
  ordering by date had no tiebreaker, so records seeded in the same second reordered on every
  request; a custom nav walker overriding `start_el()` never re-applied
  `nav_menu_css_class` / `nav_menu_item_id` / `nav_menu_link_attributes`, dropping any class a
  filter added; a demo control marked `MOCK:` / `data-mock` had no rule requiring it be
  re-derived from real data or dropped before being wired up; an optional "see more" control
  rendered for a demo's `#anchor` placeholder instead of only for a real URL; carousel controls
  stayed visible-but-dead when the real record count could not overflow the strip, and a
  `Math.ceil()` dot count could exceed the card count; and there was no rule to reuse a
  sibling template's already-correct accordion/focus-ring pattern instead of re-deriving a new
  one per section.
- **`agents/wp-cf7.md` — three form-contract gaps, plus a first grep gate for the utility-class
  rule the agent already stated.** An `[acceptance]` tag with no `acceptance_as_validation:on`
  leaves the submit button disabled on an unchecked box with no visible error; CF7's own
  `wpcf7-form-control-wrap` does not stretch the control inside it, so a control needs its own
  `width: 100%`; CF7's AJAX spinner ships with an unclipped side margin that caused a phone
  viewport to gain 20px of horizontal scroll; a loading-state `padding-right` override loses to
  an `@apply px-*` utility's logical `padding-inline` regardless of specificity, so it has to be
  written as `padding-inline-end`; and the live form is the `_form` post meta, not the
  `cf7/*.html` reference file — a change has to be pushed through the seeder, and pushed for
  every language, to reach the site.
- **ACF Local JSON bootstrap lock could never be acquired by the second user.**
  The starter created the lock with `fopen(..., 'c')` under the process's default
  umask (0644, owned by whoever ran first). When the web server user and the CLI
  user differ — the common case — the second one can never open it for an
  exclusive lock, and the bootstrap returns early, silently, on every later
  request from that user: a field group's JSON drifts behind its PHP with
  nothing logged anywhere. `__tailwind__` and `__cinematic__` now widen the lock
  to 0666 right after creating it.
- **`/wp-sitemap.xml` 404s on a project with no native `post` content.**
  `WP::handle_404()` only clears the 404 when the current query matched
  something, and a sitemap route runs no post query of its own — on a site that
  publishes `post` it survives by accident (the default "latest posts" query
  behind it isn't empty); on a site modeled entirely as custom post types that
  query IS empty, so core marks the sitemap request 404 while
  `WP_Sitemaps::render_sitemaps()` prints a perfectly valid sitemap on
  `template_redirect` immediately afterward — a correct XML body under a 404
  status line, which every crawler reads as absent. The `__tailwind__` starter
  now exempts the sitemap and sitemap-stylesheet routes via `pre_handle_404`.
- **A starter scaffold part left on disk after its last caller is removed ships
  unreviewed.** `/wp-header`, `/wp-footer` and `/wp-page search` fully replace
  `header.php`/`footer.php`/`search.php` with project markup, which removes the
  `get_template_part()` call to the starter's placeholder part
  (`header/site-branding.php`, `header/navigation.php`, `footer/site-info.php`,
  `content-search.php`) — but nothing then deleted the now-unreferenced file, so
  a starter placeholder (down to a hardcoded credit link to an external domain)
  shipped on a real build, one accidental `get_template_part()` away from
  rendering. `agents/wp-template.md` now instructs deleting an orphaned part in
  the same step its last caller is removed.
- **`content-page.php` (the generic/legal page template) shipped as unstyled
  underscores boilerplate** while every other template in a project is
  pixel-matched to its demo. It now gets its own small baseline: a
  comfortable-width column and Tailwind Typography's `prose` utility (already
  loaded by the starter's `main.css`) carrying headings, lists and links through
  the project's own `@theme` colors.
- **`/wp-finalize`'s theme-structure check never looked for a favicon or a
  branded login screen.** A demo can declare `<link rel="icon">` on every page
  and have the conversion to PHP drop the tag entirely, leaving the live site
  with no icon at all; `wp-login.php` is the one page that never enqueues the
  theme's own stylesheet, so it stays WordPress's stock grey screen — the first
  thing the client sees every day — unless something re-skins it. Both are now
  checked (favicon/site icon as a blocking item, login branding as a
  warning-only item, since some projects ship the default by choice).

- **`tests/checks/wp-config-gate.sh`'s validator-call assertion matched a prefix, not the
  real invocation.** `grep -Fq 'wp-config.mjs validate'` is satisfied by
  `wp-config.mjs validate-profile`, which `commands/wp-create.md` already calls (Task
  5/6) — so the one file this whole task exists to protect could lose its actual gate
  call and the check would still pass. The same shape existed for the migration-exit-code
  assertion: a bare `grep -Fq 'exit 2'` is satisfied by unrelated `exit 2` documentation
  already in `commands/wp-yolo.md` and `commands/wp-demo.md` (the `demo-verify.mjs
  --probe` contract). Both assertions now match the actual gate text — the invocation
  with its `'${PROJECT_PATH}'` argument, and the gate's own migration sentence — neither
  of which any unrelated content in the twelve files happens to contain.

- **Fix: the gate said `${PROJECT_PATH}` without ever saying what it is.** Eleven of the
  twelve gated commands never defined it — only `/wp-create` does — and it sits inside a
  `bash -c` beside `${CLAUDE_PLUGIN_ROOT}`, which is a real environment variable, so the
  gate expanded to `validate ''`, printed the usage line and exited `1`: "stop and report"
  on every project. The block gains one sentence naming the path and what to do without
  one, and stays byte-identical at all thirteen insertion sites.
  `tests/checks/wp-config-gate.sh` now diffs every site against one canonical copy instead
  of grepping for two of its lines, and finds the gated commands by walking
  `commands/*.md` rather than from a hardcoded twelve-name list that shipped a thirteenth
  ungated manifest-reading command green. `/wp-seed`, `/wp-debug`, `/wp-robin` and
  `/wp-init` now *amend* the exit `3` table row instead of contradicting it three lines
  later.

- **Fix: two places still handled a secret as if Task 6 had not happened.**
  `skills/wp-environments/SKILL.md`'s placeholder table is a mapping an agent follows at
  `/wp-create` Step 4.3, not an example, and it routed `{{db_password}}` to
  `database.password` — a field the manifest no longer carries, so the generated
  `docker-compose.yml` / nginx conf got an empty password, or a silent legacy read on a
  project that has not migrated. It now names
  `wp-config.mjs get '${PROJECT_PATH}' db_password`, and the stale `root` example value is
  gone. Separately, `/wp-init` Step 9.6 appended the `.gitignore` entry without
  guaranteeing a leading newline: a project-root `.gitignore` ending `*.log` with no
  trailing newline became `*.log.wp-create.local.json`, `git check-ignore` stopped
  matching, and the next `git add -A` committed the database and admin passwords
  (measured in a real repository). The append now normalises the newline first, and the
  step's `**Validation:**` line gains the `**On failure:**` action every sibling block in
  `/wp-create` already has.

- **Fix: the generated block and the manifest's rules were two lists that had to agree,
  and did not.** `REQUIRED` and `renderContext`'s field list are now derived from one
  `CONTEXT_FIELDS` table, so a field cannot be rendered into the authoritative block
  without also being validated: a manifest lacking `theme` or `languages` used to render
  `- **Theme slug:** ` and `- **Primary language:** ` as blanks with `validate` exiting 0,
  and reading that block is every agent's first mandatory action. The absent-value
  defaults (`suffix`, `plain`) come from the same table instead of being spelled a third
  time inside `getKey`, where a two-entry ternary left "an absent `i18n strategy` means
  `suffix`" unguarded on the `get` path. `CURRENT_VERSION` is derived from the migration
  table rather than typed beside it, so bumping it without writing the step can no longer
  produce an uncaught `Error`.
- **Fix: migrating a legacy project made `.claude/CLAUDE.md` contradict itself.** `migrate`
  appended the generated block beside the legacy prose decision line it had just read, and
  `contextDrift` only compares inside the markers — so the file could state `polylang` on
  line 4 and `suffix` on line 12 with `validate` exiting 0, reintroducing the exact
  disagreement this work exists to remove, for exactly the projects migration targets.
  Migration now comments the superseded lines out, preserving their pre-migration values,
  so each decision is asserted in exactly one place.

- **Fix: the `wordpress.admin_password` refusal was asserted against a fixture with no such
  key.** Absence, not the guard, supplied the exit code and the empty stdout, and the grep
  was satisfied by the message echoing the operator's own key: pointing
  `SECRETS.admin_password.manifestPath` at a nonexistent field left the whole suite green
  while `get wordpress.admin_password` would have printed the password. The fixture now
  holds the key, and both the exact and the suffixed path are asserted against it.
  `tests/checks/wp-profiles.sh`'s comment said "exactly one plugin required" where the
  assertion is "at least one"; the comment now states the rule that is enforced.

- **Fix: migration could retire the only record of a decision and leave the project
  permanently invalid.** A v1 manifest with no `theme` and no `languages` migrated with
  `ok:` and exit 0, the prose lines carrying those decisions were commented out, the
  generated block was written with a blank `Theme slug` and `Primary language`, and
  `validate` then exited 1 on both — the old values recoverable only from inside an HTML
  comment. `render-context` now validates before it renders and refuses to write a partial
  block, and retiring the prose moved from `migrate` into `render-context`, downstream of
  that refusal, so the record survives exactly as long as it is the only record and a
  refused migration leaves `.claude/CLAUDE.md` byte-identical. Recovery is one
  `render-context` after the manifest is filled in. `tests/fixtures/manifests/legacy-incomplete/`
  reproduces the case end to end.
- **`/wp-demo` consults `inspo` for page-level direction, in both modes.** A free
  MIT archive of 832 production sites, opt-in and never registered by default. It
  answers macrostructure, section ordering and fold composition; `wp-design-library`
  keeps role, section and motion device; the client's own material keeps colour.
  Plain mode had no reference source at all before this — its library step lives
  inside the craft-only Step 2.6 — so Step 2.7 gives it one.

  Four exclusions are rules, not judgment calls: its colour table never becomes theme
  tokens (its role labels are self-declared heuristics, and on `animaapp-com` it calls
  `#063f77` the accent while its own prose names purple `#5d4fae`), `get_reference_jsx`
  is never called because it returns React, nothing reaches `/wp-yolo --transcribe`,
  and it never picks a motion device because it carries no motion data.

- **Check Inspo's fallback and search budget within each demo mode.** The checks
  previously required exactly two matching lines in the whole command, so an extra
  mention caused a false failure. Craft and plain are now checked independently;
  a repeated rule elsewhere cannot hide its removal from either mode.

- **Pin the optional Inspo server to `inspo-mcp@0.1.16`.** The README's `0.1.x`
  range allowed automatic patch upgrades despite its deliberate-upgrade rationale.
  The example now uses the measured release, and the check matches the quoted package
  argument literally so a range or a longer version cannot satisfy it.

- **`wp-config.mjs get` answered a prototype-chain key with a JS intrinsic.**
  `at()` walked plain bracket access, so `get toString.length` printed `0` —
  `Object.prototype.toString`'s arity, not a config value — and exited 0 as though
  the manifest had said so. `getKey`'s object/function guard does catch
  `constructor.prototype` (Object.prototype is an object), which is why only the
  primitive intrinsics leaked, and the secret-subtree refusal covers a secret's own
  paths but nothing else. `at()` now requires `Object.hasOwn` at every step, so
  traversal stays on the parsed JSON's own properties and any such key reads as
  `unknown key` with exit 1. Every path it walks is a plain JSON leaf, so no
  legitimate lookup changes behaviour. `tests/checks/wp-config-secrets.sh` pins all
  three shapes.

## [1.18.0] - 2026-09-15

### Added

- **`/wp-demo` consults `wp-design-library` when it is registered.** A new
  MCP server (separate repo) holds a corpus of design references; the craft
  path queries it per role and cites slugs in `demo/BRIEF.md` under
  `## References`. Absent server: `References: library unavailable`, build
  continues. `.mcp.json` registers the stdio default; README documents the
  hosted override.
- **`bin/tailwindify-parity.mjs` — the conversion is now gated on what it RENDERS.**
  `/wp-tailwindify` rewrites a plain-CSS demo into utilities and archives the original.
  Its Step 4 verified structure — delimiters kept, no `<style>` block, no project
  stylesheet `<link>` — and nothing verified the result against the original. A demo
  whose reset read `button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}`
  converted with the whole rule dropped as "preflight covers it". Preflight covers five
  of those six declarations and not `cursor`: Tailwind v4 leaves buttons on the UA
  default, which is `default`. Every button on the site lost its pointer.

  Nothing downstream could catch it either. Every later gate compares the theme against
  the CONVERTED demo, so once a declaration is gone from the reference both sides agree
  and the site is wrong. Conversion is the last point in the pipeline where the original
  still exists to compare against, which is why the gate lives there.

  It renders both files and joins leaf elements on tag + text — the two use different
  class systems, so a selector join is impossible, but they render the same words — then
  compares fourteen computed properties. Colours are resolved through a canvas in the
  page, because Tailwind emits `oklab()` for a colour carrying an opacity modifier where
  plain CSS emits `rgba()` and string-comparing the two buried the real findings under
  dozens of notation differences. A converted page with no Tailwind runtime renders as
  bare HTML, where every element differs; that shape is detected and reported as "not
  compared" rather than as hundreds of lost declarations. Exit 0 clean, 1 deltas, 2 no
  usable browser, 3 crashed.

- **`static-page` now says what to do about itself, because the obvious remedy is the
  wrong one.** Measured on a real build: two interior pages fired it, and the cause was
  that they were the only interior pages with no banner image — the banner bed carries
  the `parallax`, so no image meant no scroll device. The client had asked rounds
  earlier that interior banners use images and these two were the last not honouring
  it. The finding fires on a *motion* axis and the defect was on a *content* one, so
  the rule now reads: a page with only `reveal` is usually not a motion decision, it is
  a page that is missing something. Adding a device to clear the finding would have
  buried the real defect and made the page worse.

- **How to read a jump in the advisory count.** A bed is one `unobserved` row at every
  sampled position, so adding one device to one page raises the count by exactly the
  per-page sample count — measured, 80 to 96 when two pages gained a parallax bed,
  eight rows each. An advisory rise that is an exact multiple of the sample count is a
  device being added, not a device breaking.

- **An override can conceal what it overrode.** The known hazard was an override that
  silently fails to apply — appended above the rules it replaces, losing on source
  order at equal specificity. The other direction is worse: an override that *flattens*
  a ladder makes a broken ladder unobservable, because "all correct" and "all
  identical" look the same on a screenshot. Measured on the build using this library,
  an override collapsed two columns onto one range, hiding `offer-table`'s off-by-one
  and costing the stagger itself for several rounds without anyone noticing.

- **Measuring motion: two readouts, and they answer different questions.**
  `animation.currentTime` is raw timeline progress and is the one for "is this ladder
  in order"; the computed property is post-ease and is the one for "does this look
  arrived". `getComputedStyle` and `getBoundingClientRect` both go through the timing
  function — an eased reading put `entry 100%` at cover 52.8% where the truth is 30.8%,
  and `getBoundingClientRect` returns the *transformed* box, so nodes mid-`scale`
  measured 44 / 43.8 / 43.3 / 42.6px. Both artefacts, and between them the cause of
  every wrong number produced while writing these rules.

- **`ladder-scan.py` gains an exemption that has to be argued.** `:nth-of-type` is
  unavailable to a ladder whose children are deliberately of mixed type, and the
  stylesheet cannot tell that case from a broken one. The author writes
  `ladder-scan: allow-nth-child <selector> -- <why>`; a marker with no reason is
  refused, so the exemption records a judgement rather than silencing the scan.

- **`process-flow`, a second answer in the `process` role.** A pipe with a node per
  step and a line the scroll draws along it, stacked on a phone and horizontal once
  the container can hold a column per step. Costs 0 vh where `process-rail` costs a
  viewport-height and pins, so the two are chosen on page budget rather than on taste
  — the role had one answer, and a library with one good answer per role gives every
  build the same answer. It is also the composition the coupling rule is shaped
  around: every animated element runs on one `view-timeline-name` declared on the
  section, because a segment's progress and the arrival of the node it points at are
  the same quantity. The rail is drawn per step rather than spanning the list, and
  nothing in it counts the steps; measured 0.0px at every junction at 1440, 1024, 768
  and 390, and at three, four, five and six steps.

- **The generative half of the ported skill, absent since the port.**
  `wp-demo-craft` was ported from nateherkai/scroll-craft as *prose* — taste floor,
  refuse list, feeling curve, device kit — and every one of those is a constraint. The
  three references that make one build differ from the last never came over. Measured:
  the source skill is 5,155 lines, this one was 1,752. Now ported and wired into
  `SKILL.md`, because an unread reference is the same as an absent one:
  - `references/uniqueness.md` — the template trap, the signature move, the seven
    aesthetic families, and the burden of proof on the default grammar.
  - `references/hero-depth.md` — layering is the baseline, not a polish pass. A
    full-screen photograph with one parallax transform and a text fade is the flat hero
    it exists to prevent.
  - `references/worlds.md` — eight art-direction preambles, each pasted verbatim into
    every image prompt so separately generated plates look like one shoot.

- **A second axis of sameness the source never had to name.** scroll-craft builds one
  page per project, so its only axis was build against build. A multi-page demo can
  also repeat *itself*: eleven pages that are the same page with different words, which
  is what was actually reported. No two pages of one demo may now share their whole
  composition sequence, and the index's sequence may not be a superset of an interior
  page's.

- **`aesthetic family` joins the brief.** Premium-minimal is a choice, not the default
  costume, and a shelf of dark pages with one accent each is what happens when nobody
  decides.

- **Every silent-failure rule now carries the measurement that produced it.** Such a
  rule is by definition one nobody has cause to test — the advice is followed, nothing
  breaks, and the stated *reason* is never exercised — so a wrong reason survives until
  someone reasons forward from it. Measuring the two rules in `devices.md` that had no
  numbers found a second wrong one immediately: the fill-mode rule said an element
  outside its range "flashes to its `from` value", and measured on keyframes running
  `10`→`90` against an `initial-value` of `0`, it renders `0`, not `10`. The fallback is
  the un-animated value. Checked: each numbered item must be marked as measured and
  carry a figure that can be re-run.

- **`score-scale`: the first composition that draws data rather than describing it.** The
  library was nine-of-fourteen text only — every composition a heading and some paragraphs
  arranged differently — so every page came out the same shape, and "less text" had nothing
  to become. This one draws the credit-score range with the five bands at their **real point
  spans** (Poor is genuinely half of 300–850, which is the fact worth drawing) and the five
  factor weights at their published values. Bands grow from the baseline left to right, then
  a marker travels the range. All element-level `view()` animation: zero vh, and the root
  `data-motion` attribute left free.

  The numbers are hardcoded rather than slotted, and the marker carries **no value**. A
  published band edge is a fact about FICO scoring; a needle reading "580 → 720" is a claim
  about a client's results, which `taste.md` refuses — in the one industry where that claim
  draws regulators. A slot would invite a build to change an edge, and a changed edge is
  misinformation in a regulated field.

- **Compositions carry element motion, and the budget stopped metering it.** A craft build
  produced pages that read as static while passing every gate, and the cause was neither
  restraint nor the budget: a measured build finished with a quarter of its scroll allowance
  unspent, having never dropped a device for it. One word covered two costs. Scroll
  choreography lengthens the page and is correctly budgeted; fades, rises, zooms, icon draws
  and staggered entrances lengthen nothing and were rationed by a ceiling that was never
  about them. Seven compositions now carry per-element `view()` animation staggered by
  `animation-range` instead of one root `reveal` -- ten of thirteen previously shipped
  `reveal` as their only device, so composing faithfully produced one one-shot entrance per
  section.

- **New `icon-row` composition.** Four capability marks whose SVG icons draw themselves on
  via `stroke-dasharray`/`stroke-dashoffset`, cards arriving left to right. `icon`
  previously appeared in the craft rules only as a prohibition.

- **Motion reaches the design references.** 67 reference sites, 57 of them describing
  motion, and the token pipeline extracted none of it, so a demo took its palette from a
  reference and its motion from nowhere. `--ease-entry` and `--motion-rise` are now mapped
  and consumed by every composition.

- **`demo-verify` reports `static-page`.** A page whose entire motion is `reveal` plus
  pointer devices is a static page that measures as animated, and no existing finding
  could say so: `no-engine` asks whether motion exists, `dead-scroll` whether a section
  moves, and both are satisfied by devices that are present and correctly wired. The new
  finding judges the *mix* — it names the devices the page actually has and fails the round
  when none of them reacts to scrolling. Blocking, not advisory.

  This is the first gate in the craft path that catches a build rather than a contract.
  The greps beside it pin the rule's wording, which was accurate before this change and
  accurate after it; the wording was never what failed.

### Changed

- **The brief asks what this business has that could be drawn.** The docs said "impactful
  animated website", which is unfalsifiable, so the old step asked nothing and the
  adjective survived four rounds of revision unsatisfied. The answerable version is a list
  of pictures the demo is then obliged to contain. Adds two more: three named sites whose
  motion to match, and which page a visitor must understand in ten seconds.

- **The demo brief now interviews the operator about form, and gates the build on
  approval.** Every field it captured — person, pain, promise, vibe words, references,
  the feeling curve, the peak — was about *story*. None was about *form*: what the site
  looks like, how much it moves, how much of it is reading. A build could satisfy the
  brief completely and still ship twelve pages of dense paragraphs with one animation.

  The old rule, "ask in one pass only what the docs cannot answer", is right for story
  and wrong for form: documents describe a business and almost never describe a website,
  so it resolved to never asking. Six form fields are now always asked, with concrete
  options — which facts become a picture rather than a paragraph, text density, motion
  appetite, microinteraction appetite, the one action, and what specifically to take from
  each reference. They bind on the composition plan, so a row contradicting a recorded
  answer is a defect rather than a judgment call.

  The brief is shown whole and revised in a loop with no pass limit; the build runs only
  once the operator approves, and the approval is recorded with its date. `AskUserQuestion`
  is added to the command's tools — it was instructed to interview and had none.

### Fixed

- **The walk measured the painted box, so it walked moving sections at the wrong
  offsets.** `bin/demo-verify.mjs` read section bounds with `getBoundingClientRect()`,
  which returns the box *after* transforms — and every value from that read becomes a
  scroll position the walk drives to. Measured on a fixture at 1280×800, painted minus
  layout: a parallax bed **−90px**, an entrance start state **+44px**, a scaled wrapper
  **−28px top and +56px height**. A motionless section reads correctly, which is why it
  survived a composition corpus that is cleaner than a real build; the error is largest
  on exactly the sections the walk exists to judge. The read now neutralises
  `animation`, `transform`, `translate`, `scale` and `rotate` for its duration and
  restores the page immediately — all of them, because `animation: none` leaves the
  engine's inline transform on a parallax bed and `offsetTop` misreads under a
  transformed ancestor. Verified by running the shipped bounds body against the
  fixture: all four deltas zero.

  **What this does and does not change, measured on a real build rather than a
  fixture:** it makes a finding's reported `y` and the scrub range the walk drives
  trustworthy. It does *not* generally change the verdict, because a section that is
  genuinely moving still reports as moving when sampled from a slightly wrong offset.
  Run against a build full of moving sections, before and after, the findings were the
  same. The entry above says the error is largest on the sections the walk exists to
  judge, which is true and should not be read as "those sections were being judged
  wrongly" — they were being judged from the wrong coordinates.

- **`references/verify.md` gains the two-readout table, before the rubric.**
  `animation.currentTime` is raw timeline progress; the computed property and
  `getBoundingClientRect()` are post-ease and post-transform. It sits next to the act
  of measuring rather than in a reference section, because the moment it is needed is
  the moment somebody opens a probe.

- **`offer-table`'s stagger was off by one, shipped.** Its plans are `<th>` preceded by
  a `<td>` corner cell, so `:nth-child` counted the corner: plan 1 received the range
  written for plan 2, and the `:nth-child(1)` rule matched nothing at all. With four
  plans the fourth would have fallen through to the catch-all and lost its animation
  entirely. `:nth-child` is a fact about the parent's *other* children; all 39 indexed
  selectors in the library are now `:nth-of-type`.

- **A ladder that mixes `entry` and `cover` endpoints is ordered only by luck.** The
  entry phase spans `min(elementH, viewportH)` of scroll and the cover phase spans
  `viewportH + elementH`, so `entry 100%` sits at `min(h,vh)/(vh+h)` of cover —
  measured across eight element/viewport pairs at exactly that value, from cover 11.8%
  to 47.1%. `process-flow` shipped one such rung. It did not invert at any geometry
  measured, because `entry X%` can never exceed `cover X%`, but it was safe by margin
  rather than by construction. `tests/checks/lib/ladder-scan.py` now refuses the mix,
  along with child-indexing and a missing catch-all, and names the fourth cause it
  cannot see: rungs on `view()` each build a timeline from their own box.

- **A child past the last written `:nth-child` range runs out of sequence.** An element
  with no `animation-range` falls back to `normal`, which on a view timeline is
  `cover 0%` to `cover 100%` — a range unrelated to the stagger, so the extra child
  leads where the explicit ranges are late and lags where they are early. In
  `process-flow` at six steps it led: the last node was 54% along while nodes 2–5 sat
  at 0%, at every scroll position, not only on arrival. Guidance would not have stopped
  it, because a sixth step lays out perfectly. Above five steps the pipe is now
  structure without a sequence, guarded on the list rather than on the sixth step —
  exempting only the untimed elements leaves the last node lit beside dark ones, which
  is the same inversion held still. Generalising it into a check found the same latent
  shape in `icon-row`, `offer-table` and `score-scale`; all three are guarded, and
  `offer-table` records that it is not visibly wrong today only because its stagger is
  early.

- **`devices.md` said a duration on a scroll-driven animation hijacks it. Measured,
  it does nothing at all.** The file claimed a duration "overrides the range and the
  element plays through on its own clock", and a check pinned that wording, which is
  what made it durable. Two rules identical but for `animation-duration: auto` against
  `2s`, sampled at six scroll positions in Chrome: same value at every one — 13.165,
  79.0622, 95.4148, 99.9709, 100, 100. The advice survives, the reason was wrong, and
  a pin that fixes a false reason in place is worse than no pin.

- **A clock loop written near scroll-driven CSS silently does not run.** A scroll
  timeline is inherited from any broader rule handing one out, and `motion.css` gives
  descendants of a `reveal` section their own `view()`. A looping animation that lands
  on one reports `playState: "finished"` and sits at its start value forever: measured,
  an infinite 2s sweep read `ViewTimeline, duration=2000, finished, value 0` and never
  moved, while the same rule stating `animation-timeline: auto` and
  `animation-range: normal` ran on the `DocumentTimeline` and swept 54.5 → 6.0 with the
  page held still. Now stated, and checked structurally — a rule with
  `animation-iteration-count: infinite`, a finite duration and no `animation-timeline`
  is either wrong or lucky.

- **Two elements reading one value on `view()` do not agree.** `view()` builds its
  timeline from each element's own box, so identical `animation-range` declarations
  buy identical *ranges*, not identical *progress* — a box higher in the card is
  further along. Measured on a gauge at one scroll position: needle `-31.38%`,
  figure `-13.64%`, an arrow pointing at 850 beside a figure showing 300 in the same
  frame. Nothing reports it, because every probe correctly says both elements have a
  live `ViewTimeline` on the range they asked for. `references/devices.md` now states
  the coupling rule — a shared value means a `view-timeline-name` on the nearest
  common ancestor — and separates the two counters: `data-motion-count` tweens on a
  clock and is right for a figure that counts up on arrival, wrong for a figure that
  reads out something else moving, which is animated as a custom property and read
  back through `counter()`. No shipped composition has the shape today; four on the
  build list do.

- **There are two ways to couple two readouts, and only one was written down.** A
  pair driven by scroll position couples with a `view-timeline-name` on the nearest
  common ancestor; a pair driven by a clock couples with identical timing longhands
  and one keyframe domain. The mistake is the same in both — declaring the same intent
  on two elements and assuming that makes them one animation. `devices.md` also now
  names the cost of the scroll version before you pick it: a scroll-scrubbed readout
  is motionless whenever the reader is, which is a still picture in every screenshot
  and on any page somebody is reading rather than scrolling.

- **The fingerprint gate compared fonts and not structure.** v2 reduced it to display
  family, text family and accent hue, reasoning that the composition library chooses
  structure per role so structure needed no fingerprint. A library with one good answer
  per role gives every build the same answer — which is exactly what structural
  fingerprinting catches. Two structurally identical sites passed the gate because
  their fonts differed. v3 restores the structural axes: seven dimensions, four of
  which must differ against every row individually, with the palette rule kept as an
  absolute on top.

- **`footer-columns` flattened the measured type scale on every page.** It used `<h2>`
  for three column labels at `0.8rem`, and a heading element is a role rather than a
  size: 12.8px entered the h2 role on every page of every craft build, so correctly
  proportioned sections elsewhere tripped `flat-type-hierarchy` because of a footer. The
  labels are `<p>` now, with `aria-label` carrying the accessible names. A structural
  check refuses any heading sized below `1.1rem`, and it caught one more on the way in:
  `icon-row__name` at 1.13x over its body text, since raised to 1.27x.

  `taste.md` gains the rules behind it — a heading element is a role not a size, a
  component heading clears 1.25x over body at the size it renders, and **cut inside the
  sentence, not at its pivot**: trimming at the pivot removes almost no information while
  converting a sentence into a manufactured aphorism, and three in a section is a cadence
  the detector names. The bold-lead-in list format produces them as a set.

- **A recorded client brief had no authority over the craft defaults, and the defaults
  won.** `/wp-context` writes the client's own direction into the project's
  `.claude/CLAUDE.md`; on one project that direction was explicit — *"an impactful
  animated website: hero entrance, scroll-reveal on section blocks, animated counters,
  animated step/timeline, before/after score chart animation, hover micro-interactions"* —
  and every item on it was later reported as missing by the person who asked for it.
  Nothing failed to capture the direction. `wp-demo-craft` overrode it, because nothing
  said it must not. The skill now opens by deferring: a recorded client decision binds
  over every default in it, and where a brief asks for something the floor discourages,
  the brief wins. Honest copy and a verified render remain the only exceptions.

- **The card rule produced the shape it exists to prevent.** *"A card is a lazy
  container"* read as a ban, and the alternative it recommends — proximity, a hairline,
  space — is undifferentiated text, so a faithful build wrote a hairline definition list
  for every section of every page. Reworded: the failure is *identical* cards, not cards.
  Likewise `icon`, which appeared in the entire skill exactly once, inside a prohibition,
  leaving authors to conclude icons are a slop signal while clients ask for animated ones
  by name. Decorative icons are the tell; an icon that carries meaning is not.

- **`taste.md` gains its first positive instruction.** It was entirely prohibition, which
  is why builds that obeyed every rule still shipped as walls of prose — nothing ever said
  reach for a graphic. *When a section states something quantitative, draw it.* A fact
  published about the sector is not an invented statistic; it is the subject.

- **Element keyframes wrote `transform`, which races the engine.** GSAP writes `transform`
  for `parallax`, `magnet` and cue rise, and `reveal` writes it on every child, so the
  entrance keyframes added in the previous commit would have collided on exactly the
  compositions carrying a root `reveal` -- last declaration wins, one motion silently gone.
  All seven use `translate`/`scale` now, which compose instead of replacing. Five further
  traps reported from a real build are documented beside it: a second rule inherits
  `animation-timeline` from the first; a guessed class name is a silent no-op; an
  accent-tinted hover glow is a slop finding; a modifier on the container root cannot match
  its own `@container` query; and `--motion-p` can drive any property inside a scrubbed
  section, which was demonstrated nowhere.

- **Interior pages had a ceiling and no floor, so a craft build shipped eleven of them
  uncomposed.** The rules said "Interior pages never pin", and nothing said what an
  interior page must *do*. Read alone, the prohibition became permission to do nothing: a
  real build planned nine compositions for `index.html` and none for the other eleven
  pages, which were written from one hand-rolled template — eyebrow, headline, rule,
  definition list. Their only composition blocks were `site-head`, `closing-block` and
  `footer-columns`: a header, a CTA and a footer.

  Every machine gate passed, because each gate asked a question the build answered
  correctly. The markup was valid, the tokens were right, the devices were wired. Nothing
  asked whether an interior page had been composed at all.

  Three changes close it. `references/compositions.md` states that "cheap roles"
  constrains *which* compositions an interior page uses, never *whether* it uses any, and
  that chrome does not count toward the floor. `references/devices.md` gains a motion
  floor beside its never-pin ceiling: at least one scroll-reactive device that is not
  `reveal`, because `reveal` fires once and the pointer devices need a cursor, so a page
  holding only those cannot respond to a scroll — 74 reveals and 19 pointer devices across
  eleven pages measured as motion and moved nothing. `/wp-demo` sub-step 5 now plans every
  page in the agreed set rather than the index alone, and sums the budget per page.

  Both reference files carry the substance because `/wp-yolo`'s craft path reads them and
  never opens `commands/wp-demo.md`.

- **`container-type` on an ancestor freezes every reveal beneath it, and nothing said so.**
  The composition library is container-query based, so adding `container-type: inline-size`
  higher up — to `body`, to a page wrapper — reads as the natural next step. It is not: it
  freezes `animation-timeline: view()`, so the timeline reports one constant progress at
  every scroll position and every CSS-path `reveal` lands on its end state without
  animating. A build that did it lost every reveal on all twelve pages and spent a full
  round on 58 `dead-scroll` findings before locating one declaration. Measured there:
  ViewTimeline `currentTime` pinned at `11.2849%` with it, tracking `-10.34% → 47.02%`
  without it. `compositions/README.md` now warns beside the container-query explanation,
  and `demo-verify` names the cause on every `dead-scroll` finding when it sees the
  declaration. The finding was always right; it could not say why.

- **Author CSS could lose to composition CSS silently.** Nothing stated where author
  overrides sit in the cascade, so a build that emitted them above the composition
  stylesheets had every equal-specificity rule ignored — fixes that looked applied,
  changed nothing, and were found by screenshot after a wasted round. Composition CSS is
  now emitted inside `@layer compositions`, and author CSS stays unlayered, which wins
  regardless of source order. A layer is a guarantee; an ordering rule is an etiquette
  that fails quietly.

- **The standard accessible honeypot failed `clipped-copy`.** `position: absolute;
  left: -9999px` and the `1px` sr-only clip both work by making a box far smaller than its
  text and hiding the overflow, which is exactly the signature the detector looks for. One
  honeypot field produced 72 blocking findings on a build whose accessibility was correct —
  a gate that fails correct code teaches authors to delete the correct code. Deliberately
  hidden copy is now exempt, and `clipped-copy` is deduplicated: one element clipped at
  every scroll position is one defect, not one per sample.

- **`hero-bleed` pressed its CTA against the bottom of a short fold.** `align-content: end`
  on a `100dvh` grid pins the copy block to the floor of the frame, so the CTA is the last
  thing above the edge by construction — at 390×844 the button rendered with its top few
  pixels visible and no label, failing the rubric's own "First paint complete" line with no
  author error. Copy is now centred by default and the bottom anchor is restored above
  `900px` of viewport height. A height query, not a width one: a short wide window fails
  identically and a width query would pass it.

- **`footer-columns` had no logo slot.** Its only brand slot was `{{wordmark}}`, typed in
  CSS as display text, so no build could put a client's real mark in the footer without
  styling an element the composition believes is type. Adds `{{logo_src}}`/`{{logo_alt}}`
  with their own rule, sized by height so a wide logo and a square one carry the same
  optical weight, and the wordmark stays as the fallback.

- **`pan` was recommended for sets it cannot move, by a remedy that hid the heading.**
  With three content-sized cards the rail cannot overflow a 1440 viewport at all, so the
  device travels zero and pins a motionless section. The fix the reference suggested — add
  the heading as the first rail item rather than widening cards — buys travel by panning
  the section's own label off the left edge, leaving it unlabelled for several hundred
  pixels of scroll; an independent evaluator flagged that unprompted on a build that
  followed the advice exactly. `pan` now states a five-item floor, and the
  heading-in-the-rail remedy is retracted.

- **Two thresholds an author could only find by trial are now written down.** The slop
  detector reads wide tracking on a short uppercase string as a signature, and the line
  sits between `0.08em` (passes, every round) and `0.16em` (eleven slop findings, one per
  page, gate failed) — `taste.md` now names it. And `--space-section` floored at `4.5rem`
  spends 14.4vh of a 390px page on padding across nine sections, over the scroll budget
  before anything has been said, which contradicts the rule in the line below it.

- **The `{{` ship check failed on the engine it inlines.** `motion.js` carries the literal
  `{{slot}}` in a source comment, so the obvious whole-file implementation of "no page may
  ship with a `{{` left in it" fails every time. The check now reads rendered markup.

- **A hand-built section had no path to a generated image.** `image-gen.mjs plan` builds
  `gaps[]` from `sections[] × slotsOf(composition)`, so a bespoke role — which the craft
  rules explicitly permit — could not receive a plate. The supported escape hatch, appending
  gap entries to `.image-plan.json` and calling `run`, is now documented rather than
  rediscovered.

- **Interior pages fell outside the step that produces composition plans.** `feel.md`
  defines "the curve" in the singular and every worked example is a home page, so sub-step 5
  produced an index-shaped plan by construction and interior pages were left with two
  prohibitions and the word "cheap". They now get their own short curve — three or four
  states, a smaller peak — which is what "take the cheap roles" was always meant to mean: a
  lower ceiling on the same structure, never an exemption from having one.

- **The research agent could not reach either MCP rung of its own source ladder.**
  `tools:` in agent frontmatter is an allowlist, not a hint, and `agents/wp-research.md`
  listed only built-ins — so `mcp__firecrawl` and `mcp__dataforseo` were unreachable to the
  subagent no matter how healthy the servers were. The ladder then did what it is designed to
  do, dropped a rung and reported "Firecrawl MCP was not reachable", which reads as a
  connection fault and is not one.

  Firecrawl survived on its `firecrawl_url` HTTP fallback, so that rung degraded rather than
  disappeared. **DataForSEO has no fallback** — it is MCP or nothing — so the top rung was
  dead in every run since the feature shipped, and a research pass that should have produced
  real local competitor listings by category and location silently produced none.

  Both servers are now granted with `mcp__<server>` patterns, and
  `tests/checks/wp-research.sh` pins each grant. The check that existed asserted the ladder's
  *wording*, which was correct throughout; nothing asserted that the agent could reach the
  rungs the wording described. The grant assumes the conventional server ids; a server
  registered under a different id is not matched and degrades to the rung below, which is the
  intended behaviour when a server is genuinely absent.

- **`/wp-robin` reported every attachment as missing from disk while every file was
  there.** Step 4 carries the attachment metadata base64-encoded so it cannot drag a tab
  or a newline into the tab-separated read, but `TO_BASE64()` wraps its own output every
  76 characters. In batch mode the client escapes those newlines to a literal
  backslash-n, and `base64_decode()` drops the backslash and keeps the `n` — a valid
  base64 character — so every row decoded to garbage, `unserialize()` failed, the file
  name came back empty and the step skipped the attachment as missing. Nothing was
  queued and the run still ended with a clean "0 remaining", which is exactly the false
  "nothing left to do" this script exists to undo. The wrap is now stripped server-side
  with `REPLACE(TO_BASE64(...), CHAR(10), '')`. `DECODE_META` first removes literal
  backslash-n sequences and then drops non-base64 characters before decoding, so a client
  that escapes newlines differently cannot reintroduce them.

  The explanation lives in a shell comment above the query rather than inside it: a `--`
  comment in a `-e` batch query takes the rest of the line with it, which silently
  emptied the result set a second time.

- **`/wp-robin` re-encoded a library that was already WebP.** Steps 4, 5 and 6 matched
  attachments against a hardcoded mime list that included `image/webp`, while the
  `allowed_formats` setting the same script writes one step earlier does not. On a site
  whose media library is already WebP, every original and every thumbnail was therefore
  converted again into `<name>.webp.webp` — a second lossy pass over an already-lossy
  source, which `webp_delivery_mode=picture` then serves in place of the original. The
  candidate list is now derived from `allowed_formats`, with `image/jpg` riding along
  with `image/jpeg` for installs that store it, and falls back to the built-in list only
  when the setting has been emptied by hand, so an emptied setting cannot silently widen
  the query to every attachment on the site.

- **A reset rule is converted declaration by declaration, not as a whole.**
  `agents/wp-tailwind.md` now requires each declaration in a reset to be either matched
  to the preflight rule that already sets it or carried across, and names what preflight
  does not restore: `cursor`, `text-transform`, `letter-spacing`, `white-space`,
  `word-break`, `:focus-visible` outline, `list-style` position, `scroll-behavior`, and
  anything in a `font` shorthand past family and size. Survivors go in `@layer base`, not
  in unlayered CSS that would outrank every utility.

- **Two more conversion traps, both found by the new gate on a real demo.** `text-*`
  carries a line-height, so a demo declaring `font:600 14px/20px` and overriding only
  `font-size:16px` renders at 20px and converts to 24px — a translated font-size must be
  paired with the demo's own `leading-*`. And two overlapping `max-*` variants do not
  resolve in source order: a rule that is `nowrap` between 430px and 768px converts
  literally to `max-md:whitespace-nowrap max-[429px]:whitespace-normal`, which is
  textually faithful and renders `nowrap` at 390px; a band has to be written as a band.

- **A repeated block's per-item variation is data, and a list's order and count come
  from the demo.** `agents/wp-template.md` bound the element tree to the demo but said
  nothing about what varies BETWEEN items of a grid, so six practice cards that mixed
  three SVG icons with three font glyphs at three different sizes — three of them also
  carrying a second, longer heading for phones — were normalised to one icon type at one
  size with one heading. The markup looked right and every card was wrong. The same
  section let `get_terms()` sort by name: with a limit of six over seven terms, the
  default ordering was not rearranging the cards, it was choosing which term never
  reached the front page.

- **The `tailwind` transcription path had a licence the `basic` path never had, and every
  section built through it drifted.** `/wp-section`'s overlay called the converted demo "a
  geometry reference, **not** a source of verbatim declarations" and told the agents to
  "reproduce this geometry using Tailwind utilities", never to "copy the declared values
  verbatim". That sentence is true about the notation — the conversion leaves no raw
  declarations behind, only utility classes — and false about the mandate, and it was read
  as the second thing: an agent that may reproduce geometry may also substitute a utility
  it judges equivalent. On `basic` the same overlay says the demo CSS is the SOURCE OF
  TRUTH and its declared values are copied exactly, so only one of the two paths was ever
  bound to the demo.

  The converted demo is now the source of truth on both paths, with the tailwind notation
  spelled out: its utility classes ARE its declared values, carried across character for
  character, element structure included. `gap-[9px]` is not `gap-2`, `max-[1024px]:` is not
  `max-lg:`, and two siblings that swap at a breakpoint stay two elements.

- **`agents/wp-tailwind.md` shipped Section Authoring Mode with no fidelity mandate at
  all.** `agents/wp-css.md` carries one — "the demo is the SOURCE OF TRUTH, not
  inspiration. Your job is to COPY, not re-author" — and that agent runs only on `basic`,
  so every project on the `tailwind` template was authored by an agent that was never told
  to copy. It now carries the same mandate, including that promotion to `@apply` is a move
  and never a rewrite.

- **`agents/wp-template.md` bound only CPT teasers to the demo's markup.** It owns the
  element tree for every section on both templates, and nothing outside the teaser rule
  told it to preserve one, so a wrapper judged redundant or two siblings merged into one
  passed every gate — the defect renders correctly at the breakpoint being looked at. It
  now requires the demo's elements, class attributes and breakpoint variants to survive
  intact, and one ACF field per distinct string rather than one field and a shortened copy.

### Chore

- `.codebase-memory/` is ignored. It is a per-machine index, like `.serena/` beside it,
  and showed up as untracked in a clean checkout.

## [1.17.0] - 2026-09-13

### Added

- **`/wp-audit` reconciles the manifest before it trusts it, and reports what has never
  run.** `.wp-create.json` is called the shared source of truth, and nothing ever checked it
  against the site: a project could claim Yoast while running Rank Math, nginx while running
  LiteSpeed, and PHP 8.4 while running 8.5, and every downstream branch took the manifest's
  word. The new Step 2.5 measures instead — active plugins, PHP version, web server (an
  `.htaccess` carrying `BEGIN LSCACHE` outvotes the manifest), and Tier 3 availability,
  re-probed every run rather than read from a capability recorded once months ago. Drift is
  reported line by line, naming both values.

  `audit.categories_run` was written and never read, so no project could discover that a
  category which shipped after it was built had never run on it — the audit record kept
  looking complete while a whole category sat unexecuted. It is now cumulative, read back,
  and diffed against the categories this version offers; a never-run category is a blocking
  warning at the top of the report. A record older than 90 days is flagged stale, and
  `issues_found - issues_fixed` is re-opened rather than quietly forgotten.

  A missing recorded decision is reported as an unknown, with evidence, instead of being
  defaulted. `i18n strategy` absent means `suffix` — but on a site running Polylang that
  fallback is wrong, and every command that branches on the line took the wrong branch
  silently. The manifest now carries `manifest_version`, so a project that predates a key
  is distinguishable from one where the key is legitimately empty.

- **A development host is no longer indistinguishable from an unscanned site.**
  `bin/geo-scan.sh` detects a non-public host itself — `localhost`, `.local`, `.test`,
  RFC 1918 ranges, any name without a dot — and exits `3` with a message naming the fix,
  where it used to let the request go out and return a `404` that read as "nobody has
  scanned this yet". Exit `2` now means only that: no report exists, or no network.
  `/wp-audit --host <public-url>` supplies the public address for a project whose manifest
  holds the one it develops against, which is every project built before the live scan
  existed. Neither exit is a pass, and `/wp-yolo` treats both as incomplete.

- **`UNMEASURED` is now a status of its own, separate from `N/A`.** They were one, and
  merging them hid "this check applies and nothing ever ran it" behind "this does not apply
  to this site" — a reader counting failures could not tell them apart, and only one of them
  needs action. `UNMEASURED` is never folded into the passing total.

- **Six checks for defects that were invisible to every tier.** `GEO-A26` catches a physical
  file at the web root shadowing the theme's rewrite for the same path — the web server
  answers it before PHP runs, so the theme's endpoint is correct, tested, and never served.
  `GEO-A27` follows the redirect chain on the advertised `/.well-known/*.json` paths, because
  a CDN that normalises them to a trailing slash leaves the canonical path answering only
  through a `301` that many agent fetchers do not follow. `GEO-A28` checks that the URLs
  advertised inside `llms.txt`, the ARD catalog and the agent-skills index resolve and agree
  with the sitemap — existence is not agreement, and the three surfaces went stale
  independently of the content. `SEC-036` searches the options table for the development host
  (exempting `home` and `siteurl`, which are meant to hold it) because a sync writes those
  values verbatim into production. `SEC-037` finds backup and editor files inside the theme
  directory, which ship with any push of `wp-content/`. `SEO-053` reports two of the site's
  own URLs competing for one intent, the usual pair being a thin term archive against the
  real article.

- **`WP-046` catches the unquoted `ABSPATH` constant, which `WP-016` could not.** The old
  detection pattern, `defined.*ABSPATH`, matched `defined( ABSPATH )` as happily as
  `defined( 'ABSPATH' )` — and the unquoted form is a PHP 8 **fatal** that stops the render
  partway, so the page shows its header and then nothing. `php -l` passes it, because it is a
  runtime error rather than a syntax error. `WP-016` now requires the quoted form and
  `WP-046` hunts the broken one, with a render probe rather than a lint. `WP-047` reports
  class names a template part emits that no stylesheet defines — a section that ships
  completely unstyled while every check passes.

- **The site-name signal is checked, and written from one source.** Nothing in the plugin
  read `og:site_name` — the signal that decides whether an engine prints the brand or the
  bare domain — and `SEO-025` asserted only that `knowledgegraph_type` was *set*, so a site
  whose `<title>` said one brand and whose Rank Math options said another passed every
  check. Two codes close it. `SEO-051` requires `og:site_name` on the rendered head;
  `SEO-052` compares it against the `<title>` brand segment, the schema `WebSite.name`,
  `get_bloginfo('name')`, `website_name` and `knowledgegraph_name`, and treats a
  `website_alternate_name` identical to the name as a finding — an alternate that repeats
  the name tells an engine nothing while occupying the slot a real one would use. Both read
  the head snapshot the SEO auditor already takes, so they cost no extra request. The
  configurator side is the root fix: `wp-audit-rankmath` now writes `website_name` as well
  as `knowledgegraph_name`, both from `get_bloginfo('name')`, and drops an alternate name
  that merely repeats it. Leaving `website_name` unset was what let the two drift apart.

- **`GEO-A25` resolves schema `@id` references instead of counting blocks.** `GEO-A07`
  counts identity JSON-LD, so a graph whose `WebSite.publisher` points at an `@id` that no
  node declares looks complete to it — while a generative engine, unable to resolve the
  entity, falls back to the bare domain. The new code decodes every JSON-LD block, collects
  the `@id` values the graph declares and the ones it references at any depth, and reports
  every dangling reference as an ERROR, naming the referencing node and the ids that do
  exist. The usual cause is a `rank_math/json_ld` filter that renames a node after Rank Math
  has already built the references to it.

  `GEO-A25` carries **no ORA check id**: the published catalog has no check that resolves a
  reference, so the code is reported outside the ORA score and marked plugin-added, keeping
  the score reproducible against the public catalog.

- **`/wp-audit` gains a GEO / AI-agent-readiness category behind `--geo`.** The new
  `wp-audit-geo` auditor scores a site against the four ORA layers — Discovery, Access,
  Usability, Payments — and maps the ORA check catalog to GEO codes. Site type is detected,
  not assumed (content, local business, merchant or SaaS), and every check the detected type
  does not apply to is reported `N/A` rather than failed. The fixable half is handed to the
  new `wp-agentic-surfaces` agent, which owns `inc/agentic.php` and emits the generated
  surfaces — `llms.txt`, the ARD catalog, the agent-skills index, markdown negotiation, Link
  headers, an agent-friendly 404, JSON-LD breadth — and seeds the trust anchors. The auditor
  parses the rendered head with `DOMDocument`, never a regex, because attribute order and
  quoting are not fixed and a regex reads a broken page as clean. The reference — check
  catalog, applicability matrix, AI crawler allowlist and surface specs — is the new
  `wp-audit-geo-standards` skill. The live score is fetched by the new `bin/geo-scan.sh`,
  which calls the public is-agentic report for the site's host (falling back to `ax score`)
  and prints the JSON the auditor maps back to GEO codes; exit `2` is a clean skip — no
  network, no `npx`, or no reachable public URL — and the run reports the live score as
  unavailable instead of failing. `/wp-yolo` runs `/wp-audit --all --geo` and the same scan as
  mandatory finish-phase steps, and a run whose scan did not succeed cannot print "Build
  Complete".

  Three ceilings are recorded. Off-site checks — Wikipedia/Wikidata presence, registry
  listings, agentic share of voice, brand search accuracy — are advisory: no theme file can
  change a third party's listing, so they are reported with a recommendation and left
  unfixed. The payments codes (ACP, UCP, MPP, x402, AP2) are merchant-only and advisory,
  detected but never fixed. The live scan needs a public URL: a host it cannot reach publicly exits `3`
  (a configuration problem, fixable with `--host`) and a reachable host with no report yet
  exits `2`. Neither is a pass.

- **README and `docs/commands.md` now document how to supply the image-generation key.**
  Which variable per provider (`GEMINI_API_KEY` / `OPENAI_API_KEY`), the three places to
  set it — an `env` block in the gitignored `.claude/settings.local.json`, an `export`
  before starting Claude Code, or a shell profile — and the two things that look like they
  should work and do not: exporting inside a running session (each command gets a fresh
  shell) and putting the key in `.wp-create.json`, which records only which provider was
  chosen. The prose added in this release told the agent what to do with a key; nothing
  told a human how to provide one.

- `/wp-demo` Step 5.5 fills a composition's image slots from a client file or a
  generated plate, via the new `bin/image-gen.mjs`. Provider-agnostic across
  `google/gemini-3.1-flash-image` (nano banana) and `gpt-image-2.5-flare` /
  `gpt-image-2.5-sunburst`. The provider decision is asked once, when a key is
  present and plates are needed, and recorded as `"image provider"` in
  `.wp-create.json` — `"<vendor>/<model>"` on a yes, `"none"` on a decline — so
  a later run never re-asks. The aspect and size of every request are read off
  the composition's own `<img>` tag, so a plate arrives at the crop the CSS
  displays. Plates are content-hashed on prompt, aspect and model, so a re-run
  or a verify round never re-bills, and an edited prompt always regenerates
  instead of serving the stale image. The API key is read from
  `GEMINI_API_KEY` / `OPENAI_API_KEY` in-process only — never a CLI argument,
  never written to a file, never logged — and a missing key stops the build
  naming the variable rather than falling back to a placeholder. `/wp-yolo`
  never generates; it consumes plates already on disk.

- `/wp-demo` Step 2.4 researches the client's business and competitors before
  the demo mode is chosen, via the new `wp-research` agent and skill. Writes
  `demo/RESEARCH.md` and the `"research"` key in `.wp-create.json`.
- Six build steps now cite `demo/RESEARCH.md`: `designlang`'s target, the
  brief's person/pain/promise, the domain-classification corpus, the composition
  table's research-signal column, the image prompts' vocabulary, and plain-mode
  copy.
- `/wp-yolo` researches the client unattended, recording the identity as
  `unconfirmed` rather than asking, and Step 6's report surfaces that
  unconfirmed identity to the operator — the only channel an unattended run
  has to a human.
- Optional Firecrawl (MCP or `firecrawl_url`) and DataForSEO (MCP) tiers improve
  extraction and local competitor discovery. No API key is ever requested.

### Changed

- **`SEO-023` names the pages and covers posts.** It reported `18/24 pages have meta
  descriptions` — a count the reader had to re-derive to act on — and its query filtered
  `post_type='page'`, so a money page published as a post was never examined at all. It now
  lists every published post and page without a description, with its URL and title. Where a
  description is missing Google writes the snippet itself, and on a non-Spanish crawl of a
  Spanish page it will often write it in English.

### Fixed

- **A script registered without `in_footer` slipped past PERF-010.** The check grepped
  `wp_enqueue_script` only, so a theme that re-registered a core handle — the usual way a
  bundled jQuery replaces the WordPress copy — kept loading it in `<head>` and blocking the
  first render with no finding raised. The rule now covers `wp_register_script` and the 5th
  positional argument as well as the array form, and flags a handle only when NEITHER call sets
  the group — either one can, so checking a single call gives false positives in both directions.
- **Nothing weighed a theme's own image assets.** PERF-001 caps the CSS bundle and PERF-018
  looks for `srcset`, but a decorative export sitting in `assets/` was never measured. Design
  tools export at 2x the CSS slot, which is right for photographs and wasteful for flat art —
  a gradient panel, a glass card, a solid shape — where the extra pixels are interpolated back
  away. New **PERF-053** flags any theme image over 100KB, and any over 40KB whose standard
  deviation is under 0.12, with the downscale-and-compare procedure in Step 2.
- **The responsive walk sampled 1024 and 1440 and nothing in between.** A layout is free to be
  wrong across that whole range: `lg:` utilities apply from 1024 with no `xl:` override until
  1280, so a row that reads correctly at both sampled widths can be broken for 256px nobody
  looked at. The five legacy widths sample breakpoint EDGES only, and an edge is where the rules
  change, not where they do damage. `/wp-demo-verify` now also shoots 1152, which sits inside that
  band, and 1280, the first width where `xl:` applies; the responsive skill states that a
  breakpoint is a range to be checked through, not a line to be checked at.
- `/wp-seed` could not import a demo-relative image path. Phase 2 collected
  `img[src]` as "URLs" and Phase 3's example was remote, so a local
  `assets/img/...` source failed on every import. Sources are now resolved
  against the demo folder, and a failed import of a generated plate is reported
  on its own line rather than folded in with a remote URL that 403'd.
- **Three of the six `demo/RESEARCH.md` consumers never reached `/wp-yolo`'s
  craft path.** `/wp-yolo` builds a craft demo from `skills/wp-demo-craft/SKILL.md`
  and its `references/`, never through `/wp-demo` — so the `designlang` target,
  the `demo/BRIEF.md` citation option, and the composition table's
  research-signal column were wired only into `commands/wp-demo.md` and
  silently absent on the entry point a one-shot build actually uses.
  `references/design-md.md`, `SKILL.md` and `references/compositions.md` now
  state the same three rules, in the same terms `commands/wp-demo.md` uses.
- **The composition row format disagreed across three files.** `commands/wp-demo.md`
  named seven columns while `SKILL.md` and `references/compositions.md` still
  named six, so a build following either reference wrote a plan with no
  research-signal row. All three now state the same seven columns, and
  `tests/checks/wp-research.sh` pins the research-signal column in each of the
  three independently.
- Two pins in `tests/checks/wp-research.sh` could not fail on their own: the
  dispatch pin against `commands/wp-demo.md` matched an unrelated skill-path
  substring, and the `firecrawl` tier pin could not fail independently of the
  `firecrawl_url` pin beside it. Both now pin exact, unique phrasing, and a
  new pin catches the three-answer confirmation table drifting between
  `agents/wp-research.md` and `commands/wp-demo.md`.
- The English-only fallback sentence in `commands/wp-demo.md` and
  `commands/wp-yolo.md` still said "a docs set with no English-language
  material", left over from before the domain-classification corpus widened to
  include `demo/RESEARCH.md`. Both now say "a corpus", matching the wording
  used one clause above it.

## [1.16.0] - 2026-09-11

### Fixed

- **The `@property --container-max` guard stopped at the demo; the delivered
  theme reproduced the bug it closed.** `/wp-section` copies thirteen
  `padding-inline: max(var(--space-gutter), calc((100% - var(--container-max,
  1280px)) / 2))` rules into the theme, but `/wp-init` Step D4 wrote neither the
  token nor its registration into the Tailwind `@theme` block, so a malformed
  value there unset `padding-inline` to `0` at every viewport in the artifact the
  client actually receives. Step D4 now writes `--container-max` from
  `demo/DESIGN.md`'s `spacing.container` and emits the same `@property` rule at
  the top level of `main.css`. Measured at a 1920 viewport on that exact gutter
  rule: `1440px` → 232px either way, `wide` → 312px with the rule and 0px
  without, empty → 312px with and 0px without.
- **`/wp-demo` Step 6 told the build to emit the `@property` rule "in the same
  `<style>`", inside a step that writes one file per page.** A builder could
  satisfy that on `index.html` alone and leave every interior page with the
  unguarded token. The instruction now says every page this step writes, and the
  suite pins the wording.
- **Three records had the `overflow-y` rationale backwards.** The composition
  comment, the check beside it and the CHANGELOG all said the implicit `auto`
  would "silently clip". `auto` scrolls — it would add a second, vertical
  scrollbar to a horizontal scroller; `hidden`, the value actually chosen, is the
  one that clips, and clipping is what is wanted there. All three now say what
  each value does.
- **Both composition unit gates pinned one spelling and let the whole family
  past.** The `vw` justification loop fed on a literal `[0-9.]vw`, so a `6dvw`
  or `6vmin` ramp dropped into a composition with no comment passed (rc=0,
  sha-verified), and `svw`/`lvw`/`vi`/`vmax` are the same shape — all of them
  the viewport-relative sizing the conversion removed, and `dvw` the spelling a
  mobile-aware author reaches for first. The self-container loop matched
  `[0-9.]cqi` only, so a `6cqw` inside the rule declaring `container-type` also
  passed, reintroducing the identical resolve-against-the-viewport defect with
  a unit the library already uses elsewhere. Both patterns now cover their
  families — `(d|s|l)?(vw|vi|vmin|vmax)` and `cq(i|b|w|h|min|max)`, each with a
  trailing class so a unit cannot match inside a longer identifier. Viewport
  *height* is deliberately excluded and the check says why: `container-type:
  inline-size` offers no block-axis container unit to convert to.
- **`demo-verify` failed a round on correct CSS whenever a container query was
  scoped to a breakpoint.** `containerAudit()` decides whether an `@container`
  rule can ever match by reading `container-type` off the subject's ancestors,
  and it was sampled once per page at the first width. That was harmless while
  the audit only saw top-level `@container` rules; once it also collected the
  ones nested in `@media` — which is exactly where breakpoint-scoped
  `container-type` lives — liveness became width-dependent. Measured on the new
  `tests/fixtures/container-audit/index.html`: the single-width audit reported
  `.bp-max__child`, whose container is declared inside `@media (max-width:
  700px)` and is live at 390, as dead from its 1440 sample. `container-noop` is
  blocking, so a demo written the ordinary way failed all three rounds and
  `/wp-demo` wrote `demo/FAILED.md`, which `/wp-init`, `/wp-section` and
  `/wp-yolo` then refuse to build on. The audit now runs at every width walked
  and reports only the selectors dead at all of them; `external-module`, which
  genuinely is width-independent, stays a once-per-page read. The fixture
  carries both halves — two breakpoint-scoped pairs that must not be reported
  and one genuinely dead rule that must be — and `tests/checks/wp-demo-verify.sh`
  runs the real script over it and requires exactly `.dead__child`, so a fix
  that reports nothing fails it too.
- **`process-rail` shipped a dead tab stop and a phantom landmark on every craft
  build at default motion.** The `tabindex="0" role="region" aria-label="{{title}}"`
  added with the reduced-motion scroll fix was unconditional, but the scroll
  region only exists under `prefers-reduced-motion`: at default motion the frame
  is `overflow-x: hidden` and pinned, so Tab landed on a box that could not be
  scrolled and every AT landmark list gained a region named after the `<h2>`
  sitting inside it. The markup carries no a11y attributes now; `motion.js`
  creates the affordance in the pan device's reduced-motion branch, on whichever
  box actually scrolls (with the engine running that is the rail, whose own
  `overflow-x: auto` makes it the scroll container; with the stylesheet alone it
  is the frame), and names it with `aria-labelledby` pointing at the section's
  own heading — so no unsubstituted `{{slot}}` and no hand-written, one-language
  label can reach a screen reader. Measured in both modes on the real
  composition with `motion.js` running: reduce → Tab lands on the rail,
  `role=region`, name taken from the heading, ArrowRight moves `scrollLeft`
  0 → 40; default → no `tabindex`, no `role`, no name, Tab skips the section.
  `tests/checks/wp-craft-compositions.sh` asserts the markup is clean, that the
  three lines live inside the pan device's reduced branch (extracted by its own
  brace range, comments stripped), and that every `{{slot}}` used as an
  accessible name anywhere in the library has a value in `fills.json`.
- **`process-rail`'s reduced-motion rail overflowed the whole document instead
  of scrolling inside its own frame.** Under `prefers-reduced-motion` the
  section's own comment calls the rail "a native scroll region", but nothing
  made it one: the frame was `overflow: visible` with no `overflow-x`
  anywhere, so the row overflowed `documentElement` itself — measured
  `scrollWidth` 2496 at a 1920 viewport, i.e. a horizontally scrolling page.
  `.process-rail__frame` now carries `overflow-x: auto` inside that media
  query, placed after the `overflow: visible` shorthand (which resets both
  axes and would otherwise win by source order and silently undo the fix).
  Measured before/after with a headless-Chrome probe with
  `prefers-reduced-motion: reduce` forced, at four viewports:
  `documentElement.scrollWidth` 1587 → 390, 1981 → 768, 2074 → 1280 and
  2496 → 1920, with the frame itself still scrollable at each
  (`scrollWidth` > `clientWidth`). `overflow-y: hidden` is then stated
  explicitly, because CSS corrects a `visible` axis to `auto` when the other
  axis is not visible — left implicit it computed to `auto`, which would give
  anything that later grew vertically out of the frame a second, vertical
  scrollbar on a horizontal scroller. `hidden` clips that overflow instead,
  which is the intended behaviour here and the reason the value is stated at
  all. And the scroll region takes `tabindex="0"` with `role="region"`, added
  by `motion.js` under reduced motion rather than written into the markup: a
  scroll container no keyboard can reach is a different bug, not a fix, and
  before this change the overflowing row at least scrolled with the page.
  Verified with real key events — without the affordance, ArrowRight left
  `scrollLeft` at 0; with it, `scrollLeft` moved 0 → 80 at both 390 and 1920.
  `tests/checks/wp-craft-compositions.sh` asserts
  `overflow-x: auto` on the `__frame` rule specifically inside the
  reduced-motion block, and after the `overflow: visible` shorthand, not
  merely present anywhere in the file.
- **A composition's fluid ramps ignored the container its breakpoints already
  respected.** `@container` sizing (Task 3) covered layout, but the `vw` inside
  `clamp()` gaps, padding and type scales still keyed off the viewport, so a
  section dropped into a narrow column laid out for the column and then took
  desktop-maximum spacing anyway — 40 occurrences across 12 of the 13
  compositions. 37 now read `cqi`, tracking the block's own inline size. The
  remaining 3 stay `vw`, each with a comment recording why. Two are the display
  headline of a full-bleed hero (`hero-bleed`, `hero-type`),
  sized against the viewport on purpose: a hero in a narrow column is not a
  scenario those compositions serve. `hero-split` was counted a third until its
  justification was checked against the composition it defends: that title sits
  in a `1.1fr 0.9fr` split column, not the bleed. Its nearest container is the
  section root, so `6cqi` measured identical at full bleed (86.4px at 1440,
  76.8px at 1280, 38.4px at 390, same box and position) and 38.4px rather than
  86.4px in a 420px column — it converted. The third is `feature-zigzag`'s root `gap`,
  which *cannot* be `cqi` — that rule is the element declaring `container-type`,
  and an element never matches a container query against the container it
  establishes itself, so `cqi` there would resolve against the viewport while
  reading as if it tracked the block. `tests/checks/wp-craft-compositions.sh`
  asserts every remaining `vw` carries that justification on its own line or the
  line directly above it, so one justified ramp can no longer green-light every
  other `vw` left in the same file.
- **A present but malformed `--container-max` (`wide`, an empty string) unset
  `padding-inline` to `0` at every viewport, phones included.** `var(--container-max,
  1280px)` only ever guarded an *absent* token — `var()` still substitutes a
  malformed one, which makes `calc()` invalid at computed-value time. A craft build
  now emits `@property --container-max { syntax: "<length>"; inherits: true;
  initial-value: 1280px; }` alongside `:root` in `commands/wp-demo.md`'s generated
  demo and in `bin/composition-preview.mjs`'s preview harness, so an invalid value
  falls back to `initial-value` instead of unsetting. Measured before/after with a
  headless-Chrome probe: `1440px` → 240px (unchanged), `wide` → 320px (was 0px),
  empty → 320px (was 0px). Where `@property` is unsupported, the `1280px` `var()`
  fallback remains the only guard, and it still covers only the absent case.
- **`unobserved` could not fire, so a section that only the harness could not read
  was reported as a section that does not move.** `demo-verify.mjs`'s `probe()`
  counted `samplable` over a document-wide `querySelectorAll('[data-motion]')`, so
  `samplable === 0` required *every* device on the page to be unreadable — the kind
  could only fire where `no-engine` already did, and a single live `reveal` child
  anywhere closed the door for the whole document. A section carrying only pointer
  devices (`tilt`, `magnet`, `spotlight` publish nothing a scroll walk can sample)
  was therefore judged by whether some *other* section happened to be readable, and
  fell to `dead-scroll`, which blocks: a blocking finding on a working section.
  `probe()` now takes the section index `bounds` already carries and walks
  `[data-motion]` inside that subtree only, root included. A section's frame
  signature is its own as a result, instead of being perturbed by every other
  section on the page. The cue sweep, the canvas sample, `clipped` and `overflow`
  stay page-level facts and keep querying `document`.
- **A plain `<section>` on a moving page is not a dead engine.** `bounds` walks
  `section, [data-motion]`, so scoping the device count alone would have made
  `no-engine` — a blocking finding — fire on every ordinary static section, which is
  the false positive the whole gate exists to avoid. `probe()` returns a separate
  document-wide `pageDevices` count and `no-engine` keeps testing that, so it still
  means "this demo carries no motion at all". A section with no device of its own on
  a page that does move is now reported as nothing at all, not even advisory.
- **The two verification contracts said both counters were page-wide.** That is now
  true only of `no-engine`. `skills/wp-demo-craft/references/verify.md` and
  `commands/wp-demo-verify.md` record `unobserved` as a per-section judgment, name
  the pointer devices that produce it, and state that a device-free section is not a
  defect.
- **`containerAudit()` never saw an `@container` rule nested inside `@media`,
  `@supports` or `@layer`.** The lint walked only each stylesheet's top-level
  `cssRules`, so a rule nested even one level down was silently unlinted — the
  exact failure class `container-noop` exists to catch, and `proof-row`'s own CSS
  already nests `@media` inside `@supports`. The sheet loop now recurses into
  `CSSMediaRule`, `CSSSupportsRule` and `CSSLayerBlockRule` bodies and collects
  every `@container` rule found at any depth, keeping the existing all-matches
  (`querySelectorAll`) and `parentElement`-rooted ancestor walk unchanged.
  `skills/wp-demo-craft/references/verify.md` and `CLAUDE.md` no longer record
  the top-level-only scope as a known limit.

- **A full-site build paid three times over for work the flow then discarded.** Measured
  on a real twelve-page bilingual Tailwind build: roughly 1.9M subagent tokens before a
  single template part existed, ~90% of it spent reading and rewriting demo HTML. Three
  causes, all contract holes rather than model error.

  `wp-normalize` captured verbatim `section.cssRules` for every section on **both**
  template paths, which costs a full read of every stylesheet and a full write of every
  matched rule. On the `tailwind` path `/wp-yolo` Step 2.6 converts each demo page and
  then forbids the section walk from reading that field at all — so the capture produced
  something the flow is contractually required to ignore. It is now skipped on that path
  and written as `null`, with a `review[]` entry so the null is not read as a failed scan.
  `backgrounds`, `fonts` and `computed` are still captured on both paths: the font carry
  and the demo-parity gate read them regardless, and `fonts` cannot be recovered from
  converted markup at all, because conversion strips the `@font-face` rules it absorbed.

  Step 2.6 converted **every copy** of a repeated card. A demo pads a list with mock
  repetition — sixteen profile cards cut from four records, eighteen board members from
  three, twelve branch cards from two — and those pages were the most expensive
  conversions in the run while collapsing hardest in the theme, where all N become one
  template part inside a loop. `wp-normalize` now records `section.repetition` as an array with
  one entry per repeated list (`selector`, `count`, `distinct`, `exemplar`, `variants`;
  the exemplar is never one of the variants) and Step 2.6 converts the
  exemplar plus any real variants, applying the exemplar's `class` attributes to its
  siblings position-for-position and leaving each sibling's own text, `href`, `src`, `alt`
  and `data-*` untouched. Lists whose children genuinely differ are not collapsed.

  `wp-acf` and `wp-template` each ship a "WP-CLI Integration" section instructing the
  agent to run `$WP …`, while their frontmatter granted `Read, Write, Edit, Grep, Glob`
  and no `Bash`. Both reported verification they had no way to perform, and the
  orchestrator had to re-run it. Both now grant `Bash`; the check also refuses the reverse
  drift — an agent gaining `Bash` by copy-paste with no shell step in its instructions.

  New check: `tests/checks/wp-yolo-transcription-cost.sh`.

- **The `@apply` promotion ran once per section, so it depended on dispatch order.** The
  `wp-tailwind-system` ladder promotes a utility group seen "3+ times, or on 2+ distinct
  pages" — a judgment about the whole theme. On the `tailwind` path `/wp-section` dispatches
  `wp-tailwind` in author mode after `wp-template` returns, per section, and tells it to grep
  what earlier sections already wrote. The first section therefore runs with nothing to grep
  and ships raw utilities; when a later sighting finally crosses the threshold, the template
  parts already written that carry the same group are never revisited. The group ends up a
  semantic class in the sections built late and raw utilities in the ones built early, so the
  `@apply` file exists without covering the repetition it was created for. On top of that it
  is one serialized agent per section, each re-reading a template part `wp-template` has just
  written and each appending to the same `main.css`.

  `/wp-section` gains `--defer-promotion` (tailwind only — on `basic` it would ship an
  unstyled section, since `wp-css` writes the section's only stylesheet). `/wp-yolo` sets it
  on every section-walk dispatch and runs the promotion once in a new Step 4.4, over every
  template part the walk produced, counting distinct pages rather than files and touching
  class names only. Hand-invoked `/wp-section` is unchanged: a section added to a finished
  theme has the whole theme to grep and nothing to aggregate.

- **The viewport-height gate judges every declaration on a line, not the first.**
  A rule written on one line carries several, and judging only the first let a
  block-axis declaration shield an inline one behind it: `.x { height: 100vh;
  width: 50vh }` exempted the `width` because the `height` came first. Measured:
  the same `width: 50vh` alone failed and behind a `height` passed.
- **The self-container check parses declaration blocks, not lines.** Line-based
  brace tracking made the verdict depend on formatting — `@supports (display:
  grid) { .a { container-type: inline-size; } .b { gap: 1cqi; } }` on one line was
  flagged while the byte-identical CSS across four lines passed. Two separate
  rules are not one rule whatever the whitespace. It now matches innermost
  `{...}` blocks, which are exactly declaration blocks, so at-rule wrappers are
  ignored without having to understand at-rules.
- **The reduced-motion rail affordance is attached only when a box actually
  overflows.** Below `process-rail`'s own documented three-step minimum neither
  the rail nor the frame scrolls, and attaching `tabindex`/`role="region"`
  anyway shipped a focusable, named region that scrolls nothing — the same dead
  tab stop the affordance was written to remove, reached by a different route.
  Measured: a short rail selects `container` unguarded (which scrolls nothing)
  and nothing at all guarded.
- **The viewport-height units are gated by AXIS, not by spelling.** Excluding
  `vh`/`dvh`/`svh`/`lvh`/`vb` outright is correct for block-axis declarations —
  a pinned frame is one screen tall by definition and `container-type:
  inline-size` gives it nothing to convert to — but it also let a height unit be
  smuggled into an inline ramp, where it is as viewport-relative as `vw` and as
  convertible. A height unit on a width, gap, font-size or inline padding now
  has to justify itself like any other. Unit detection runs over a copy with
  comment bodies blanked and line numbers preserved, so a unit merely *named* in
  prose is not mistaken for a declaration.

### Changed

- **All 26 composition previews re-rendered against the changed CSS.** Nine moved,
  all of them at 1440 and none at 390, and the split is arithmetic rather than luck.
  A container query length resolves against the query container's *content* box, so
  on the nine compositions whose root carries both `container-type: inline-size` and
  the `padding-inline` content inset, `cqi` at a 1440 viewport is 13.44px against
  `vw`'s 14.4 — every converted ramp inside an active `clamp()` band lands 4-7%
  smaller, which is the conversion doing exactly what it says. `hero-split`,
  `hero-type` and `process-rail` did not move because their inset sits on `__inner`
  / `__frame` rather than on the container, so `cqi` there equals `vw`; `footer-line`
  carries no fluid ramp at all. No preview moved at 390: at that width every
  converted ramp is already pinned to its `clamp()` minimum under both units. No
  composition changed structurally, which is the signal that no ramp was converted
  in the wrong place.
- **The before/after walk was measured on a composition corpus, not on the v1.15.0
  client demo.** That demo no longer exists on disk — the project is now a WordPress
  install and the demo was consumed into the theme — so the comparison was made
  two-sided instead of historical: a five-page corpus assembled from the thirteen
  in-repo compositions (`composition-gate.sh`'s document shape plus the generated
  `:root`, `motion.css`, GSAP and `motion.js`) was walked twice, once with
  `bin/demo-verify.mjs` as of 1.15.0 and once with this revision. Release: **0
  findings, exit 0**. This revision: **16 `unobserved`, 0 of every other kind, exit
  0** — advisory, so the exit code is unchanged. Every one of the 16 is a parallax
  image that is its own bounds entry (`hero-bleed__bed`, and `hero-split`'s unclassed
  `<img>`): a one-device subtree whose only device publishes no `--motion-p`, which
  the document-wide count could never see because the reveals elsewhere on the page
  kept `samplable` non-zero. That is the per-section scoping, on a real page, and
  nothing else in the corpus moved: no `dead-scroll`, no `no-engine`, no
  `container-noop` in either walk — the library's nested `@container` rules all match,
  so the deeper recursion found nothing new to report on clean input. A composition
  corpus is cleaner than a real client build, so this shows the harness changed
  behaviour as intended without showing what a messy build now scores; the ceiling is
  recorded in `CLAUDE.md`.
- README and `docs/commands.md` no longer describe the fluid `vw` ramps as open work,
  and state that `unobserved` is counted per section while `no-engine` stays
  document-wide.

## [1.15.0] - 2026-09-10

### Added
- **A repeat client can no longer be handed back the structure they rejected.** The
  fingerprint gate compares palette and type across clients and nothing within one, and a
  build that fails the rubric records no row — so a client who rejected a demo and had it
  deleted got a rebuild reproducing the rejected build's recorded header silhouette almost
  exactly, invisible on every axis including palette. `fingerprint.md` gains a same-client
  rule: when a row already exists for this client, the new build's grammar and hero
  composition must differ, and the plan must say how — read from the plan and from any
  prior demo in `docs/` or git history, not from the registry alone, since a deleted
  predecessor left no row to compare against. Structure stays uncompared across clients
  and v1's six retired axes stay retired; this is one same-client rule, not a seventh axis.
  `/wp-demo` Step 2.6's fingerprint gate states the requirement and rules out "it is a
  fresh build" as an answer, since the previous rebuild was written fresh and converged on
  the same silhouette anyway.
- **A content width, an asset inventory, and no inherited placeholders — three client
  complaints, three contract holes.** Craft is told to ignore plain mode's `:root` clause,
  which was the only place `--container-max` was ever defined, so every composition padded
  by the gutter alone and above about 1600px a heading sat hard left and an aside hard
  right with a dead field between them. `--container-max` joins the craft token set in
  `references/design-md.md` and the neutral `_preview.md`, and all thirteen compositions
  now constrain content with
  `padding-inline: max(var(--space-gutter), calc((100% - var(--container-max)) / 2))` —
  on the root where the root carries the gutter, on `__inner` for `hero-split` and
  `hero-type`, and on `__rail` in `100cqw` for `process-rail`, whose `width: max-content`
  box would otherwise disagree with itself about a percentage padding and leave the
  horizontal travel short. Second: `docs/` reached a craft build exactly once, in the mode
  decision, and `design-md.md` read the logo only for its colours — so a 400x400
  transparent PNG of a client's real logo sat unused while the same run listed it as owed
  by the client. Step 2.6 gains an asset inventory that writes every image, SVG and font
  under `docs/` into `demo/BRIEF.md` with a role, and the header chrome takes its logo
  from that list. Third: craft's exemption list named only Step 4's single-file, no-CDN
  and `:root` clauses, leaving Step 4's `Logo area (placeholder)` and "placeholder images
  using CSS background colors" in force — which is how a hero rendering the words
  "HERO PHOTOGRAPH PENDING" passed "First paint complete", a rubric line that asks only
  that a primary visual be present. The exemption now covers the placeholder-content
  clauses too, and `wp-demo-craft/SKILL.md` blocks a placeholder image, a placeholder
  logo, or the words "pending", "placeholder" or "TBD" in rendered text.
- **A craft build that fails verification writes `demo/FAILED.md` and cannot pass for a
  finished one.** The loop already treated a rubric FAIL as a failing round, but nothing
  downstream changed what reached the client: `demo/index.html` stayed on disk looking
  finished, no command read `demo/VERIFY.md` as a gate, and the only recorded penalty was
  an unwritten fingerprint row the client never sees. `/wp-demo` now writes
  `demo/FAILED.md` at the three-round cap — naming every failing rubric line, every
  outstanding `slop` warning, every `dead-scroll`/`no-engine`/`container-noop` finding, and
  the round count reached — and leads its report with the failure instead of burying it as
  a caveat. `/wp-yolo` carries its own copy of the same craft verify loop (a craft
  `/wp-yolo` run never calls `/wp-demo`), and its loop now writes the same marker at its
  own three-round cap, so the full-site build path gates identically to the single-demo
  one instead of only consuming a marker it never produces. `/wp-init`, `/wp-section` and
  `/wp-yolo` all stop on `demo/FAILED.md` before building a theme from an unverified demo.
  `demo/VERIFY.md` now numbers its rounds under
  `## Round N` headings and requires a `## Findings judged to be capture artefacts` heading,
  with a measurement per entry, before a machine finding can be dismissed in prose.
- **A composition gate proves the library passes its own slop rule.**
  `bin/composition-gate.sh` assembles each `skills/wp-demo-craft/compositions/*/section.html` +
  `section.css` pair into a complete document before scanning, because `impeccable detect`
  scans zero files and exits 0 against the bare fragments — the reason `closing-block`'s and
  `proof-row`'s infinite loop animations went uncaught. `tests/checks/wp-craft-composition-gate.sh`
  runs it against the library, and against two synthetic libraries it must reject: one carrying
  an infinite marquee (`rc=2`) and one with a 0-byte `section.html` behind a real
  stylesheet (`rc=1`). A gate only ever watched passing cannot be told from a disabled
  one — mutating the detector filter or zeroing `MIN_HTML_BYTES` left the old check green.
  `bin/composition-gate.sh` takes a `COMPS_DIR` override for that, and loses its disk
  recount, which could never disagree with the counter it was checking.

### Documentation
- **The `@container` lint's two blind spots are written down.** `containerAudit()` walks
  only each stylesheet's top-level `cssRules`, so an `@container` nested inside `@media`,
  `@supports` or `@layer` is never linted — and `proof-row`'s own CSS already nests
  `@media` inside `@supports` — and it judges a selector by `document.querySelector(sel)`,
  its first match only. Both under-report; neither fires falsely. Recorded in
  `references/verify.md` beside the harness's other limits and in `CLAUDE.md`'s ceilings,
  and deliberately not fixed here: a limit nobody wrote down is indistinguishable from a
  bug, which is how a gate becomes untrustworthy enough to dismiss wholesale.
- **`cramped-padding`'s dismissal gains a lower bound.** `verify.md` recorded it as a known
  false-positive source on evidence of 56/57px and 131/129px — large paddings the detector
  misread — which as written taught builds to dismiss the one machine signal that catches a
  collapsed token, whose padding computes to **0px**. A measured padding under roughly 16px
  is now stated to be a true positive, not a capture artefact.

### Fixed
- **`container-noop` stops firing on valid CSS.** `containerAudit()` resolved each
  `@container` rule's selector with `document.querySelector(sel)` — the first match only —
  and then walked that one element's ancestors, so a selector matching several elements was
  reported dead whenever the first match sat outside any container and a later one sat
  inside, even though the rule genuinely applies. `container-noop` blocks, so a verification
  round failed on correct CSS — the same untrustworthy-gate failure this branch exists to
  cure, recreated inside the cure. The lint now walks every match and reports the selector
  only when none of them has a container-establishing ancestor; the ancestor walk still
  starts at `parentElement`, because an element never matches a container query against the
  container it establishes itself. Three fixtures pin both directions: `.orphan` (no
  container anywhere) is still reported, `.good__inner` (parent establishes one) is still
  not, and the multi-match `.card` is not. The first-match limit recorded in
  `references/verify.md` and `CLAUDE.md` is retired there rather than left standing as a
  known ceiling — it was a false positive, not an under-report — and
  `tests/checks/wp-craft-detect.sh` fails if either file reasserts it.
- **The verification server enforces path containment.** `serve()` stripped leading `../`
  from the request path and then called `join(root, rel)`, which is not containment: a path
  normalising to a Windows drive-absolute `/C:/Windows/...` lands outside the root, and a
  symlink inside the root pointing outside it was followed and served (measured: a symlink
  to `/etc/passwd` returned 200 with its contents). A page under test is untrusted markup,
  and the plugin ships to other people's machines, so "we run Linux" was not an answer. The
  handler now resolves the path, follows the links with `realpathSync`, and refuses anything
  that is not the root or under it with 404; a missing file still answers 404 rather than
  throwing. The whole existing traversal battery still 404s, `/` still 403s, `/index.html`
  and a nested asset still 200, and `tests/checks/wp-demo-verify.sh` runs that battery
  against `serve()` lifted verbatim out of the script instead of grepping for it.
- **A failed bind no longer hangs the walk.** `serve()`'s promise took only `resolve`, so a
  `server.listen` that failed — port exhaustion, a sandbox refusing the bind — never settled
  it and the walk stopped with no answer at all. A verification that produces no answer is
  the failure this branch exists to stop, and a hang is its worst shape because it looks
  like progress. The promise now rejects on `server.once('error', …)`, and the handler is
  removed once `listen` succeeds so a later runtime error cannot reject an already-settled
  promise; the walk's `finally` still closes the server on the throw path.
- **`bin/composition-gate.sh` returns a verdict on an unexpected detector payload.**
  Parseable JSON without a `findings` array left `findings` bound to the dict itself and the
  next loop raised `AttributeError` — an unhandled Python traceback instead of a gate
  verdict. The payload is normalised to a list first: a list stays as-is, a dict yields
  `findings` only when that is itself a list, and anything else is a scan that did not
  happen and exits 1, the same code as "could not scan". Treating an unreadable payload as
  zero findings would be a vacuous pass. `tests/checks/wp-craft-composition-gate.sh` runs
  the real gate behind a stub `npx` that emits `{"ok": true}` and asserts rc 1, no
  traceback, and a message that says why.
- **`demo/FAILED.md` stops being a one-way latch.** Nothing anywhere deleted the marker,
  so the branch's headline mechanism shipped without its inverse: a craft `/wp-yolo` run
  that exhausted its three rounds wrote the marker at Step 2.6 and was then refused by its
  own Step 0 gate forever, and a build that failed, was fixed and then passed on a later
  `/wp-demo iterate` still left the marker on disk, with `/wp-init`, `/wp-section` and
  `/wp-yolo` permanently refusing a demo that had since passed and nothing telling anyone
  why. The craft verify loop now clears it at its top (`rm -f demo/FAILED.md`) rather than
  on success, in both entry points, so the marker always describes the **last** loop and
  never a past one; the three Step 0 gates say what clears it. `references/verify.md`
  records the rule and `tests/checks/wp-craft-failed-build.sh` pins the literal deletion
  in every file that runs the loop, so a rewording cannot satisfy the pin while the
  deletion is gone.
- **`tests/checks/wp-craft-detect.sh` greps a comment-stripped copy of
  `bin/demo-verify.mjs`.** It stripped nothing, so all ~27 of its pins on that file fell to
  comment-parking — write `<broken code> // <original line>` and every grep stays green.
  Nine were verified to fall that way, one of them re-opening the dead-engine regression a
  whole fix round had closed (dropping `&& !b.scrub` from `frame.samplable === 0 &&
  !b.scrub`). The check now strips block comments and line comments once into a temp file
  and greps that, leaving URLs and escaped slashes in regex literals intact.
- **Four more text-pins become behaviour-pins.** A comment-stripped grep does not catch a
  polarity inversion or a renamed constant, so each is pinned on the line that carries it:
  the `view()` guard including its `!` and early return (dropping one character makes
  `revealState` return the unjudged sentinel on every browser that *has* `view()` — every
  browser the harness runs on — and reveal detection ceases with the suite green); the
  `CSSContainerRule` comparison and the `if (!el) continue;` beneath it (either one
  renamed or inverted silences the `@container` lint entirely); and `revealState`'s own
  `[data-motion="reveal"]` queries, both the section-root `matches()` and the descendant
  `querySelectorAll()` (renaming the attribute value collects zero devices and every
  section is skipped). All four are the same defect as the `[type="module"]` pin this
  branch already closed.
- **`bin/composition-preview.mjs --tokens` prints the preview `:root` and exits 0 without a
  browser**, and `tests/checks/wp-craft-compositions.sh` asserts that the emitted
  `--container-max` is a CSS length. Every other assertion about that token reads source
  text, which has four recorded bypasses — comment the line out, rename the key, reassign
  after the read, add a duplicate key later in the object — and an output assertion
  defeats all four at once. One `rootBlock()` builds both the flag's output and the page's
  own `<style>`, so the two cannot drift.
- **`dead-scroll` learns to tell a section that does not move from one the harness cannot
  read.** `reveal` publishes no `--motion-p` and no composition carries a cue, so every
  library-built section reported `dead-scroll` forever — 392 findings on a 12-page build
  whose only clean section was its one hand-built pin. `bin/demo-verify.mjs`'s probe now
  samples the reveal child the ruleset targets (`[data-motion="reveal"] > *`); a section
  the harness still cannot read reports `unobserved` and stays advisory, and a page with
  zero `data-motion` devices reports `no-engine` instead of walking clean on an empty
  frame signature. Sampling the reveal child was necessary but not sufficient: `reveal`
  is a one-shot entry transition a few pixels long, driven by the child's own `view()`
  progress around `scrollY = top - viewport`, so a sparse walk caught it by luck and a
  miss reported `dead-scroll` on a section that reveals perfectly. A section carrying no
  `pin`/`pan`/`kinetic`/`wipe`/`drift` is now judged by two samples — below the fold and
  fully entered — and reports `dead-scroll` only when no reveal child moved between them.
  Scrubbed sections keep the walk and its stall logic unchanged.
- **Advisory findings stop failing the round.** `unobserved` raised `demo-verify.mjs`'s
  exit code exactly like `dead-scroll`, so a page the harness merely could not read still
  failed — the false positive moved rather than left. The blocking/advisory split is named
  once, at the top of the file; advisory lines print with `[advisory]` and land in
  `findings.json` like any other, a run whose findings are all advisory exits `0` and says
  `nothing blocking, N advisory finding(s)` instead of looking clean, and any blocking
  finding still exits `1`.
- **The compositions that failed the library's own slop gate are scroll-linked now.**
  `closing-block` ran a 7s infinite conic sweep and `proof-row` a 38s infinite translate,
  both reported by `impeccable` as `marquee` at `category=slop`/`severity=warning` — the
  shape that fails a verification round before a screenshot is taken — so every build
  using the closing or proof role failed by construction. Both are now scroll-linked
  through the view timeline: the beam sweeps once on entry, the name track drifts while
  its section is on screen. No device, no span, no motion-cost change, so the role table
  stays true. `proof-row` loses its hover/focus pause block, which existed only because
  the movement was automatic.
- **A page whose motion engine never ran fails again, and a spoofed reveal stops passing.**
  Making the harness stop crying wolf had also stopped it barking at a real intruder: a
  demo carrying `pin`/`kinetic` markup whose `motion.js` never booted — a `file://`-blocked
  module script, the failure that shipped a demo the client rejected — reported `unobserved`
  and exited `0`. `drive()` is contractually required to publish `--motion-p` for
  `pin`/`pan`/`kinetic`/`wipe`/`drift`, so a stalled section carrying one of those with
  nothing samplable now reports blocking `dead-scroll`; `unobserved` stays for the section
  the harness genuinely cannot read. The two-point reveal check now compares the reveal
  child's scroll-driven animation (`getAnimations()` filtered to a `ViewTimeline`) instead
  of its computed opacity and transform, which any decorative `@keyframes` on the same
  children — or a percentage transform re-resolving after a lazy image loads — could move
  on a section with no reveal wired at all. `findings.json` rows now carry
  `"advisory": true`, so a consumer reads the field instead of keeping its own copy of the
  kind list. Scrubbed sections keep today's geometry and stall logic.
- **A reveal on a browser without `view()` is unjudged, not dead.** `revealState` reads
  `getAnimations()` for a `ViewTimeline`, but `motion.js` drives `reveal` in GSAP whenever
  `CSS.supports('animation-timeline', 'view()')` is false, and a GSAP tween is rAF-driven
  and invisible to `getAnimations()` — so on such a browser a working section read
  `none|none` and was reported `dead-scroll`. It now returns the unjudged sentinel there,
  the same one the above-the-fold and `parallax` ceilings return, and `verify.md` records
  it as the fourth limit. Latent on the current harness, where `view()` is supported.
  `tests/checks/wp-craft-detect.sh` also pins the two-point block's own guard by polarity
  and by what it gates: inverting `!b.scrub` or wrapping the condition in `false &&` left
  every existing assertion green while reveal detection disappeared entirely.
- **`bin/demo-verify.mjs` lints dead `@container` rules and serves the walk over HTTP.**
  An `@container` rule whose subject has no ancestor declaring `container-type` never
  applies and said nothing about it — this cost a previous effort a whole task and cost a
  real client build six blocks that never rendered, found only from screenshots. A new
  `container-noop` finding, blocking, reports the selector; the ancestor walk starts at
  `parentElement`, never at the element itself, because a container query never matches
  the container an element establishes on its own. Separately, the walk loaded pages as
  `file://`, where an external `<script type="module">` is a cross-origin fetch against
  an opaque origin, so Chrome blocks it silently, the engine never boots, and every page
  reports dead scroll with no trace of why — the exact failure this branch exists to fix,
  and it cost an hour to diagnose. Local targets are now served on an ephemeral
  `127.0.0.1` port instead; the contact sheet stays on `file://`, since it is a locally
  generated file with inlined images. A new advisory `external-module` finding names any
  module script that survives into a built demo, since it works served and breaks the
  moment a client double-clicks the file.
- **A malformed percent-encoding no longer kills the walk.** `demo-verify.mjs`'s demo
  server decoded the request path outside its `try`, so a request carrying a bare `%` —
  a stray character in an href or asset path is enough — threw `URIError` out of the
  request handler and Node killed the process mid-run. The decode is inside the guard
  now and answers `400`; traversal vectors still `404` and a directory still `403`.
  Three assertions in `tests/checks/wp-craft-detect.sh` also stopped being text-pins:
  the container lint's polarity (`if (!found)`), the module-script selector
  (`script[type="module"][src]`) and the once-per-page `staticChecked` gate are each
  anchored on the token whose inversion or typo silently switches the check off.
- **The 392-finding client baseline re-walked at 33.** `bin/demo-verify.mjs demo/` against
  `next step credit solution/demo/` (12 pages, the build this branch exists to fix) now
  reports 32 `dead-scroll` and 1 `container-noop`, zero `unobserved` and zero
  `external-module`. The drop is real and traces mostly to serving over HTTP: with the
  module script no longer blocked, `motion.js` boots and most sections read as moving
  outright, with no finding at all, rather than falling back to `unobserved`. None of the
  32 remaining `dead-scroll` findings moved to `unobserved` on this walk, because
  `unobserved` requires the probe's page-wide `samplable` count to be zero — a whole-page
  "the engine produced nothing readable" state that a booted engine essentially never
  reaches, even on a page carrying a genuine dead section elsewhere. The remaining findings
  are one real design defect repeated across pages (`closing-block__inner`, dead on 9 of 12)
  and one page with two additional dead sections (`index.html`'s `how` and `steps__title`).
  This walk does not exercise the `unobserved` path at all; that it fires correctly when a
  page's engine is genuinely unreadable is asserted by `tests/checks/wp-craft-detect.sh`,
  not demonstrated by this baseline.

## [1.14.0] - 2026-09-09

### Added
- **A vendored 192-row domain table constrains the composition plan, never the tokens.**
  `skills/wp-demo-craft/references/domains/domains.csv` takes only `domain`, `keywords`,
  `page_pattern`, `considerations` and `confidence` from `nextlevelbuilder/ui-ux-pro-max-skill`
  (MIT, imported by `bin/domains-import.sh`, with `SOURCE.txt` recording the exact ref and
  commit it pulled). Its colour and typography tables were refused on sight: the source
  catalogue maps 192 product types onto 50 distinct primary colours and pairs Playfair Display
  with Inter, which would hand every client in a category the same palette — exactly what this
  plugin's fingerprint gate exists to refuse, and a pairing its own type floor already names
  Inter against as the most-used face in machine-generated pages. New check:
  `tests/checks/wp-craft-domains.sh`.
- **`/wp-demo` and `/wp-yolo` classify the client's domain before the composition plan, and
  the match never touches a token.** Two distinct keyword hits is the bar; the highest count
  wins; an exact tie reports both names and proceeds `unclassified` rather than guessing; and
  because the keyword lists are English-only, a docs set with no English-language material is
  reported `unclassified` with that reason stated instead of silently falling through. A
  match's `page_pattern` and `considerations` fold into the brief as constraints on which
  section roles the plan may pick — colour and type still come only from `demo/DESIGN.md` and
  the client's own material. Recorded once per site in `.wp-create.json` under `"domain"`, and
  read rather than re-derived on a later run.
- **`reveal` now has a second, CSS-only engine, and the two never double-drive the same
  section.** `starter-theme/__tailwind__/assets/css/src/tailwindcss/utilities/motion.css`,
  pulled in through the theme's existing Tailwind entry (`main.css`), drives every
  `[data-motion="reveal"]` child under `@supports (animation-timeline: view()) { @media
  (prefers-reduced-motion: no-preference) { ... } }`. `motion.js` tests the identical
  feature-query string, `CSS.supports('animation-timeline', 'view()')`, and yields the device
  to CSS whenever it matches and motion is not reduced, so exactly one engine drives `reveal`
  in every combination of feature support and reduced-motion preference. New/extended check:
  `tests/checks/wp-craft-motion.sh`.
- **A seventh rubric line, `Name-swap`, plus scales derived in `oklch()`.** Replacing the
  client's name with a competitor's throughout the copy and re-reading it catches a page that
  describes a category rather than a business — graded from the sheets like the other six
  lines. `demo/DESIGN.md` now carries a token's `oklch()` triple beside its recorded hex value,
  because equal numeric steps in oklch are equal perceptual steps while a scale stepped in hex
  or HSL produces visible bright and dark spots at the same interval; the hex value stays the
  recorded token so nothing downstream breaks. `taste.md`'s Depth section now warns that grain,
  film texture and tactile brutalism are in every trend roundup published this year, so
  reaching for them because they read as anti-AI is today's antidote becoming tomorrow's
  default unless the reason is stated in `demo/BRIEF.md`.

### Changed
- **Every composition sizes its breakpoints to its own container, not the viewport.** Each
  root declares `container-type: inline-size` and every size-based breakpoint is an
  `@container` query, so a section dropped into a narrow column lays out for the column
  instead of the screen. An element never matches a container query against the container it
  establishes itself, so four compositions needed an `__inner` wrapper to carry the queried
  layout. Three of them — `faq-list`, `hero-split` and `hero-type` — moved `data-motion` onto
  that wrapper so `reveal` still staggers the same children; `footer-line` carries no
  `data-motion` attribute at all, because it is not a reveal composition. The
  fluid ramps do not share the fix: the `vw` in `clamp()` gaps and type scales, 40 occurrences
  across 12 of the 13 compositions, still key off the viewport, so a section in a narrow column
  still takes desktop-maximum spacing. `compositions/README.md` and the root `CLAUDE.md` both
  record that as open work rather than claim it is done.
- **Craft mode is reference-first and render-verified (`wp-demo-craft` v2).** The first real
  craft build shipped blind — nothing checked whether a browser was even usable before the
  build started, so a 12,000px page with an empty first screen and a headline clipped mid-word
  by its own kinetic mask reached the client. v2 makes a browser a hard prerequisite:
  `bin/demo-verify.mjs --probe` exits 0 for a usable browser and 2 otherwise, `/wp-demo` stops
  on 2, and the script's `playwright-core` resolution ladder now also checks `<cwd>/node_modules`,
  which is what makes a project-local install visible to the plugin's own script. The build now
  starts from `demo/DESIGN.md` — tokens assembled from the client's own docs, `npx designlang`
  run on their site, and a vendored MIT catalogue of 64 real-brand DESIGN.md files under
  `skills/wp-demo-craft/references/design-md/` (64 and not a rounder number because ten upstream
  entries carry no YAML front matter and cannot supply parseable tokens), with a generated
  `INDEX.md` regenerated by `bin/design-md-index.sh` and a neutral `_preview.md`. Every section
  is built from a new composition library (`skills/wp-demo-craft/compositions/`, thirteen worked
  sections, each with markup, CSS, a README naming what it ports and its licence, and two
  rendered previews checked by `bin/composition-preview.mjs` against the neutral reference, plus
  a role table and `fills.json`), and the build is verified by looping `npx -y impeccable@4
  detect --json` (pinned to major version 4 — `@1` does not exist on the npm registry) plus a
  six-line critique rubric written to `demo/VERIFY.md`, for at most three rounds, with no
  fingerprint recorded for a build that never passes. Findings from the detector carry a
  `category` of `slop` or `quality` — there is no P0 severity — and are always counted by
  parsing the JSON array on stdout, never read from the exit code: exit `0` means the scan
  completed with no primary findings, `1` means a target could not be scanned, `2` means
  findings are present. A `slop` finding at `warning` severity fails the round outright; `quality` findings are
  reported and weighed against the rubric instead. New checks: `wp-craft-gate.sh`,
  `wp-craft-detect.sh`, `wp-craft-compositions.sh`, `wp-craft-design-md.sh`, `wp-craft-rubric.sh`.
- **Variety is no longer the product.** The old forced-variety rules are gone; a motion budget
  replaces them — a pin outside the peak is capped at span 2.0, the one element marked
  `data-motion-peak` may reach 3.0, and interior pages never pin — and the fingerprint gate now
  compares only palette and type pair instead of six structural axes, because fingerprinting
  structure was pushing builds into shapes chosen to clear the log rather than to suit the
  client. Split stage and rhythmic cutlist are retired from the default grammars.
- **`/wp-demo-verify` is now the runner for the detector, the walk and the critique**, and
  `/wp-demo` Step 2.6 is rewritten around the same order: gate, `DESIGN.md`, brief, grammar and
  composition plan, build, loop, record. A directory target now walks every `*.html` in it, one
  output folder per page, with `findings.json` shaped `{ pages: [...] }`. `/wp-init` reads
  `demo/DESIGN.md` before scraping `:root` and carries it into the theme through an alias table
  so the starter's own tokens resolve onto the craft vocabulary; craft demos skip
  `/wp-tailwindify`.

### Fixed
- **`motion.js`** refuses the kinetic split on an `h1` — a hero uses `reveal` and never
  `kinetic`, and a bare `data-motion-cue` does nothing outside a section the engine scrubs
  continuously, so it could not have rescued one anyway — gives the split mask headroom so
  ascenders and descenders never clip, and warns on a pin span above budget when the section is
  not marked `data-motion-peak`.

## [1.13.0] - 2026-09-09

### Added
- **`/wp-yolo` now runs `/wp-audit --all` as part of its finish phase.** A yolo build
  shipped without anyone ever measuring SEO, Core Web Vitals, accessibility, security or
  coding standards — `/wp-finalize`, `/wp-polish` and `/wp-responsive-check` all judge
  demo parity, nothing judged quality. It is Step 5 item 7, MANDATORY like the other
  three, its Step 9 fix prompt pre-answered yes, and fixes that touch theme CSS,
  templates or enqueues re-run `/wp-finalize`'s Layers 2-3 so a perf or SEO fix cannot
  silently break demo parity. `tests/checks/wp-yolo-checkpoint.sh` guards it.
- **`/wp-robin` and `/wp-aos-animator` — runner commands for the plugin's only two action
  skills.** Every skill here is `user-invocable: false`, which is the layer rule and stays
  that way, so the two skills that actually *do* something had no way in: the README once
  carried phantom command rows for them, those were removed, and the docs then told users to
  describe the task in prose — discoverable only by reading docs a user typing a slash never
  opens. `/wp-robin [wp-root]` resolves and validates a WordPress root, checks the database
  client and webp converter the skill requires, and runs the skill's bundled `robin-fix.sh`
  with `WP_ROOT` set. `/wp-aos-animator [<theme>] [templates…] [--report-only]` sequences the
  skill's audit → install → enqueue → init → animate pipeline and dispatches one subagent per
  template for the animate phase, with `--report-only` stopping after the audit on the same
  contract as `/wp-audit`'s flag. Both commands dispatch and never reimplement: the phases,
  the settings, the skip list and the animation table stay in the skills, which remain the
  source of truth. New check: `tests/checks/skill-runner-commands.sh`, whose load-bearing
  assertions are the negative ones — that neither skill has been flipped to
  `user-invocable: true`, and that neither command carries a copy of the procedure it runs.

### Changed
- **`/wp-init` now defaults to Polylang, not field suffixes.** The old default was justified
  on inertia — "what every existing project uses" — and it costs the second language its
  entire search presence: one URL serves both languages off `?lang=`/cookie/`Accept-Language`,
  so a crawler that sends no cookie only ever sees the primary language; `?lang=es`
  canonicalizes back to the primary URL; there is no hreflang pair because there is only one
  post; and per-post meta leaves Rank Math nowhere to store a translated title or description.
  Step 0.7 now lists Polylang first, defaults to it on Enter, states the SEO reason, and
  offers `suffix` as what it is — a language toggle for a site whose second language does not
  need to be found. Existing projects are untouched: the strategy is still read from the
  project's `.claude/CLAUDE.md` and an absent `i18n strategy` line still means `suffix`.
  `tests/checks/wp-polylang.sh` guards both the new default and that fallback.
- **The docs no longer say these two capabilities have no slash command.** `README.md`,
  `docs/commands.md` and `docs/workflows.md` each said so, correctly, until now; all three
  now state that the skills are invoked through their runner commands while remaining
  non-invocable themselves, so the layer rule reads as intact rather than abandoned.

### Fixed
- **A bare `/wp-yolo <folder>` skipped its own checkpoint.** The command name was being
  read as the `--yolo` flag, Step 1 called the default mode "hands-off", and Step 3 said
  "ask" without a stop, so the model approved the plan for the user and rolled into the
  build. Step 1 now states the name is not the flag, Step 3 is a hard stop that prints a
  build plan (pages, CPTs, content types, skips, review items) and ends the turn, and
  `AskUserQuestion` is in the command's tool list. `tests/checks/wp-yolo-checkpoint.sh`
  guards it.
- **`/wp-yolo` stopped after seeding and told the user to run the finish commands
  himself.** `/wp-finalize`, `/wp-polish` and `/wp-responsive-check` were bare one-word
  bullets in Step 5, so a long run treated them as optional and reported "site works"
  with the 3-layer demo-parity gate never executed. They are now marked MANDATORY with a
  dispatch instruction each, and a completion rule says a run that reaches the report
  without all three is incomplete, under `--yolo` too. Step 5.5 also pointed at the wrong
  Step 5 item for `/wp-finalize`. Same check guards it.
- **`/wp-init` never wrote the site's name or tagline, so every scaffolded site shipped
  "Just another WordPress site."** The command already asked for a one-sentence description
  and then dropped it on the floor: `blogname` was set only by `/wp-create`'s
  `core install --title` (so an adopted site kept the previous project's name) and
  `blogdescription` was set by nothing at all. Both are `critical` in `/wp-finalize`'s
  Layer 2 gate, which therefore failed on every project by construction. `/wp-init` now
  extracts a tagline from the demo (`<meta name="description">`, then the hero subtitle),
  shows it among the demo-first defaults for confirmation, prompts for it when there is no
  demo, and writes both options next to theme activation. Under `i18n strategy: polylang`
  this writes the primary language only — but that is the point, because Polylang omits an
  empty option from its string table entirely, so an unset tagline was not even translatable.
  New check: `tests/checks/wp-init-site-identity.sh`.
- **The theme named fonts it never loaded, so every non-`/wp-yolo` build rendered in a
  fallback stack.** `/wp-init` Step D4 wrote the demo's font *names* into `--font-primary`
  / `--font-secondary` and nothing ever carried a font file, which is why a converted theme
  looks "almost right" and nobody can say what changed. Three parts, one cause: the Tailwind
  starter shipped `--font-primary: "Inter"` with no `@font-face` and no Inter anywhere, so
  even a demo-less scaffold rendered in the system fallback; `functions.php` preconnected to
  `fonts.googleapis.com` unconditionally while the theme never made one request to it — a
  dead hint on every page; and the demo's families were never fetched at all. New `/wp-init`
  **Step 4.5: Font carry** self-hosts every family the theme names, including Google Fonts
  (downloading the woff2 with a browser user-agent — the default `curl` UA silently gets the
  legacy TTF build, and every fetch uses -f so an error page is never written into a .woff2),
  guarantees `font-display: swap` on every carried block rather than only keeping it where
  Google emitted it, drops a family that could not be carried from the head of its token
  instead of leaving the theme naming a font it does not have, preloads the one file that pays for itself (the primary family's regular
  latin subset — preloading every unicode-range subset would defeat the lazy loading that
  makes carrying them all cheap), and the starter's default tokens are now a system stack,
  which is the only value that renders as written when there is no demo. `/wp-yolo` Step 4.5 stops
  permitting a Google Fonts preconnect so both commands give one answer.
  New check: `tests/checks/wp-init-font-carry.sh`.
- **The audit agents now run the checks they document.** A batch of SEO, performance and
  Rank Math checks had been appended below the agents' last step with a note to "add these
  to the tables above" — an instruction to a reader, left undone, so an agent that only
  runs what Step 1 and Step 2 tabulate ran none of them. Every code is now a row in its
  own tier table (`wp-audit-seo` SEO-035 to SEO-050, `wp-audit-performance` PERF-047 to
  PERF-052), the Rank Math steps sit beside the steps they extend rather than after
  Step 13, and `tests/checks/audit-check-tables.sh` fails if a check code is ever
  referenced without being tabulated again.
- **Broken `wp eval` payloads in those checks.** Two were PHP parse errors, several used
  `$wpdb` and `$p` unescaped inside a double-quoted shell string (the shell ate the
  variable before PHP saw it), and one shipped a `TODO` as a CRITICAL check that compared
  nothing. The five checks that need rendered `<head>` values now share one snapshot
  command instead of fetching the site five times.
- **`glob('/**/*.php')` skipped the theme root.** PHP's `glob()` has no recursive `**`, so
  the theme-JSON-LD conflict scan never saw `functions.php` — the single most likely place
  for a theme to emit schema. Replaced with `RecursiveDirectoryIterator` in all three
  copies, and the new check refuses the pattern.
- **PERF-016 and PERF-048 contradicted each other** — one asked for `fetchpriority="high"`
  on the hero image, the other flagged it. They are two halves of one decision (is the LCP
  an image or text?) and are now cross-referenced as such.
- **Two audit checks passed by never looking at anything.** The Rank Math sitemap
  validation reported that noindex pages "may still be in" a sitemap it had already
  fetched, and counted drafts site-wide without looking at it at all. It now walks
  `sitemap_index.xml` into its child sitemaps — the index lists children, not URLs, so a
  permalink search against the index alone could never match — and compares whole `<loc>`
  values, because a permalink is a prefix of its own paginated children and `/blog/page/`
  was reported as listed whenever `/blog/page/2/` was. The walk is gated on
  `<sitemapindex>`: in a flat `<urlset>` the `<loc>` entries are the post URLs, and
  following them would refetch every published post.
- **The rendered-head checks (SEO-038 to SEO-043) read `canonical`, `og:locale` and
  `hreflang` out of the markup with regexes** that assumed double-quoted attributes and
  `rel` before `href`. Both are optional in valid HTML, and on the other order the regex
  returns an empty string — which reads as "no finding", so the checks passed a broken
  site. Now parsed with `DOMDocument` + `DOMXPath`. The snapshot issues one request per
  post against the site itself, so it is capped at 50 with the reason stated; SEO-041
  gains the caveat that a counterpart missing from the sample is not a broken pair.
- **PERF-047's deferral recipe unhid the theme's real print stylesheet.** It documented a
  footer script sweeping every `link[media="print"]` to `media="all"` — a genuine print
  stylesheet is such a link too. Replaced with a `style_loader_tag` filter that defers
  only the handles it names.

## [1.12.1] - 2026-09-04

### Changed
- **The demo is documented as every path's input, not a step inside path B.** Every
  path converts a demo: `/wp-init` reads it to learn the project, `/wp-yolo` converts it
  page by page, `/wp-section --transcribe` copies its declared values and `/wp-seed` turns
  its files into WP Pages. Both `README.md` and `docs/workflows.md` now carry a required
  demo stage between setup and build with the three ways in (hand a mockup to `/wp-init`,
  polish files dropped into `demo/`, or `/wp-init` then `/wp-demo` from nothing). This also
  closes an ordering trap: a bare `/wp-init` run before any demo exists can never trigger
  its demo-first flow, so a reader following the old order answered by hand what the
  mockup already knew.
- **The README opening diagram no longer contradicts the corrected section further down**,
  and three docs stopped naming a `basic` template that `/wp-init` only keeps as a legacy
  alias for `tailwind`. Both build paths open with a `Needs:` line, `/wp-init`'s three
  questions state their defaults, `/wp-demo-verify` is the name shown everywhere with
  `/wp-responsive-check` noted once as its alias, and `docs/commands.md` gains the demo
  section and the `/wp-demo-verify` table row it was missing.

## [1.12.0] - 2026-09-04

### Fixed
- **Three ways a design frame's numbers are transcribed correctly and still render wrong**,
  now in `wp-css`'s transcription contract: a frame `y` is a page coordinate in a page with
  no site chrome, so a breadcrumb the design never drew shifts everything below it (take
  vertical positions as distances between neighbours); section gaps are authored and
  irregular — one real design ran 53, 73, 103, 94, 107, 117, 147, 128, 73, so a single
  spacing token is uniformly wrong and splitting a gap across two paddings renders their sum;
  and a px width in the frame is a fraction of that frame's track, which frozen as px inside
  a `max-width` query holds the narrow-frame width up to the breakpoint.
- **Four `/wp-debug` commands ran a `bash -c` inside a command substitution and read the
  wrong path in silence.** Inside `$( … )` bash re-parses the text as a fresh command, so
  the `\"` written to survive the outer quoting arrives as a literal quote: the inner shell
  dies on `unexpected EOF while looking for matching \"`, the substitution is empty, and
  `tail -50 "$( … )/wp-content/debug.log"` reads `/wp-content/debug.log` and still exits 0.
  The wrapper bought nothing — `$WP` is a command plus its global arguments and word-splits
  correctly on its own. Dropped in all four, with the expansion quoted at the point of use.
  New check: `tests/checks/no-nested-bash-c.sh`.
- **`/wp-debug` can now diagnose "my CSS change doesn't show".** A static version constant in
  `wp_enqueue_style` keeps the URL stable while the file changes, so browsers serve the copy
  they cached. The `filemtime()` rule already existed in `wp-theme-standards` but only reaches
  themes this plugin generated; `/wp-debug` runs on themes it did not write. The same symptom
  was diagnosed twice as something else — once as broken images, once as a specificity
  problem — before anyone read the enqueue. New checks:
  `tests/checks/design-value-transfer.sh`.
- **A headline field that carries markup now has a correct escaper.** Section headlines
  routinely hold a `<span>` the CSS paints as a highlight and `<br>` where the design breaks
  the line, and both usual answers were wrong: `esc_html()` prints the tags, `wp_kses_post()`
  admits `<iframe>`, `<img>`, inline styles and a class on any tag — the run of the page from
  a headline field. `wp-theme-standards` and `wp-template` now carry `wp_kses()` with a
  two-tag allowlist, forbid `the_field()`/`the_sub_field()` by name (they echo unescaped and
  read as the natural template call), and state the corollary: a CSS class inside field
  content is not a thing that exists, so which break applies at which width is chosen in the
  stylesheet by `br:nth-of-type()`, with the `display:none` whitespace trap spelled out.
  New check: `tests/checks/acf-markup-escaping.sh`.
- **The CSS skills now say where a reset must live.** A reset scoped to a page —
  `.page img { max-width:100%; height:auto }` at (0,1,1) — outranks a single class on
  that same image at (0,1,0), so the image ignores its own class and paints at its
  intrinsic size. The symptom reads as "my CSS is not loading": `getComputedStyle`
  returns the reset's value and the class is right there in DevTools. Both
  `wp-css-system` and `wp-tailwind-system` now carry the rule and its remedy, `:where()`,
  which contributes no specificity. New check: `tests/checks/css-reset-specificity.sh`.
- **`/wp-tailwind-migrate` now gates on the Tailwind major instead of assuming it.** Every
  step it runs writes the v4 layout and Step 5 deletes `assets/css/styles.css`, so pointing it at
  a v3 theme — `tailwind.config.js`, a PostCSS build, `style.css` at the theme root carrying
  the `Theme Name:` header — turned a conversion into an unrequested v3→v4 upgrade plus a
  restructure of every partial, and then removed the stylesheet the unmigrated templates were
  still styled by. Step 0 reads the installed version and stops with what it found.
- **`/wp-tailwind-migrate`'s visual comparison no longer presents a differing-pixel count as
  proof.** `compare -metric AE` is not deterministic where the GPU composites: on a page with
  `backdrop-blur` cards, two consecutive captures of the *same unchanged page* differed by
  more than baseline-vs-migrated did. The step now establishes that noise floor first, and
  adds the numeric contract — geometry measured in the page — as the real oracle, including
  the on-screen order of every reversible row. A dropped `flex-row-reverse` mirrors a section
  while every box keeps its size, so a size-only contract reports a perfect match.
### Added
- **`wp-demo-craft` skill and craft mode for `/wp-demo`, `/wp-yolo` and `/wp-polish`**: a
  design floor, page grammars, a scroll-motion device kit and an anti-slop refuse list for
  demos that need to feel premium rather than templated. `/wp-demo` now infers craft or plain
  mode from the project's docs (`--craft`/`--plain` override it), records the choice as
  `demo mode` in `.wp-create.json`, self-authors `demo/BRIEF.md` with a per-section feeling
  curve, and checks the plan against `~/.claude/wp-builder/FINGERPRINTS.md` so two clients
  never ship the same shape. Motion is a contract, not a library call: sections carry
  `data-motion-*` attributes and an inlined `motion.js` bundle built on GSAP ScrollTrigger.
  `/wp-polish --craft` runs the same skill as a retrofit audit against an existing demo
  instead of a plain normalize pass.
- **`/wp-demo-verify`**: replaces the single-screenshot check with a scroll walk: per-section
  screenshots at desktop and mobile widths, a reduced-motion pass, full-page shots at five
  breakpoints, and machine findings for dead scroll, cues that never reach full opacity,
  horizontal overflow and clipped copy. `/wp-responsive-check` is now an alias that dispatches
  to it. A green machine run is explicitly not a pass on its own; the command still requires
  a human feel check against `demo/BRIEF.md`'s curve.
- The cinematic path (`/wp-cinematic-demo`, `agents/wp-cinematic.md`) now reads
  `skills/wp-demo-craft/` first for the same design floor and feeling curve a static craft
  demo uses, with the kit's own contract still owning everything video-specific.
  `/wp-demo-verify`'s dead-scroll check samples the stage `<canvas>` so a cinematic reel whose
  video never actually changes between scenes is caught the same way as a static section with
  no motion.
- **`position: absolute` is for superposition, not for layout**: a mockup's `x`/`y` is where
  an element fell in one frame at one width, so an absolute box copied from a demo is out of
  flow and the first longer ACF value (or the second language) puts it on top of its
  neighbour. `skills/wp-css-system/SKILL.md` and `skills/wp-tailwind-system/SKILL.md` now own
  the rule in full — flex/grid for layout, `absolute` only for a real overlap (badge on an
  image, floating icon, dropdown, `inset:0` veil, `sticky`/`fixed`, `.sr-only`), a
  survives-a-content-change test before the declaration, and the instruction to read a
  mockup's offsets as `gap`/`padding` rather than `left`/`top`. `agents/wp-css.md` carries the
  same section and a new rule in its Rules list; an `absolute` inherited from demo HTML during
  `/wp-polish`, `/wp-section`, `/wp-yolo`, `/wp-tailwindify` or `/wp-tailwind-migrate` is
  explicitly not a value to preserve. `tests/checks/wp-layout-flow.sh` fails if the wording
  disappears from any of the three files.

## [1.11.0] - 2026-09-02

### Added
- **`wp-contributing` skill and `/wp-contribute`** — the conventions a contributor could
  previously only learn by breaking them: calls go down the four layers and a command
  dispatches builders rather than reimplementing them, tests are grep gates over prose
  (with the house style for writing one), the frontmatter contract per layer, the two i18n
  systems, and the PR and release rituals including the stacked-PR squash hazard. The skill
  auto-loads when editing this repository; `/wp-contribute new` scaffolds a layer file
  together with its check and its doc rows, so a PR cannot arrive missing either.
- **`bin/doc-sync-check.sh`** — asserts the docs still describe the plugin that exists: every
  command has a README row and a `docs/commands.md` entry, every documented command exists
  (the phantom `/wp-robin` and `/wp-aos-animator` rows survived two releases), every agent and
  skill is listed, frontmatter is present per layer, the four version references agree, and
  `CHANGELOG.md` moved when behavior did. Run by `/wp-contribute check` and
  `tests/checks/wp-contributing.sh`.

### Fixed
- Documentation drift the new gate found on its first run: eleven agents (`wp-cf7`,
  `wp-normalize`, `wp-context`, `wp-cinematic` and the seven `wp-audit-*`) and three skills
  (`wp-environments`, `wp-audit-standards`, `wp-audit-seo-standards`) were missing from the
  README tables, and `wp-aos-animator` and `wp-robin` declared no `user-invocable`, leaving
  them inert rather than broken.

## [1.10.0] - 2026-09-02

### Fixed
- **Tailwind CSS is recompiled after every builder.** `functions.php` enqueues only the
  compiled `assets/css/dist/main.css`, which `/wp-init` built before any section existed;
  `/wp-section`, `/wp-header`, `/wp-footer`, `/wp-page`, `/wp-cpt` and `/wp-yolo` never
  rebuilt it, so the live site — and `/wp-yolo`'s parity gate — showed an unstyled page
  unless `npm run preview` happened to be running. New `bin/tailwind-rebuild.sh` runs
  `npm run tailwindbuild` at the end of each (no-op on non-Tailwind themes, skipped when a
  watcher owns `dist/`). `/wp-init`'s summary and `docs/workflows.md` now explain the
  live-reload workflow. `tests/checks/tailwind-rebuild.sh`.
- **`wp-robin`'s `robin-fix.sh` did nothing on MariaDB, and gave up on a partially populated queue.** Three bugs, found running it against a live site (MariaDB 10.x, WP 7.1, 95 attachments, only 2 of them in the queue): the thumbnail scan aborted the whole script under `set -e` whenever the theme registered no `add_image_size`; the attachment query used `CAST(meta_value AS JSON)`, which MariaDB does not implement, and read `_wp_attachment_metadata` with `json_decode()` even though WordPress serializes it — so the query errored out and the loop registered nothing; and registration ran only when the queue was completely empty, so a queue holding a couple of stale rows was reported as done and 93 attachments were never optimized. Registration now runs for every attachment missing from the queue, the counts are read with `unserialize()`, and both `NOT IN (...)` subqueries exclude `NULL` `object_id` values, which otherwise make the whole predicate match no rows.
- The same script no longer reports a clean run it did not have: a failed `INSERT` is counted as a failure rather than silently inflating the total, mariadb's stderr is no longer discarded, a missing queue table stops the run instead of producing ten unexplained errors, an attachment whose original file is gone is skipped instead of being queued as a successful optimization, and a failed attachment query aborts instead of announcing "0 new attachments". Step 4 now reads every attachment in one query and one PHP pass and inserts in batches, rather than opening a client and forking two interpreters per image.

### Added
- **`/wp-section --hybrid`** now exists. `/wp-init`, `/wp-cinematic-init` and
  `docs/cinematic-mode.md` had been pointing users at the flag while
  `commands/wp-section.md` never parsed it. It appends a layout to the `trailing_sections`
  flex field, renders via `get_sub_field()`, writes CSS to `cinematic.css` and skips page
  injection; refused on non-cinematic projects. `tests/checks/wp-section-hybrid.sh` guards it.
- **`/wp-seed` works without `.wp-create.json`** — falls back to bare `wp` and the
  `Languages:` line of `.claude/CLAUDE.md`, matching `/wp-debug`. `tests/checks/wp-seed-fallback.sh`.
- **Five gaps a full client build hit in production, closed at the source** (#30). `wp-cf7`
  now treats a CF7 form as what it is — a post row no build step ever scans: one hook class
  per element declared in the theme CSS instead of utility classes that vanish when the
  theme normalizes its variants, plus an idempotent `inc/seed/cf7.php` so the markup travels
  with the theme. `wp-aos-animator` documents the identity `transform` AOS leaves behind
  (stacking context, containing block, rewritten `transition-property`) as skip conditions.
  `wp-tailwind-system` separates Tailwind's `hidden` utility from HTML's `hidden` attribute.
  `/wp-page legal` emits `inc/legal-search.php`, and Rank Math builds no breadcrumb on a 404.
- **Twenty-one defects a 52-commit client build had to work around** (#31), with
  `docs/postmortem-reference-build.md` carrying the full table — defect, cost, root cause,
  fix — including the three left open and why. Five were silent bugs in the Tailwind starter
  (SVG upload support, an ACF options `ID` collision, `main.css` pathing, and 36 translation
  twin fields that were dead on a Spanish-primary site because `fields/*.php` hardcoded `_es`
  while the helper appends the non-default suffix — `/wp-init` now rewrites the suffix and a
  grep proves it). Sixteen more are now documented traps with grep gates: the `_`-in-arbitrary-
  variant escape that silently killed 22 focus indicators, unlayered CSS beating
  `@layer utilities`, `/wp-yolo` porting no demo JavaScript (new Step 4.6 enumerates
  `demo/js/*.js`) and having no re-run gate (it now refuses on an already-built theme without
  `--force`), Rank Math shipping active but unconfigured, and ACF options fields with no
  `default_value`.

### Changed
- README "Tech Stack" no longer claims vanilla CSS / no build tools; it names the Tailwind
  starter, the cinematic starter and the suffix-or-Polylang i18n choice.
- **Docs restructured around the three build paths.** README now opens with the
  setup → path A (`/wp-yolo`) / B (step by step) / C (cinematic) → finish shape and a
  command table that marks each command required / optional / auto. Long-form guides moved
  to `docs/workflows.md` (per-path how-to, `/wp-init` choices, i18n systems, shared files)
  and `docs/commands.md` (arguments, inputs, outputs per command). Removed the phantom
  `/wp-robin` and `/wp-aos-animator` command rows — they are skills, not slash commands.
- `docs/code-connect-draft.md` — proposal for Figma Code Connect integration (#26), draft only.

## [1.9.0] - 2026-08-29

### Added
- **Per-task model routing** — every agent now declares a `model:` cost tier in its
  frontmatter (opus for planning `wp-normalize`/`wp-context`, sonnet for code authoring
  and judgment audits, haiku for mechanical `wp-acf`/`wp-cf7`/AIOS/Rank Math), so
  `/wp-yolo` and every other dispatcher route subagents to the cheapest capable model
  automatically. `/wp-yolo` documents the contract in its "Model routing" section;
  `tests/checks/model-routing.sh` enforces it.

## [1.8.0] - 2026-08-27

### Added
- **`/wp-robin-image-optimizer`** — installs Robin Image Optimizer, converts the whole Media Library to WebP and rewrites the database references to the converted images.
- **`/wp-aos-animation`** — wires the AOS library site-wide and animates existing sections.
- **WebP image delivery and right-sizing** in generated themes, plus an SEO link-text fix and a defined `.screen-reader-text`.
- **Polylang as a first-class translation model, selectable at scaffold time.** `/wp-init` now asks which i18n strategy a project uses and records the answer as `i18n strategy` in its `.claude/CLAUDE.md`; `_suffix` remains the Enter-key default so existing projects and non-interactive callers are unaffected. Choosing Polylang installs and activates the plugin, creates the languages through the same `pll-setup.php` the retrofit command uses, assigns the primary language to existing content, and swaps in a per-template Polylang variant of `inc/i18n.php`. Every downstream step branches on the recorded strategy: `/wp-seed` builds a counterpart page per language from the demo's own secondary-language copy and hands the remainder to `/wp-polylang`, `/wp-header` registers one menu location per name and renders `pll_the_languages()`, the `wp-acf` agent stops emitting `_<lang>` duplicate fields outside the settings group, and `/wp-yolo` passes the strategy through and gates on the verifier.
- **`/wp-polylang`**: retrofit an existing site into a second language through the `pll_*` API — export to a manifest, translate, import, verify. Handles posts, terms, menus, attachments, ACF/SCF fields including repeaters, groups and flexible content, and re-points internal links and reference fields at their translated targets.
- **`wp-tailwind-system` skill** — the utility-first decision ladder, `@theme` tokens, and file layout for `template=tailwind`. Tailwind projects finally have a skill of their own instead of borrowing `wp-css-system`.
- **`wp-tailwind` agent gains Section Authoring Mode**, replacing `wp-css` on the Tailwind path so sections are written as utilities in the markup rather than as a stylesheet.
- **`/wp-tailwind-migrate`** — convert an already-built plain-CSS theme to Tailwind-native in place, with a before/after responsive screenshot comparison.
- **`/wp-yolo` Step 2.6 converts the demo via `/wp-tailwindify`** before the section walk, so the section builders see Tailwind-native markup.
- **`bin/tailwind-native-check.sh`** — validates any Tailwind theme against the convention; run by `/wp-finalize` before delivery.
- **An explicit `Mode: **author**` dispatch line.** `/wp-section`, `/wp-page`, `/wp-cpt`, `/wp-header`, `/wp-footer` and `/wp-tailwind-migrate` now open every author-mode prompt with it, and `wp-tailwind` selects Section Authoring Mode on that line and nothing else.

### Fixed
- **Generated SCF/ACF field groups are now editable in the dashboard.** PHP-local `acf_add_local_field_group()` groups have no DB post, so they never appeared under Custom Fields → Field Groups and clients could not edit or extend them. Each starter theme's `acf/init` loader now treats `fields/*.php` as a one-time bootstrap per group: it registers the group only until `acf-json/<key>.json` exists, then persists it there. ACF/SCF auto-loads the local JSON and syncs dashboard edits back to the file, so groups stay both client-editable and versioned in code. Editing a group's PHP definition after the JSON exists requires the documented invalidation step.
- **`/wp-polylang` import no longer corrupts real content.** Payloads handed to WordPress are slashed, so backslashes survive a round trip instead of being stripped once per cycle; a manifest naming the wrong `target_id`, another site's `site_url`, or one menu as both source and target is refused instead of overwriting live content; a child whose parent has no counterpart stays dirty for the next run instead of being permanently stranded at the site root; term hierarchies survive re-import; a trashed counterpart is detected instead of reading as fully translated; an editor's own reference-field values are no longer re-derived away on every import; a reference the importer finds already correct is recorded as its own, so a later source change still reaches it instead of being refused forever; and a rewritten link keeps the `&amp;` separators its surrounding markup was written with.
- **`wp-bilingual` skill no longer claims the plugin does not support Polylang**, and now routes to the right skill based on the project's recorded strategy.
- **`/wp-init` no longer offers a starter template that does not exist.** "Basic Starter" was option 1 *and* the Enter-key default while `starter-theme/__starter__/` had been removed as superseded by Tailwind, so the most likely path through the command copied a missing directory. Tailwind is now the default, `basic` is accepted as an alias, and `tests/checks/wp-init-templates.sh` compares the command against the filesystem so it cannot rot again.
- **The Tailwind template was cosmetic.** `/wp-init` scaffolded a working Tailwind build, then every downstream command ignored `Template: tailwind` and dispatched `wp-css`, producing BEM CSS written to `assets/css/styles.css` — a file the Tailwind starter never enqueues. Themes shipped with no utility classes in their markup.
- **Comment-only starter stubs.** Five CSS files (`components/navigation.css`, `components/forms.css`, `layouts/{header,footer,sidebar}.css`) shipped containing only a comment, imported by `main.css` and never filled. Removed; a CSS file now exists only once it holds a rule.
- **`/wp-polish` wrote its backup where `/wp-seed` would find it.** The pre-polish copy went to `demo/original.html` / `demo/original-<filename>`, siblings of the demo pages, so the next `/wp-seed` turned each one into a phantom WordPress Page seeded from pre-polish markup. It now goes to `demo/.prepolish/<filename>`, and is written only if no copy is already there — the documented "overwrites if exists" meant a second polish destroyed the only unpolished version.
- **`wp-css-system` forbade Tailwind unconditionally**, so even Tailwind projects were told not to use it. Now scoped to `template=basic`, with `wp-tailwind-system` owning the other path.
- **The `wp-tailwind` agent had every tool, including `Bash`, while its own text said it had none.** Its frontmatter used `allowed-tools:` where all fourteen other agents use `name:` + `tools:`, so the key was ignored and the agent registered unrestricted — and `tests/checks/wp-tailwind-agent.sh` hard-required the wrong key, cementing it.
- **The agent picked its mode from a bare `author` token anywhere in the prompt.** The demo-conversion dispatch hands over an input file path, so an ordinary `demo/author.html` flipped the agent into Section Authoring Mode and that page was silently never converted. The gate now keys on the quoted `Mode: **author**` line, which a path cannot supply.
- **`/wp-init` re-introduced the demo-detection heuristic this branch exists to remove**, and all seven repo fixtures satisfied its skip condition — so it converted nothing, ever. Replaced with Step 2.6's evidence rule.
- **The delivery gate was invoked by a bare relative path.** Commands and agents run with the working directory set to the user's WordPress project, where `bin/tailwind-native-check.sh` resolves to nothing and exits 127 — the gate silently never ran. Every documented invocation is now rooted at `${CLAUDE_PLUGIN_ROOT}`.
- **`/wp-finalize`'s report never named the Tailwind convention check**, so a Tailwind theme could be reported "ready to deliver" without a word about the one gate that decides whether its markup carries any utility classes at all.
- **`/wp-header` and `/wp-footer` gained routing blocks but kept unrouted dispatch sites** whose bodies still told `wp-css` to write BEM rules into `assets/css/styles.css`, contradicting the block directly above them.
- **`bin/tailwind-native-check.sh` had four defects of its own.** The no-new-directory rule inspected only depth 1, so `components/parts/` passed; a commented-out `@import` satisfied the import rule and shipped the file unbuilt; a theme with all its CSS in `main.css` was rejected for an "unexpected directory `*`" that was just an unexpanded glob; and the three-template floor permanently failed a correct two-template theme while reporting a reason that was not true. The floor now scales to the templates present, and a compiled theme with no class-carrying template is its own explicit failure.
- **The delivery gate could die silently.** `hits=$(grep … | wc -l)` under `set -o pipefail` fails the assignment when `grep` matches nothing, and `set -e` then killed the script with exit 1 and no output — precisely on a compiled theme with zero utilities, the case that most needed a message.
- **`/wp-polish` and `/wp-yolo` attributed a literal `demo/*.html` glob to `/wp-seed`**, which states none; and each named only its own backup directory in the `find` caveat, so a folder both had touched left one of the two exposed.
- **`/wp-tailwind-migrate` restated the promotion ladder without its threshold**, telling an agent to promote a group it saw twice inside one section — which `wp-tailwind-system` keeps inline.
- **The upstream merge left two decision trees side by side in four commands**, and a `tailwind` + `polylang` project got contradictory instructions from each pair. `/wp-init` Step D4 carried two bullets with the same condition and two `@theme` targets, one of them a file the starter does not ship; `/wp-header`'s `wp-template` and `wp-acf` prompts ordered per-language menu locations and `_es` duplicates no matter the strategy; `/wp-finalize` Check 2, Check 4 item 5, Check 7 item 2 and Layer 2 item 3 demanded `_es` variants and suffix menu locations on every project, so a correct Polylang delivery failed all four; `/wp-yolo` Step 5 stated the suffix seed model unconditionally. All of them now branch on the recorded `i18n strategy`, with the polylang half of Check 2 running the same `pll-verify.php` the retrofit uses.
- **`/wp-finalize` Check 3 failed every correct Tailwind theme.** It read `assets/css/styles.css` and demanded `@media` at fixed pixel breakpoints — a file the convention check in the same command fails delivery for existing, and a mechanism the SKILL forbids — while promising "3 of 5" breakpoints it only listed 4 of. It now branches on `Template:`: `basic` keeps the media-query walk, `tailwind` verifies responsive prefixes in the markup.
- **`/wp-yolo` never named the cinematic template.** A reel project fell through Step 1, skipped conversion, ran the section walk, and got BEM CSS in a theme whose CSS is `cinematic.css`. Step 1 now refuses it and points at the `/wp-cinematic-*` flow; `/wp-header` and `/wp-finalize` state the same boundary instead of falling through.
- **The breakpoint table was inverted.** `agents/wp-tailwind.md` mapped `max-width: 640px` to a bare `sm:`, but bare Tailwind prefixes are min-width — every responsive rule fired on the wrong side of every breakpoint, and the markup still compiled so nothing downstream caught it.
- **The `@theme` lookup read a file with no values.** Colour mapping told the agent to read `.claude/CLAUDE.md`, which names `main.css` and holds zero hex literals, so the agent found nothing and shipped the default palette. It now reads the theme's `assets/css/src/tailwindcss/main.css`.
- **The delivery gate matched utilities as substrings**, so BEM names from this repo's own fixtures — `services__grid`, `team-archive__grid` — counted as Tailwind and a purely-BEM theme printed PASS. A utility is now a whole class token; the accepted ceiling (a hand-written `bg-image-holder` vs a token utility) is documented in the script.
- **The converted demo was an unstyled page the command told the user to review.** `/wp-tailwindify` now says plainly that the conversion is an intermediate artifact whose styling arrives with the theme build, instead of inviting a browser check of HTML with no CSS.
- **Preflight was never mentioned anywhere** and silently moved the baseline (`<button>` 13.33→16px, `<img>` inline→block, `<p>` margins zeroed, logo underline dropped). The SKILL now carries a Preflight section with the measured effects, and the conversion path names it.
- **Bare element selectors had no home.** `a {}`, `h1,h2,h3 {}`, `body {}` reached elements no class covers; the rehearsal reasoned one was dead and the computed diff proved it wrong. The SKILL now states where they land and how to check for the elements they reach.
- **Tailwind v4 specifics no document named**: the OKLCH palette (v4 `gray-300` is `#d1d5dc`, not a demo's `#d1d5db`), OKLab gradient interpolation, `bg-linear-to-r` vs v3's `bg-gradient-to-r`, and the pinned `^4.1.5` version. All named once, where utilities are chosen.
- **`mv` aliased to `mv -i` cost the rehearsal three pages silently**, with the loop reporting success. The conversion now specifies `\mv -f` and proves the move happened before reporting.
- **`wp-template` and `wp-tailwind` raced on one file with opposite class systems.** The ownership rule now stands in `/wp-section` and `/wp-header` (and its one-line summary matches it): `wp-template` writes the PHP on both paths, `wp-tailwind` runs after it and owns only class names — never beside it, never BEM in a Tailwind theme.
- **The delivery gate and its checks had a list of latent defects**, each closed with an executed proof: `/wp-tailwind-migrate` Step 6 resolved the theme path twice; `-mindepth 2` exempted every sibling of `main.css`; two checks exited 1 with no message on a zero-match grep; two gates were line-anchored and died on the next re-wrap; the directory-set gate misread brace notation; a region anchor with a trailing space disagreed with its sibling; a closure proof was file-wide instead of region-wide.

### Changed
- **The check suite grew from 19 to 33 checks.** Every contract this work added is gated by a grep-for-required-tokens script under `tests/checks/`, and each assertion carries three executed proofs: the inverted wording fails, the deleted wording fails, and a realistic correct edit — a re-wrap, a heading rename, a step renumbering, a synonym — stays green.

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
