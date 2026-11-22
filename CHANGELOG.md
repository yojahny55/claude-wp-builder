# Changelog

## [Unreleased]

## [1.34.0] - 2026-11-22

### Added

- **Documented exit-code table for every `bin/*.mjs` tool.** `bin/lib/exit-codes.mjs`
  (`COMMON` for new tools, `TOOLS` with the codes each existing tool really returns) and
  `docs/exit-codes.md` record them without renumbering anything, since commands and checks
  read the numbers in prose. `tests/checks/exit-code-table.sh` fails when a tool exits with
  an undeclared code or the table and the doc drift apart.

- **`/wp-backup` and `/wp-restore`.** One verified backup script (`bin/wp-backup.sh`) replaces
  the three hand-written database exports in `/wp-update`, `/wp-clone` and `/wp-anonymize`,
  which had different permissions, no check of the dump and no uploads. The dump must start
  with a SQL header and end with its `Dump completed` footer (a PHP notice printed by the
  wrapper fails it), is written to a temp name and renamed only when complete, and the folder
  is `<slug>-<timestamp>`, 700/600, always outside the WordPress root, with sha256 sums plus
  table and post counts in `backup.json`. `/wp-restore` verifies the sums, refuses another
  database name or site URL unless `--yes`, takes a pre-restore copy, imports, swaps uploads
  with a way back, and fails unless the site URL, table count and post count match afterwards,
  printing the command to return to the pre-restore copy.

- **`/wp-status`: where the project is and what runs next.** A read-only command backed by
  `bin/wp-status.mjs` reads `.wp-create.json`, `.claude/CLAUDE.md`, `demo/` (including
  `FAILED.md`), the `/wp-yolo` build ledger and the audit findings ledger, and ends with
  `Next: <command> - <reason>`. It writes nothing, runs no WP-CLI and uses no network;
  `--json` gives the same report for scripts. Exit 0 whenever a report prints, 64 on bad usage.

### Changed

- **`wp-agentic-surfaces` follows the BLOCKED contract.** Without a readable `.claude/CLAUDE.md`
  that records the function prefix and theme path it stops and returns `BLOCKED: <reason>`
  plus the files it touched, instead of guessing a prefix into `inc/agentic.php`.
  `agent-contracts.sh` now includes it in the BLOCKED list.

- **`wp-agentic-surfaces` copies its PHP instead of rewriting it.** The ~700 lines of
  `inc/agentic.php` that lived inside the agent's markdown are now `templates/agentic/agentic.php`,
  copied with two tokens (`__prefix__`, `__SITE_TYPE__`) substituted. CI's `php -l` at the 7.4
  floor now covers that file, which it never did while the code sat in a fenced block, so a run can
  no longer drift from the floor. The emitted file is byte-identical to what the agent produced.

- **Check hygiene.** `tests/lib/assert.sh` gives checks `fail`, `skip`, `need_token` and
  `require_tool` (SKIP, not a confusing FAIL, when php, python3 or curl is missing;
  `CHECKS_REQUIRE_TOOLS=1` in CI turns that back into a failure). The composition-gate check
  SKIPs when the impeccable detector cannot start offline instead of failing. The 27 checks
  that ran without `set -e` now run under `set -euo pipefail`, `cd` failures stop them, and
  the re-audit check writes its probe to a temp dir. Every check is executable in git, and
  `assert-lib-adoption.sh` freezes the checks that still define their own `fail()`.

- **CI and test-harness coverage.** CI jobs pin `runs-on: ubuntu-24.04` instead of the floating
  `ubuntu-latest`. New `tests/mutation.sh` (manual tool) deletes a required token from a copy
  of the repo and reports contract checks that still pass, with `tests/checks/mutation-harness.sh`
  guarding it. `seeded-defects.sh` now compares against a committed recorded audit
  (`recorded-findings.json`, plus a negative case), so the comparison runs in CI without
  `SEEDED_FINDINGS`.

- **The impeccable detector follows the newest release.** Every call is now `npx -y impeccable@latest`
  instead of a major-version pin, on purpose. `bin/composition-gate.sh` refuses detector output it
  does not understand (a finding that is not an object, one missing `antipattern` or `file`, a
  `category` outside slop/quality or a `severity` outside warning/advisory) and exits 1 instead of
  passing it. The checks now fail on any numeric `impeccable@` pin.
  The gate also keeps the detector's exit code: anything but 0 or 2, or a code that
  disagrees with the payload, is "could not scan", and so is a wrapper object with keys
  besides `findings`. `/wp-demo-verify`'s detector step states the same rule.

- **`wp-audit-rankmath` now runs on sonnet, and its long scripts moved to references.** The agent
  settles schema conflicts, title quality, the JSON-LD merge and the Polylang route, which is
  judgment rather than mechanical config, so it leaves the haiku tier (`/wp-yolo` model routing
  and the README follow). The code of Steps 5.5, 8.5, 12 and 15 now lives in
  `skills/wp-audit-seo-standards/references/rankmath-*.md`; the agent keeps each step's
  condition, rules and a pointer, and the checks that grepped those tokens now read the
  reference and require the pointer.

- Repository docs sweep. The README no longer names a `/wp-woo-verify` command that does not exist, and gains an update/uninstall note, a per-command requirements matrix and a troubleshooting table. `bin/doc-sync-check.sh` now fails when README.md or any `docs/*.md` cites a `/wp-<name>` that has no `commands/<name>.md` (family prefixes ending in `-` and an explicit exclusion list aside). `docs/README.md` indexes every document in `docs/`, and `tests/checks/docs-index.sh` fails when one is missing. Releases before 1.30.0 moved verbatim from `CHANGELOG.md` to `docs/changelog-archive.md`, with a link left behind. `TODO.md` (a deprecated pointer) and `docs/finds/audit` (a pasted terminal transcript) are removed. `SECURITY.md` now sends sensitive reports to the maintainer privately first and covers `store-kit`, Stripe keys, clone and anonymizer data, and image API keys. `wp-contributing` documents the manual tag and `gh release` sequence.

### Fixed

- **Agent contracts stated once and enforced.** `wp-tailwind` now has a First Action block
  (author mode reads the project file; conversion mode may run with no project), and
  `wp-context` and `wp-normalize` document why they have none. The agents that read the
  project file return `BLOCKED: <reason>` plus touched files instead of guessing a prefix;
  auditors (security and usability included) keep their JSON and add a `"blocked"` key, which
  `/wp-audit` re-dispatches once and, if still blocked, names in the `INCOMPLETE` report. `wp-audit-aios` and `wp-audit-rankmath`
  say they write, and `wp-contributing` explains the `wp-audit-*` prefix. FAQ schema is
  seeded only for visible questions, with no rich-result promise, and the demo-craft devices
  reference says where GSAP comes from and points to its license.
- The normalize agent captures `cssRules` when the project file or its `Template:` line is
  absent, and the CSS agent's blocked rule no longer contradicts its own instruction to add
  missing `:root` definitions.

- **Command cross-references, the craft gate, the model table and the flag vocabulary.**
  `/wp-update` and `/wp-polish` cited "Step 5.3", "Step 1.2" and "Step 3.1", which are list
  items, not headings, so a run looking for them found nothing; they now read "Step 5, item 3",
  and `tests/checks/step-refs-resolve.sh` fails on any `Step N.M` a command cites without a
  heading, and on an unqualified citation of another command's step. The craft gate no
  longer runs `npm i -D playwright-core` in the WordPress project on probe exit 2: it points
  `PLAYWRIGHT_CORE` at a copy already on the machine, and installs only after the user says yes.
  `/wp-yolo`'s model routing list now names every agent (it omitted `wp-audit-geo`,
  `wp-audit-ux`, `wp-agentic-surfaces` and `wp-research`), and `model-routing.sh` checks it
  against each agent's frontmatter. `skills/wp-contributing/references/flag-vocabulary.md` fixes
  what `--yes`, `--force`, `--dry-run` and `--resume` mean and lists the existing exceptions.

- **Env setup and encoder edge cases.** `wp-env-setup.sh detect` runs `npx --no-install`, so a
  detection pass can no longer download `@wordpress/env`; `is_running` returns the real state
  (`mariadb || mysql` now reaches the second service); empty arrays are guarded for bash 3.2.
  `wp-cinematic-encode.sh` exits 1 without importing when the all-keyframe check fails, refuses
  `--desktop-only --mobile-only` (exit 2), expands a leading `~` in `--kit` and resolves
  `--theme` to an absolute path. The Lando template no longer points at a `php.ini` nothing
  creates, and the `store-kit-sync.sh` comment no longer claims the swap has no gap.

- `/wp-finalize` example report now adds up and lists the parity layers; the no-manifest variants are gone because exit 3 is the `stop` policy. `/wp-create` states that an existing manifest (2b) is handled before Adopt Mode (2a), and Overwrite exports the database and asks for confirmation naming the database and core before download. `/wp-seed` names its own `bare-wp-fallback` policy.

- **Suffix-model language no longer leaks through page caches, and Accept-Language reads
  q-values.** Both starters' `inc/i18n.php` (Tailwind and cinematic) send
  `Vary: Accept-Language, Cookie` on front-end responses, and keep a response out of
  WordPress page caches (`DONOTCACHEPAGE` plus `nocache_headers()`) when it is not the
  default language or carries `?lang`; before, the first visitor's language could be cached
  and served to everyone. `fr,es;q=0.9` now resolves to Spanish instead of the default; an
  unsupported `?lang` falls through to the cookie in both starters (the cinematic one reset
  it to English); and the `<html lang>` rewrite no longer reaches wp-admin or the login
  screen. Check `theme-i18n-request-lang.sh` runs both resolvers under stubbed WordPress.

- **Index and import scripts no longer truncate versioned files, and the gate no longer skips a bad composition.**
  `design-md-index.sh` and `domains-import.sh` wrote straight into tracked files, so a
  python or awk failure midway left them truncated (and `domains-import.sh` had already
  replaced the licence and source record). Both now build into temporaries and rename at
  the end, with a trap removing leftovers. `design-md-index.sh` matches `api` and `car` as
  whole words instead of inside "capital", "rapid", "card" or "care", which mislabelled
  industries. `composition-gate.sh` treats a composition missing `section.html` or
  `section.css` as a failure (exit 1, like truncated content) instead of skipping it.

- **One definition of a local host, and it no longer trusts `*.local.com` by name.**
  `prod-gate.sh`, `audit-suite.sh` and `geo-scan.sh` each kept their own list, and all
  three treated any `*.local.com` as development although `local.com` is a public domain
  (a production host there skipped the gate, got 4 workers, and was refused by the GEO
  scan). They now share `bin/lib/local-host.sh`: reserved suffixes (`.test`, `.local`,
  `.internal`, `.lan`, `.home.arpa`, `.example`, `.invalid`, `localhost`) and private IP
  literals by octet are local by name; any other name is local only when every address it
  resolves to is loopback or private, and an unresolved name is not local. `geo-scan.sh`
  also lower-cases the host and no longer matches `10.example.com` with a prefix glob.
  `audit-suite.sh` empties `results/audit/*.json` at the start of a run, so a run over
  fewer pages no longer reports the pages of an earlier one; with `--only` it empties only
  that pass's files, so separate passes still add up to one report. `prod-gate.sh` falls back to
  a symlink-to-pid lock where `flock` is missing (macOS) instead of exiting 1; a lock it
  cannot create (read-only state dir, name too long) exits 1 with `cannot create lock`
  instead of spinning, and its
  header documents that the wrapped command's own exit 4 or 5 is indistinguishable from
  the gate's.

- **A hung resolver no longer hangs the production gate, and the design-md index keeps
  its hand corrections.** `bin/lib/local-host.sh` runs `getent ahosts` under `timeout 3`
  when `timeout` exists; a lookup that times out resolves to nothing, which is the
  not-local side. `bin/design-md-index.sh` reads hand corrections from
  `references/design-md/INDEX.overrides` (`<domain> <industry> [<tone>]` per line) and
  applies them after its keyword heuristic, so regenerating `INDEX.md` no longer erases
  the twelve rows that had been fixed by hand. An override naming a domain with no
  DESIGN.md fails the run, and a check fails when the versioned `INDEX.md` differs from a
  regeneration.

- **The last early-exit readers under `pipefail` are gone, and the check now sees them.**
  `bin/clone-preflight.sh` read the `Server` header with `tr | awk '…exit'`, which died with
  141 under `set -e` when the headers outgrew the pipe buffer after that line;
  `bin/audit-suite.sh` reported a Playwright CLI that does not load with `| grep -m3 … ||
  tail -3`, so an early grep could SIGPIPE `printf` and print the tail after the matches; and
  `bin/tailwind-rebuild.sh` read a watcher's `-o` the same racy way. Each reader now
  consumes all of its input. `tests/checks/no-early-exit-pipes.sh` also flags `| grep -m`
  and a piped awk whose program exits outside `END`, and its self-test runs the same program
  as the scan.

## [1.33.0] - 2026-11-21

### Changed

- **`CLAUDE.md` is down from 805 lines to about 245.** It loads into every session, and the
  history behind each rule was paid for on every task. The testing detail, the architecture
  reasoning and every known ceiling moved verbatim to `docs/testing.md`,
  `docs/architecture.md` and `docs/known-ceilings.md`, and `CLAUDE.md` keeps the rules, the
  recorded-decision lines and a pointer to each. The `bin/` list now names every script, and the
  fixed counts of compositions, roles and audit checks are gone in favour of their source of
  truth. The checks that read the moved text follow it, and the zero-occurrence controls now
  read both files, so they cannot pass on a file that no longer holds the text;
  `tests/checks/claude-md-budget.sh` holds the size cap.

### Fixed

- **`/wp-audit` scores each defect once, audits to WCAG 2.2 AA, and no longer writes reports
  into the site.** The accessibility auditor now targets WCAG 2.2 AA and tabulates the new
  criteria as A11Y-070 to A11Y-074 (focus obscured, accessible authentication, dragging
  movements, redundant entry and consistent help, the last two at level A). The PHP version floor is `>= 8.2`, written
  only in SEC-026 and in the new "Same defect, one owner" table; PERF-040 and WP-042 point at
  it. That table names the owner of defects listed under several ids (PHP floor, XML-RPC,
  `WP_DEBUG`, escaping, dangerous functions, `wp_body_open`, image alt) and the `root_cause`
  slug owner and duplicates share, so the report's existing root-cause fold counts the defect
  once; a defect only the duplicate finds is still reported, at the owner's severity, and a
  folded id stays `still_failing` in the ledger. Rules that now report differently carry a
  revision (`SEC-026@2`, `SEC-008@2`, `PERF-029@2`, `PERF-040@2`, `WP-042@2`), and SEC-008
  joins WP-040 under the local-clone `INFO` ceiling. The SEO, accessibility and GEO auditors
  return their findings to the parent instead of writing `audit/` or `audit-results/` files
  inside the site. Unused and retired check ids are listed and never reused; new usability
  ids start after UX-058.

- **The audit report and runbook tools no longer trust their input.** A category named like an object property (`constructor`) no longer renders function source in the report; `--help` and `--flag=value` work; archiving an earlier same-day run is all or nothing; a malformed `.wp-create.json` aborts the runbook instead of being treated as absent, and a relative `audit.out_dir` resolves against the site root in both tools (`--root` for the runbook, `--site-root` for the report) instead of the working directory.

- **Browser tools reject bad input instead of crashing.** `demo-verify.mjs` exits 1 with a one-line message when `--widths` or `--out` has no value or `--widths` is not `WIDTHxHEIGHT` (a last-argument flag threw an uncaught TypeError, and `--widths 1440` made every page crash on `NaN`), and it now closes each page's browser contexts in a `finally`, so a page that throws mid-walk no longer leaks them. `tailwindify-parity.mjs` exits 3 with a clear message when the two trees share no ancestor below the filesystem root, instead of serving `/`, and its local server now answers only inside the two trees (and the targets of their top-level symlinks, such as `.original/css`), not the rest of their common ancestor. `composition-preview.mjs --tokens` reports a bad preview token through the existing crash path (exit 3) instead of a raw stack.

- `bin/wp-config.mjs` refuses a flag it does not know instead of ignoring it. `adopt`,
  `code-home`, `env-set`, `git-init`, `keep-inactive` and `require-origin` each name the
  flags they accept; a typo (`adopt --replce`), a space instead of `=` (`--branch main`) or
  an uppercase name now exits 1 with the flag named and nothing done, where it used to run
  as if the flag had never been passed.
- `demo-verify`, `composition-preview` and `tailwindify-parity` resolve Chromium through
  `bin/lib/browsers.mjs` like every other tool, so they prefer the revision playwright-core
  pins over the system Chrome and read `WP_BROWSER_CHROMIUM`. `WP_DEMO_CHROME` is still
  honoured as its older name when it points at an executable.

- **Commands now declare what they use, in an order that refuses before it asks.** `/wp-init`
  validated the manifest and stopped on `demo/FAILED.md` only after it had asked the template,
  custom-fields and i18n questions, and could dispatch to `/wp-cinematic-init` first; both
  refusals now come before any question or dispatch. `/wp-init` and `/wp-polylang` declare
  `AskUserQuestion` and `/wp-demo-verify` declares `Agent`. Argument hints list the flags the
  bodies accept (`/wp-yolo`, `/wp-init`, `/wp-section`, `/wp-demo-verify`,
  `/wp-responsive-check`, `/wp-contribute`). The five `/wp-cinematic-*` commands move from
  `name:`/`arguments:` to the standard frontmatter, `/wp-cinematic-demo` takes `--no-hybrid`
  like the rest, and `/wp-cinematic-init` no longer points at a nonexistent `--update-kit`.
  `tests/checks/command-frontmatter.sh` and `tests/checks/wp-init-order.sh` pin all of it.

