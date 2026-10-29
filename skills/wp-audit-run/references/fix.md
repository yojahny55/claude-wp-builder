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

When `stack.builder` is `elementor`, read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-standards/references/builder-elementor.md` before the
first fix: it says which fixes stay in Elementor and which must be code, the backup, flush
and replay steps, and the widget traps. Any other builder: do not load it.

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

**Security fixes:** Dispatch an agent with `subagent_type: wp-audit-aios` with the security level context and the list of security issues to fix. Also apply direct fixes where applicable (wp-config constants via `$WP config set`, .htaccess hardening edits).

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
Fixes include: performance.php boilerplate, .htaccess caching rules, adding image dimension attributes, lazy loading attributes.

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

## Git hygiene for any phase that edits

Applies before the first edit of this step, and to `/wp-update`. Skip it when the root is not a git repository.

- **Clean tree first.** Run `git status --short | head -20`. Changes that this run did not make belong to someone else or to an earlier session: show them and ask for confirmation before continuing. Do not stash, reset or commit them.
- **Commit by path.** `git add <paths>` with the files this run changed, never `git add -A` or `git commit -a`.
- **Mass deletions.** Before committing, count the deleted files with `git status --short | grep -c '^ *D'`. If more than 50 files are deleted, stop and report it: this run did not delete them, and committing them removes plugins or uploads from history.
- **At the end,** print how many commits exist since the last reviewed point (`git rev-list --count <last-reviewed>..HEAD`, or the commit count of this run when there is none) so unreviewed work is visible.
## The replay log

Every `setting` fix, and every content fix that writes to the database, is appended to
`<out>/replay.json` (next to the report) at the moment it is applied, before the next fix
starts. Fix agents are told this in their fix prompt. One entry per fix:

```json
{
  "check": "SEC-014",
  "resource": "option:blog_public",
  "command": "wp option update blog_public 1",
  "previous value": "0",
  "applied_in": "local",
  "applied_on": { "local": true, "staging": false, "prod": false }
}
```

- `command` is the exact WP-CLI command that was run, with its arguments, so it can be
  repeated verbatim.
- `previous value` is read **before** the write and stored as the value to revert to
  (`null` when the option or row did not exist).
- `applied_in` is the environment the fix ran against; `applied_on` starts with only that one
  `true`. Whoever repeats the step on another environment flips its flag.

A fix that is not in `replay.json` was not recorded; do not report it as applied.

**Planned, not implemented:** `/wp-audit --replay <env>` would run every entry whose
`applied_on[<env>]` is false against that environment, flip the flag, and stop on the first
error. Against production it would go through `bin/prod-gate.sh` and the production
confirmation like any other write. Until then the log is read by a person.

## Bulk database fixes keep the old value

A fix that changes more than 25 rows (a search-replace, a bulk post-meta or term update, a
bulk status change) dumps the previous values to `<out>/backups/` before it is applied. This
is part of the fix, not an option: for example
`$WP db export <out>/backups/<check>-<timestamp>.sql --tables=<affected tables>` or, for a
narrow change, a CSV of `ID,<field>,<previous value>` from `$WP db query`. The replay entry
records the backup path in a `backup` field. Without the backup the fix is not applied; report it
`manual`. At 25 rows or fewer, `previous value` in the replay entry is enough.
