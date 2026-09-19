---
description: Comprehensive audit — security, SEO, accessibility, performance, best practices, GEO/AI-agent readiness
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "[--security] [--seo] [--a11y] [--performance] [--best-practices] [--geo] [--all] [--report-only] [--host <public-url>] [--security-level basic|recommended|maximum]"
---

# WP Audit — Comprehensive Site Audit

Run a comprehensive audit across security, SEO, accessibility, performance, best practices, and GEO/AI-agent readiness. Reports issues with severity levels and offers to auto-fix what it can. Dispatches specialized audit agents and optionally configures Rank Math SEO and All-in-One WP Security.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
- **Category flags:** `--security`, `--seo`, `--a11y`, `--performance`, `--best-practices`, `--geo`
- **`--all` flag** (default if no category flags provided)
- **`--report-only` flag** (skip fix phase)
- **`--security-level basic|recommended|maximum`** (default: `recommended`, ignored if `--report-only`)
- **`--host <public-url>`** — the publicly reachable URL to scan, overriding
  `wordpress.url` from the manifest. A project whose manifest holds a `.local` or `192.168.*`
  URL can never be scanned from the manifest alone; this is how such a project supplies one
  without rewriting the manifest it still develops against. Used by the live scan in Step 9
  and by nothing else — it does not change which site WP-CLI talks to.

If `--all` or no category flags are present: enable all 6 categories (security, seo, a11y, performance, best-practices, geo).

## Step 2: Read Project Context

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary)
- **Theme directory path**
- **Industry** (used for schema type: Organization vs LocalBusiness)

If `.claude/CLAUDE.md` does not exist, tell the user:
```
Error: Project not initialized. Run /wp-init first to set up the project context.
```
And stop execution.

If `--geo` is selected and `.wp-create.json` exists, also note its `wordpress.url` — the live
scan in Step 9 needs a reachable host. `--host` takes precedence over it when given; a
project developed locally and served publicly has two URLs, and the manifest holds the one
WP-CLI needs, not the one the scanner needs.

## Step 2.5: Reconcile the Manifest

`.wp-create.json` is the shared source of truth, so a stale manifest is not a cosmetic
problem — every later step branches on it. This step measures the project instead of
trusting what was written the day it was scaffolded. Skip it entirely when
`.wp-create.json` does not exist; run it before tier detection, because it can turn Tier 3
back on.

### 2.5a — Schema version

Read `manifest_version`. The current version is `3`.

| Found | Meaning | Action |
|---|---|---|
| `3` | current | reconcile as below |
| absent or `< 3` | the project predates the current manifest version (versioning started at `2`; `/wp-create` writes `3` as of the credential-contract change) | reconcile, then write `"manifest_version": 3` |
| `> 3` | written by a newer plugin | **stop** — report the version and do not rewrite keys this version does not understand |

A missing version is not an error; it is the signal that every check below has never run
on this project.

### 2.5b — Measure, do not trust (Tier 2 only)

```bash
$WP plugin list --status=active --field=name --format=json
$WP eval "echo PHP_VERSION;"
$WP eval "echo isset(\$_SERVER['SERVER_SOFTWARE']) ? \$_SERVER['SERVER_SOFTWARE'] : 'unknown';"
```

The web server is also visible on disk: an `.htaccess` carrying `# BEGIN LSCACHE` or a
`litespeed-cache` plugin means LiteSpeed, not nginx, whatever the manifest says. Prefer the
measured value; `SERVER_SOFTWARE` under WP-CLI is a CLI SAPI value and may be empty.

Compare each measured value against `plugins.installed`, `environment.web_server` and
`environment.php_version`. Report every drift as a line of its own, naming both values, then
write the measured value:

```
=== Manifest Reconciliation ===

  plugins     DRIFT  manifest claims wordpress-seo, wp-super-cache, wordfence
                     measured seo-by-rank-math, litespeed-cache, all-in-one-wp-security-and-firewall
  web_server  DRIFT  manifest nginx → measured LiteSpeed (.htaccess carries BEGIN LSCACHE)
  php_version DRIFT  manifest 8.4 → measured 8.5.10
  tier 3      RE-PROBED  now available (was false)
```