- **decision-sheet and style-diff stop dropping things silently.** A sidecar finding with the same `check` as a proposal but on another page now gets its own card instead of being skipped (a site-wide finding with no page is still covered by its check's proposal, and exact page matches are made first so the sidecar's order does not matter); a `--proposals` or `--against` file that parses but is not a list of objects is a usage error (exit 2) instead of a crash; `--parse` warns on stderr about any `DECISION` line it cannot read inside the block (for example no `|` after the option) and exits 1, while text outside a block is ignored whenever the paste holds one (a prose line that fits the grammar is not an answer), and `--parse --against <decisions-*.json>` drops answers for unknown cards or options a card does not offer; `--date` and `--label` are restricted to `[A-Za-z0-9._-]+` without `..` so they cannot escape `--out`; and `style-diff` records the HTTP status and final URL of each page, so a 4xx/5xx page or a different final URL between snapshots (the fragment aside) is UNMEASURED (exit 3) rather than CLEAN.

- **`/wp-audit` and `/wp-update` read the exit code their tools document.** The audit fix step
  took any non-zero `bin/style-diff.mjs` exit as a moved style value, so an INCOMPLETE run
  (exit 3, a page or viewport not measured) was reported as a diff; it now repeats the
  measurement, and exit 2 is a tool failure. `/wp-update` took any non-zero
  `bin/assets-fresh.mjs` exit as stale critical cuts; exit 2 (bad usage or an unreadable
  manifest) is now reported as "critical cuts not checked".

- **`image-gen.mjs` robustness.** A multi-line `## World` in `BRIEF.md` is now read whole instead of being cut at its first line, and an empty one followed directly by a heading reads as no world instead of the next section (existing plates composed with a multi-line world get a new hash and are regenerated once; single-line worlds are unaffected). Requests time out after 120 s; a timeout fails the slot without a retry, since the first request may still be billing. An unknown provider, a missing, unreadable or non-object plan file, and two `use` files sharing a basename now exit 2 before any request instead of "no key ... undefined" or exit 4. Plates and copied files are written through a temp file and a rename (removed if the write fails), so a killed run no longer leaves a truncated plate that is treated as cached forever.

- **Lint and gate tools stop answering in silence.** `css-contour-lint` rejects unknown
  flags and accepts `--rule=<name>` (both used to run every rule), no longer reads `clearfix`
  as a search clear control, and no longer reads a border-only compound such as
  `.btn.btn-primary` as transparent when `.btn` paints a solid background. `contrast-propose`
  reads `#rgb`, `#rgba`, `#rrggbbaa` and `rgb()`/`rgba()` (alpha is flattened onto the
  background, then onto white; the proposal stays opaque) and reports bad or missing input as
  a one-line error with exit 2 instead of a stack or "no shade reaches it". `assets-fresh`
  exits 2 ("critical cuts not checked") when a manifest lists no sheet and no cut, instead of
  printing FRESH, and checks an optional `cutHash` for the cut file itself. `theme-template-check`
  takes the `widgets` script entries from `--entry` alone, or from every path any `wp-scripts
  build|start` call in `package.json` names plus `assets/js/src/index.js` when it exists (a
  module passes when any of them imports it), and its finding lists the files it read.
  `contrast-propose` also scores a moved background with a translucent foreground composited
  over each candidate and reports the final pair's real ratio. What is now an error (exit 2):
  an unknown argument, a `--pair` ratio of 0 or 1 or below or not a number (an empty ratio
  still means 4.5), and an unreadable colour in `--pair`; an unreadable or non-text colour in
  an `--axe` node is skipped with a WARN on stderr and the rest is reported.

- **Manifest CLI edge cases.** A site root containing a space or an apostrophe is quoted in the detected WP-CLI wrapper and read back word-aware, so `adopt` no longer fails with "eval exited"; `git-init --commit/--push` accepts a root reached through a symlink; credentials in `--remote` are masked in everything printed; `set` warns on stderr when JSON parsing changes a key's type; a `-->` in a superseded CLAUDE.md line no longer closes the comment early; CRLF in the generated block is not drift; and `env-set`, `keep-inactive`, `remove-plugin` and `migrate` now take the manifest lock like `set`, and `code-home` takes it around its write, after its WP-CLI probe (an exit inside a locked command releases it).

- **Network tool edges.** `link-sweep` now reports a redirect cycle (a target already
  requested in the chain) as `broken` with the reason "redirect loop", while a long chain of
  distinct URLs stays `unmeasured` at the 5-hop cap. `h2-proxy` keys its HTML cache on the
  request cookies and `Accept-Language` as well as the URL, so pages that vary by a language
  cookie are no longer served crossed, and it no longer caches responses carrying `Set-Cookie`
  or `Cache-Control: no-store`/`private`. The suite preload keeps the third-party block closed
  when `BASE_URL` is missing (it protects production properties) but now says so on stderr
  instead of blocking every host silently.

- `robin-fix.sh` no longer reads a queue hash that is already taken as free once the
  WebP queue passes about a thousand rows. It asked `echo "$hashes" | grep -qF` under
  `pipefail`: once the list outgrew the pipe buffer, `grep -q` closed the pipe at its
  match, `echo` died of SIGPIPE and the pipeline reported the hash missing, so the
  collision branch never ran and the row was inserted again. Lookups now read a
  here-string and match whole lines. The same early-exit reader (`grep -q`, `head`) is
  gone from every other shipped script that runs under `pipefail` (`wp-env-setup.sh`,
  `geo-scan.sh`, `clone-preflight.sh`, the S3 mirror's error summary, `audit-suite.sh`'s
  refusal listing and others), and `tests/checks/no-early-exit-pipes.sh` now scans
  `bin/*.sh` and `skills/*/scripts/*.sh` as well as the checks.

- **Native server templates agree on what they refuse, and stop breaking local setups.** The
  PHP-FPM pool now sets `upload_max_filesize` and `post_max_size` from `{{max_upload_size}}`
  (PHP's 2M/8M defaults rejected plugin zips even when nginx allowed 1024M, and the doc claimed
  otherwise). The nginx template no longer sends a two-year HSTS header over a 365-day
  self-signed certificate, which locked the browser out of `example.test` once it expired. The
  Apache vhosts add `Options -Indexes`, and the Caddyfile adds `tls internal` so a local domain
  stops asking a public ACME CA. nginx, Apache and Caddy now share one deny list
  (`templates/native/_deny.list`): `/xmlrpc.php` (including `/xmlrpc.php/x`), `.sql.gz` and
  `phar`/`pht(ml)` under uploads are refused by all three, and `.zip`, `.tar.gz` and `.tgz` are
  refused everywhere except `/wp-content/uploads/`, so media-library zips still load, and
  `tests/checks/vhost-deny-list-parity.sh` fails when an engine stops denying an entry.

## [1.32.0] - 2026-11-20

### Added

- **An adopted site records where its own code lives.** When adoption finds no editable
  theme or plugin of the site's own (a commercial theme and, at most, a sync plugin), it asks
  once for a child theme, a site plugin or an mu-plugin and stores the answer as `code_home`
  (`--code-home=`, `wp-config.mjs code-home`). Hook-based audit fixes read that field instead
  of improvising a location. For a child theme the command prints the `theme_mods_<parent>`
  copy that must run before the theme is activated.
- **`wp-config.mjs keep-inactive` and `remove-plugin`.** A plugin deactivated on purpose is
  recorded in `plugins.intentionally_inactive` and is no longer drift (it stays in the
  stack); a deleted plugin is dropped from the manifest, both scope lists and the generated
  block in one step.
- **`adopt --json`.** Stdout is exactly one JSON document (dry run and real run), with the
  human lines under `notes` and the backup path under `backup`; the dry run also reports
  `code_home_needed` and `code_home_options`.

- **`wp-config.mjs git-init` puts an adopted site's root under git in place.** Opt-in
  (`/wp-adopt` Step 6b): it refuses a root that is already, or sits inside, a repository,
  merges a WordPress `.gitignore` (template plus every tool state path) without duplicates,
  runs `git init -b <branch>`, adds the remote and prints a dry-run summary with large and
  secret-looking files before anything is staged. Commit and push are separate confirmed
  steps, and only the named branch is ever pushed, never a second one.

- **/wp-audit checks that a local clone serves its own pages before any agent runs.** A clone
  of a site served by nginx has no `.htaccess`, so on the local Apache every permalink 404ed
  while the home page answered 200, and the page measurements of the run were silently wrong
  until a person asked. `bin/clone-preflight.sh` (Step 2.3) requests a post, a page and a
  category archive on the audited host and requires 200, reports whether the host answers http
  or https (passed to every agent as `Audited scheme:`), diagnoses a missing, empty or
  WordPress-less `.htaccess` (noting that `wp rewrite flush --hard` writes nothing under
  WP-CLI), and, only after the user agrees, backs up the file and appends the stock rewrite
  block as a local-only change kept out of git. If it fails and the user declines, page-based
  checks are `UNMEASURED` with the reason.

- **Step 6.8 coverage is a script, and every agent gets its exact must-run list.** `bin/audit-coverage.mjs` reads each category's catalog from the agent's own file and the run's `checks_executed`, prints `executed/total`, percent and the missing ids per category (`--json`, exit 1 under the threshold, `--final` for the second pass, `--list <category>` for the exact must-run list). The first dispatch passes that list to each agent and a re-dispatch sends only the missing ids. Before this the gate was prose: one run skipped it, others recomputed it with ad-hoc regexes, and a first dispatch with no id list came back at 38/61 and 58/68 and cost two extra agents. An `UNMEASURED` whose reason is not one of the allowed ones ("not measured in this run", "not run", no reason) is reported as missing; the allowed reasons are now written down in the status vocabulary.

- **`bin/decision-sheet.mjs`, the approval page for `design_impact` findings.** Builds one
  self-contained HTML in the audit results directory: per finding a before and after picture
  at desktop and mobile (the injected CSS is forced `!important` and transitions are frozen,
  so the "after" shows the proposed value), measured values, a recommended badge, approve /
  reject / postpone / other radio options and a copy-answers box that works with a plain click.
  `--parse` reads the pasted `DECISION <id>: <option> | <note>` block back as JSON, with
  rejected findings flagged for the ledger as `accepted`. `fix.md` now routes every `visual`
  finding through it and forbids applying one without an answer.

- **Elementor fix playbook for adopted sites.** `/wp-audit` fixes on an Elementor site kept
  rediscovering the same facts: what stays in Elementor and what must be theme code, that
  `$WP elementor flush-css` (not `flush-cache`) follows every data edit, the Loop Grid
  pagination, `fetchpriority`, ARIA-role and thumbnail-link traps, and that heading changes
  restyle. `skills/wp-audit-standards/references/builder-elementor.md` now holds them, and
  `fix.md` and the a11y, UX and performance agents load it only when `stack.builder` is
  `elementor`.

- **`/wp-audit` reports MCP, OAuth and agent servers exposed over REST (SEC-046).** Plugins
  now register MCP and OAuth servers as REST routes, on by default, some accepting the
  subscriber-level `read` capability, with a signing secret in `wp_options` that every
  database sync copies. No check read the route table, so an owner found them by chance.
  SEC-046 lists the matching routes with their owning plugin and required capability, probes (GET only)
  each one unauthenticated (through the production gate), and rates it: WARNING when
  reachable or `read`-level, INFO when admin-only, PASS when none. The fix names the known
  switches (two plugin filters, an Elementor option), says a filter goes where
  `code_scope.editable` allows and a DB option must be repeated per environment, and asks to
  rotate a stored secret that was ever exposed. An intentional public endpoint is "confirm
  intended", never "remove", and the GEO guidance now says so.

- **Record decisions and fixes in the audit ledger without auditing.** `bin/audit-report.mjs`
  gains `--accept <id> --reason`, `--unaccept`, `--mark-fixed <id> --evidence`, `--rerender`
  and `--summary [--json]`. `accepted` was defined as "set by a human" but nothing let a
  human set it, so a declined finding was proposed again every session and fixes applied
  between audits left the ledger stale (or got hand-written into the report). Accepted
  entries now leave the open and critical counts and the plan and get their own report
  section; a new `fixed_unverified` status holds a fix no check has re-measured and only a
  measured re-run turns it into `resolved`. `--rerender` rebuilds the newest report from its
  sidecar and the ledger, `--summary` prints counts by status and severity, and `ledger.md`
  documents the file's shape. The sidecar now also keeps each finding's `fix`.

- **`/wp-audit` renders a production runbook from its replay record.** Every applied fix now
  appends a typed entry to `<out>/replay.json` (`kind`: code, db-option, post-meta,
  wp-config, server, post-deploy; the exact command or file, the previous value or backup,
  and a `needs_server_rule` flag), and `bin/audit-runbook.mjs` renders it as
  `<out>/runbook-<date>.md` in the order production needs: pre-deploy checks, code and theme
  activation, wp-config, WP-CLI with a production `--url`, server rules, post-deploy
  (Elementor `flush-css`, page-cache purge) and verification curls. Before, the replay log
  covered settings only and every session wrote its "for production" list and its server
  steps by hand. Those lists reported `.htaccess` fixes as done for an nginx production,
  missed the nginx `location` that PHP-served endpoints such as `/llms.txt` and
  `/.well-known/` need, and let a physical `robots.txt` carrying the local host shadow the
  dynamic route. The runbook takes its Apache and nginx snippets from the new
  `skills/wp-audit-run/references/server-rules.md`, marks each one not applied, rewrites
  commands to the production URL, and refuses to write a runbook that would carry a local
  host. Named environments gain optional `server` and `page_cache` fields
  (`wp-config.mjs env-set --server= --page-cache=`).

- **`bin/audit-suite.sh` run flags and third-party blocking.** `--workers`, `--timeout`,
  `--engines` and `--settle` replace hand edits of the generated `playwright.config.js`
  (which the scaffold used to overwrite at the start of the run, so they never applied;
  an edited config is now kept, tracked by `.scaffold-sums`). `--block-third-party` /
  `--no-block-third-party` with `--allow-hosts` block every host but the audited one, on
  by default against a local host so a clone sends no real hits to production analytics or
  embeds; `--workers` above 1 is refused against production, and `--project` points to
  `--engines`. A non-empty `--dir` refusal now lists the files in the way.
  `bin/ux-probe.mjs` gains `--block-third-party`, `--block-hosts` and `--allow-hosts` on the
  same allowlist (`bin/lib/third-party.cjs`). `/wp-audit` now looks for an existing Chromium
  with `bin/lib/browsers.mjs` before reporting "no browser".

### Changed

- **Plugin-list drift no longer interrupts `/wp-audit`.** When the only disagreement is the
  plugin list, `refresh` runs without a question and the report logs it; the audit asks only
  for theme or code-scope changes. `refresh` now also drops plugins that are gone from disk
  out of `code_scope` (so `render-context` stops listing a deleted plugin as read-only code),
  and does nothing when nothing changed.
- **Manifest backups leave the docroot.** `adopt --replace` and `refresh` write
  `.wp-create.json.bak-<timestamp>` to `~/.local/state/wp-builder-backups/<root>-<hash>/`
  (`$XDG_STATE_HOME` honoured, newest 20 kept) instead of beside the site, where they were
  served and committable.

- **`audit-report.mjs` normalizes agent reports instead of trusting their key names.** `--agents <dir|file>` builds the findings and the unmeasured list from the agents' report files, and every finding goes through `bin/lib/audit-schema.mjs`: `code`/`id` for `check`, `owner` for `ownership`, `fix: auto` for `auto_fixable` and the like are accepted (the alias table lives once, in `wp-audit-standards`), while a finding in an agent report with no id, an id in no catalog, or a check reported as both a finding and a pass is refused with exit 1. Before this each agent drifted into its own keys and the parent wrote a throwaway script per run to rebuild `run.json`.

- **The audit report follows the site's language and an audits root.** `--lang` (`--report-lang`) defaults to the manifest's `languages.primary` when it is `es` or `en`, else `en`; it used to default to `en` whatever the site was, so a Spanish site needed it asked for. The output directory gains one step before `.wp-audit`: `<audits root>/<site>/results` when `WP_AUDITS_ROOT` or the manifest's `audit.audits_root` is set, so reports land beside the other sites' instead of wherever the working directory was. With neither set the directory is unchanged; `--out`, `WP_AUDIT_OUT_DIR` and `audit.out_dir` still win. `--site-root <dir>` reads the manifest from somewhere other than the working directory.

