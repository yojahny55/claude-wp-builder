# The executable code this plugin ships

Moved out of `CLAUDE.md`, which keeps the short version. Almost everything in the repo is
markdown; this is the rest.

The root `package.json` is dev tooling only, pinning the `playwright-core` that
`bin/demo-verify.mjs`, `bin/composition-preview.mjs` and the browser checks already import. It
is never shipped to a user's project and nothing in `commands/`, `agents/` or `skills/` requires
it — those tools each resolve it through a ladder and degrade when it is absent. It is committed
because the dependency existed either way and pinning it nowhere made "works on my machine" the
contract.

## `bin/*.sh`

Env setup, ffmpeg wrappers and gate scripts, invoked by commands: `wp-env-setup`,
`wp-cinematic-encode`, `composition-gate`, `doc-sync-check`, `geo-scan`,
`tailwind-native-check`, `tailwind-rebuild`, `design-md-index`, `domains-import`,
`store-kit-sync`, `changelog-release` (compiles `changes/*.md` at release), `audit-suite`
(scaffolds and runs the Playwright audit suite), `clone-preflight` (does the audited host
serve the site's own internal URLs), `prod-gate` (serializes and paces every audit request
to a production host) and `wp-quiet` (runs a WP-CLI command without the PHP diagnostics
a noisy plugin prints on stdout, keeping its exit code).

## `bin/*.mjs`

Node tools a command runs and reads the exit code of. These carry real logic, and several are
load-bearing gates rather than helpers:

- `wp-config.mjs` — the single definition of a valid `.wp-create.json`.
- `demo-verify.mjs` — the browser walk behind `/wp-demo-verify` and craft mode's probe,
  Chromium plus an existing Firefox; `css-contour-lint.mjs` is its static cross-engine companion.
- `tailwindify-parity.mjs` — computed-style comparison during CSS conversion.
- `image-gen.mjs` — the image generator and its cost/key handling.
- `composition-preview.mjs` — renders `skills/wp-demo-craft/compositions/` previews.
- `theme-template-check.mjs` — the ABSPATH, compiled-class and widget-script gate behind
  `/wp-finalize` Check 4 and the practices audit.
- `link-sweep.mjs` — the audits' link sweep, with the 4-in-flight cap, sampling, clone-origin
  and CDN-challenge rules built in.
- `h2-proxy.mjs` — HTTP/2 + brotli proxy in front of a local site for Lighthouse runs.
- `contrast-propose.mjs` — palette proposal for failing contrast pairs.
- `ux-probe.mjs` — the usability audit's page harness: one browser launch per run, built-in DOM
  probes, site probes from a module, and the 3-launch / 15-minute / 2-attempt budget enforced
  through a state file.
- `style-diff.mjs` — before/after computed-style snapshots and diff with a two-baseline noise
  filter: the measurement behind "a tag swap is a visual change".
- `section-diff.mjs` — one built section against its demo section, pixel by pixel per viewport
  (pixelmatch over the shared area, height delta apart), with demo, site and diff images.
- `theme-screenshot.mjs` — the theme's 1200x900 `screenshot.png` from the built homepage.
- `decision-sheet.mjs` — the approval page for `design_impact` findings and the parser for its
  answers.
- `audit-report.mjs` — renders an audit run into a dated Markdown and HTML deliverable.
- `audit-coverage.mjs` — `/wp-audit` Step 6.8: how much of each agent's catalog the run executed.
- `audit-runbook.mjs` — renders the replay record of an audit's fixes as an ordered production
  runbook.
- `assets-fresh.mjs` — fails when a theme's critical CSS cuts no longer match the sheet they
  were cut from.
- `wp-status.mjs` — the read-only `/wp-status` report.
- `demo-sections.mjs` — the read-only `/wp-section --list`: a demo's sections and delimiter
  defects.
- `family-lint.mjs` — glass, rounded bordered cards and extra accents in a craft demo, reported
  to the `/wp-demo` critique and never blocking.

`bin/lib/` holds what they share.

## PHP and the rest

- `skills/wp-polylang/scripts/*.php` and `skills/wp-woocommerce/scripts/*.php` — run inside a
  real WordPress via `wp eval-file`.
- `plugins/store-kit/` — a WordPress plugin copied into stores by `/wp-create` and
  `/wp-woo-setup` through `bin/store-kit-sync.sh`: catalog mode, and Stripe keys read from
  `wp-config.php` instead of the database. Held to the PHP 7.4 floor, and exercised against a
  real WooCommerce in the fixture.
- `starter-theme/**` — PHP copied into user projects (never executed here).
- `templates/agentic/agentic.php` — the theme's `inc/agentic.php`, copied whole by the
  `wp-agentic-surfaces` agent with its tokens substituted (never executed here).