Drift is reported, never silently corrected: a manifest that claimed Yoast while the site
ran Rank Math sent every SEO check at the wrong plugin, and the run that discovers this
should say so out loud. A wrong `web_server` sends cache-purge and `.htaccess`-versus-nginx
advice the wrong way; a wrong PHP minor misjudges which constructs are fatal.

**Re-probe Tier 3 here** rather than trusting `audit.web_quality_skills_available` —
capability recorded once in the past is not capability now. The recorded value is an input
to the drift report, never to the tier decision.

### 2.5c — Recorded decisions that are missing, not defaulted

Two decisions are recorded per project, and both have a documented fallback for projects
that predate them: `i18n strategy` (absent ⇒ `suffix`) and `demo mode` (absent ⇒ `plain`).

**A fallback is a guess, and this step reports it as one.** Detect first:

```bash
$WP plugin is-active polylang && echo "SIGNAL: Polylang active — i18n strategy is polylang, not suffix"
$WP eval "echo function_exists('pll_languages_list') ? implode(',', pll_languages_list()) : '';"
```

When a decision line is absent from `.claude/CLAUDE.md` **and** a signal contradicts the
fallback, report it as an unresolved unknown with the evidence, and use `AskUserQuestion` to
have the operator record it:

```
  i18n strategy  UNKNOWN  no line in .claude/CLAUDE.md; the fallback is `suffix`
                          but Polylang is active with es,en — the fallback is wrong here
```

Never write the fallback into the manifest as though it were a decision. Record only what
the operator confirms, then add the line to `.claude/CLAUDE.md` so the next run finds it.
When no signal contradicts the fallback, note that the fallback is in use and continue —
a silent default is what made a Polylang site take the suffix branch in every downstream
command.

### 2.5d — Category coverage matrix

`audit.categories_run` records which categories have ever run on this project. Read it back
and diff it against the categories this plugin version offers — `security`, `seo`, `a11y`,
`performance`, `best-practices`, `geo`:

```
  coverage    NEVER RUN: geo
              This project was created 2026-03-18 and last audited 2026-03-21.
              The geo category shipped later, so it has never run here.
              Run: /wp-audit --geo
```

**A never-run category is a blocking warning**, printed at the top of the Step 8 report, not
buried in it. Without this, a project sits indefinitely with a whole category unexecuted
while its audit record keeps looking complete — the record says what ran, and nothing ever
asked what did not. This is how a site ships with an entire category unexamined and a clean
report to show for it.

The diff is against the categories **this version offers**, never against a list stored in
the project, so a category added to the plugin after the project was built is detected the
first time the project is audited again.

**A category that has run is not a category that is current.** `categories_run` answers "has
this ever run here", and a category keeps answering yes forever while checks are added to it
that this project has never seen. So for every category that *has* run, diff its catalog
against `audit.checks_run[<category>]` — the IDs this project has actually executed:

```
  coverage    security last ran 2026-03-21; 2 checks have shipped since
              SEC-036, SEC-038 have never been measured on this project.
              Run: /wp-audit --security
```

The catalog is the set of check IDs in that category's own agent file — `SEC-*` in
`agents/wp-audit-security.md`, `WP-*` in `agents/wp-audit-practices.md`, `SEO-*` in
`agents/wp-audit-seo.md`, `A11Y-*` in `agents/wp-audit-a11y.md`, `PERF-*` in
`agents/wp-audit-performance.md`, `GEO-*` in `agents/wp-audit-geo.md`. Read the agent, not a
list kept anywhere else: a stored list is a second copy that goes stale, and a stale copy
here would report a green coverage line for checks nobody has run — the exact failure this
diff exists to prevent, reproduced by the thing preventing it.

**This is a warning, not a block.** A never-run category is blocking because nothing in it
has been examined; a category missing two checks out of forty has been examined, just not
completely. Both print at the top of the Step 8 report.

**An absent `audit.checks_run` is not "nothing has run".** A project audited before this
record existed has no per-check history, and reporting all 261 checks as never measured
would be true but useless. Report it as unknown and say why, once:

```
  coverage    per-check history begins at the next run
              This project was last audited before check-level coverage was recorded,
              so which individual checks ran is unknown. The categories above are
              still accurate.
```

### 2.5e — Freshness and carry-over

