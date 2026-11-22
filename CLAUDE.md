# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **Claude Code plugin**, not an application. Almost everything here is markdown that instructs
Claude at runtime — commands, agents and skills. There is no build step and no runtime for the
plugin itself; the root `package.json` is dev tooling only, pinning the `playwright-core` that
`bin/demo-verify.mjs`, `bin/composition-preview.mjs` and the browser checks already import. It
is never shipped to a user's project and nothing in `commands/`, `agents/` or `skills/` requires
it — those tools each resolve it through a ladder and degrade when it is absent. It is committed
because the dependency existed either way and pinning it nowhere made "works on my machine" the
contract. The only executable code shipped is:

- `bin/*.sh` — env setup, ffmpeg wrappers and gate scripts, invoked by commands:
  `wp-env-setup`, `wp-cinematic-encode`, `composition-gate`, `doc-sync-check`, `geo-scan`,
  `tailwind-native-check`, `tailwind-rebuild`, `design-md-index`, `domains-import`,
  `store-kit-sync`, `changelog-release` (compiles `changes/*.md` at release), `audit-suite`
  (scaffolds and runs the Playwright audit suite), `clone-preflight` (does the audited host
  serve the site's own internal URLs), `prod-gate` (serializes and paces every audit request
  to a production host) and `wp-quiet` (runs a WP-CLI command without the PHP diagnostics
  a noisy plugin prints on stdout, keeping its exit code).