- **CI checks now measure what they claim.** `tests/run.sh` runs every check in parallel and counts a
  skip (a `SKIP` line, or a browser check's "static only -- NOT exercised" pass) apart from a pass.
  With `CHECKS_REQUIRE_BROWSER=1` those browser checks fail instead of skipping, and the browser job
  sets it for the ones its runner can serve. The syntax job also parses `.cjs` files, shellcheck now
  covers `tests/`, actions are pinned to commit SHAs, the WP-CLI phar is verified against its
  published checksum, and a push to main is no longer cancelled by the next one.

### Fixed

- **Agents keep shell noise and blocking patterns out of their runs.** The `wp-cli-patterns` skill, which every seeding and audit agent loads, now states four shell rules: call WP-CLI through the `$WP` wrapper and its quiet filter, send a failing `wp eval` on PHP 8.5 to `wp eval-file`, never chain `sleep` or use `nohup` (start long jobs in the background instead), and use `cp -f` / `mv -f` in scripted copies. `tests/checks/agent-shell-hygiene.sh` pins them.

- **A clone audit and vendor-code noise no longer inflate the headline.** On a local clone,
  SEC-036 is an `INFO` pre-deploy gate (listed as a push blocker, `guid` rows never searched or
  counted), database schema and data findings cap at `WARNING` with "confirm on prod" after
  reading the sync tool's exclude list, transport findings measured on the local server are
  "local server only, unverified on prod" and not counted, the scheme the local host answers is
  probed before HTTP checks, and WP-040 and WP-045 are `INFO`. In `code_scope.read_only`, only
  vulnerability, update and abandoned-plugin checks produce findings; pattern hits collapse into
  one `vendor notes` INFO line per plugin. A finding must carry a catalog code (no shard-local
  labels), and hits with one root cause are grouped before counting.

- **The browser suite completes on third-party-heavy sites.** On a site loading 160-250
  requests a page (video embeds, analytics, widgets) the suite timed out on every page and
  Tier 3 stayed UNMEASURED. Pages now load to `domcontentloaded` plus a bounded settle
  (`--settle`, default 5 s) instead of waiting for a network idle that never comes. The
  timeout brake sends one GET to the audited host after each timeout and counts it only when
  the host does not answer or refuses (403/429/503); a slow page on a host that answers, and
  a check that ran on a page a timeout had closed, are recorded in
  `results/unmeasured-pages.json` and reach the run file as `SUITE-PAGE-*` UNMEASURED rows
  with the reason, instead of tripping the brake or reading as a metadata error.

- **The cinematic starter's mobile menu and motion toggle now work.** `nav.php` emitted a
  hamburger, a `#mobile-menu` dialog and a motion toggle that `cinematic.css` and
  `cinematic-engine.js` never styled or wired: on mobile the button did nothing, and the dialog
  rendered unstyled in normal flow on every viewport. The menu is now hidden on desktop and a
  focus-trapped overlay at 780px and below (Escape and link clicks close it, `inert` while
  closed). A pause/play toggle, also added to the desktop nav, pauses every video and stops the
  engine from playing one while paused, defaulting to paused under `prefers-reduced-motion`
  (WCAG 2.2.2).

- **The cinematic starter is now an activatable classic theme.** It shipped no `index.php`,
  `page.php`, `single.php` or `404.php`, so WordPress refused to activate the generated theme
  and any non-front-page request had no template. Minimal escaped versions are added. The
  loader also looked for a `templates/cinematic.php` page template that no command or agent
  ever creates; it now keys on the front page alone, which is where the reel renders, and the
  `_is_cinematic` filter remains the way to opt other pages in.

- **The cinematic starter no longer ships unreplaced placeholders.** It used `__TEXTDOMAIN__`
  and `__VERSION__`, which `/wp-init` Step 4 never replaces, so every generated cinematic theme
  carried the literal tokens in its stylesheet header, constants, menu labels and nav. It now
  uses `__starter__` as the text domain and a literal `1.0.0`, like the Tailwind starter.
  `tests/checks/wp-init-templates.sh` fails on any `__token__` in either starter that Step 4
  does not replace.

- **Contract checks no longer fail at random on a busy runner.** Hundreds of checks piped a
  producer into `grep -q` or `head` under `set -o pipefail`. Those readers stop at the first
  match, so a producer still writing died of SIGPIPE and the pipeline reported failure for a
  pattern that was found, or, inside a command substitution under `set -e`, the check exited
  141 with no output. It only happened when the reader won the race, so local runs passed and
  CI failed unrelated pull requests. The readers now consume their whole input
  (`grep >/dev/null -c`, `sed -n 1p`), awk programs that exit early read a here-string or a
  process substitution, `tests/run.sh` prints the exit status of every failed check, and
  `tests/checks/no-early-exit-pipes.sh` refuses the pattern from coming back.

- **The composition gate answers impeccable's new `kicker-above-heading` rule.** A newer
  impeccable 4.x release flags the small label above the section title in ten non-hero
  compositions, which turned `tests/checks/wp-craft-composition-gate.sh` red on `main`
  and on every open PR. The rule is now ignored only in those ten compositions, through a
  new per-composition `IGNORED_AT` list in `bin/composition-gate.sh`, so a new composition
  that adds a kicker still fails the gate. Removing the kickers
  changes how every craft build looks, so it waits for a measured design PR. The detector
  still follows the newest 4.x.

- **`demo-verify` refuses a target with nothing to walk.** A directory with no `.html`
  files, or a page path that does not exist, used to end in "no machine findings on
  0 page(s)" with exit 0, so an empty `demo/` or a typo read as a clean verification. It
  now exits 1 with "no pages to verify" before looking for a browser, and
  `/wp-demo-verify`'s walk reference says to fix the target rather than report a pass.

- **`wp-env-setup.sh` no longer aborts in `--json` mode, and Apache on Debian is served.**
  The output helpers returned non-zero when quiet, so `set -e` ended the script at the
  first message after work was done. `native-setup` for Apache on the Debian layout now
  enables the required modules and the site before the reload instead of leaving the
  installed vhost inactive.

- **The production runbook no longer splits a command on an operator inside quotes.**
  `bin/audit-runbook.mjs` split each recorded command on `|`, `;`, `&&` and `||` without
  reading quotes, so a value such as `"%title% | %sitename%"` received a stray `--url=` inside
  the quoted text. The split is now quote-aware; an ordinary pipeline keeps one `--url` per
  `wp` call.

- **`/wp-init` now parses the flags `/wp-cinematic-init` hands it.** The hand-off passed
  `--path`, `--mode`, `--starter` and `--acf-flavor`, none of which `/wp-init` read, so it asked
  for the template and the custom-fields plugin again, and choosing cinematic dispatched back to
  `/wp-cinematic-init` in a loop. A new Step 0.4 owns those values and skips Steps 0.5 and 0.6
  when they are preset, and a run entered with `--mode=cinematic` no longer dispatches back.
  The hybrid switch had two spellings (`--hybrid` and `--no-hybrid`); it is now `--no-hybrid`
  in both commands.
  Only `--mode=cinematic` and `--starter=__cinematic__` mark entry from the caller;
  `--template=cinematic` still dispatches. When entered from the caller, `/wp-init` does the
  shared bootstrap only (starter copy, placeholders, server, database) and returns: the agent,
  scenes, seeding and menus are owned by `/wp-cinematic-init` alone, and `--acf-flavor` is
  passed only when given.
  Choosing cinematic now dispatches `/wp-cinematic-init --path=<dir>` with `--acf-flavor` and
  `--no-hybrid` when set; a caller-entered `/wp-init` prints a return line instead of "Next step"
  and the live-view line; and `/wp-cinematic-init` builds the agent payload from `--scenes` and
  `--no-hybrid` instead of hard-coding 9 and hybrid on.

- **`/wp-update` stops tripping on restored clones and bundled-plugin themes.** The held
  parent-theme lookup no longer asks WP-CLI for a `parent` field it does not have; the core
  backup lists root PHP files with `find` instead of `ls`, which broke under a coloured `ls`
  alias; the preflight reports an ACL mask of `r-x` (web server cannot write) and a leftover
  `.maintenance`; a vendor package that is not a zip is skipped like an unlicensed one; and
  plugins that a commercial theme ships inside itself are reinstalled when the theme moves.
  A core release whose translation package for the site locale is not out yet is now
  reported as skipped instead of aborting the run (core, plugins and themes run as separate
  commands, no `&&` chain); long updates over SSH go through the harness's background run (no `nohup`);
  paid-plugin updates that only wp-admin shows (`Update package not available`, `already
  updated`) are listed as admin-only; language packs are refreshed after the migrations; and an
  "update everything" answer is no longer narrowed by the run on its own judgement.

### Security

- **The Docker template publishes its ports on loopback only.** The web server,
  phpMyAdmin and Mailpit were mapped as `{{port}}:80`, which Docker binds to every
  interface, so a project started on a shared network exposed them to that network.
  Each mapping is now `127.0.0.1:{{port}}:…`, and `tests/checks/wp-environments.sh`
  fails if a bare mapping comes back.

- **`wp-env-setup.sh` checks its arguments before running anything privileged.**
  `permissions` resolves the path and accepts only a WordPress directory (not `/` or the
  home directory), validates `--web-user`, leaves `.git` and `node_modules` alone, and re-owns only real directories and files
  (`chown -h`, symlinks are not followed). Each `chown`/`chmod` runs through `sudo env PATH=<absolute system path> find -execdir`
  (a relative or empty `PATH` entry would abort `-execdir`, and `sudo` may keep the caller's `PATH`),
  so it is applied relative to the directory `find` is visiting. That closes the race on intermediate
  directories, and a symlink is excluded by type. GNU `chmod` has no `-h`, so a leaf swapped for a
  symlink between `find`'s stat and the exec remains a narrow residual risk. The `wp-content` writable
  directories are changed in the same pass (`-type d`); one that is a symlink is skipped with a warning.
  `vhost-install` writes only under the web servers' config directories,
  `service-reload` accepts only known web server and PHP-FPM units, and `native-setup`
  validates the web server and the vhost destination before the certificate or hosts file is touched.

- **`bin/link-sweep.mjs` checks every redirect hop and the original link itself.** Redirects
  were followed automatically, so a link on the site that redirected to the clone-origin host
  was requested without `--follow-clone-origin`, and a redirect to a link-local or metadata
  address was followed. Redirects are now followed by hand (at most 5 hops) and each target is
  checked first, and the original link is checked the same way before its first request (a page
  linking straight to a metadata address or a private host from a public site is `unmeasured`):
  the clone origin needs `--follow-clone-origin`; link-local and metadata addresses are refused
  by their literal spelling (IPv4-mapped IPv6 such as `::ffff:169.254.169.254`, and
  `fd00:ec2::254`, included) and, for a hostname, by every address it resolves to at check time;
  a private or loopback host (literal or resolved) is refused unless the swept site is itself
  on one, which is judged by what the site's host resolves to (a dev name that `/etc/hosts`
  points at loopback is local) and not by its spelling alone. A failed lookup leaves the link `unmeasured` with the reason. DNS rebinding between
  that lookup and the request itself is not closed. A refused hop leaves the link `unmeasured`
  with the reason.

- **Runbook shell lines quote every path taken from the replay record.** File names and
  theme slugs were interpolated bare into the `git ls-files`, `git grep`, `ls` and `wp`
  lines the operator pastes, so a name with spaces or shell metacharacters broke the line or
  ran extra commands. `bin/audit-runbook.mjs` now single-quotes any value that is not a
  plain path word.

## [1.31.0] - 2026-10-27

### Added

- **`/wp-audit` recognizes a re-audit.** Step 1.5 detects a prior run (`audit.last_run`,
  the findings ledger, the dated sidecar), prints `Re-audit of <date>`, and asks one
  question to reuse the stored mode, browser suite and production URL (or clone-only)
  instead of re-asking each, with a scoped option that re-measures only open findings and
  categories touching files changed since the last run. Stale or unconfirmed answers are
  never reused silently. Answers persist in `audit.last_answers`, validated by
  `bin/wp-config.mjs`, and the report states its baseline.

- **`/wp-audit` keeps a replay log and a resumable run state on disk.** Setting and
  database fixes were printed once at the end and then lost, per-agent reports lived only
  in the conversation, and a bulk database fix kept no old value. Now each such fix is
  appended to `<out>/replay.json` with its WP-CLI command, previous value and per-environment
  `applied_on` flags, and the closing list is printed from that file. Each agent's full
  report is written to `<out>/agents/<agent>.md` before synthesis (the parent receives only
  the findings JSON and a short summary), `<out>/run-state.json` lets a run resume after
  `/clear`, and a fix touching more than 25 rows dumps the previous values to
  `<out>/backups/` first. A `--replay <env>` flag is documented as future work.

- **CI parses and lints the shell scripts, and a stub-PATH harness tests them with hostile
  input.** CI linted PHP and ES modules but never `bin/*.sh` or `skills/*/scripts/*.sh`,
  and their checks only grepped the script text, so nothing ran a script that calls `sudo`,
  `rm` or `sed` with a hostile argument. CI now runs `bash -n` on all of them (blocking)
  and `shellcheck` at warning severity (blocking; exclusions are documented in `.shellcheckrc`). `tests/lib/stub-path.sh` puts
  logging stand-ins for `sudo`, `rm`, `sed -i`, `wp`, `mysql` and friends on a temporary
  `PATH`, and `tests/checks/hostile-input-env-setup.sh` runs `wp-env-setup.sh` with
  traversal, separator and injection-shaped `--domain` values, expecting a refusal before
  anything would run. It fails if any hostile case reaches a destructive call, so removing
  the domain validation turns CI red.

- **Inline critical CSS is now a conditional recommendation, not a rejected one.** The
  performance lessons recorded one failed experiment (FCP better, LCP worse) as "rejected",
  and the auditor only offered `.min` copies. A real build later made per-template cuts work,
  and the failures it hit were all process: the second of two build scripts forgotten (the
  cuts invalidated in silence), cuts left stale after a core or builder update, verification
  over two different page loads instead of one DOM, and a decision taken on simulated LCP.
  `performance-lessons.md` now states five conditions, `wp-audit-performance` gives the
  regenerate-and-commit order, and the new `bin/assets-fresh.mjs` recomputes content hashes
  and fails with "regenerate critical cuts"; `/wp-update` runs it in its verification step.

- **`/wp-polylang` backs up first and can preview the import.** The command never mentioned
  a backup although `pll-import.php` updates posts and menus in place and rewrites
  `_menu_item_url`, and Step 3.5 moves every URL to `/<lang>/…` with no confirmation. It now
  exports the database outside the docroot (Step 2.5), runs `pll-import.php … dry-run` (lists
  what would be created or modified, writes nothing) before the real import, asks before
  setting `hide_default=0`, and calls `$WP` instead of a bare `wp`, so the `.wp-create.json`
  wrapper (Docker, custom paths) is honoured.

- **WebP delivery now covers HTML returned by admin-ajax, and the audit checks it.** The
  Robin reference listed the delivery modes as if `picture` covered the whole site, but Robin
  only processes `template_redirect`, so infinite scroll, tabs and "load more" kept serving
  the PNG or JPEG next to an existing `.webp` (354 KB against 39 KB on a real build).
  `webp-delivery.md` gains the symptom, the measurement and the recipe (a theme helper that
  reuses Robin's API, availability checked before the buffer starts, with the warning about
  coupling to internal classes) and a rule not to serve or preload a `.webp` that weighs as
  much as the original. `wp-audit-performance` adds PERF-078 (UNMEASURED when the action
  cannot be launched) and `/wp-robin` verifies that the hero image has a `.webp`.

- **Seeded-defects corpus for the audits.** `tests/fixtures/seeded-defects/` holds a theme and
  plugin with eleven deliberate defects (security, accessibility, SEO, performance, best
  practices) and `expected-findings.json` naming the check that must fire for each.
  `tests/checks/seeded-defects.sh` keeps the list honest offline (shape, catalog membership,
  defect still present, markers match) and compares it with a real audit's findings when
  `SEEDED_FINDINGS` is set. `WP_FIXTURE_SEEDED=1` makes `provision.sh` copy the corpus into the
  fixture. Before, nothing showed whether an edit to an audit agent stopped it seeing a defect
  it used to catch.

- **State-file contract and configurable report directory.** The audit ledger
  (`.wp-audit-findings.json`), the `.wp-audit/` reports, manifest backups and Robin's runtime
  cache were written without ever saying whether they belong in git, and in a normal repo the
  ledger got committed. `TOOL_STATE_PATHS` in `bin/wp-config.mjs` is now the single list, and
  `wp-config.mjs gitignore-check <root>` prints the entries git would commit (exit 4).
  `/wp-adopt`, `/wp-audit` and `/wp-robin` call it and offer (default yes) to ignore the
  plugin's own entries, the one exception to `/wp-adopt`'s no-`.gitignore` rule. Reports go to
  `--out`, else `WP_AUDIT_OUT_DIR`, else `audit.out_dir`, else `.wp-audit`; the renderer warns
  when that directory is unignored inside a git tree and prints absolute paths.

- **Named remote environments, EnvSync recipes and a measured DB dump in `/wp-clone`.** The
  manifest takes an optional `environments` map (`role` local, staging or prod, `url`, and a
  token-free `sync` block) that `validate` checks and `wp-config.mjs env-set` writes;
  `/wp-adopt` registers the environments `wp envsync env list` reports. The production gates
  of `/wp-update`, `/wp-clone` and `/wp-audit` read `role: "prod"` instead of comparing URLs
  and keep the URL rule only when there are no `environments`. `wp-environments` gains the
  EnvSync recipes (pull by scope, push only what is missing, volatile tables, token
  handling). `/wp-clone` Path A measured nothing before dumping: it now lists the ten heaviest
  tables, offers to skip log, queue, session and cache tables, and exports with
  `--single-transaction` through `gzip`, downloaded with a resumable `rsync --partial`.

### Changed

- **A11y fixes are measured by scope and state.** The tag-swap comparison now also covers
  `:hover`, `:focus-visible`, dark mode and every element sharing the class. A global colour
  fix must use the narrowest selector and be measured on light, dark, text over an overlay,
  hover and focus; the theme-switch attribute is located on `<html>` or `<body>` before
  writing a `:not()` guard, with transitions off. `wp-css-system` gains a section on
  end-of-sheet overrides. Before, a broad override could repaint overlay cards and a
  `:not([data-theme])` guard could silently never exclude dark mode.

- **The two largest audit agents load far less per dispatch.** `wp-audit-performance` (84 KB) and
  `wp-audit-security` (79 KB) carried every procedure, script, fix recipe and the plugin
  inventory in the file the loader reads whole on each invocation, although a given run needs a
  few of them. The check tables, the report contract and the rules stay in the agent; the long
  per-check procedures moved verbatim to `skills/wp-audit-standards/references/perf-*.md` and
  `sec-*.md`, and each agent carries an index saying which file to read before which check. No
  check code was removed or reworded, and the checks that grep the agents now read the agent
  plus its references through `tests/checks/lib/agent-text.sh`.

- **`/wp-audit` no longer applies fixes that change how a site looks without asking.** The fix
  offer split work by owner (code, setting, content) but not by whether the render changes, so
  a "y" also applied CSS focus styles, size and spacing changes and tag or class swaps, which
  were never measured. Findings now carry `design_impact`, shown in the report; those marked
  `true` form a `visual` class that is never counted as auto-fixable, is listed with its
  computed-style and box measurement first, and is applied one at a time and re-measured. When
  the site's builder has a control for the setting, the fix goes to the builder's data (backed
  up first) rather than the theme's CSS, unless the control cannot express it.

- **Builders stop on adopted sites.** `/wp-init`, `/wp-section`, `/wp-seed`, `/wp-yolo`,
  `/wp-header`, `/wp-footer`, `/wp-page`, `/wp-cpt`, `/wp-settings`, `/wp-tailwind-migrate`
  and the three `/wp-cinematic-*` builders assume a starter theme and never read `origin`,
  so on an adopted site (a third-party theme) they could overwrite it or generate a theme that
  does not belong. Each now runs the new `wp-config.mjs require-origin` first, which exits `5`
  on an adopted manifest; `--force-adopted` overrides it on purpose. `/wp-audit`, `/wp-debug`,
  `/wp-update`, `/wp-clone` and the other non-builders are not gated.

- **`shellcheck` is now a blocking CI gate.** It ran as informational (`continue-on-error`)
  because the scripts had never been linted. The `Shell scripts` job now fails on any
  finding at warning severity. The three intentionally split `$(...)` package lists in
  `bin/wp-env-setup.sh` carry an inline `# shellcheck disable=SC2046` with the reason, and
  `tests/checks/ci-shell-lint.sh` now fails if the step regains `continue-on-error`.

- **`/wp-contribute pr` runs the OCR review before the push, and fix flows check the git tree.**
  The local flow opened PRs without the diff review CI already runs, and `review` (a skill
  review) read as if it were that step; both now say what each one does, and a missing `ocr`
  stops the flow instead of being installed. `/wp-update` and the `/wp-audit` fix step now
  show foreign uncommitted changes and ask before editing, commit by path, stop on a mass
  deletion before committing, and report the unreviewed commit count at the end.

- **One exit-3 policy instead of eight copies.** `/wp-audit`, `/wp-debug`, `/wp-adopt`,
  `/wp-init`, `/wp-seed`, `/wp-robin`, `/wp-s3`, `/wp-update` and the two `/wp-clone` paths each
  carried a hand-written "Amending the exit `3` row above" paragraph, and they had drifted. They
  now name one policy defined in the new `wp-manifest-gate` skill (`stop`, `adopt-or-stop`,
  `adopt-or-bare-wp`, `bare-wp-fallback`, `scaffold`, `register`, `destination-adopt`);
  `tests/checks/wp-config-gate.sh` pins the table and refuses the inline paragraph.

### Fixed

- **Anchor-only links no longer go into ACF `url` fields.** `wp-acf` always emitted
  `'type' => 'url'` for a link, but ACF validates that type as an absolute URL, so a `#contact`
  link was refused by the editor. A new rule picks `text` for anchors and site paths, `url` for
  external addresses and `page_link` for other pages, and a check keeps the rule in place.

- **`wp-acf`, `wp-cf7` and `wp-normalize` end in a validation step they can run.** The
  first two generate PHP under fine-grained rules on the haiku tier and their tests only grep
  prose, so a generated file that did not parse shipped unnoticed; `wp-normalize` wrote the
  manifest the whole build follows with no Bash to check it. `wp-acf` and `wp-cf7` now finish
  with `php -l` on what they wrote plus `wp-config.mjs validate`, and `wp-normalize` gets
  Bash for one final manifest parse. The tiers are unchanged (the step is the cheaper fix);
  `model-routing.sh` records why and a new check pins the steps.

- **Manifest writes are atomic and the Tailwind rebuild lock holds.** `wp-config.mjs`
  wrote `.wp-create.json` (migrate, adopt, refresh) and the rendered CLAUDE.md block with a
  bare `writeFileSync`, and `wp-research` edited the manifest freehand, so parallel builders
  could read a torn file or lose each other's keys. Writes now go through a temp file plus
  rename, and a new `wp-config.mjs set <project> <key> <value>` changes one key under a lock
  and validates before writing; `wp-research` uses it. `bin/tailwind-rebuild.sh` deleted its
  lock file after building, and since `flock` locks the inode a third process could end up
  holding an unlinked file while a fourth created a new one, so two compiles ran together.
  The lock file is now kept (and gitignored by `/wp-init`), the wait for it is bounded, and
  the implicit `npm install` inside it has a timeout.
  `set` also refuses a parent key whose value would carry a secret (`database`, `wordpress`),
  extra arguments, and a value that starts with `{` or `[` but does not parse; `-` reads the
  value from stdin, and `wp-research` passes its record that way through a quoted heredoc.

- **`/wp-audit` no longer sends an existing site to `/wp-init`.** With no
  `.claude/CLAUDE.md` it said "Project not initialized. Run /wp-init first", which contradicts
  the adoption flow and points a site that already has a theme at a command that scaffolds a
  starter. It now suggests `/wp-adopt` for an existing site and `/wp-init` for a new project.

- **Browser suite: audited host, production gate, timeouts, lockfile, visible UNMEASURED.**
  `bin/audit-suite.sh` rewrote `baseURL` inside the persistent `audit.config.js`, so a stale
  or hand-edited value pointed the next run at the wrong host (in one case production, with
  90 s timeouts, outside the gate). The audited host now comes from `--url` through
  `BASE_URL`; the config is only read, and a mismatch is reported. The script re-runs itself
  through `bin/prod-gate.sh` for any production host (public, or role prod in the manifest's
  `environments` when present) instead of trusting the caller; the gate exports
  `WP_AUDIT_GATE_HELD` and accepts `--prod`. After 3 consecutive page timeouts
  (`--max-timeouts` / `WP_AUDIT_MAX_TIMEOUTS`) the run stops and exits 2 with the cause
  instead of hammering a silent host. Dependencies install with `npm ci` from a committed
  `package-lock.json` (no lockfile, no install; still no browser download). A run with Tier 3
  unmeasured now opens the report summary (`.md` and `.html`) with a bold notice.

- **The audit suite no longer re-takes its own gate on an IPv6 host, and a browser launch
  timeout is no longer read as a silent host.** `bin/audit-suite.sh` cut `https://[2001:db8::1]/`
  to `[2001`, so the child of a gated run never matched `WP_AUDIT_GATE_HELD`, re-ran the gate
  and waited 300 s on its own lock. Both scripts now derive the key from one helper,
  `bin/lib/host-key.sh`. The timeout guard also ignores `browserType.launch` timeouts (four
  workers on little RAM), which wrote `unmeasured.json` with the wrong cause.

- **Mobile-only elements now get their desktop override.** `wp-css` never stated that an
  element shown only on mobile needs a `min-width` rule to hide it (`display: none`) or to
  dissolve its wrapper (`display: contents`), so such blocks stayed visible or broke the
  inline flow on desktop. The agent now has the rule with an example, a list-and-confirm step
  before it returns, and a check keeps both in place.

- **`wp-config.mjs env-set` refuses a missing or invalid `--role` or `--url` up front.** A
  call without them used to write an environment entry with `undefined` values and rely on
  manifest validation to complain afterwards; it now stops with a usage message before
  touching the manifest. The CF7 HTML-scope check's mail stub also answers by key, as the
  real `WPCF7_Mail::get()` does.

- **Live payment keys no longer reach the transcript, and the domains import is pinned.**
  `/wp-update` looked for live gateway keys with `grep -E '(sk|rk|pk)_live_'`, which prints
  the full key line; it now counts (`grep -cE`) and reports only how many options hold one.
  `/wp-clone` listed `*_live_*` options with their values; it now lists names only.
  `bin/domains-import.sh` cloned a third-party repository's `main` unpinned and fed the CSV
  to the agent's context; it now fetches `DOMAINS_REF` (a tag or full SHA, defaulting to the
  commit last reviewed) and tells the maintainer to read the CSV diff before committing.