```
  freshness   STALE  last run 2026-03-21 (176 days ago)
  carry-over  25 findings were found and never fixed (70 found, 45 fixed)
```

Warn when `audit.last_run` is more than 90 days old. Report `issues_found - issues_fixed` as
findings that were carried over, and re-open them in this run rather than starting the count
from zero — a stale "all clear" is not a clear, and a difference of 25 that no later run
mentions reads as though it resolved itself.

Write the whole reconciliation block into the Step 8 report as its own section. When every
line is clean, print one line instead:

```
  Manifest reconciled — no drift, all categories have run, record is current.
```

## Step 3: Detect Environment & Tier

Determine the audit tier:

**Tier 1 (always):** Code-only checks via Read, Grep, Glob.

**Tier 2 (if `.wp-create.json` exists):** Read `.wp-create.json` to get `$WP` wrapper. Set `$WP` to the value of `wp_cli.wrapper`. Enables WP-CLI runtime checks.

**Tier 3 (if web-quality-skills installed):** Probe every run — Step 2.5b already
re-probed it, and `audit.web_quality_skills_available` from a previous run is a drift input,
never the answer. Check these paths in order:
1. `~/.claude/skills/performance/SKILL.md`
2. `.claude/skills/performance/SKILL.md`
3. Glob for `**/web-quality-skills/skills/performance/SKILL.md`

If any path exists, Tier 3 is available.

Print tier status:
```
=== Audit Tier Detection ===

Audit Tier: <Code | Code + Runtime | Code + Runtime + Lighthouse>
  ✓ Tier 1: Code analysis (always available)
  <✓|✗> Tier 2: WP-CLI runtime checks (<.wp-create.json found|.wp-create.json not found>)
  <✓|✗> Tier 3: External quality skills (<web-quality-skills detected|web-quality-skills not found>)
```

**`--geo` needs Tier 2.** The GEO auditor's live HTTP checks and the `bin/geo-scan.sh`
verifier in Step 9 require `.wp-create.json` (for `$WP` and a reachable site URL). Without
Tier 2, `wp-audit-geo` still runs its code-only checks and reports the runtime GEO codes
`N/A`, and the live scan is skipped.

## Step 4: Dependency Check (Tier 2 only)

If Tier 2 is NOT available, skip this step entirely.

If Tier 2 is available, check what plugins are installed:

```bash
bash -c "$WP plugin list --status=active --format=csv"
```

Determine which plugins are relevant based on selected categories:
- `--security` needs `all-in-one-wp-security-and-firewall`
- `--seo` needs `seo-by-rank-math`
- `secure-custom-fields` is always relevant

Build dependency report:

```
=== Audit Dependencies ===

WordPress Plugins:
  ✓ secure-custom-fields — installed & active
  ✗ seo-by-rank-math — not installed (needed for --seo)
  ✗ all-in-one-wp-security-and-firewall — not installed (needed for --security)

Claude Code Plugins:
  <✓|✗> web-quality-skills — <installed|not installed> (enables browser-based audits)
      Install: npx skills add addyosmani/web-quality-skills

Options:
  [A] Install all recommended WordPress plugins
  [B] Let me pick which ones to install
  [C] Skip — run audit with what's available
```

Only show plugins relevant to the selected categories (don't prompt for Rank Math if `--security` only, don't prompt for AIOS if `--seo` only).

Use AskUserQuestion for the choice. If A: install all listed via `bash -c "$WP plugin install <slug> --activate"`. If B: ask which ones via AskUserQuestion and install selected. If C: continue without installing.

## Step 5: Security Level Selection

If `--security` or `--all` is selected AND `--report-only` is NOT set:

If `--security-level` was provided in arguments, use that value and skip the prompt.

Otherwise, use AskUserQuestion:
```
Security posture for AIOS configuration:
  [1] Basic — login lockout, hide WP version, disable file editing
  [2] Recommended — basic + renamed login, firewall, XML-RPC disabled, security headers (default)
  [3] Maximum — recommended + user enumeration blocking, comment captcha, brute force cookie

Select level (1-3, default: 2):
```

Map the response: 1 → `basic`, 2 → `recommended`, 3 → `maximum`. Default to `recommended` if no valid response.

If `--security` is not selected or `--report-only` is set, skip this step.

## Step 6: Dispatch Audit Agents