- `bin/*.mjs` — Node tools a command runs and reads the exit code of. These carry
  real logic, and several are load-bearing gates rather than helpers:
  `wp-config.mjs` (the single definition of a valid `.wp-create.json`), `demo-verify.mjs` (the browser walk behind `/wp-demo-verify`
  and craft mode's probe, Chromium plus an existing Firefox; `css-contour-lint.mjs` is its
  static cross-engine companion), `tailwindify-parity.mjs` (computed-style comparison during
  CSS conversion), `image-gen.mjs` (the image generator and its cost/key handling),
  `composition-preview.mjs` (renders `skills/wp-demo-craft/compositions/` previews),
  `theme-template-check.mjs` (the ABSPATH, compiled-class and widget-script gate behind
  `/wp-finalize` Check 4 and the practices audit), `link-sweep.mjs` (the audits' link
  sweep, with the 4-in-flight cap, sampling, clone-origin and CDN-challenge rules built in),
  `h2-proxy.mjs` (HTTP/2 + brotli proxy in front of a local site for Lighthouse runs),
  `contrast-propose.mjs` (palette proposal for failing contrast pairs),
  `ux-probe.mjs` (the usability audit's page harness: one browser launch per run, built-in
  DOM probes, site probes from a module, and the 3-launch / 15-minute / 2-attempt budget
  enforced through a state file), `style-diff.mjs` (before/after computed-style snapshots and
  diff with a two-baseline noise filter: the measurement behind "a tag swap is a visual change"),
  `decision-sheet.mjs` (the approval page for `design_impact` findings and the parser for its
  answers), `audit-report.mjs` (renders an audit run into a dated Markdown and HTML deliverable),
  `audit-coverage.mjs` (`/wp-audit` Step 6.8: how much of each agent's catalog the run executed),
  `audit-runbook.mjs` (renders the replay record of an audit's fixes as an ordered production
  runbook) and `assets-fresh.mjs` (fails when a theme's critical CSS cuts no longer match the
  sheet they were cut from).
  `bin/lib/` holds what they share.
- `skills/wp-polylang/scripts/*.php` and `skills/wp-woocommerce/scripts/*.php` — run inside a
  real WordPress via `wp eval-file`
- `plugins/store-kit/` — a WordPress plugin copied into stores by `/wp-create` and
  `/wp-woo-setup` through `bin/store-kit-sync.sh`: catalog mode, and Stripe keys read from
  `wp-config.php` instead of the database. Held to the PHP 7.4 floor, and exercised against a
  real WooCommerce in the fixture.
- `starter-theme/**` — PHP copied into user projects (never executed here)
- `templates/agentic/agentic.php` — the theme's `inc/agentic.php`, copied whole by the
  `wp-agentic-surfaces` agent with its tokens substituted (never executed here)

Editing a "feature" therefore usually means editing prose contracts, and the tests assert on
those contracts (grep for required tokens in the markdown), not on program behavior.

## Testing

Each check is a standalone bash script that prints `PASS` or exits non-zero. No framework.

```bash
bash tests/checks/wp-yolo-gate.sh        # one check
bash tests/run.sh -j 8                   # all checks in parallel; --exclude "a.sh b.sh" skips some
```

`tests/run.sh` runs every check and then reports (it does not stop at the first red) and counts
`SKIP` separately from `PASS`. Browser checks print that the browser path was NOT exercised unless
a `playwright-core` is found; point `PLAYWRIGHT_CORE` at one already on the machine (for example
`$(npm root -g)/@playwright/test/node_modules/playwright-core`) rather than installing one. Checks
that need a real WordPress skip unless `WP_FIXTURE=1` (a disposable install built by
`tests/fixtures/wp/provision.sh`) or `PLL_TEST_SITE` is set.

CI runs the same suite plus `node --check` on `bin/*.mjs`, `bash -n` and `shellcheck` on shell
scripts, `bin/doc-sync-check.sh` and `php -l`. **The PHP lint is pinned to 7.4** (8.0 for
`starter-theme/__cinematic__/`), because those scripts run inside whatever WordPress the client
has and `php -l` on 8.x accepts `match` and union types that are fatal on 7.4: a default-version
lint would be green and wrong. Run the checks yourself before claiming a change works.

Detail (the WordPress fixture and its `net-guard`, the CF7 delivery check, visual baselines, what
no check covers): `docs/testing.md`.

## Architecture

Four layers, strictly ordered:

```
commands/*.md   user-facing slash commands — orchestration, argument parsing, step-by-step flow
   ↓ dispatches
agents/*.md     specialized subagents (wp-template, wp-css, wp-acf, wp-audit-*, wp-normalize…)
   ↓ reads
skills/*/SKILL.md   knowledge libraries — methodology, never actions. user-invocable: false
   ↓ produces
starter-theme/ + templates/   PHP theme scaffolds and env/plugin-profile configs copied per project
```

Key consequences when changing things:

- A command must not reimplement a builder. `/wp-yolo` is the model: it normalizes the demo once,
  then drives the existing commands/agents in dependency order.
- Every agent's first mandatory step is to read the **project's** `.claude/CLAUDE.md` (generated by
  `/wp-init` in the user's WordPress project — a different file from this one) to pick up the
  function prefix, languages and theme slug. `prefix_` in agent/skill docs is a placeholder.
- Plugin-relative paths in commands are always `${CLAUDE_PLUGIN_ROOT}/…`, never relative.
- The `.wp-create.json` manifest in a user project is the shared source of truth for the WP-CLI
  wrapper, environment type and language config — commands read it instead of re-asking.

### Two independent i18n systems — do not mix them

| | `wp-bilingual` skill | `wp-polylang` skill |
|---|---|---|
| Model | one page, ACF field `_<lang>` suffixes (`hero_title_es`) | one post per language, joined by translation groups |
| Helpers | `prefix_get_field()`, `prefix_t()`, `prefix_e()` resolve the suffix transparently | `pll_*` API via `wp eval-file` scripts |
| Used by | `/wp-init` when `i18n strategy: suffix`, `/wp-section`, `/wp-seed` | `/wp-init` when `i18n strategy: polylang` (**the default**), and `/wp-polylang` to retrofit an existing site |

**Which one a project uses is a recorded decision, not a guess.** `/wp-init`
asks (Step 0.7) and writes the answer as `i18n strategy` into the project's
`.claude/CLAUDE.md`. Every downstream command and agent branches on that line —
`/wp-seed`, `/wp-header`, `wp-acf`, `/wp-yolo` — so read it before assuming the
suffix model. When the line is absent, the project predates the choice and is
`suffix`.

The seam is a single file, `inc/i18n.php`: templates call `prefix_get_field()` and friends and
never `get_field()` directly, so swapping that file switches the theme's model. The Polylang
variants live in `starter-theme/_i18n-variants/` and are copied over it by `/wp-init`. Under
Polylang, ACF options-page fields keep their `_<lang>` suffixes. Why Polylang is the default
(SEO), its failure modes and the pure-PHP test of `pll-lib.php`: `docs/architecture.md`.

### Craft vs plain is a recorded decision

`/wp-demo` (and `/wp-yolo`) choose craft or plain mode from the project's docs and write the
answer as `demo mode` into `.wp-create.json`. Every downstream command branches on that line
(`/wp-init`, `/wp-section`, `/wp-finalize`), so read it instead of re-deriving it. Craft builds
read `skills/wp-demo-craft/` and ship GSAP plus `motion.js` in the theme bundle; plain builds
ship neither and use the `wp-aos-animator` skill instead. When the line is absent, the project
predates the choice and is `plain`.

Craft mode has a hard prerequisite: a browser. `/wp-demo` probes with
`bin/demo-verify.mjs --probe` and stops on exit 2; it never builds blind and never
falls back to plain. A craft build writes two files: `demo/BRIEF.md` (the story) and
`demo/DESIGN.md` (tokens, in the open Stitch DESIGN.md format). `/wp-init` reads
`demo/DESIGN.md` before scraping `:root`, and copies it into the theme. Sections are
built from `skills/wp-demo-craft/compositions/` (previews rendered against the
neutral `references/design-md/_preview.md`), and verified by `npx impeccable detect`
plus the seven-line rubric in `references/verify.md`, at most three rounds.

How the compositions' tokens map onto the starter's (aliases by role, `## Token aliases`):
`docs/architecture.md`.

### A store is a recorded decision

A WooCommerce store records what it sells in the `store` block of `.wp-create.json` — tier
(`catalog`, `store`, `full`), address, currency, checkout type, shipping, tax, Stripe in test
mode — validated by `bin/wp-config.mjs` like every other manifest field, with the Stripe keys
as secrets beside the database password. `/wp-woo-setup` writes the block and runs
`skills/wp-woocommerce/scripts/woo-setup.php`, which brings WooCommerce in line with it. The
script records a hash of every value it writes in `store_kit_setup_state`, so a value that no
longer matches is the client's and is left alone unless `force` is passed — except launch state
(coming soon, Stripe enabled and test mode, cash on delivery), which `force` never writes on a
store that already has orders, even when the row is absent. `/wp-audit` reads `store.tier`, so a catalog is never scored for a checkout it does not have.
What `plugins/store-kit/` owns: `docs/architecture.md`.

## Authoring conventions

**Command** (`commands/<name>.md`) — frontmatter with `description`, `allowed-tools`,
`argument-hint`. Add `Agent` to `allowed-tools` only if it dispatches subagents.
A command is read whole on every run, so a long step keeps its heading and entry condition in
the command and moves its detail to `skills/<command>-run/references/<step>.md`, read at that
step (`/wp-audit` with `wp-audit-run`, `/wp-yolo` with `wp-yolo-run`, `/wp-demo` with `wp-demo-run`, `/wp-init` with `wp-init-run`, `/wp-seed` with `wp-seed-run`, `/wp-create` with `wp-create-run`, `/wp-finalize` with `wp-finalize-run`, `/wp-section` with `wp-section-run`, `/wp-clone` with `wp-clone-run`, `/wp-page` with `wp-page-run`, `/wp-demo-verify` with `wp-demo-verify-run`, `/wp-header` with `wp-header-run`, `/wp-tailwind-migrate` with `wp-tailwind-migrate-run`, and `/wp-tailwindify` with `wp-tailwindify-run`, are the model). Not a `commands/` subfolder: those load as extra slash commands.
Checks read such a command through `tests/checks/lib/expand-command.sh`, which splices in only
the command's own `<command>-run` references.

**Agent** (`agents/<name>.md`) — frontmatter `name`, `description`, `tools`, `model` (`opus`|`sonnet`|`haiku` — cost tier, see `tests/checks/model-routing.sh`) (order:
`Read, Write, Edit, Grep, Glob, Bash`). Must open with the "First Action (MANDATORY)" block,
and return `BLOCKED: <reason>` plus the files it touched when it cannot proceed, never a guess
(contract and exceptions: `skills/wp-contributing/SKILL.md` § Agent contracts).

**Skill** (`skills/<name>/SKILL.md`) — frontmatter `name`, `description`, `user-invocable: false`.
Skills inform; they never act. The description says what the skill does and ends with a
"Use when …" clause — it is the only text Claude reads before loading the skill. Keep the body
under 500 lines and put templates, long samples and catalogs in `references/`, named from
SKILL.md (`tests/checks/skill-authoring.sh`).

**Starter theme edits** — use the placeholder tokens (`__starter__`, `__STARTER__`,
`__STARTER_NAME__`), replaced by `/wp-init`.

**New behavior needs a check.** The house style is a grep-for-required-tokens script under
`tests/checks/` that fails if the contract wording disappears from the command/skill/agent.
Under `set -o pipefail` a check never ends a pipe in `grep -q` or `head`: the reader exits early,
the producer dies of SIGPIPE and the check fails at random on a busy runner. Use
`grep >/dev/null -c` and `sed -n 1p` (`tests/checks/no-early-exit-pipes.sh` enforces it).

## Generated-theme conventions (what the agents must emit)

- Fields: `<section>_<element>` / repeaters `<section>_<plural>` / keys `field_<section>_<element>`,
  `group_<section>`; bilingual duplicates append `_<lang>`.
- Templates: always `prefix_get_field()` (never raw `get_field()`), `?:` fallbacks, everything
  escaped (`esc_html`, `esc_url`, `esc_attr`).
- CSS: custom properties for all tokens, BEM, mobile-first `min-width` queries, section delimiters
  `/* ====== Section: Hero ====== */`. In transcription mode (`--transcribe`, `/wp-yolo`) agents copy
  the demo's exact declared values instead of re-authoring them, and scope every selector under a
  unique BEM block so parallel section builds cannot collide.
- Prefer WP-CLI over generating PHP (`wp-cli-patterns` skill).

## Release chores

Version lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (twice) and the
README badge — bump all of them together. Add a `changes/<slug>.<section>.md` fragment (format
in `changes/README.md`) and never edit `CHANGELOG.md` in a PR; update `README.md` when adding a
command.

**Reconcile `BACKLOG.md` as part of cutting the release**, and update its `**Reconciled** on`
line. `tests/checks/backlog-freshness.sh` fails when the newest release in the CHANGELOG is
dated after that line, so this is a gate rather than a good intention. It became one because
the last hand reconciliation went stale in a single day: three releases shipped a clone
anonymiser, resumable builds, a findings ledger, ACF nesting and a WordPress fixture, and the
backlog mentioned none of them. The check cannot tell whether a reconciliation was any good —
only that one happened, which is the part that kept being skipped.

**Changelog entries are fragments, compiled at release.** `bin/changelog-release.sh X.Y.Z`
turns `changes/*.md` into a `## [X.Y.Z] - date` block inserted *below* `## [Unreleased]` and
deletes the fragments; entries already under `[Unreleased]` are carried into the block. It never
renames `## [Unreleased]`, which stays as an empty anchor at the top. Fragments exist because
PRs that all insert under one heading conflict with each other once any one merges, and GitHub
ignores `merge=union`, so the old workaround only worked in a local `git merge`.
`tests/checks/changelog-fragments.sh` pins the format and runs the script on a scratch copy.

## Known ceilings

Deliberate, documented limits — not bugs to fix on sight. Before "fixing" something that looks like
a bug in one of these areas, read its entry in `docs/known-ceilings.md`:

- Clone and anonymize: a clone carries data never code, the backup is a database export only,
  isolation is partial, `/wp-anonymize` rewrites a catalog not a database.
- Seed: records and field values are owned separately, media deduplicates by source, default
  records and menu items follow narrow rules.
- Yolo resume and settings: a resumed build trusts its own output, drift is detected per file.
- i18n and Polylang: media is not translated, ACF references recurse, parents mirror the source,
  tagline and fonts are written once, the Polylang branching is verified by grep.
- Craft, compositions and motion: ports not copies, container-relative sizing, the two `reveal`
  paths, headless evaluation, previews need the network, `unobserved` is a confession.
- Image generation: the HTTP call is uncovered, costs are estimates, aspect fidelity varies,
  plates are watermarked.
- Audit: checks are contract greps, coverage is tracked per check, a ledger identifies findings.
- Research and inspo: quality is judgment not machinery, the network halves are uncovered,
  inspo is opt-in.
- Manifest and validator: the validator binds the commands that call it, adoption is a heuristic,
  credentials are only as private as the local file.
- Store: constant-supplied keys cover Stripe only, setup ownership is by value hash, native WP-CLI only.
