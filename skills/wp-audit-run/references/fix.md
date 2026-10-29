# /wp-audit — Step 9

`commands/wp-audit.md` sends the run here at Step 9. Follow it in order; nothing in it is optional background.

## Contents

- The report-only exit, and the fix offer split by owner, `visual` fixes and builder first
- Adopted sites: editable code only
- Fix dispatch per category: security, SEO, a11y, performance, best practices, usability
- Usability fixes change how the site looks, so they are measured before and after
- GEO fixes: the live scan, its exit codes, and why none of them is a pass
- Counting fixes by owner, and the settings to repeat on staging and production
- Git hygiene for any phase that edits: clean tree, path-scoped commits, mass deletions
- Counting fixes by owner, the replay log, and backups for bulk database fixes
- Production on nginx: an `.htaccess` fix is not a production fix
- The production runbook, rendered from the replay log

If `--report-only` was set, print:
```
Report complete. Use /wp-audit (without --report-only) to auto-fix issues.
```
And skip to Step 10.

Otherwise, if auto-fixable issues exist, use AskUserQuestion. Offer the work split by
owner rather than as one number, so the user can see what is being proposed:

```
M auto-fixable issues: C in code (travel with the commit), S in settings
(database or server — applied here, must be repeated on staging and production).
K more are content or manual and stay with you.
V change how the site looks and are NOT in that number: listed below, one at a time.

Apply them? (y/n)
```

When Step 8.5 did not run, derive the same split from the findings anyway — the owners are
a property of a fix, not of the report.

**The fourth class, `visual`.** Code, setting and content say where a fix lands; `visual`
says whether it changes the render, and it is decided first. A finding is `visual` when its
`design_impact` is `true`, or when its fix touches a colour or the palette, typography, a
size, spacing, an asset's dimensions, any new or modified CSS rule (focus styles included),
or a tag or class (a `<span>` becoming a `<button>` changes the render with no value
edited, and the reset class added to compensate can beat the utilities already on the
element). A finding with no `design_impact` field is judged by that list, never assumed
safe. The rules:

- A `visual` finding is **never** counted as auto-fixable, whatever its `Fix:` says, and a
  "y" to the offer above does not cover it. A report's "auto-fixable" label does not
  override this.
- List each one apart, with its **measurement before the change**: `getComputedStyle()` of
  the element (`color`, `backgroundColor`, `fontSize`, `fontFamily`, `borderWidth`,
  `borderRadius`) and `getBoundingClientRect()` (width, height), at desktop and mobile. Say
  what would change and why, then wait.
- Apply them **one at a time**, each after its own answer. Measure again after applying: the
  values must match the ones before, except what the user agreed to change. Do it on every
  element that shares the class or the component, at desktop and mobile. A mismatch outside
  what was agreed is a regression to fix before the next one, not a note in the report.
- `node ${CLAUDE_PLUGIN_ROOT}/bin/style-diff.mjs` takes this measurement on every element
  of a page (the recipe is under *Usability fixes* below); use it instead of picking
  elements by hand.
- When the user declines a `visual` finding it stays in the report as open, untouched.

**Builder first.** When `stack.builder` is not `none` (for example `elementor`) and the
element is a widget of that builder with a control for the setting, the preferred fix is
the builder's own data, not the theme's CSS: the same widget, edited where the site's editor
would edit it. Back up the builder's data for the affected posts before writing (a copy of
the builder's post meta, or a database export of those rows), and record the backup path.
The fix is `Owner: content`, because that data lives in the database and does not travel
with the commit. If the control cannot express what is needed (it has no separate light
and dark value, or no hover state, or it applies to a single widget when the defect is
site-wide), the fix goes to the theme instead, with the reason written in the finding's
`Method`. Either way it is `visual` and follows the rules above.

If the user declines, skip to Step 10.

If the user confirms, dispatch fix operations by category.