For each selected category, dispatch the corresponding agent using the Agent tool. Pass complete context in each agent prompt.

**Dispatch order:** security → seo → a11y → performance → practices → geo

For each agent, use this prompt template (adapt the category-specific instructions):

### What each agent is scoped to

"Audit the theme" was the whole scope, and it is not enough. The theme can be correct while
the defect lives in a plugin's option array, in postmeta, in what the web server serves before
PHP runs, or in the markup the two produce together. Those four surfaces are not the theme,
and until they were named, none of them had an owner — so every audit read the code, passed,
and said nothing about the layer the defect was actually in.

| Surface | Owner | Examples |
|---|---|---|
| theme source | every agent, per category | escaping, enqueues, template structure |
| plugin configuration and DB options | `wp-audit-seo` (SEO options), `wp-audit-security` (dev-host leakage, SEC-036) | Rank Math option values, site-name options |
| per-post meta coverage | `wp-audit-seo` | missing descriptions, focus keywords, canonical |
| rendered output | `wp-audit-seo` (head), `wp-audit-geo` (head, schema graph, DOM) | `og:site_name`, dangling schema `@id` |
| serving layer | `wp-audit-geo` (GEO-A26, GEO-A27) | a physical root file shadowing a theme rewrite, CDN path rewrites |

An agent whose surface needs Tier 2 and does not have it reports those codes `UNMEASURED`,
never `PASS`. Say so in the prompt, so the agent does not quietly narrow its scope to the part
it can reach.

```
Audit the WordPress theme at <theme_path>, and the surfaces listed for your category in
"What each agent is scoped to" — the theme is where the code is, not where every defect is.

Project context:
- Function prefix: <prefix>
- Theme slug: <slug>
- Languages: <languages>
- Industry: <industry>
- WP-CLI wrapper: <$WP or "not available">
- Audit tier: <1|2|3>
- Web-quality-skills: <available|not available>

Run all checks for your tier level. Output your findings as a structured report with the following format for each issue:

[<SEVERITY>] <CODE>: <message> (<file>:<line> if applicable)
  Fix: <auto|manual>
  Method: <description of fix>

Where SEVERITY is one of: CRITICAL, WARNING, INFO
Where CODE follows the pattern: SEC-NNN, SEO-NNN, A11Y-NNN, PERF-NNN, BP-NNN, GEO-Dnn/Axx/Uxx/Pxx
```

Use these `subagent_type` values:
- `wp-audit-security` — security checks (file permissions, SQL injection, XSS, nonces, ABSPATH, wp-config hardening, AIOS configuration)
- `wp-audit-seo` — SEO checks (meta tags, schema markup, sitemap, robots.txt, Rank Math configuration, heading hierarchy, canonical URLs)
- `wp-audit-a11y` — accessibility checks (skip links, ARIA attributes, alt text, color contrast references, focus styles, semantic HTML, keyboard navigation)
- `wp-audit-performance` — performance checks (asset enqueuing, image optimization, caching headers, database queries, lazy loading, render-blocking resources)
- `wp-audit-practices` — best practices checks (ABSPATH guards, escaping, i18n, theme supports, coding standards, enqueue patterns, template hierarchy)
- `wp-audit-geo` — GEO/AI-agent readiness checks (ORA layers Discovery/Access/Usability/Payments, AI crawler allowlist, `llms.txt` and ARD catalog, rendered-head DOM checks, agent-skills index, is-agentic live scan)

**Error handling:** If an agent fails:
1. Note which agent failed and the error message
2. Continue with remaining agents (do not block the entire audit)
3. Mark the failed category in the report
4. Skip the failed category in the fix phase

## Step 6.9: Every finding is a measurement

A finding is the output of a command that ran in THIS run, and it carries what produced it:
the `$WP` call, the file:line, the URL fetched. Nothing else is a finding.

Two shapes have shipped in real reports, and both read exactly like a real defect:

- **Asserted from reading, not from counting.** An agent that sees two code paths capable of
  printing a meta description reports a duplicate description — on a page that emits one. The
  fix is to count the rendered output, not the code paths: `curl -s <url> | grep -c '<meta
  name="description"'`.