- **Audit snippets and `wp-cinematic-encode.sh` no longer share fixed `/tmp` files.**
  Paths such as `/tmp/emitted`, `/tmp/site-text.txt`, `/tmp/rm-head.html`,
  `/tmp/geo-home.html` and `/tmp/wp-cine-*.log` were the same on every run, so two
  concurrent runs or sessions could read each other's output and compare one site against
  another. They now use a per-run `mktemp -d`, and `tests/checks/no-fixed-tmp-paths.sh`
  fails on a new literal `/tmp/` outside the documented exceptions.

- **The AJAX nonce example is complete, and `wp-cf7` writes a form per language.** The
  `wp-theme-standards` enqueue reference showed `wp_create_nonce()` with nothing that
  verified it; it now pairs the localized nonce with a handler using `check_ajax_referer()`,
  a capability check and input sanitizing, and notes the page-cache and `wp_localize_script()`
  string-casting pitfalls. The `wp-cf7` agent only created the English form post; it now
  creates one per language on the project's language list (primary plus every secondary),
  with the same fields, messages translated key for key, and one form ID per language.

- **`robin-fix.sh` no longer pastes file names into PHP and SQL, and reads `wp-config.php`
  like PHP does.** The webp queue row was built with `php -r '... "'$s_path'" ...'` and a
  `VALUES (... '${EXTRA_DATA}' ...)` string, so an upload named `O'Brien.jpg` (or any name
  with `"` or `$`, which rsync and metadata can deliver) broke the step or injected code.
  One PHP process now receives the values as arguments, builds `extra_data` and returns
  the INSERT with every string as a hex literal. `parse_define` took the first
  `define('DB_NAME', ...)` even when it sat in a `//`, `#` or `*` comment and cut a password
  holding `\'` short; it now skips comment lines and decodes only the escapes PHP does (an unknown one such as `\w` keeps its backslash). ImageMagick 7
  ships `magick` and deprecates `convert`: the script, `/wp-robin` Step 2 and the skill now
  prefer `magick` and fall back to `convert`.

- **wp-robin: the missing queue table is created from the command line.** After
  `wp plugin activate`, Robin's `rio_process_queue` table can be absent because WP-CLI
  activation skipped its table setup, and the skill's only fix was to deactivate and
  reactivate the plugin in wp-admin, which a headless or scripted run cannot do. The
  troubleshooting row now gives `wp eval 'RIO_Process_Queue::try_create_plugin_tables();'`,
  the call Robin's own activator makes, and keeps wp-admin as the fallback without WP-CLI.

- **`/wp-s3` no longer leaves credentials in the docroot.** The setup and revert scripts
  wrote `wp-config.php.bak-<stamp>` and `s3-config.php.bak-<stamp>` next to the originals;
  those names do not end in `.php`, so the web server served them as plain text (database
  password, previous S3 secret). Backups now go to a `0700` directory outside the docroot
  (`~/.local/state/wp-s3-backups/`, override with `WP_S3_BACKUP_DIR`) at `0600`. The
  `wp-config.php` rewrite also keeps the original mode, owner and group instead of resetting them
  (when `chown` is refused, it rewrites the file in place rather than renaming over it);
  the revert parks its credential-bearing `s3-config.php` outside the docroot too.
  The documented secret flow (`! read … && export …`) could never work, since a `!` line
  runs in a subprocess; the command now has the user write a `0600` file and passes it with
  the new `--secret-file`.

- **`/wp-s3 --revert` no longer leaves the S3 credentials in the docroot.** It parked the
  config as `s3-config.php.disabled` beside `wp-config.php`, which a web server serves as
  plain text (the `.php` extension is gone), exposing the bucket key and secret. The file now
  moves to a `0600` file inside a `0700` directory outside the docroot
  (`~/.local/state/wp-s3-backups/<key>/`, override with `WP_S3_BACKUP_DIR`), and the script
  prints the `mv` that turns S3 back on.
  A `s3-config.php.disabled` left in the docroot by the earlier version is parked the same
  way (kept beside an existing parked copy with a `.legacy-<stamp>` suffix), and the hash
  of the site root falls back to `shasum` on hosts without `sha256sum`.

