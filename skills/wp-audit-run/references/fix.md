# /wp-audit — Step 9

`commands/wp-audit.md` sends the run here at Step 9. Follow it in order; nothing in it is optional background.

## Contents

- The report-only exit, and the fix offer split by owner
- Adopted sites: editable code only
- Fix dispatch per category: security, SEO, a11y, performance, best practices, usability
- Usability fixes change how the site looks, so they are measured before and after
- GEO fixes: the live scan, its exit codes, and why none of them is a pass
- Counting fixes by owner, and the settings to repeat on staging and production

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

Apply them? (y/n)
```

When Step 8.5 did not run, derive the same split from the findings anyway — the four
owners are a property of a fix, not of the report.

If the user declines, skip to Step 10.

If the user confirms, dispatch fix operations by category.

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
agreed to visual changes, this category is reported and not applied.

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
| `0` | report returned | the score | — |
| `1` | tool error | `ERROR` | record the error and continue |
| `2` | no network, a transient `429`/`503`, or a `--start` scan that did not complete (without `--start`: no report yet) | `UNMEASURED` | retry once; else scan at `https://is-agentic.com` |
| `3` | the host is not publicly reachable | `UNMEASURED — configuration` | re-run with `--host <public-url>` |

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
repeats is indistinguishable from one that was never made.