- **Carried over from a stale input.** An agent that reads a manifest, an earlier report or a
  cached snapshot and reports what it said — "the site has no posts" against a site with
  twenty — is quoting history, not measuring the site. §2.5b already says this about the
  environment; it holds for every finding.

So:

1. Each finding line carries its evidence — the command, the path, or the URL. A finding with
   no evidence line does not reach the report.
2. What the tier cannot reach is reported as `UNVERIFIED`, with the command the user can run,
   and is never counted in the totals or offered as a fix in Step 9.
3. When a check needs a number, take the number. Counting is one command; guessing costs the
   client a change that fixes nothing.

The aggregator enforces this: a finding arriving with no evidence is dropped and reported as
dropped, naming the agent — an agent that guesses should be visible, not silently trusted.

## Step 7: Aggregate Reports

Collect reports from all agents. For each agent's output, parse the findings into a unified list.

**Deduplication:** If the same file:line appears in multiple reports:
- Keep the finding with the highest severity
- Remove duplicates from lower-severity reports
- Ownership rules: Security owns vulnerability checks, Practices owns coding-standards checks

Sort all issues: CRITICAL first, then WARNING, then INFO.

Count totals per category and overall.

## Step 8: Present Report

Print the formatted report:

### Status vocabulary

Every check resolves to one of five statuses, and the last three are not interchangeable:

| Status | Means |
|---|---|
| `PASS` | ran, and the site satisfies it |
| `FAIL` | ran, and the site does not |
| `N/A` | does not apply to this site type — say why |
| `UNMEASURED` | applies, but was never measured — say what stopped it |
| `NEVER RUN` | the whole category has never run on this project (Step 2.5d) |

`N/A` and `UNMEASURED` were one status, and merging them hid the difference between "this
site has no API to check" and "this check applies and nothing ever ran it". A reader counting
failures cannot tell those apart, and the second one is the one that needs action. Count them
separately in every summary line, and never fold `UNMEASURED` into the passing total.

The reconciliation block from Step 2.5 goes **first**, above the per-category counts. A
never-run category and a stale record change how every number below them should be read, so
they cannot sit underneath those numbers.

```
=== WP Audit Report ===
Tier: <tier description>
Categories: <comma-separated selected categories>

<the Step 2.5 reconciliation block, or its one-line clean form>

[SECURITY] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: <message> (<file>:<line>)
  ✗ WARNING: <message>
  ℹ INFO: <message>

[SEO] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[A11Y] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[PERFORMANCE] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[BEST PRACTICES] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[GEO] <site_type> — N issues (X errors, Y warnings, Z info, K N/A)
  Layer coverage: <Discovery ✓|✗> <Access ✓|✗> <Usability ✓|✗> <Payments ✓|N/A>
  ✗ ERROR: <message> (GEO-A13)
  ✗ WARNING: <message> (GEO-A06)
  ℹ INFO: <message>
  ○ N/A: <layer> — <rationale>
  Live scan: <score|unavailable — skipped: <reason>> (produced by Step 9's scan, below)

---
Total: N issues (X critical, Y warnings, Z info)
Auto-fixable: M/N
```

If any agent failed:
```
[SECURITY] ⚠ Agent failed: <reason>. Skipped.
```

If all checks passed in a category:
```
[SECURITY] ✓ All checks passed
```

## Step 9: Offer to Fix (unless --report-only)

If `--report-only` was set, print:
```
Report complete. Use /wp-audit (without --report-only) to auto-fix issues.
```
And skip to Step 10.

Otherwise, if auto-fixable issues exist, use AskUserQuestion:
```
Want me to fix the M auto-fixable issues? (y/n)
```

If the user declines, skip to Step 10.

If the user confirms, dispatch fix operations by category:

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

**GEO fixes:** Dispatch an agent with `subagent_type: wp-agentic-surfaces` with the full project context and the list of auto-fixable GEO findings. It owns `inc/agentic.php` and every generated agent surface (`llms.txt`, ARD catalog, agent-skills index, markdown negotiation, Link headers, agent-friendly 404, JSON-LD breadth, trust anchors) — do not re-implement the surfaces here. Before dispatching, run the live verifier to capture the before score; run it again after the fixer completes and report the before → after score:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh <home-host>
```

`<home-host>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` (or
`$WP option get home`). Exit codes:

| Exit | Meaning | Report as | Actionable |
|---|---|---|---|
| `0` | report returned | the score | — |
| `1` | tool error | `ERROR` | record the error and continue |
| `2` | no report yet, no network, or a transient `429`/`503` | `UNMEASURED` | scan once at `https://is-agentic.com` |
| `3` | the host is not publicly reachable | `UNMEASURED — configuration` | re-run with `--host <public-url>` |