- `s3-setup.sh` now derives its private backup directory with the same key as `s3-revert.sh`
  (24 hex characters of the site root's sha256, `shasum -a 256` where `sha256sum` is absent), so
  a revert parks the config beside the backups setup made instead of in a different subdirectory.

- **Tailwind starter: the CF7 HTML mail filter only touches the theme's own forms.**
  `wpcf7_mail_components` forced `text/html` on every Contact Form 7 form on the site, so on
  a plain-text form of the client's own, a visitor's `[your-message]` was parsed as HTML in
  the owner's inbox (injected links, remote images). It now acts only when the mail template
  has `use_html` set, which is what the wp-cf7 agent writes. Substituted settings values are
  escaped for where they land: `esc_html()`/`esc_url()` in the body, plain text in the
  subject. The `wp-cf7` agent also passes the template directory to `wp eval-file` as an
  argument instead of splicing `$(pwd)` into a quoted PHP string, which broke on a path
  containing a quote.

- **Cinematic starter: the ACF field-group scan ran on every request.** `functions.php`
  globbed `fields/*.php`, read each file and ran a regex over it on every `acf/init` to find
  groups with no Local JSON yet, even when every group already had one. It now stores a
  signature (file names, newest mtime, and the `acf-json/` directory mtime, which moves when
  a JSON is added or removed) in an option once a scan finds nothing left to bootstrap, and a
  matching signature skips the scan. The signature is never stored after a pass that
  bootstrapped or while `acf-json/` is unwritable, so a failed or partial persist is retried
  on the next request. Delete the `__starter___fields_scan` option to force a rescan.

- **Starters: mobile menu init, menu semantics, skip link, reduced-motion video.** The
  Tailwind starter's mobile menu registered on `DOMContentLoaded` only, so a bundle loaded
  later by a cache or "delay JS" plugin left the button dead; it now runs on the same
  `readyState` guard as the rest of the file, closes on Escape (returning focus to the
  button) and sets `aria-controls`. `navigation.php` no longer puts `role="menubar"` on a
  plain list of links or `role="navigation"` on a `<nav>`, and both starter headers gain a
  skip link. In the cinematic starter, `prefers-reduced-motion` returned before touching
  `.scene__video-mobile`, so the autoplaying loop kept playing (WCAG 2.2.2); it is now
  paused, stripped of autoplay and loop, and reset to its poster.

- **Tailwind starter: stale WebP siblings, over-broad output buffering, per-request ACF scan.**
  A `.webp` sibling was used whenever it existed, so a medium replaced under the same name
  (or `wp media regenerate`) kept serving the old picture; it now counts only when it is at
  least as new as its original, and the upload hook rebuilds a stale one. The WebP output
  buffer also ran over sitemaps, embeds and non-HTML responses; it now rewrites `text/html`
  only. From WordPress 6.7, indexed and alpha PNGs and tiny PNGs are no longer re-encoded to
  WebP; earlier versions keep the previous all-PNG mapping because that filter does not pass
  a filename. `__starter___image()` with a bare URL emits `alt=""` and known dimensions. `functions.php`
  stores a signature of `fields/*.php` and skips the glob/read/regex scan when nothing
  changed (its comment already claimed so), no longer prints a nonce on every page for an AJAX
  handler that does not exist, and defers the bundle through the script `strategy` argument
  (WP 6.3+) instead of a `str_replace` on markup.

- **Script inputs are validated before they reach sudo, sed, SQL and PHP.**
  `bin/wp-env-setup.sh` used `--domain=` as-is in `sudo rm -f /etc/ssl/certs/$domain.crt`
  (a `../` or `/` walked out of the cert directory) and as an unanchored regex in
  `/etc/hosts` (removing `foo.local` also deleted `foo.local.es` and `myfoo.local`, and an
  existing `foo.local.es` made `hosts-add` think `foo.local` was present). It now rejects
  anything outside `^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$` up front, matches hosts lines with an
  anchored pattern, and `ssl-generate` adds `subjectAltName` (browsers reject CN-only
  certificates) and no longer hides openssl's stderr. `bin/wp-cinematic-encode.sh` pasted
  `--scene=` into the PHP of `wp eval`, so a crafted value ran code; it must now be an
  integer, as must the attachment IDs from `wp media import`.

### Security

- **The project path no longer travels inside a `bash -c` string.** Every `wp-config.mjs` call in the commands and skills used to interpolate the path into a double-quoted `bash -c` string, so a path containing a single quote, `$()`, a backtick or `;` could break the quoting or run code. The call now uses a fixed single-quoted `-c` script and passes the plugin root and the path as positional arguments, and the shared prologue says how to write the path safely. A new check feeds hostile paths through every call shape and fails on the old form.

- **The remaining `bash -c` calls that carried the project path or the web user are quoted safely too.** The `test -f`, `mkdir -p`, `wp core download`, `cd && docker-compose/ddev/lando/wp-env`, `setfacl`, store-kit sync and `wp eval-file` calls in `/wp-create`, `/wp-woo-setup` and the plugin-profile reference still interpolated `${PROJECT_PATH}` (and `${WEB_USER}`) into a double-quoted `-c` string, so a value holding a single quote, `$()` or a backtick could run code. They now use a fixed single-quoted `-c` script with the values as positional arguments; `$WP` is handed to the child shell as an environment variable so it still expands to the command plus its flags. The quoting check now fails on any `bash -c "..."` that spells either variable inside the string and runs every new call shape with a hostile path. A path carried inside a native `$WP` wrapper in a `bash -c "$WP ..."` string is not covered.

- **Native vhost templates deny sensitive files.** The nginx, Apache and Caddy templates
  denied only `/.ht` (nginx) and served everything else under the project root, so
  `.wp-create*.json` (which can hold test payment keys) and its `.bak` copies, `.git/`,
  `.env` and `*.sql` dumps were downloadable, and PHP ran inside `uploads/`. They now deny
  dotfiles (except `.well-known`), `.sql`/`.bak`/`.log`/`.bak-*` files and PHP in uploads, and
  nginx runs `try_files $uri =404` before `fastcgi_pass`.
  The Apache rules match the URL (`LocationMatch`, uploads anchored to `/wp-content/uploads/`),
  not the filesystem path, so a docroot under a dot-directory or below a directory named
  `uploads` is not denied wholesale.
  The uploads PHP rule in Apache and Caddy is `(?i)^/wp-content/uploads/.*\.(php[0-9]?|phar|pht(ml)?)(\.|/|$)`,
  not `\.php$`: it also covers `.phar`, `.phtml` and `.pht`, which the Debian/Ubuntu and RHEL global PHP handlers execute. `mod_mime` applies `AddHandler .php` to the extension in any position of the name
  and ignores case, and PATH_INFO maps `evil.php/foo` to `evil.php`. Measured on Apache 2.4 with
  `mod_php`: `evil.php`, `evil.php/foo`, `evil.php/x.jpg`, `evil.php.jpg`, `evil.PHP`, `evil.php5/x`, `evil.phtml`, `evil.phar` and `evil.pht` answer 403,
  while `x.php_.jpg` (the name WordPress gives a renamed upload), `my.phpunit.pdf`, `a.jpg` and `/index.php/foo` are
  untouched. The Caddy pattern is the same regexp, checked by reading only (no Caddy binary).
  nginx needs no change: its PHP location is `\.php$` with no PATH_INFO split, so neither
  `evil.php/foo` nor `evil.php.jpg` reaches fastcgi.

## [1.30.0] - 2026-10-20

### Added

- **`/wp-contribute review <skill>` audits a skill against the authoring best practices, and a
  new skill is not done until it passes.** `tests/checks/skill-authoring.sh` sees what a grep
  can — frontmatter, a "Use when" clause, length, contents lists, named files — and cannot see
  whether a description would be chosen for the right requests, whether a skill explains what
  Claude already knows, or whether a fragile write is left to improvisation. `review` runs the
  two gates, then hands the skill to a fresh subagent with
  `skills/wp-contributing/references/skill-review.md`: twelve judgment rules from Anthropic's
  guide adapted to this repository, returned as a findings table with a `PASS`/`FIX` verdict,
  at most three rounds. Fresh, because the author's own context fills exactly the gaps the
  written skill leaves. `new skill` now loops on the gates and then runs the review, `pr` runs
  it for every skill a branch touches, and a declined finding goes into the PR body instead of
  disappearing. The `new skill` scaffold also stopped teaching `trigger:`.

- `/wp-adopt` gains an opt-in Step 6 that publishes an adopted site to a git remote (SSH). It builds in a scratch clone with a whitelist `.gitignore` and a `* -text` `.gitattributes` (so line endings stay byte-identical to the server), refuses to commit when `wp-config.php` is in the staged tree, scans staged files for secrets, pushes `dev` and `master`, and records the remote and included paths under `git_publish` in `.wp-create.json`. Documents that rsync filters are first-match: an `--include` placed before `--exclude='/wp-config.php'` once copied the config file into the working copy. The default is unchanged: the step is asked once, defaults to no, and the site's own `.gitignore` is never edited.

- **PERF-071 to PERF-074 attribute database bloat to the plugin that causes it.** PERF-061 to
  PERF-064 count rows but never say whose they are, so a real store kept 1.9 million pending
  Action Scheduler actions from ad-platform plugins that were never connected (about 2 GB), 739,000
  temporary options from one cart-recovery plugin, a 289,340-row Rank Math 404 log, and 23
  autoloaded options of removed plugins. PERF-071 groups pending actions by group and hook prefix
  and flags a backlog over 10,000 or one whose plugin is off or removed. PERF-072 flags one name
  prefix over 10,000 `options` rows. PERF-073 sizes `rank_math_404_logs` and reads the monitor
  mode and limit (PERF-060 only checks the table exists). PERF-074 lists autoloaded options whose
  owner is not installed. All reads, every fix needs approval and a backup, and a clone-suppressed
  plugin counts as active so a clone and production agree. `tests/checks/audit-db-bloat.sh` covers
  them.

- **/wp-audit reports heavy embedded ICC profiles on images (PERF-075), unbounded queries in
  Elementor widget controls (PERF-076) and missing Elementor generated CSS (PERF-077).** A
  WooCommerce review found three costs no check named. Five attachments carried 0.5 to 1.8MB CMYK
  ICC profiles copied into 95 files, so a 300px thumbnail weighed 1.8MB. A third-party widget
  filled a control dropdown with an unbounded product query, which Elementor also runs when
  rendering on the front end, costing about 0.85s and 280MB per uncached home render. And
  Elementor had emptied its CSS folder, so pages requested `post-<id>.css` files that 404ed or
  were redirected to the home page. PERF-075 and PERF-077 read file bytes and HTTP responses, so
  a local clone and production agree. PERF-076 is a static finding on a clone, with timings
  relative only; it points to WP-026 for the general rule. All three are manual fixes.
  `tests/checks/audit-perf-elementor-images.sh` covers them.

- **SEC-045 reports file-manager plugins, and PERF-070 reports a page-cache drop-in left
  without its plugin.** A plugin review on an adopted store found both, and no audit had
  reported either. A file manager (File Manager, Filester, Advanced File Manager, or any fork
  that bundles elFinder) edits PHP from wp-admin and ignores `DISALLOW_FILE_EDIT`; its elFinder
  connector answers direct requests even when the plugin is inactive, so SEC-045 checks
  inactive copies too. PERF-070 flags `advanced-cache.php` loaded with `WP_CACHE` true while the
  plugin that wrote it is off, since nothing purges that cache any more. On a local clone it
  defers to Step 2.3: when the owner is on `Clone-suppressed plugins` (active on production),
  it prints a clone-artifact line instead of a finding. `tests/checks/audit-plugin-hygiene.sh`
  covers both.

- **The audit report can carry a "Scope and coverage" section.** The renderer had no field for
  free text, so a user hand-added an "Alcance y cobertura" section to the generated report and
  lost it on the next run. A run file now takes `notes` (a string or an array of paragraphs) and
  `bin/audit-report.mjs` accepts `--notes <file>`; both render in the `.md` and the `.html`
  (escaped, localised) and are kept in the sidecar. `tests/checks/audit-deliverable-report.sh`
  covers it.

- **`wp-config.mjs refresh <path>` updates only what the probe measures.** `drift` could not
  tell "the owner deactivated or installed plugins" from "this manifest describes another
  site", and the only remedy was a full re-adoption. `refresh` rewrites `plugins.installed`,
  `stack` and the PHP and WordPress versions, keeps every other field, writes a timestamped
  backup, re-renders the CLAUDE.md block and validates; it refuses when drift is structural
  (missing theme directory, another active theme). `/wp-audit` Step 2 offers it when every drift
  line is a plugin-list line.

- **`/wp-demo-verify` finds the gap between `max-width: N` and `min-width: N+1`.** Page
  builders emit integer breakpoint pairs, and at a fractional CSS width (browser zoom, or OS
  display scaling such as 110% with a 766px window, 767.27px wide) neither query matches. On
  a real Elementor site that gave a 704px logo instead of 112px, columns with no width, and a
  box hidden on every device visible with 119px headings. The walk only shot integer widths,
  so it could never see it and the defect reached the client's eyes. It now reads the page's
  same-origin stylesheets for such pairs (up to three), loads the page inside each gap in
  Chromium (`--force-device-scale-factor=1.1`, window size searched and read back), compares
  it with N and N+1, and reports a blocking `breakpoint-gap` with up to five culprits and a
  `gap-<N>.png`/`.jpg`. Mobile-first pages report nothing; `--no-gaps` skips it.
  `wp-responsive` now says to write `max-width: N.98px` or `(width < N+1)` when a `max-width`
  query cannot be avoided. Check: `tests/checks/demo-verify-breakpoint-gap.sh`.

- **`bin/h2-proxy.mjs` and `bin/contrast-propose.mjs`, plus the performance lessons of a full
  store optimization.** Lighthouse on a clone behind a stock local server (HTTP/1.1, no
  compression) reports serving-layer artifacts as findings and doubles the simulated LCP.
  `h2-proxy.mjs` fronts a local HTTP site with HTTP/2, brotli and an anonymous-HTML cache using
  a throwaway certificate generated at runtime. `contrast-propose.mjs` turns failing contrast
  pairs into the nearest compliant shade with ratios before and after, for client approval.
  `performance-lessons.md` gains the lab recipe (5 runs, median), the used-CSS subset method
  and its carousel regression, deferring stylesheets that touch nothing above the fold, the
  JavaScript, image and layout-shift lessons. `tests/checks/perf-local-lab.sh` covers them.

- **Two measured lessons from a WooCommerce store.** `skills/wp-robin/references/png-to-webp-conversion.md`
  converts PNG attachments to WebP originals instead of adding `.webp` siblings: when it is
  worth it (uploads 3.5 GB to 509 MB on that store), a map of every old file to its new one
  because `-scaled` sizes change name, a serialization-safe database replacement that skips
  Robin's queue, a regex 301, and the traps of an interrupted run. `performance-lessons.md`
  gains "Per-template used CSS": keep every vendor sheet and load it asynchronously behind a
  per-template used-CSS file (blocking CSS 1.2-1.4 MB to 0.33-0.44 MB), why dropping the
  WooCommerce sheet broke header panels, and the CSP `'unsafe-hashes'` the inline `onload`
  needs.

- **README banner, social preview and Quickstart.** `docs/assets/` carries a hand-drawn
  SVG banner shown at the top of the README, plus a 1280x640 social preview (SVG source and
  PNG) for the repository settings. A five-line Quickstart sits between Installation and
  Workflow.

- **Both starter themes link `site.webmanifest` when it exists.** `functions.php` prints
  `<link rel="manifest">` from `assets/img/favicon/` only if the file is there, so a theme that
  never ran `/wp-favicon` prints nothing and one that did needs no further edit.

- `bin/style-diff.mjs`, a before/after visual-regression tool based on computed styles. `snapshot` records, for every element of each page at 1366x768 and 390x844, a positional selector path, a computed-style subset (colour, background, font, line height, border, display, visibility, opacity, margin, padding) and the box size, plus console errors and failed requests; `--scroll` triggers lazy content and `--state name=selector@width` records a clicked state such as an opened mobile menu. `diff` compares two snapshots, reports style and size differences separately with a pixel tolerance, and exits 1 on style differences. Passing two snapshots taken before the change as `--noise` sets apart elements that already differ between them (random-order carousels, sliders, a 0/1 px separator), which on a WooCommerce store were the only differences between two untouched baselines. Why: a tag swap or a reset class (`.btn-reset { color: inherit; font: inherit }`) beats the utility classes already on an element on source order and can turn a white 26px icon into a black 18px one with no edited value and no visible layout shift, so the audit-fix and finalize docs, which only described measuring by hand, now point at a tool that measures every element on every page.

- **A WooCommerce shopper-flow regression suite ships with the browser suite.** Performance
  and update work had no way to prove it broke nothing: the audit measures quality, not whether
  a customer can still search, add to cart and reach the checkout. `npm run test:regression` in
  `.wp-audit/suite/` (desktop and mobile projects, `@regression` tests) walks home, live and
  results search, archive filters and pagination, sorting, currency switching, product gallery,
  zoom and variations, AJAX add to cart, quick view, wishlist, cart update/remove/coupon,
  checkout validation, account forms, contact and newsletter forms, mobile menu, sticky header,
  an admin smoke and a final URL sweep recording JS errors and failed requests. Each flow is
  `PASS`, `FAIL` or `SKIP` with a reason, and a flow whose feature the site lacks skips rather than
  fails. It never places an order or presses the checkout button, and the two flows that write
  (contact, newsletter) run only on a local clone or with `allowWrites`, where a Contact Form 7
  `mail_failed` is accepted as the expected result of disabled mail. `REGRESSION_LABEL=before|after`
  names a run and `npm run regression:compare -- before after` exits 1 on any PASS to FAIL.
  Configured through a `regression` block in `audit.config.js`; the report lands in
  `results/regression/<label>.md`. `tests/checks/audit-regression-suite.sh` covers it.

- **`/wp-audit` asks whether to run the browser suite.** Without `--suite`, the first
  question of the run now also offers the Playwright suite (axe-core, Lighthouse and the
  rendered-page criteria vendored from `web-portal-audit`). A yes acts exactly as the typed
  flag and reuses Step 6.5's public-URL resolution. Before, a bare `/wp-audit` never ran it.

- **`/wp-clone` Path C restores a site from a full-site files archive plus a database dump.**
  Hosting-panel backups (Plesk, cPanel) hand over the whole docroot as one `.zip` or `.tar.gz`
  and a dump, which Path B (dump plus uploads only) could not use. `--files=` and `--db=` select
  the path. It reads the archive index to find the docroot depth (the shallowest `wp-load.php`;
  `--strip=` overrides), reads the table prefix and the `siteurl`/`home` values from the dump,
  strips `CREATE DATABASE`/`USE` lines so the import cannot land in the source's database,
  reconciles `wp-config.php` with the local credentials (pinned `WP_HOME`/`WP_SITEURL` and forced
  SSL undone), sets cache drop-ins aside, extracts without unpacking to a temporary directory,
  and skips log, session and queue tables in the URL search-replace with a note that the old
  domain can remain there. `--uploads-target=<dir>` keeps a large media library on another disk
  through a symlink, with the traps spelled out: the web server user must be able to traverse
  every directory of the target (a mode-700 home directory blocks it) and NTFS mounts need
  group and umask mount options. The step detail lives in
  `skills/wp-clone-run/references/path-c.md`; `commands/wp-clone.md` stays a map.

- **`/wp-favicon <image>`.** One square image becomes the favicon set: 16, 32, 180, 192 and
  512 px PNGs, a multi-size `favicon.ico` and `site.webmanifest` in the theme, plus the
  WordPress Site Icon set through WP-CLI. A non-square or under-512 px raster is refused
  rather than cropped or upscaled, and an icon already set is kept unless `--force`.

- **`/wp-update` updates core, plugins and themes behind a backup and a verification pass.** Updating a store by
  hand meant remembering the order (backup, core, db update, plugins, migrations, checks) and
  rediscovering the traps: `tar --exclude` after the operands has no effect, premium plugins
  licensed to another domain fail with `Unauthorized` and must be skipped rather than bypassed,
  and a half-updated pair such as Elementor and Elementor Pro leaves version skew. The command
  backs up outside the docroot, runs WooCommerce and Elementor migrations, verifies pages and
  `debug.log`, keeps a clone's mail and gateways disabled, and prints the rollback.

### Changed

- **The ops skills — `wp-robin`, `wp-s3`, `wp-environments`, `wp-contributing`,
  `wp-woocommerce` — were reviewed against `references/skill-review.md`, and their contracts
  are now pinned.** Each description names the requests that should load it and the nearby
  ones that should not. `wp-robin` opens with a run-and-verify loop (back up the database, run,
  done when `error`, `processing` and `remaining` are 0, re-run after a fix), lists all
  sixteen settings the script overwrites, and moves its WebP delivery templates to
  `references/webp-delivery.md`; `robin-webp-gaps.sh` now fails when a setting the script
  writes or a binary it calls is missing from the skill. A library an earlier copy of the
  script re-encoded into `<name>.webp.webp` is repaired by deleting those files and their
  `item_type='webp'` rows. `wp-s3` gains one table of its scripts and templates with
  arguments, environment variables and exit codes, a numbered order, a default for the IAM-role
  transfer (temporary credentials) and for paid downloads (kept off S3), and measures
  downloadable products with WP-CLI instead of asking on every run; `skill-authoring.sh` now
  requires every file under a skill's `templates/` to be named, and `wp-s3-scripts.sh` pins the
  template constants, the path-style endpoint, all five exclusions and the never-public bucket
  paths. `wp-environments` names every `wp-env-setup.sh` subcommand with the SELinux rule for
  vhosts, reads the manifest through `wp-config.mjs get` instead of `jq`, defines
  `environment.type` and `environment.engine`, and points to `/wp-create` for Adopt Mode instead
  of keeping a drifting copy. `wp-contributing` keeps only what a release rests on and leaves
  the procedure to `/wp-contribute release`; `wp-contributing.sh` now pins every rule of the
  review checklist. `wp-woocommerce` names the recorded keys (`store.tier`, `store.enquiry`,
  `store.checkout`/`store.checkout_reason`, `store.payments.mode`), states `woo-setup.php`'s
  arguments, exit codes and report-only rule, says no command takes a store live, and
  `wp-woo-setup.sh` pins its store rules.
- **The three demo skills read their recorded decisions and load only what a step needs.**
  `wp-demo-craft`'s References section was one fixed reading order, so every build read all
  thirteen references (about 37k tokens) before writing markup; it is now a table of file,
  contents and read-when, and names `domains.csv` and what domain classification produces.
  Its order of work opens with a checklist, splits the composition plan into sub-steps, names
  `/wp-demo` and `/wp-yolo` as its runners and says which parts a cinematic build takes. The
  seven-dimension fingerprint table moved into `fingerprint.md`, which owns the gate (with the
  manifest's `"fingerprint"` keys), the family table into `families.md`, and the readouts
  table into `verify.md`; `devices.md`'s element-motion material now sits under real
  subsections in its Contents list. `image-prompt.md` gives `image-gen.mjs`'s invocation and
  exit codes. Wording that went stale with the calendar ("current latest", "until v3.1") is
  rewritten as the rule plus its reason, and "family", "plate" and "Avoid list" mean one thing
  each. `wp-responsive` scopes its hand-written `@media` scale to plain-CSS demos (a tailwind
  theme follows `wp-tailwind-system`; craft compositions size to their container), drops the
  dead `max-width` exception and three conflicting viewport lists for a `/wp-demo-verify` loop
  with a stop condition, and its description no longer pulls screenshot-walk requests.
  `wp-demo` shows the delimiter pair as the verbatim join key it is, cuts what Claude already
  knows, and ends on the same verify loop. All three descriptions name the near misses they
  are not for. `tests/checks/wp-craft-skill.sh`, and contract pins added to
  `wp-responsive.sh` and `wp-demo-skill.sh`.
- **The five audit skills are found by the requests that need them, and load less.** Each
  description now names what a request would carry — `bin/prod-gate.sh`, Lighthouse, a
  `UX-014` on `page:/contact/`, `rank-math-options-titles`, `ard.json`, a sitemap that 404s —
  and the sibling skill that owns the near miss. `wp-audit-standards` moves its Lighthouse
  lessons to `references/performance-lessons.md`, documents `prod-gate.sh` and
  `link-sweep.mjs` with their invocations and exit codes (gate exit `5` now stops after three
  tries, in the dispatch prompt too), numbers the sweep and the block handling, gives the WebP
  loop and the AIOS fix as exact commands, and picks a default browser tool.
  `wp-audit-geo-standards` splits its catalog, surface specs and citability rubric into
  `references/` (the rubric gains a worked rewrite), records that a deliberate crawler block
  is the owner's decision in the skill, the auditor and the fixer, numbers the verification
  loop with a stop and a stale-report rule, and drops citations of a design spec that does not
  ship. `wp-audit-seo-standards` moves §13–§17's samples to `references/audit-gotchas.md`,
  keeps one bulk description seed that follows its own priority order, hands the setup order
  to `wp-audit-rankmath` instead of a drifted copy, and says "title template" throughout.
  `wp-audit-ux-standards` reads the recorded `store.tier` for checkout criteria and keeps the
  fix procedure in the agent; `wp-audit-local-standards` gives one subtype per vertical, a
  reproducible location sample, and two rule sentences where a citation directory list was.
  The contracts that had no pin now do: `tests/checks/audit-standards-contract.sh` and
  `tests/checks/seo-standards-contract.sh` are new, and the UX, local and GEO checks grew.

- **Skills follow Anthropic's skill authoring guidance.** Measured against
  [the best-practices guide](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
  and Claude Code's own loader, three things were wrong across the 21 skills:
  - **Descriptions said what a skill was, never when to use it.** The description is the only
    text Claude reads before choosing a skill, so seventeen descriptions were rewritten to end
    with a "Use when …" clause naming the agents, commands or project state that call for it.
    `trigger:`, which two skills carried and `wp-contributing` taught, is not a frontmatter
    field and was ignored. It is gone, and the contributor guide now says so.
  - **Eight SKILL.md bodies ran past the 500-line ceiling**, `wp-audit-seo-standards` to 1,182
    lines, so every agent that read one paid for all of it up front. Each now keeps its rules
    and decisions in SKILL.md and moves templates, long code samples and catalogs into
    `references/`, linked one level deep with a "read when" line, so an agent loads them
    only when it needs them.
  - **Long reference files had no contents list**, so a partial read could not see what it
    skipped, and `wp-demo-craft/references/image-prompt.md` was never named in its SKILL.md.

  `tests/checks/skill-authoring.sh` holds every skill to these rules: a name that matches its
  directory, a description under 1,024 characters with no angle brackets and a
  "Use when" clause, no `trigger:`, a body under 500 lines, a `## Contents` list on any
  reference file over 100 lines, and every top-level reference named in SKILL.md.

- **Two stale statements were corrected while reading.** `wp-polylang` still said the suffix
  model "remains the default", which stopped being true when new scaffolds moved to Polylang.
  `wp-contributing` and `/wp-contribute` told the maintainer to "roll" `[Unreleased]` into the
  release heading, which reads as a rename. A rename is the one move that conflicts every open
  PR on `CHANGELOG.md`, so both now say to insert the release heading below it.

- **The i18n skills follow the review checklist, and their contracts are pinned.**
  - `wp-polylang` was 487 of 500 lines, so every agent that needed `pll_save_post_translations`
    paid for the ACF field rules, the link-rewrite pass and the rewrite-base pattern too. Those
    moved to `references/acf-fields.md`, `references/internal-links.md` and
    `references/taxonomies-and-rewrite-bases.md`. The scripts are a numbered workflow with
    their path, dependencies and exit codes, and a verify loop that says when to stop. It now
    states what the importer does that an agent would assume it does not — parents rewritten
    every run, media ids copied as-is, ACF references owned per path — defines `$WP`, uses
    one name per concept (translation group, counterpart, link-rewrite pass) and defaults to
    SCF. Its central rule, that `pll_save_post_translations()` replaces the whole translation
    group, and five other sections were unpinned; `wp-polylang.sh` now fails without each.
  - `wp-bilingual` lost a history sentence, a checklist that restated its body and three
    pointer stubs, says where its constants come from, and its menu example no longer names a
    fallback function that exists nowhere.
  - `wp-cli-patterns` stated `$WP` three times and repeated `wp-environments`' wrapper table;
    it now states it once. The table of WP-CLI commands Claude already knows is gone; a
    dry-run-first `search-replace` recipe replaced its bare listing. The clone guard is
    numbered, stops when the guard did not load, checks the HTTP half too, says how it relates
    to `/wp-clone`'s isolation plugin and gives the cleanup commands.
    `references/shipped-scripts.md` gained `resolve-link-targets.php`. The author sweep and its
    two exclusions are pinned, and compared with the copy `/wp-finalize` Check 7 runs.
  - `wp-research` is a numbered procedure with a stop rule for the identity search, an example
    competitor row and differentiation line, a rung-selection rule, a ceiling on paid
    DataForSEO calls and the exact `firecrawl_url` request. The two-signal identity rule, the
    three-row differentiation rule and the DataForSEO tools were unpinned, and two Firecrawl
    pins were satisfied by the table alone; `wp-research.sh` now pins each.
  - Every description was rewritten around the requests that should load it, with a "Not for"
    boundary where a neighbouring skill was a near miss.
- **The four CSS and theme skills follow the review rules, and their contracts are pinned.**
  Each description now names the files, settings and symptoms a request mentions and where
  the skill stops (`Not for …`). `wp-aos-animator` moves its install snippets into
  `references/install.md`, so a per-template Phase 5 subagent no longer pays for them, and
  ends on a verification loop that walks the page with `/wp-demo-verify`. `wp-css-system`
  moves its reset into `references/reset.md`, restates the reset-class trap in plain CSS (and
  gives the Tailwind path its own `:where(.btn-reset)` line), and says how to run the contour
  lint. `wp-tailwind-system` turns adding a CSS file and converting `@media` into numbered
  steps, keeps one contour form, shows a bare selector distributed, and drops the incident
  counts. `wp-theme-standards` drops what Claude already knows (the required-files table, the
  sanitization table, the `WP_Query` sample), numbers the destructive Local JSON redefinition
  with a database step and a dashboard-fields warning, guards the WebP batch on `magick` and
  keeps the starter's per-language menu locations. New assertions in `wp-aos-seams.sh`,
  `wp-css-system-contract.sh`, `wp-tailwind-system-traps.sh` and `wp-theme-standards.sh` pin
  the stacking-context rule, BEM depth, the delimiter width, the token inventory, the
  underscore and quote traps, the `hidden` attribute rule, the one `.btn`, and the SVG
  `unfiltered_html` gate, none of which any check held before. `wp-css-system-scope.sh` loses
  a stale exemption for two skills that already declare `user-invocable: false`.

- **Changelog entries are `changes/<slug>.<section>.md` fragments, not edits to `CHANGELOG.md`.**
  Every PR inserted under the same `## [Unreleased]` heading. `merge=union` resolved that in a
  local `git merge`, but GitHub ignores merge drivers, so merging one PR marked every other open
  PR as conflicting on `CHANGELOG.md`, and union hid real same-line collisions besides. A PR now
  adds its own file; `bin/changelog-release.sh X.Y.Z` compiles them into the release block at
  release and deletes them. `bin/doc-sync-check.sh` requires a new fragment (or a release
  heading) when `commands/`, `agents/`, `skills/`, `starter-theme/` or `bin/` change, and
  `.gitattributes` no longer marks the file `merge=union`.

- **PERF-010, PERF-047, the clone serving-layer caveat and the contrast docs point at the new
  lessons.** PERF-047 now also covers deferring sheets that touch nothing above the fold and
  generated used-CSS subsets (no longer auto-fixable: it needs a per-site generator and a
  first-paint comparison). PERF-010 names the three follow-ups of a footer move
  (`DOMContentLoaded`, `jquery-migrate`, tag managers). A contrast failure now ends in a
  palette proposal for approval, never a colour edit.

- **`/wp-audit` reads each long step when it reaches it.** `commands/wp-audit.md` was 97 KB,
  and every run paid for all of it up front, including the fix phase on a report-only run and
  the adopted-site rules on a site this plugin built. It is now a 24 KB map: every step keeps
  its heading, entry condition and order, and fourteen long steps send the run to one file
  each in the new `wp-audit-run` skill. No step's wording changed. The checks that guard the
  audit read the command with its references expanded in place
  (`tests/checks/lib/expand-command.sh`), and `tests/checks/wp-audit-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.

- **`/wp-clone` now disables payment gateways instead of only reporting them.** Step 5.5.2
  said reporting was the action, on the reasoning that a silent switch hides the bug a payment
  clone exists to reproduce. A clone that keeps an enabled gateway with live keys can charge or
  refund a real customer, so it now lists the enabled WooCommerce gateways, deactivates the
  plugin that owns each, sets `enabled` to `no` in `woocommerce_<gateway>_settings`, lists every
  one in the clone report and warns that the API keys stay stored and that reactivating a
  gateway points at the real API. Webhooks, live-mode options and other integrations are still
  reported only. `tests/checks/wp-clone-isolation.sh` asserts the new behaviour and that the
  report-only wording is gone. The mail guard section now also says `pre_wp_mail` does not stop
  code that drives PHPMailer directly, or a plugin that replaces `wp_mail()` wholesale, and that
  redefining `wp_mail()` in a must-use plugin is the stronger guard.

- **`/wp-clone` reads each long step when it reaches it.** `commands/wp-clone.md` was 38 KB, and
  every run paid for both clone paths and the post-clone verification up front, though a run
  takes one path. It is now a 13 KB map: every step heading, entry condition and the step order
  stay, and three long parts send the run to one file each in the new `wp-clone-run` skill —
  Path A (SSH automated clone), Path B (manual import) and Step 6 (post-clone verification and
  summary). No step's wording changed. The checks that read `/wp-clone` now read it with its
  references expanded in place, and `tests/checks/wp-clone-run.sh` fails when a reference is
  not pointed to at its step or not listed in the skill.

- **`/wp-create` reads each long step when it reaches it.** `commands/wp-create.md` was 37 KB,
  and every run paid for all of it up front, including the plugin-profile install and the
  manifest shape. It is now a 26 KB map: every step keeps its heading, entry condition and
  order, and three long parts send the run to one file each in the new `wp-create-run` skill —
  Step 4.3 (environment config templates), Step 4.10 (plugin profile install) and Step 5 (the
  `.wp-create.json` manifest). No step's wording changed. The checks that read `/wp-create`
  now read it with its references expanded in place, and `tests/checks/wp-create-run.sh` fails
  when a reference is not pointed to at its step or not listed in the skill.

- **`/wp-demo` reads each long step when it reaches it.** `commands/wp-demo.md` was 56 KB, and
  every run paid for all of it up front, including the craft brief, composition plan and craft
  build on a plain build that never uses them. It is now a 19 KB map: every step keeps its
  heading, entry condition and order, and four long parts send the run to one file each in the
  new `wp-demo-run` skill — Step 2.6 items 3 (brief), 5 (composition plan) and 6 (build), and
  Step 4.9 (section plan). No step's wording changed. The checks that read `/wp-demo` now read
  it with its references expanded in place, and `tests/checks/wp-demo-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.

- **`/wp-demo-verify` reads each long step when it reaches it.** `commands/wp-demo-verify.md`
  was 18 KB, and every run paid for the detector rules, the whole scroll walk and the catalogue
  of finding kinds up front. It is now a 7 KB map: every step heading, the target resolution,
  the inert-control grade, the sheet critique and the report stay, and three long parts send
  the run to one file each in the new `wp-demo-verify-run` skill — Step 2a (detector), Step 2b
  (walk) and Step 3 (reading the findings). No step's wording changed. The checks that read
  `/wp-demo-verify` now read it with its references expanded in place, and
  `tests/checks/wp-demo-verify-run.sh` fails when a reference is not pointed to at its step or
  not listed in the skill.

- **`/wp-finalize` reads each long check when it reaches it.** `commands/wp-finalize.md` was
  36 KB, and every run paid for all of it up front, including the WP-CLI runtime validation, the
  GEO scan and the three demo-parity layers on a project that needed none of them. It is now an
  11 KB map: every step and check keeps its heading, entry condition and order, and seven long
  checks send the run to one file each in the new `wp-finalize-run` skill — Check 2 (bilingual
  coverage), Check 4 (theme structure), Check 7 (WP-CLI runtime validation), Check 8 (GEO and
  agent-readiness) and demo-parity Layers 1 to 3. No check's wording changed. The checks that read
  `/wp-finalize` now read it with its references expanded in place, and
  `tests/checks/wp-finalize-run.sh` fails when a reference is not pointed to at its check or not
  listed in the skill.

- **`/wp-header` reads its long step when it reaches it.** `commands/wp-header.md` was 18 KB,
  and every run paid up front for the whole `wp-template` prompt, the CSS routing and the
  `wp-tailwind` author-mode prompt. It is now a 7.5 KB map: every step heading, the argument
  handling and Steps 5 to 8 stay, and Step 4 sends the run to two files in the new
  `wp-header-run` skill. No step's wording changed. The checks that read `/wp-header` now read
  it with its references expanded in place, and `tests/checks/wp-header-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.

- **`/wp-init` reads each long step when it reaches it.** `commands/wp-init.md` was 49 KB, and
  every run paid for all of it up front, including the Demo-First Path and the font carry on a
  scaffold with no demo. It is now a 22 KB map: every step keeps its heading, entry condition
  and order, and five long parts send the run to one file each in the new `wp-init-run` skill —
  the Demo-First Path (Steps D1-D5), Step 4.5 (font carry), Step 5 (i18n), Step 7 (the project
  `.claude/CLAUDE.md`) and Step 9 (plugins, activation, site identity, Tailwind build). No
  step's wording changed. The checks that read `/wp-init` now read it with its references
  expanded in place, and `tests/checks/wp-init-run.sh` fails when a reference is not pointed to
  at its step or not listed in the skill.

- **`/wp-page` reads each page type when it reaches it.** `commands/wp-page.md` was 19 KB, and
  every run paid for the dispatch prompts of all seven page types up front, though a run builds
  one. It is now a 10.8 KB map: the argument parse, the CSS agent routing, the `tailwind` prompt
  body and the generic and custom types stay, and five long types send the run to one file each
  in the new `wp-page-run` skill (blog, legal, 404, search, embed). No type's wording changed.
  The checks that read `/wp-page` now read it with its references expanded in place, and
  `tests/checks/wp-page-run.sh` fails when a reference is not pointed to at its type or not
  listed in the skill.

- **`/wp-section` reads its dispatch detail when it reaches Step 5.** `commands/wp-section.md`
  was 33 KB, and every run paid for all of it up front, including the two-phase contact flow on
  a section that is not a contact section, and the other way round. It is now a 14 KB map: every
  step keeps its heading, entry condition and order, and Step 5 sends the run to one file each in
  the new `wp-section-run` skill — the dispatch rules every section shares (field naming, GEO
  citability, the `--transcribe` overlay, CSS agent routing, file ownership), the three-agent
  dispatch for an ordinary section, and the two-phase dispatch for a contact section. No step's
  wording changed. The checks that read `/wp-section` now read it with its references expanded in
  place, and `tests/checks/wp-section-run.sh` fails when a reference is not pointed to at its step
  or not listed in the skill.

- **`/wp-seed` reads each long phase when it reaches it.** `commands/wp-seed.md` was 45 KB, and
  every run paid for all of it up front, including the menu and bilingual detail while still
  parsing the demo. It is now an 18 KB map: every step and phase keeps its heading, entry
  condition and order, and six long parts send the run to one file each in the new
  `wp-seed-run` skill — Phase 1 (parse the demo), Phase 3 (import media), Phase 4 (ACF fields),
  Phase 5 (bilingual content), Phase 6 (menus) and Phase 7 (final setup). No phase's wording
  changed. The checks that read `/wp-seed` now read it with its references expanded in place,
  and `tests/checks/wp-seed-run.sh` fails when a reference is not pointed to at its phase or
  not listed in the skill.

- **`/wp-tailwindify` reads its two long steps when it reaches them.** `commands/wp-tailwindify.md`
  was 15.4 KB, and every run paid for the agent dispatch context and the verification detail up
  front. It is now a 5.8 KB map: every step heading, the argument parse, the already-Tailwind
  check and the next-steps report stay, and Step 3 (the context handed to the `wp-tailwind` agent
  and the temporary-path write contract) and Step 4 (structural checks, the rendering parity gate
  and the checked move) send the run to one file each in the new `wp-tailwindify-run` skill. No
  step's wording changed. The checks that read `/wp-tailwindify` now read it with its references
  expanded in place, and `tests/checks/wp-tailwindify-run.sh` fails when a reference is not
  pointed to at its step or not listed in the skill.

- **`/wp-tailwind-migrate` reads its two long steps when it reaches them.**
  `commands/wp-tailwind-migrate.md` was 23 KB and every run paid for all of it up front. It is
  now a 14 KB map: the baseline gate, the Tailwind v4 check, the golden capture and the other
  steps keep their wording in place, and Step 4 (the author-mode dispatch) and Step 6 (the
  convention check and the before/after comparison) send the run to one file each in the new
  `wp-tailwind-migrate-run` skill. No step's wording changed. The checks that read the command
  now read it with its references expanded in place, and
  `tests/checks/wp-tailwind-migrate-run.sh` fails when a reference is not pointed to at its step
  or not listed in the skill.

- **`/wp-yolo` reads each long step when it reaches it.** `commands/wp-yolo.md` was 76 KB, and
  every run paid for all of it up front, including the Tailwind conversion on a basic-template
  build and the build ledger on a run that never resumes. It is now a 32 KB map: every step
  keeps its heading, entry condition and order, and eight long steps send the run to one file
  each in the new `wp-yolo-run` skill. Steps 1, 4 and 5 stay whole, because they are the gates
  and the dispatch order. No step's wording changed. The checks that read `/wp-yolo` now read
  it with its references expanded in place, and `tests/checks/wp-yolo-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.

### Fixed

- **`demo-verify.mjs --probe` finds a globally installed Playwright.** The script resolved
  `playwright-core` from `PLAYWRIGHT_CORE`, then a bare import from `bin/`, then the working
  directory's `node_modules`. On a machine where Playwright is installed only globally
  (`npm i -g @playwright/test`) none of those exist, so the probe printed
  `probe: missing playwright-core` and exited 2 although a working copy sat under
  `npm root -g`; the docs worked around it by telling people to set `PLAYWRIGHT_CORE` by hand.
  A last rung now asks `npm root -g` (short timeout, errors swallowed) and tries
  `<root>/playwright-core` and `<root>/@playwright/test/node_modules/playwright-core`.
  `PLAYWRIGHT_CORE` still skips the ladder, so the forced-failure check stays deterministic.
  `tests/checks/demo-verify-global-playwright.sh` covers it with a fake `npm`.

- **The tailwind starter stops printing a second meta description beside an SEO plugin.**
  Its `functions.php` printed `<meta name="description">` on the front page with no early
  return, so a site running Rank Math — which `/wp-create`'s plugin profiles install —
  shipped two description tags. The detection already existed as
  `<prefix>_seo_plugin_owns_schema()`, the guard identity JSON-LD returns on, but only inside
  the `inc/agentic.php` that `wp-agentic-surfaces` writes during a GEO fix, so the starter
  could not call it; and `wp-theme-standards` taught a second, narrower detection (two
  constants, no SEOPress). The starter now defines that one guard and returns on it before
  the tag; `inc/agentic.php` declares it only inside `function_exists()`, since a theme
  built from the starter already has it and a second declaration is a fatal; and the skill
  teaches the same guard. The cinematic starter prints no description, so it had nothing to
  fix. `tests/checks/meta-description-seo-plugin.sh` fails on a starter description tag
  printed before the guard returns, on a second SEO-plugin detection, on the starter's and
  the agent's guards detecting different plugins, and on an unguarded declaration in the
  agent.
- **`/wp-demo-verify`'s static-page gate stops counting a device that does not exist.**
  `bin/demo-verify.mjs` still listed `cascade` as scroll-reactive after the device left the
  motion contract, because `motion.js` never implemented it — so a page carrying
  `data-motion="cascade"` beside its reveals passed the gate while nothing on it moved.
  `count` had the mirror defect: the gate read it off a `data-motion="count"` value, which
  is inert, while `motion.js` dispatches it off `data-motion-count` alone, so a real counter
  counted for nothing and a page whose only scroll device was one failed. Measured against
  both on Chromium: the old gate passed the cascade page and failed the counter page; it
  now does the reverse. `tests/checks/wp-craft-consistency.sh` holds the gate's set to the
  devices `motion.js` binds, `count` to the attribute both files read, and the whole set to
  the interior floor `devices.md` states.
- **The cinematic starter keeps a `?lang=` switch.** Its `inc/i18n.php` read
  `$_COOKIE['__starter___lang']` and never called `setcookie()`, so a language switch lasted
  exactly one request and the next page came back in the browser's language. An `init`
  callback now sets the cookie before any output, as the tailwind starter does — and only
  when the language came from `?lang=` and differs from the one already stored, so an
  ordinary page view sends no header. `wp-bilingual`, its i18n reference and `wp-cinematic`
  no longer say the starter sets no cookie. `tests/checks/wp-bilingual-contract.sh` runs the
  file and asserts the cookie is set on a switch, and not re-sent when it already matches or
  when the language came from `Accept-Language`.
- **`/wp-seed` sets a post author.** Every `wp post create` and `wp media import` it ran
  left `post_author` at 0, a user that does not exist: the pages rendered, `the_author()`,
  the Article schema's `author` and the admin column came out empty, and every seeded page
  failed `/wp-finalize` Check 7's author sweep. `wp-cli-patterns` already had the rule and
  the recipe ("Always set an author"); the command now follows it — it resolves an
  administrator once in Step 0, stops when there is none, passes `--post_author` to every
  create and import (including the Polylang counterparts and the `page_link` placeholder
  pages), gives an author to a previously seeded page that has none when it updates it in
  place, and runs the same sweep before it reports. The same omission is fixed where it
  repeated: the skill's own examples, `wp-template`, `wp-acf`, `/wp-cinematic-seed`,
  `/wp-cinematic-encode`, and `pll-import.php`, whose new counterparts came from
  `wp_insert_post()` under `wp eval-file` — user 0 again — and now take their source's
  author. `tests/checks/seed-post-author.sh` fails on any create or import command in a
  command, agent or skill that carries no `--post_author`.
- **Menu locations agree between the commands and the starters, on both i18n strategies.**
  Both starters register and render `primary-<lang>` / `footer-<lang>`, hyphenated, but
  `/wp-init` and `/wp-header` told the agent to register `primary_en`, `/wp-seed` assigned
  menus to `primary_en` / `footer_en` and `/wp-finalize` verified those names, so a suffix
  site's nav rendered nothing, with HTTP 200 and no notice (`fallback_cb` is `false`).
  Under `polylang` `/wp-init` registered a bare `primary` while the starter templates still
  asked for `primary-<lang>`, which left both languages with no nav. Templates now ask
  `<prefix>nav_location('primary')` in `inc/i18n.php` instead of building the name, and
  each strategy's file answers for itself (`primary-<lang>` from the suffix helper, the
  bare name from the Polylang variant). `/wp-init` Step 6 names the cinematic starter's
  `functions.php`, which has no `inc/theme-setup.php`, and scopes the string registration
  to `tailwind`, the only starter with `<prefix>get_translations()`. `/wp-header`,
  `/wp-footer`, `wp-template` and `wp-cinematic` render through the helper, and `/wp-seed`
  assigns the footer location as well as the primary one on both strategies. The tailwind
  starter's `mobile-<lang>` locations are gone: nothing rendered them and nothing assigned
  them, so `/wp-finalize`'s "every registered location has a menu" gate failed on them.
  `/wp-cinematic-init` pointed at an `inc/seed-menus.php` that no starter ships, and now
  defers to `/wp-seed` Phase 6. `tests/checks/menu-locations.sh` compares what every
  starter registers, renders and answers against what each command registers, assigns and
  verifies, per strategy.
- **`robin-fix.sh` works on a site with a table prefix other than `wp_`, and stops failing
  silently.** `$table_prefix` was matched with an unescaped `$` — a regex end-of-line anchor
  — so the prefix always read as `wp_` and every query on any other site hit tables that do
  not exist. A missing WordPress root or an unparseable `wp-config.php` exited 1 with no
  message (a failing command substitution under `set -e`); double-quoted defines and a
  `DB_HOST` with a port or socket were not read; every query called `mariadb`, though the
  skill and `/wp-robin` accept a host with only `mysql`; the download fallback saved a 404
  page as the plugin zip, so the run died on unzip's own exit code with no explanation and
  left the temporary file behind, and it set the plugin as installed without checking that
  anything was; every settings write
  ended in `|| true` and the report counted keys, not writes; WP-CLI's activation check ran
  from the caller's directory instead of the site's; and the PHP GD converter used `match`
  (PHP 8 only) with no GIF branch, though GIF is an allowed format. It now lives in
  `scripts/webp-gd.php`, linted at 7.4 by CI. The skill no longer says the zip is downloaded
  when WP-CLI is absent or that the uploads directory is discovered, lists every binary the
  script needs, and states its exit codes. A credential is read to the quote that opened it,
  so a single-quoted password holding `"`, `;` or `)` (or a double-quoted one holding `'`)
  reaches the client whole. With `cwebp` chosen, a GIF goes to `gif2webp` only when it is
  installed, and to GD when it is not; with neither, the run says once that GIFs get no
  `.webp` instead of failing each one as "conversion failed". An image size registered with
  double quotes (`add_image_size( "hero", … )`) is read by name instead of being stored as the
  raw call text, and every setting is escaped for its SQL literal, so a backslash or quote in a
  size name read from theme source cannot end the string.
  `tests/checks/robin-fix-behavior.sh` runs the script against a fake site, client and
  network.
- **The release ritual in `wp-contributing` and `/wp-contribute release` gates for real.**
  It chained `for … done && bash bin/doc-sync-check.sh`, and a loop's status is its last
  iteration's, so a red check earlier in the alphabet passed the gate. It also never
  reconciled `BACKLOG.md`, so following it cut a release that `backlog-freshness.sh` failed,
  and never said how to push the tag. Both now aggregate, reconcile, re-run the gates and
  push with `git push origin main && git push origin vX.Y.Z`. `CONTRIBUTING.md` lists `model`
  among an agent's required frontmatter keys, which `model-routing.sh` already enforced.
- **`wp-environments` describes the environment `/wp-create` builds.** Its manifest sample
  still carried `"password": "root"`; it ran `bin/wp-env-setup.sh` by a relative path; its
  placeholder table listed `{{db_host}}`, which no template uses, and missed nine tokens the
  templates do, so a `docker-compose.yml` or `.wp-env.json` built from it kept unreplaced
  `{{http_port}}` and `{{tests_port}}`; it checked 3306 (unpublished) and missed Mailpit's
  SMTP port; its PHP table typed package names the script does not install and called
  `php-list` a list of available versions; and it said a project without `.wp-create.json`
  works unchanged, where the gate exits 3. `tests/checks/wp-environments.sh` diffs the table
  against every token under `templates/`.
- **`/wp-s3 --revert` needs the transfer client, and the skill says so.** The skill called
  the client "Only for `/wp-s3-media`", but the revert downloads the media through
  `s3-media.sh download`, with a key pair. The missing-client message also told the operator
  to install it inside the plugin directory, which a plugin update replaces.
- **`wp-woocommerce` no longer describes unbuilt pieces as built.** A catalog product
  "offers an enquiry form … or a WhatsApp button", products were "the Polylang bridge's job",
  and `/wp-woo-setup` put the WhatsApp number in "the theme's settings page": no starter
  renders either channel, carries those fields, or has a bridge.
- **`wp-responsive`'s examples produce working output.** `references/images.md` passed the
  ACF image field to `wp_get_attachment_image()` as an ID, but `agents/wp-acf.md` generates
  image fields as arrays, so the call printed nothing; it now passes `$image['ID']`, and the
  hand-built `srcset` with guessed width descriptors is gone. Every hero example carried
  `loading="lazy"` against the skill's own LCP rule; heroes now set `fetchpriority="high"` and
  `'loading' => false`. The navigation reference taught a drawer that fails the audit's
  A11Y-031 — no focus trap, no Escape, no focus return, closed links still tabbable behind
  `aria-hidden` — and left body scroll locked when the viewport crossed 1024px with the menu
  open; it now does all four (verified in Chromium). The no-horizontal-scroll fix put
  `overflow-x: hidden` on `.container`, hiding the overflow the section exists to find; it now
  sends the reader to the culprit `/wp-demo-verify` names. `tests/checks/wp-responsive.sh`.

- **The `wp-demo` skill no longer contradicts its command or its own rules.** It gave
  plain-mode rules to every build without reading the recorded `demo mode`, so a craft build
  loaded two contradicting instruction sets; it now says which parts apply in which mode. It
  and `commands/wp-demo.md` Step 4 disagreed on token names (`--color-bg` against
  `--color-background`), fonts (no CDN against a Google Fonts link) and images (SVG against
  `placehold.co`); both now use `wp-css-system`'s token names, the one Google Fonts link
  `/wp-init` self-hosts, and an inline-SVG `<img>` — `/wp-seed` imports every `img[src]` URL it
  finds. It told builds to extract CSS into an `assets/css/styles.css` no current starter has.
  Its skeleton broke its own accessibility rules (no skip link, no `id="main-content"`, a
  hamburger without `aria-expanded`, `.sr-only` never defined, no focus style, no language
  switcher), used a `.footer__tagline` class `/wp-seed` never reads and a bare `<p>` copyright,
  hard-coded `© 2025`, and printed the footer twice. It also claimed two external skills were
  "invoked automatically"; nothing invokes them. `tests/checks/wp-demo-skill.sh`.

- **`wp-demo-craft`'s references agree with each other and with the engine.**
  `design-md.md` defaulted `--motion-rise` to 22px, below the ~35px floor `devices.md` calls
  invisible and against the compositions' 44px fallback. `devices.md` offered a `cascade`
  device `motion.js` never implemented, left `data-motion-peak` and `data-motion-rail` out of
  its "exactly as declared" contract, called the signature move optional while `uniqueness.md`
  and `/wp-demo` require it, and named non-existent "shadow tokens". `taste.md` named tokens and
  classes that exist nowhere (`--space-1..11`, `--font-measure`, `--shadow-e1/2/3`,
  `--transition-ease-out`, `.scrim--lead`/`--trail`) and an engine behaviour no engine has;
  `icon-row` and `score-scale` read a `--color-muted` no `DESIGN.md` defines, so their muted
  text silently inherited full ink. `process-rail` put its heading inside the pan rail — the
  advice `devices.md` retracts because it pans the section's label off screen — and allowed
  three steps where `pan` needs five; the heading now sits above the rail and the minimum is
  five (previews re-rendered). The scroll budget was restated with different numbers in
  `taste.md`, `feel.md` and `compositions.md`; pointers led to a `devices.md §10` and SKILL.md
  "pre-build checks" that do not exist; two counts were wrong; the role table had two rows on
  one line; and two files ran plugin scripts by relative paths.
  `tests/checks/wp-craft-consistency.sh`.
- **The audit's report contract is the one the renderer reads.** `wp-audit-standards` told
  every agent to emit an `issues` array with lowercase severities, `code` and `fix_method`;
  no agent did, `bin/audit-report.mjs` reads none of it, and the schema had no `status` for
  the `N/A` and `UNMEASURED` answers the skill itself demands. Each agent had drifted into a
  shape of its own — `code` beside a `check` that meant the check's *name*, `title`/`details`/
  `autofix`, a GEO severity `ERROR` the renderer refuses — so the run file had to be rebuilt
  by hand from six vocabularies. The skill now states the renderer's fields (`check`,
  `status`, `severity`, `ownership`, `resource`, `message`, `checks_executed`) and where each
  status goes, every agent's example uses them, GEO's `ERROR` is written `CRITICAL`, and the
  dispatch prompt names `WP-NNN` and `UX-NNN` instead of a `BP-NNN` no agent emits. The same
  skill read WCAG's 18pt as 18px; large text is ≥24px, or ≥18.66px bold.
  `tests/checks/audit-report-contract.sh` holds all of it.

- **Usability coverage counts the whole catalog.** `/wp-audit` Step 2.5d and the Step 6.8
  gate read `UX-*` ids from `agents/wp-audit-ux.md`, which names 8 of the 36 criteria, so the
  other 28 could never be reported as never measured. Both now read the table rows of
  `wp-audit-ux-standards`. The catalog's owner column follows the browser suite for the
  criteria the suite emits (`UX-015`, `UX-038` were `content` here and `code` there, so a
  defect's owner depended on whether `--suite` ran), `UX-009` stops restating the 24×24
  target size that is `A11Y-028`'s, applicability is stated once instead of twice with
  different answers, the numbers the suite owns are named so a new criterion cannot take
  one, and the skill no longer says rendered criteria need `--suite` when `bin/ux-probe.mjs`
  measures them. `tests/checks/audit-ux-owners.sh` and
  `tests/checks/audit-ux-standards-contract.sh` are new; the coverage check reads the skill.

- **The local SEO checks read Rank Math's real option, and the phone rule reconciles its own
  example.** `wp-audit-local-standards` and `wp-audit-seo` read `rank_math_titles`, which
  Rank Math never writes (`rank-math-options-titles`), so its name, address and phone
  silently dropped out of the NAP comparison. Digits-only phone normalization left
  `+34 900 00 00 00` and `900000000` unequal, the false positive the rule exists to prevent;
  it now strips the country code, with worked pairs. The bilingual comparison is no longer
  conditional on `suffix` (options-page fields keep `_<lang>` under both strategies),
  click-to-call applies to service-area businesses too, an absent address is not reported on
  one, `SEO-063` runs on an undetermined site, recommended schema properties stop being
  findings no check id carries, `aggregateRating` is never recommended, and locations link
  with `parentOrganization`, which supersedes `branchOf`.

- **`wp-audit-geo-standards` agrees with `bin/geo-scan.sh` and the fixer.** A non-public host
  exits `3`, not `2` as the skill said, and `--start` is documented. `Content-Signal` is an
  HTTP header only — the skill also asked for a per-`User-agent` robots block, the one line
  the fixer refuses to write because it makes the file invalid, and the auditor looked for the
  signal inside `robots.txt`. A catalog store's payment-protocol codes are `N/A`, as the
  auditor already had it; GEO-A07 to A10 are fixable only when no SEO plugin owns the graph;
  the robots body lists every crawler the table allows (`GoogleOther` was missing);
  `anthropic-ai` is one thing in both files; GEO-D04 is the `/agents.md` route the fixer
  serves; and the citability rubric is no longer said to be scored by an auditor that has no
  code for it. `tests/checks/wp-geo.sh` pins each.

- **The SEO fixer no longer shadows the GEO route it runs before.**
  `wp-audit-seo-standards` and `wp-audit-rankmath` wrote a physical `llms.txt` at the web
  root and a `robots.txt` naming six of the ten AI crawlers GEO-D02 requires. `/wp-audit`
  dispatches SEO fixes before GEO fixes, so every run that fixed both left a stale file in
  front of `inc/agentic.php`'s dynamic route (GEO-A26), and whichever agent wrote `robots.txt`
  last decided GEO-D02. `wp-agentic-surfaces` is now the one writer of both; the SEO skill
  keeps the classic robots block, identical to the writer's. The WooCommerce SEO commands
  stop writing to fixed `/tmp` paths that concurrent audits share, and an empty sitemap list
  is `UNMEASURED` instead of a silent pass. `tests/checks/seo-robots-llms-owner.sh` is new.

- **`wp-demo-craft`, `/wp-cinematic-demo` and `/wp-cinematic-scene` load with their own
  frontmatter again.** Each had a value that is not valid YAML unquoted: an unquoted `: ` in
  `wp-demo-craft`'s description and in `/wp-cinematic-demo`'s `<!-- SECTION: -->` example, and
  an `--cta` argument description in `/wp-cinematic-scene` starting with a backtick. Claude Code
  loads such a file with no fields set, so none of the three had a description to be matched
  on, and `wp-demo-craft`'s `user-invocable` fell back to true, putting it in the `/` menu as
  if it were a command. The values are quoted or rephrased, and the new
  `tests/checks/frontmatter-yaml.sh` fails on those shapes in any command, agent or skill.

- **The `wp-demo` skeleton is mobile-first.** It ended in a trailing `Section: Responsive`
  block of `@media (max-width: …)` queries, against the min-width-only rule in its own skill
  and in `wp-responsive`, and outside every section's block, so a section's CSS could not move
  to its template part whole. A demo copied from it inherited both. Each section now carries
  its own `min-width` steps; `tests/checks/wp-demo-mobile-first.sh` holds it there.

- **Every bundled script is named in its own skill.** `resolve-link-targets.php`
  (`wp-cli-patterns`), `pll-setup.php` and `pll-export.php` (`wp-polylang`) and
  `read-s3-config.php` (`wp-s3`) were run by commands and other scripts but absent from the
  SKILL.md that ships them, so the skill could not tell Claude whether to run them.
  `wp-cli-patterns` and `wp-polylang` now index their scripts with what each is for, `wp-s3`
  says its config reader is a helper never run by hand (its `--export` mode prints the
  secret), and `tests/checks/skill-authoring.sh` fails on an unnamed script.

- **The i18n skills describe the code they ship with.** A review of `wp-polylang`,
  `wp-bilingual` and `wp-cli-patterns` against the scripts and starters found them telling
  agents things that were false:
  - `wp-polylang` said ACF containers were walked one level deep and told the reader to widen
    `pllx_acf_walk()`, which already recurses to any depth, so an agent would
    hand-translate fields the importer already handles. It placed `pllx_acf_ref_id()` in
    `pll-import.php` (it is in `pll-lib.php`), said non-text ACF types were "untouched by the
    importer" (they are copied onto a new counterpart), and cited a gitignored `.superpowers/`
    report and a fixture that only ever existed on a maintainer's own site.
  - `wp-bilingual` documented `prefix__()`, `prefix_is_spanish()` and
    `prefix_get_js_translations()`, none of which any starter defines — a template written from
    it fatals — and never mentioned that the cinematic starter ships a different three-helper
    contract with no `prefix_get_field()`. Its reference was a hand-kept copy of the starter's
    `inc/i18n.php` that had drifted; it is now a pointer to that file plus what the code does not
    explain. Its Spanish samples had lost their accents.
  - **`<html lang>` never followed the language on a suffix site.** The skill appended a second
    `lang` after `language_attributes()`, and a browser keeps the first of two, the site locale.
    Both starters' `inc/i18n.php` now filter `language_attributes`, so `?lang=es` pages declare
    Spanish, and both filters return a string even when `preg_replace()` fails.
  - **The tailwind starter's language cookie could not be set.** The first call to
    `prefix_get_current_lang()` — the one that sets it — came from `wp_enqueue_scripts`, inside
    `wp_head()`, after output had begun, so a language switch lasted one page on a server
    without output buffering. The starter now makes that call on `init`, and the skill states
    the real rule instead of "include `i18n.php` early".
  - `wp-cli-patterns` taught `_es` suffix fields and per-language menu locations without
    reading the recorded `i18n strategy`, so on a Polylang project (the default) it seeded
    fields Polylang never serves and assigned menus to `primary_en`, a location neither
    starter registers. It glossed `wp post delete --force` as a confirmation skip — it deletes
    permanently — documented exits 0/1 for two scripts that also exit 2 when they could not
    measure, and invoked every script through an unresolvable `<skill>/` path.
  - `/wp-polylang` and `/wp-seed` cited their skills by a relative path, which resolves against
    the user's project.

  `tests/checks/wp-bilingual-contract.sh` (which runs both starters' `inc/i18n.php`) and
  `tests/checks/wp-cli-patterns-contract.sh` are new; `wp-polylang.sh` and
  `wp-polylang-nesting.sh` gained pins that fail on each old form.
- **The CSS and theme skills stopped teaching output that breaks.** A fresh review of
  `wp-aos-animator`, `wp-theme-standards`, `wp-css-system` and `wp-tailwind-system` found code
  an agent would copy and ship broken:
  - **`wp-aos-animator`** enqueued AOS with `_RATIO_WEB_`, one client project's constant —
    undefined anywhere else, so a PHP 8 fatal on every page — plus a `jquery` dependency AOS
    does not have and nothing ordering the deferred bundle after AOS, which turned the init
    into a silent no-op. It used `fade-up-slow`, which `aos.css` does not define, and a delay
    of 20, which matches no selector (`aos.css` ships 50 to 3000 in steps of 50); downloaded
    with `curl -sL`, which saves a 404 page as `aos.js`; and audited only `assets/js/*.js`, so a
    re-run on the starter's `assets/js/src/` bundle added a second `AOS.init`. Nothing kept it
    out of a craft or cinematic theme, which already ship a motion engine: a Phase 0 now reads
    `demo mode` and `Template:` and stops. `tests/checks/wp-aos-seams.sh` judges every
    animation name, delay, constant and download line it teaches.
  - **`wp-theme-standards`** overrode `wp_check_filetype_and_ext` for every upload, switching
    off core's content check for all file types (the starter never shipped it); taught one
    fixed layout matching neither starter, so a Tailwind theme got a second stylesheet; enqueued
    remote Google Fonts that `/wp-init` self-hosts and PERF-022 reports; printed an
    `Organization` JSON-LD block with no SEO-plugin guard, two nodes beside Rank Math's; and
    read raw `get_field()`, keyed page assets on slugs (one language under Polylang), preloaded
    the LCP original with no `imagesrcset` (two downloads on mobile) and sanitized `$_GET`
    without `wp_unslash()`. The layout is now read from the recorded template and its starter,
    identity JSON-LD belongs to `inc/agentic.php`, and the new
    `tests/checks/wp-theme-standards.sh` fails on each old form.
  - **`wp-css-system`**'s gate stopped only on `tailwind`, leaving cinematic themes and demos
    with no `Template:` line unanswered; its sample palette read as defaults to ship; its grid
    example had no mobile base and its outline button a border; and `agents/wp-css.md` (and one
    skill example) used `--color-white`, `--color-accent` and `--color-accent-dark`, which the
    token reference never defines. `wp-css-tokens.sh` now resolves every `var()` the examples
    use, and the new `wp-css-system-contract.sh` holds the examples to the skill's own rules.
  - **`wp-tailwind-system`**'s `references/breakpoints.md` marked `max-[769px]:hidden` — the
    form its heading forbids — as the right conversion and said `max-[759px]` is `≤ 759`; two
    references called plugin scripts by a bare `bin/` path (exit 127 from the user's project);
    and Verify ran the convention check before any compile, where it skips its markup rule and
    passes. Verify now compiles first, runs `theme-template-check.mjs`, states exit codes and
    loops; the new `tests/checks/wp-tailwind-system-traps.sh` pins it.

- **Re-adopting a site no longer wipes its audit history and confirmed code scope.**
  `wp-config.mjs adopt --replace` built a new manifest from the probe and kept only a backup,
  so the `audit` block (the next audit's baseline), the `store` block, the prefix, the industry
  and the code scope the operator had confirmed were lost; the scope was re-proposed from update
  transients and client code moved to read-only came back as editable. `/wp-audit` sends the
  operator to `--replace` whenever `drift` exits 4, so every such re-adoption did this. Over a
  real adoption `--replace` now carries those over (explicit flags still win, vanished paths are
  dropped, new plugins go through the normal proposal) and the dry-run reports `carried_over`;
  over a blank scaffold it behaves as before.

- **SEO and performance audits catch three false readings on WooCommerce and Elementor sites.**
  `wp-audit-seo` SEO-039 now counts BreadcrumbList blocks in the rendered shop and category
  pages: `WC_Structured_Data` adds its own to every `woocommerce_breadcrumb()` call, next to
  Rank Math's, and no theme grep sees it. The fix removes only WooCommerce's schema.
  `wp-audit-performance` PERF-048 explains Elementor's "Optimized Image Loading", which gives
  `fetchpriority="high"` to the logo and lazy-loads the real LCP after the theme has printed
  the page, and accepts one high-priority image per viewport. PERF-010 counts blocking scripts
  from the served HTML, not from a loaded DOM that holds scripts inserted after load.

- **Three readings that reported defects a site did not have.** The `wp-agentic-surfaces`
  markdown template now puts back the page `<h1>` when a theme prints it before `<main>`, and turns a
  form into "Form on this page. Fields: ..." instead of stripping it, so a contact page whose
  `<main>` holds only a form is no longer empty. `wp-audit-a11y` reads focus styles after the
  focus transition ends: a theme that animates its outline was reported with the colour from
  the middle of the animation. `/wp-clone` Step 6.2 warns that Elementor's local Google Fonts
  CSS under uploads keeps the original host's URLs, so the clone renders a fallback font and a
  visual comparison with production shows false differences.

- **A finding whose check was not measured in this run is no longer reported as resolved.**
  `compare()` in `bin/audit-report.mjs` counted every previous finding that was missing from the
  new run as resolved, including those whose check the run listed under `unmeasured` (a
  production-only check skipped on a local run) or whose category it did not cover, so skipping a
  check read as fixing it. Those findings now appear under "Not re-measured in this run" and stay
  in the sidecar flagged `not_remeasured`, so the first run that does measure them can resolve
  them. `tests/checks/audit-deliverable-report.sh` covers it.

- **A second audit report on the same day no longer erases the first one.** `bin/audit-report.mjs`
  names its files after the date only and skipped its own output path when it looked for the
  previous sidecar, so a re-run on the same day overwrote the morning's `.md`, `.html` and
  `.json` and then reported "No previous audit found". The earlier set is now kept as
  `informe-<date>-<HHMM>.*` (the time its sidecar was written) and becomes the previous run;
  sidecars sort by date and time. `tests/checks/audit-deliverable-report.sh` covers it.

- **Three audit gaps found on real runs of a local clone.** The browser suite (Step 6.5) held the
  production gate's per-host lock for many minutes while Step 6 agents waited, exited 5 and reported
  `UNMEASURED: production gate busy`; the docs now order it to start only after every agent has
  returned. Timing and size metrics (LCP, FCP, TBT, Lighthouse score, bytes) measured on a clone
  were reported as the site's although they inherit the clone's serving layer (one baseline came
  from a 468 KB uncompressed stylesheet that production serves as 69 KB of brotli over h2); they
  are now probed against production's, labelled `clone measurement — serving layer differs`, and
  never a baseline or finding by themselves. Cache-purge instructions now say that on a clone only
  local caches are purged, because `wp cfcache purge_cache` can call the real Cloudflare API with
  production credentials restored from the database.

- **Re-running the browser suite against the same site no longer fails.** `bin/audit-suite.sh`
  rewrites `baseURL` and `siteName` in the kept `audit.config.js` and asserted that the text
  changed, so a second `/wp-audit --suite` against the URL and site name the config already
  held stopped with "has no assignable baseURL" and measured nothing until someone edited the
  config by hand. The guard now asserts that the pattern matched: a same-value re-run passes,
  and a config with no `baseURL` still fails. `tests/checks/audit-suite.sh` covers both.

- **A symlinked checkout no longer makes the audit suite skip Tier 3 as "no browser".**
  `bin/lib/browsers.mjs` decided it was being run as a command by comparing `argv[1]` with
  `import.meta.url`; Node resolves symlinks for the second, so reached through a link (the plugin
  directory linked into place, or a path such as `.../claude-wp-builder` that is a link) the
  comparison failed, the lookup printed nothing and exited 0, and `bin/audit-suite.sh` read that
  as "no existing Chromium" and exited 2. Both sides are now compared by real path, and
  `tests/checks/audit-suite.sh` passes again from a linked path.
  `tests/checks/browser-resolution.sh` covers it.

- **`/wp-clone` left Elementor URLs pointing at production and broke on production cache drop-ins.**
  Search-replace only matched the plain `https://old-host`, but Elementor stores URLs
  JSON-escaped (`https:\/\/old-host`) in `_elementor_data` and `_elementor_element_cache`; on a
  real store clone 149 values kept the production host (broken banners, assets loaded from
  production). Both paths now run a second, escaped pass (exact quoting shown) and `elementor
  flush-css`, and verification counts the host in postmeta in either spelling. Separately, a
  production `object-cache.php` or `advanced-cache.php` made every WP-CLI call fail on a machine
  without that backend; a new step parks them as `.bak`, sets `WP_CACHE` false and records both
  in the report.

- **The composition gate ignores `hero-eyebrow-chip` for now, and keeps following the newest
  `impeccable` 4.x.** impeccable 4.5.1 and 4.5.2 added a `hero-eyebrow-chip` rule that flags the
  kicker above the title in `hero-bleed`, `hero-split`, `hero-type` and `page-head`, so
  `tests/checks/wp-craft-composition-gate.sh` and `Contract checks` failed on `main` and on every
  open PR with no change in the repository. Restyling those kickers is a design change that needs
  measuring and approval, so it is a separate PR. Until then `bin/composition-gate.sh` lists the
  rule in `IGNORED`, prints how many findings it skipped on every run, and still blocks on every
  other slop rule, new ones included. The check fails if the gate is pinned to one version or the
  ignore list changes without it. `/wp-demo-verify` is unchanged and still reports the rule on a
  built demo.

- **The composition gate retries the detector once on an empty payload.** `impeccable@4`
  is resolved against the registry on every run, so a dropped connection left an empty
  findings file and failed the gate (and its check) as "could not scan", then passed on the
  next run. An empty answer is now retried once; any JSON the detector returns is used as is.

- **`/wp-demo-verify --no-motion` stops an existing site from failing on an engine it never had.**
  `/wp-responsive-check` now dispatches to `/wp-demo-verify`, and a URL target runs against any
  page. Against a site the plugin did not build, every section on every page reported the
  blocking `no-engine` (40 rows across 5 pages in a real run, with overflow and clipped copy all
  clean), so the walk exited 1 for a reason that does not apply, which teaches people to ignore
  the gate. The flag drops the `no-engine` and `dead-scroll` judgments and keeps overflow,
  clipped copy, container-noop, the full-page shots and the Firefox pass. It is explicit rather
  than inferred because a converted plugin page that lost its engine looks identical and must
  still fail; without the flag a URL page with no `[data-motion]` only gains one line suggesting
  it. `/wp-responsive-check` passes it for existing sites.

- **The `wp-design-library` MCP server starts under npm 12.** npm 12 no longer runs a
  dependency's install scripts unless the package is allowed, so `npx` installed
  `better-sqlite3` without building its native binding and the server died at startup with
  `Could not locate the bindings file`; the client reported `Connection closed`. `.mcp.json`
  now passes `--allow-scripts=better-sqlite3` to `npx`, which allows that one package and
  nothing else; npm 11 accepts the flag as well. A cache entry
  left broken by an earlier start is not rebuilt: delete its `~/.npm/_npx/<hash>` folder once.

- **`tests/checks/lib/expand-command.sh` no longer overwrites a caller's `r`.** Its loop
  variable was not declared `local`, so a check that held a path in `r` and then expanded a
  command grepped the wrong file. `wp-behaviour-gates.sh` was the first check to hit it.

- **`tests/checks/lib/expand-command.sh` splices in only the command's own `-run` references.**
  It expanded every `skills/*/references/*.md` path a command named, so a command that points
  at another skill's reference as reading (`/wp-demo` names `wp-demo-craft`'s `fingerprint.md`)
  got that file's text spliced in, and a check could pass on wording the command never
  carried. It now expands only `skills/<command>-run/references/`.

- **`geo-scan.sh` no longer presents two kinds of report as the site's current score.** A
  report that already existed was printed with exit 0 whatever its age, so an audit run after
  fixes could read the previous day's scan. The script now prints the report's `scanned_at`
  age on stderr and, past 24 h (`--max-age-hours N` or `GEO_SCAN_MAX_AGE_HOURS`), re-requests
  a scan through the same call the no-report path uses (with `--start`); a report it cannot
  refresh is printed marked `STALE:` with the new exit `4`. A report whose body is a CDN
  bot-challenge page (the scanner was served "One moment, please..." and scored that) is no
  longer printed as a score: it exits `2` with `SKIP: CHALLENGED` and the evidence. The
  audit docs map these to `Live scan: <score> (stale: scanned <date>)` and
  `Live scan: unavailable — challenged by a bot interstitial`.

- **The language cookie is `SameSite=Lax` and `HttpOnly`, and `Secure` on HTTPS.** Both
  starters set it with the options array; no starter script reads it, so nothing needs
  JavaScript access. The SEO-plugin detection the starter, `wp-agentic-surfaces` and
  `wp-theme-standards` share calls `class_exists()` without the autoloader, so a Composer
  autoloader cannot load a same-named class from another package while probing.

- **The `*-run.sh` checks match a step title's dots literally again.** Moving them to the
  `^## ${step}( |:)` regex let the `.` in a title like `Step 4.4` match any character, so a
  renamed heading such as `## Step 4X4:` still read as the step. Dots are now passed as `[.]`,
  which means the same thing to `grep -E` and to `awk` (an escaped `\.` in `awk -v` loses its
  backslash).

- **The `*-run.sh` checks now fail clearly on an empty `references/` and bound each step at any `##` heading.**
  With no reference files, the loop ran once on the literal `*.md` glob and failed with "never
  sends the run to *.md"; each check now sets `nullglob` and says the directory has no references.
  The "pointer sits under its step" test reset only on `## Step` (or `Step|Path`, `Step|Phase`)
  headings, so a pointer moved under a later heading such as `## Report` in `/wp-tailwind-migrate`
  still read as inside the last step; any `##` heading now ends the step. The checks that matched
  `## Step N:` literally also accept `## Step N ` now, like the others.

## Older releases

Releases before 1.30.0 live in [docs/changelog-archive.md](docs/changelog-archive.md).