**Cache purges on a clone are local only.** When `local_clone` is true, tell every fix agent to purge only local caches (`$WP cache flush`, the plugin's local fallback or file cache). A CDN or page-cache purge command (for example `wp cfcache purge_cache` from a Cloudflare page-cache plugin) can call the real CDN API with the production zone credentials restored from the database. See *Purging caches on a clone* in `wp-cli-patterns`.

**On an adopted site** (Step 2.2), every `<theme_path>` below means the editable code only.
Pass `code_scope.editable` and forbid writes under `code_scope.read_only`. After each fix
agent returns, check that nothing under a read-only path changed:
`git status --porcelain -- <read_only paths>` when the root is a git repository, otherwise
modification times compared with a snapshot taken before dispatch. A write there is a
failed fix: revert it and report it. Additionally:

- **Security fixes:** dispatch `wp-audit-aios` only when `stack.security` is `aios`. With
  another security plugin, its configuration findings stay `manual`. The wp-config
  constants and server rules below still apply, because they belong to no plugin.
- **SEO fixes:** dispatch `wp-audit-rankmath` only when `stack.seo` is `rankmath`. With
  another SEO plugin, its option findings are `manual`, and the method names that plugin's
  setting.
- **GEO fixes:** `wp-agentic-surfaces` writes `inc/agentic.php` into the active theme.
  Dispatch it only when the active theme's directory is in `code_scope.editable`. Otherwise
  the GEO findings stay `manual`.

The categories:

**Every fix below is recorded as it lands.** Each fix agent's prompt says to append its entry
to `<out>/replay.json` (*The replay log*, below) before it starts the next fix, with the
`kind` that says how the fix reaches production. A theme file is recorded too, as `kind:
code`: the runbook needs it to check the commit and the theme activation.

**Security fixes:** Dispatch an agent with `subagent_type: wp-audit-aios` with the security level context and the list of security issues to fix. Also apply direct fixes where applicable (wp-config constants via `$WP config set`, recorded as `kind: wp-config`, and .htaccess hardening edits, recorded as `kind: server` under the nginx rule below).

**SEO fixes:** Dispatch an agent with `subagent_type: wp-audit-rankmath` with the full project context and the list of SEO issues to fix. Also apply direct fixes where applicable (remove hardcoded meta tags, add `add_theme_support('title-tag')`).

**A11y fixes:** Dispatch the `wp-audit-a11y` agent again with fix instructions:
```
Fix the following issues in the WordPress theme at <theme_path>:
<list of auto-fixable a11y issues with their codes and fix methods>
```
Fixes include: adding skip links, ARIA attributes, CSS focus styles, alt text placeholders.

**Performance fixes:** Dispatch the `wp-audit-performance` agent again with fix instructions:
```
Fix the following issues in the WordPress theme at <theme_path>:
<list of auto-fixable performance issues with their codes and fix methods>
```
Fixes include: performance.php boilerplate, .htaccess caching rules (`kind: server`, see the nginx rule below), adding image dimension attributes, lazy loading attributes.

**Best Practices fixes:** Dispatch the `wp-audit-practices` agent again with fix instructions:
```
Fix the following issues in the WordPress theme at <theme_path>:
<list of auto-fixable best-practices issues with their codes and fix methods>
```
Fixes include: ABSPATH checks, adding `esc_html()`/`esc_url()`/`esc_attr()` escaping, theme supports registration, proper enqueue patterns.

**Usability fixes:** Dispatch the `wp-audit-ux` agent again with fix instructions:
```
Fix the following issues in the WordPress theme at <theme_path>:
<list of auto-fixable usability issues with their codes and fix methods>
```
Fixes include: a required-field mark, a missing active state, hover feedback, spacing
between action elements, a `max-width` in `ch`, an underline on a link that is
distinguishable only by colour.

**Every one of those changes how the site looks**, and four of them move layout. Pass the
agent its own Step 4: measure `getComputedStyle()` and `getBoundingClientRect()` before and
after, at desktop and mobile, on every element carrying the class — and report both sets.
A value that moved and was not meant to is a regression, not a fix. If the user has not
agreed to visual changes, this category is reported and not applied: every one of them is
`visual` in the sense above.

The measurement is `node ${CLAUDE_PLUGIN_ROOT}/bin/style-diff.mjs`: take **two** snapshots
before the change (`snapshot --label base1`, `--label base2`), one after, then
`diff base1.json after.json --noise base1.json base2.json`. Two untouched baselines differ
only in random-order carousels and sub-pixel separators; those elements are listed as noisy and
never fail the run, so a non-zero exit means a style value the change moved. Add
`--state menu=<toggle-selector>@390` to record an opened mobile menu. Run it at desktop and
mobile (the default 1366x768 and 390x844) and read the diff for every element sharing the class.

**GEO fixes:** Dispatch an agent with `subagent_type: wp-agentic-surfaces` with the full project context and the list of auto-fixable GEO findings. It owns `inc/agentic.php` and every generated agent surface (`llms.txt`, ARD catalog, agent-skills index, markdown negotiation, Link headers, agent-friendly 404, JSON-LD breadth, trust anchors) — do not re-implement the surfaces here. Before dispatching, run the live verifier to capture the before score; run it again after the fixer completes and report the before → after score:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh <home-host> --start
```

`--start` makes a host with no report yet get one: the script asks is-agentic to scan it
(the same HTTP call `npx is-agentic` makes, through curl, no package run) and reads the
report when the scan finishes. The three calls are capped at 110 s together, so run the command with a Bash
timeout of at least 150000 ms. Pass it only for a host this run
confirmed as public — the scan makes a third party fetch that site.

`<home-host>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` (or
`$WP option get home`) — **unless `local_clone` is true (Step 2.3): the live scan must not probe
the clone's own host**, so Step 2.3's live-check rule applies instead of that fallback — the
confirmed production URL, or `UNMEASURED — needs the public URL` with no scan run. Exit codes:

| Exit | Meaning | Report as | Actionable |
|---|---|---|---|
| `0` | current report returned | the score | — |
| `1` | tool error | `ERROR` | record the error and continue |
| `2` | no network, a transient `429`/`503`, or a `--start` scan that did not complete (without `--start`: no report yet), or a report that is a bot-challenge page (`CHALLENGED`) | `UNMEASURED` (`unavailable — challenged by a bot interstitial` when challenged) | retry once; else scan at `https://is-agentic.com` |
| `3` | the host is not publicly reachable | `UNMEASURED — configuration` | re-run with `--host <public-url>` |
| `4` | report returned but older than 24 h and not refreshable (`STALE:` on stderr) | the score, marked stale: `Live scan: 28 (stale: scanned 2026-10-12)` | scan again at `https://is-agentic.com`; the score is not evidence of the site now |

A challenged report (exit `2`) is printed as `Live scan: unavailable — challenged by a bot interstitial`: its score describes the interstitial the scanner was served, so it is never shown as a score. A stale one (exit `4`) is never the "after" score of a fix made since it was scanned.

**None of these is a pass.** An absent score is not a good score; a category whose evidence
was never collected must not read like one that was collected and came back clean — which is
exactly what "skipped" used to look like in the report. Exit `3` in particular is a
configuration problem with a one-flag fix, and it is the state every project built before the
live scan existed is in, because its manifest still holds the URL it was developed against.
Print the reason on the `Live scan:` line and repeat it in the blocking-warnings block at the
top of the report. Only a returned report yields a score; map its failed ORA check ids back to GEO codes using the `wp-audit-geo-standards` skill. Advisory and off-site findings (GEO-D05 through GEO-D08, GEO-U10, GEO-P01 through GEO-P05) are left unfixed.

The before → after score this step produces is the value the Step 8 report's `Live scan:` line records: Step 6.2 already produced the score the report shows; this step adds the after score. On a fix run, show the line as `<score> → pending` at Step 8 and fill it here.

After all fix agents complete, count how many issues were successfully fixed, and count
them by owner. Print the `setting` fixes again as a list of steps to repeat on staging and
production: they were applied to a database this deploy will not carry, and a fix nobody
repeats is indistinguishable from one that was never made. Print that list from `<out>/replay.json`, not from memory, then give the path of the file.
Then render the production runbook from the same file (*The production runbook*, below) and
give its path too. Never write that list, a runbook or a "server steps" file by hand.

## Git hygiene for any phase that edits

Applies before the first edit of this step, and to `/wp-update`. Skip it when the root is not a git repository.

- **Clean tree first.** Run `git status --short | head -20`. Changes that this run did not make belong to someone else or to an earlier session: show them and ask for confirmation before continuing. Do not stash, reset or commit them.
- **Commit by path.** `git add <paths>` with the files this run changed, never `git add -A` or `git commit -a`.
- **Mass deletions.** Before committing, count the deleted files with `git status --short | grep -c '^ *D'`. If more than 50 files are deleted, stop and report it: this run did not delete them, and committing them removes plugins or uploads from history.
- **At the end,** print how many commits exist since the last reviewed point (`git rev-list --count <last-reviewed>..HEAD`, or the commit count of this run when there is none) so unreviewed work is visible.
## The replay log

Every fix that is applied is appended to `<out>/replay.json` (next to the report) at the moment it
is applied, before the next fix starts: code, settings, content written to the database, server
rules and the steps that must run after a deploy. Fix agents are told this in their fix prompt.
`<out>` is the report directory of Step 8.5, never the site root. The default `.wp-audit/` is
already in `TOOL_STATE_PATHS`; a new file at the site root would have to be added there.

The file is one object, and each fix adds one entry to `entries`:

```json
{
  "replay_version": 1,
  "entries": [
    {
      "check": "SEC-014",
      "kind": "db-option",
      "resource": "option:blog_public",
      "command": "wp option update blog_public 1",
      "previous value": "0",
      "needs_server_rule": false,
      "applied_in": "local",
      "applied_on": { "local": true, "staging": false, "prod": false }
    }
  ]
}
```

`kind` says how the fix reaches production, and it decides where the runbook puts it:

| `kind` | What it is | Required besides `check` |
|---|---|---|
| `code` | a file in the editable code, new assets (fonts, images) included; it travels with the commit | `file` (path from the site root, or a list) |
| `db-option` | an option set by WP-CLI: a plugin's settings, `theme_mods_*`, a flag such as `elementor_mcp_enabled` | `command`, `previous value` |
| `post-meta` | a post, term or post-meta row: an SEO description, a builder widget's data, a bulk script over IDs | `command`, `previous value` or `backup`; `ids` and `selector` when it iterates on IDs |
| `wp-config` | a `wp-config.php` constant, which is not in git | `command` (`wp config set …`), `previous value` |
| `server` | a web-server rule (`.htaccess` here, or the server configuration) | `file`, `server_rule` (an id from `references/server-rules.md`, or `null` when none fits) |
| `post-deploy` | a step that must run on production after the deploy: `wp media regenerate --only-missing` after adding an image size, deleting leftover sync tables | `command` |

- `command` is the exact WP-CLI command that was run, with its arguments, so it can be
  repeated verbatim. The runbook rewrites `$WP`, `--path` and the local URL itself, so record
  the command as it ran.
- `previous value` is read **before** the write and stored as the value to revert to
  (`null` when the option or row did not exist).
- `needs_server_rule` is `true` when the fix only works once the production server routes or
  serves something: every `server` entry, and a `code` entry that adds a URL served by PHP
  (`/llms.txt`, a dynamic `/robots.txt`, `/.well-known/…`). Such an entry also carries
  `endpoint`, the path it serves (a prefix ends in `/`).
- `ids` lists the rows a bulk script touched. Those IDs come from the local database, so add
  `selector`, the read-only command that selects the same rows by something stable (slug,
  post type, meta value) and can be run on production first.
- `verify` (optional) is a read-only command that proves the fix on production, with `expect`
  for what it prints. The runbook adds it to its verification list.
- `applied_in` is the environment the fix ran against; `applied_on` starts with only that one
  `true`. Whoever repeats the step on another environment flips its flag.

A fix that is not in `replay.json` was not recorded; do not report it as applied. An older
record that is a bare array of entries, with no `kind`, is still read: the runbook infers the
kind from `resource` and `command`.

**Planned, not implemented:** `/wp-audit --replay <env>` would run every entry whose
`applied_on[<env>]` is false against that environment, flip the flag, and stop on the first
error. Against production it would go through `bin/prod-gate.sh` and the production
confirmation like any other write. Until then a person runs the runbook rendered from it (*The production runbook*, below).

## Bulk database fixes keep the old value

A fix that changes more than 25 rows (a search-replace, a bulk post-meta or term update, a
bulk status change) dumps the previous values to `<out>/backups/` before it is applied. This
is part of the fix, not an option: for example
`$WP db export <out>/backups/<check>-<timestamp>.sql --tables=<affected tables>` or, for a
narrow change, a CSV of `ID,<field>,<previous value>` from `$WP db query`. The replay entry
records the backup path in a `backup` field. Without the backup the fix is not applied; report it
`manual`. At 25 rows or fewer, `previous value` in the replay entry is enough.

## Production on nginx: an `.htaccess` fix is not a production fix

Read the production server from the manifest: the `server` field of the `role: "prod"` entry
in `environments` (`wp-config.mjs env-set … --server=nginx`). `environment.web_server`
describes the local clone, not production. When that field is `nginx`, `caddy`, `unknown` or
absent, an `.htaccess` rule does nothing in production. In that case:

- Record the fix as `kind: server`, `needs_server_rule: true`, `applied_on.prod: false`.
- Report it as `applied locally — production needs the server owner`. **Never** count it as
  fixed for production, in the fix count, the summary or the report.
- Name its rule from `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/server-rules.md`,
  which holds the Apache rule and the nginx equivalent side by side. When no rule there fits,
  record `server_rule: null`: the runbook says there is no vetted equivalent, and nobody
  improvises one.
- A URL that WordPress serves from PHP (`/llms.txt`, `/robots.txt`, `/.well-known/…`) gets
  `needs_server_rule: true` and its `endpoint`, whatever the server. nginx answers 404 or 403
  for it until a `location` sends it to `index.php`. A physical file of the same name in the
  web root shadows the route on any server, and on one site it carried the local host.

## The production runbook

At the end of this step, render the record:

```bash
node ${CLAUDE_PLUGIN_ROOT}/bin/audit-runbook.mjs --replay <out>/replay.json --out <out> \
  --lang <report language> [--prod-url <confirmed production URL>]
```

It writes `<out>/runbook-<YYYY-MM-DD>.md` and prints its absolute path; relay it as written.
It reads the production URL, `server` and `page_cache` from the `role: "prod"` environment and
the builder and cache from `stack`, and a flag overrides each one. The sections are in the
order they must run: pre-deploy checks (the development host in the database, physical files
that shadow a PHP-served endpoint, the local host in recorded files, files to commit), code
and the theme activation it assumes, wp-config, database commands with `--url` set to the
production URL, server rules (nginx and Apache, each marked `not applied`), post-deploy
(`wp elementor flush-css` when `stack.builder` is `elementor`, the page-cache purge when a
cache is known) and verification curls.

| Exit | Meaning |
|---|---|
| `0` | runbook written; print the path |
| `1` | the record is unusable, an entry lacks what its `kind` needs, a `server_rule` is unknown, or the runbook would carry a local host or path. Fix the entry and run it again |
| `3` | crash: report it, and hand over `replay.json` itself |