**None of these is a pass.** An absent score is not a good score; a category whose evidence
was never collected must not read like one that was collected and came back clean — which is
exactly what "skipped" used to look like in the report. Exit `3` in particular is a
configuration problem with a one-flag fix, and it is the state every project built before the
live scan existed is in, because its manifest still holds the URL it was developed against.
Print the reason on the `Live scan:` line and repeat it in the blocking-warnings block at the
top of the report. Only a returned report yields a score; map its failed ORA check ids back to GEO codes using the `wp-audit-geo-standards` skill. Advisory and off-site findings (GEO-D05 through GEO-D08, GEO-U10, GEO-P01 through GEO-P05) are left unfixed.

The before → after score this step produces is the value the Step 8 report's `Live scan:` line records: the report is printed before this step runs, so at Step 8 show that line as pending and fill it here.

After all fix agents complete, count how many issues were successfully fixed.

## Step 10: Update Manifest

If `.wp-create.json` exists, read it and update with audit metadata:

```bash
bash -c "cat .wp-create.json"
```

Add or update the `audit` key in the JSON:

```json
{
  "audit": {
    "last_run": "<ISO 8601 timestamp>",
    "security_level": "<basic|recommended|maximum>",
    "categories_run": ["security", "seo", "a11y", "performance", "best-practices", "geo"],
    "checks_run": {
      "security": ["SEC-001", "SEC-002", "SEC-036"],
      "geo": ["GEO-A11"]
    },
    "issues_found": N,
    "issues_fixed": M,
    "carried_over": K,
    "web_quality_skills_available": true
  },
  "manifest_version": 3
}
```

`categories_run` is a **cumulative** record, not a record of this run: union the categories
this run covered with the ones already there. Overwriting it would erase the very history
Step 2.5d reads back, and the coverage matrix would report every category as run the moment
any single category ran.

`checks_run` is cumulative the same way, and per category: union this run's executed check
IDs into the array for each category it covered, leaving the other categories untouched.
Record **every check that executed, including the ones that passed** — a check that ran and
found nothing is measured, and it is the pass that has to be distinguishable from the
never-run. A check reported `UNMEASURED` did not execute and is not recorded, so the next
run with the tier it needed still sees it as outstanding.

Write the IDs exactly as the agent's catalog spells them (`SEC-036`, `GEO-A11`). This is the
record Step 2.5d diffs against the catalogs, so an id invented here becomes a check that is
never reported missing and never reported run. `bin/wp-config.mjs validate` refuses a
`checks_run` whose shape is wrong — a bare string instead of an array, an unknown category,
an id that is not shaped like one — because the diff consumes it directly.

`carried_over` is `issues_found - issues_fixed` for this run — the number Step 2.5e re-opens
next time. Write `manifest_version` on every run, including the run that adds it to a project
that never had one.

Also update the `plugins.installed` array if new plugins were installed during Step 4.

Write the updated JSON back to `.wp-create.json`.

If `.wp-create.json` does not exist, skip this step.

## Step 11: Print Summary

```
=== Audit Complete ===
Fixed: M/N auto-fixable issues
Remaining: K issues require manual attention

Manual issues:
  1. [SEC-002] SQL injection in custom-query.php:45 — use $wpdb->prepare()
  2. [A11Y-003] Color contrast ratio 3.2:1 on .hero__subtitle — increase to 4.5:1
  ...

Next steps:
  - Review and test the applied fixes
  - Address the remaining manual issues listed above
  - Run /wp-finalize for pre-delivery validation
```

If `--report-only` was used:
```
=== Audit Report Complete ===
Total: N issues found (X critical, Y warnings, Z info)
Auto-fixable: M/N

To auto-fix issues, run: /wp-audit <same flags without --report-only>

Next steps:
  - Review the report above
  - Run /wp-audit (without --report-only) to auto-fix issues
  - Run /wp-finalize for pre-delivery validation
```
