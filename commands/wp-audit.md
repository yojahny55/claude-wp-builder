---
description: Comprehensive audit — security, SEO, accessibility, performance, best practices, GEO/AI-agent readiness, usability
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "[--security] [--seo] [--a11y] [--performance] [--best-practices] [--geo] [--usability] [--all] [--report-only] [--report md|html|both] [--report-lang en|es] [--suite] [--pages <list|auto|none>] [--host <public-url>] [--security-level basic|recommended|maximum]"
---

# WP Audit — Comprehensive Site Audit

Run a comprehensive audit across security, SEO, accessibility, performance, best practices, GEO/AI-agent readiness and usability. Reports issues with severity levels and offers to auto-fix what it can. Dispatches specialized audit agents and optionally configures Rank Math SEO and All-in-One WP Security.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
- **Category flags:** `--security`, `--seo`, `--a11y`, `--performance`, `--best-practices`, `--geo`, `--usability`
- **`--all` flag** (default if no category flags provided)
- **`--report-only` flag** (skip fix phase)
- **`--security-level basic|recommended|maximum`** (default: `recommended`, ignored if `--report-only`)
- **`--suite`** — run the browser audit as a generated Playwright project instead of
  depending on a browser tool being present in this session. Needs a reachable URL, the
  same one `--host` supplies.
- **`--report md|html|both`** — also write the run as a dated deliverable under
  `.wp-audit/`. Absent, the audit prints to the console and writes only the ledger —
  **except on a report-only run, where it defaults to `both`** (see below). An explicit
  `--report md|html|both` always wins.
- **`--report-lang en|es`** (default: `en`) — the language of that deliverable. It is read
  by a client, not by the person who ran the audit, so it follows the project's primary
  language rather than the plugin's. Take the default from `languages` in the project's
  `.claude/CLAUDE.md` when the flag is absent and that line names one.
- **`--host <public-url>`** — the publicly reachable URL to scan, overriding
  `wordpress.url` from the manifest. A project whose manifest holds a `.local` or `192.168.*`
  URL can never be scanned from the manifest alone; this is how such a project supplies one
  without rewriting the manifest it still develops against. Used by the live scan in Step 9
  and by nothing else — it does not change which site WP-CLI talks to.

If `--all` or no category flags are present: enable all 7 categories (security, seo, a11y, performance, best-practices, geo, usability).

- **`--pages <list|auto|none>`** — which pages the page-level criteria are measured on.
  `auto` derives the list; `none` skips the page walk and reports every page-level check
  `UNMEASURED`. Default: `auto` whenever the **usability category is selected** or `--suite`
  is given, `none` otherwise, because the other six audit the theme and need no page list.
  Selected, not typed: `--all` and a bare `/wp-audit` both select usability without naming
  it, and keying this off the literal flag would make the commonest invocation report the
  whole category `UNMEASURED` — the quiet failure Step 2.7 exists to prevent.

### Ask for report-only up front when the flag is absent

If `--report-only` was NOT passed, ask before any other question of the run (before the
adoption prompt in Step 2, the plugin prompt in Step 4 and the security level in Step 5).
Use `AskUserQuestion`:

```
What should this audit do?
  [A] Report only — audit and write the report (.md + .html); nothing on the site is installed or changed
  [B] Report, then offer fixes — the report comes first, then Step 9 asks before applying anything
```

On A, set `--report-only` for the rest of the run, exactly as if it had been typed. On B,
continue without it. When the flag was passed, do not ask.

**A report-only run always writes the deliverable.** When `--report-only` is set — by the
flag or by answer A — and `--report` is absent, set `--report both`. An explicit
`--report md|html|both` wins. `--report-lang` keeps its own default. The operator who chose
"report only" asked for a report and no changes; without this, the only report of that run
was the console scrollback, gone at the next `/clear`, and the first report-only run on a
project wrote no dated sidecar, so the next audit had no baseline to diff against.

Before this question existed, a run without the flag only learned that the operator wanted a
read-only audit at Step 9, after Steps 4 and 5 had already offered to install and configure
plugins on the site. The answer belongs at the start, where it decides those prompts too.

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

**Amending the exit `3` row above:** Exit `3` is not a stop here until the operator declines
adoption. A site this plugin did not build has no manifest, and auditing it is a legitimate
use, not a misconfiguration. Ask with `AskUserQuestion`:

```
No .wp-create.json: this site was not created by /wp-create.
  [A] Adopt it now — read-only detection, writes .wp-create.json and .claude/CLAUDE.md only (recommended)
  [B] Stop
```

On A, run `${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md` Steps 2 to 5 against
`${PROJECT_PATH}`. Then run the validator again: it must exit `0`, and the audit continues
from here with the adopted manifest. On B, stop and say so, as the row says. A site that is
only files, with no running WordPress for WP-CLI to probe, cannot be adopted. In that case
say so and stop.

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary)
- **Theme directory path**
- **Industry** (used for schema type: Organization vs LocalBusiness)

On an adopted site (`"origin": "adopted"` in `.wp-create.json`), all of these come from the
generated block that adoption wrote. **Function prefix** and **Industry** are rows of that
block. The theme directory path is `code_scope`, not one directory. See
**Step 2.2** below.

If `.claude/CLAUDE.md` does not exist, tell the user:
```
Error: Project not initialized. Run /wp-init first to set up the project context.
```
And stop execution.

If `--geo` is selected and `.wp-create.json` exists, also note its `wordpress.url` — the live
scan in Step 9 needs a reachable host. `--host` takes precedence over it when given; a
project developed locally and served publicly has two URLs, and the manifest holds the one
WP-CLI needs, not the one the scanner needs. This note is not itself the URL-selection rule:
Step 9's dispatch is the single site that picks the scan's host, and it applies Step 2.3's
local-clone override there — `wordpress.url` is never used as a fallback when `local_clone`
is true.

## Step 2.2: Adopted sites (`origin: adopted`)

Read `origin`. When it is absent or `created`, skip this step: nothing below applies, and
every later step behaves exactly as it did before adoption existed.

When it is `adopted`, the site was registered by `/wp-adopt`. This plugin built none of it,
so three assumptions made everywhere else are false here:

1. **The code is not one theme directory.** `code_scope.editable` lists the site's own code:
   the child theme, the site's own plugins, mu-plugins. `code_scope.read_only` lists vendor
   code: a commercial parent theme and third-party plugins. **Both lists are audited.**
   - Findings in editable code follow the normal rules.
   - Findings in read-only code are always reported with `Fix: manual` and `Owner: manual`.
     Their `Method` names the way around the vendor file, never an edit to it: an override
     in the child theme, a filter from the site's own plugin, or a report to the vendor.

   An update overwrites every file under a read-only path. A fix written there is lost at
   the next update and hides the defect until then.
2. **The plugin stack was not chosen by this plugin.** `stack.seo`, `stack.security`,
   `stack.fields`, `stack.multilingual`, `stack.builder` and `stack.cache` name what the site
   already runs. `none` means nothing was detected.
   - Never offer to install a second plugin for a concern the site's stack already owns.
     Rank Math beside Yoast, or AIOS beside Wordfence, is a new defect, not a fix.
   - Checks that read one plugin's options are `N/A (stack: <name>)` when that plugin is
     not the one in the stack. This covers Rank Math option checks on a Yoast site and AIOS
     configuration checks on a Wordfence site.
   - Checks that read the rendered output apply whatever plugin produced it: the head, the
     schema graph, response headers, the DOM.
3. **The i18n strategy was detected, not decided.** `polylang` when Polylang is active,
   otherwise `none`. `none` means the site is monolingual, or `stack.multilingual` names a
   plugin this one does not build for. `none` never falls back to `suffix`: an adopted site
   has no ACF `_<lang>` fields to check.

Print it before the tier detection, so the scope of the run is visible up front:

```
=== Adopted site ===
  Editable code   <path>, <path>, …
  Read-only code  <path>, <path>, …   (audited, reported, never edited)
  Stack           seo=<…> security=<…> fields=<…> multilingual=<…> builder=<…> cache=<…>
```

## Step 2.3: Site type and local clone

Two facts decide how many later checks should even run, and both are read once, here, before
any category dispatches.

### Site type — is this a store?

A store fails in ways an informational site cannot, and an informational site must never be
scored against checks it could not satisfy. Detect commerce once and record it:

```bash
$WP plugin is-active woocommerce && echo "site type: commerce (WooCommerce)" \
  || echo "site type: non-commerce"
```

Set `site.commerce` to `woocommerce` or `none`. This is the contract every commerce-only
check — present or still to be added — must follow: **read `site.commerce`, and report
`N/A` when it is `none`**, said with the reason "no WooCommerce", and excluded from the
denominator. A check whose object is the store (a cart, a checkout, a priced-per-currency
listing, a protected paid file) is commerce-only by definition, whichever category dispatches
it. For example, the gateway-credential check, the download-protection check, and the
multi-currency check are commerce-only, as are the SEO checks that a commerce-specific
section of `skills/wp-audit-seo-standards` adds — each reads `site.commerce` and is `N/A` on
a non-commerce site rather than being skipped or, worse, scoring a blog for a cart it never
had. This is how commerce depth is added without regressing a generic site: a blog audited
after a new commerce check ships scores exactly as it did before, because that check reads
`N/A` on it.

`is-active`, not `is-installed`: a store with WooCommerce deactivated is not currently a
store, and its commerce surfaces are not live to audit.

### Local clone — audit production's posture, not the copy's

When `.wp-create.json` carries `project.source: "restore"` (the field lives under
`project`, not at the manifest's root — `restore` itself holds only
`files_archive`, `db_archive` and `url_rewritten`, none of which name production), or a
`wordpress.url_origin` (the pre-restore URL, written beside `wordpress.url`), or its
`wordpress.url` is a non-public host, the project is a **local clone of a site that lives
somewhere else**. "Non-public host" is not this check's own list to keep in sync by hand:
it is exactly what `bin/geo-scan.sh` already refuses to scan — `localhost`, `*.localhost`,
`*.local`, `*.local.com` (this plugin's own default domain shape: `/wp-create` Step 3.3
offers `<slug>.local.com`, and `/wp-clone`'s placeholder follows the same shape), `*.test`,
any of those with a port, the private ranges `127.`, `10.`, `192.168.`,
`172.16.`–`172.31.`, `[::1]`, and a dotless hostname. Set `local_clone = true` and read
`production_url` from `wordpress.url_origin` when present.

A clone is deliberately altered to run in isolation, and those alterations are not defects of
the site being audited — they are the cost of having a local copy at all. Reporting them
audits the clone instead of the site. When `local_clone` is true, the following are
**`N/A (local clone)`**, out of the denominator, and are *not* printed as findings — the
reader wants production's posture, not a list of what localization changed:

| Condition normally a finding | Why it is a clone artifact here |
|---|---|
| Dev host stored in the database (SEC-036) | the clone's own URL is *supposed* to be the local host |
| Known-local plugins deactivated (payment gateways, a CDN/page-cache plugin, an object-cache/Redis plugin, a mail plugin, a security/scanner plugin) | turned off so the copy does not reach live payment, cache or mail endpoints |
| `DISABLE_WP_CRON` true, `WP_CACHE` false | set so an isolated copy does not fire scheduled or cached work |
| `object-cache.php` / `advanced-cache.php` absent or left as `*.bak` | the backing service (Redis, a CDN cache) does not exist locally |
| A must-use plugin that neutralizes mail or external calls (e.g. a local `wp_mail()` override) | added by the clone to keep the copy from contacting the outside world |
| `WP_DEBUG` / `WP_DEBUG_LOG` on (SEC-008/009) | a development copy logs; production is what those checks are about |
| An attachment whose file is missing on disk **when the file archive predates the database** | the media was uploaded after the file backup was taken; it exists in production |

Do not widen this list to excuse a real defect: a plugin deactivated on the clone that has no
local reason to be off is still a finding, and media missing with no archive/database date gap
is still a finding (see WP-060/061/062 in `agents/wp-audit-practices.md`). The test is
"would this be true on production too?" — if yes, report it; if it exists only because this is
a copy, suppress it.

**Record what was actually suppressed, not just that the rule applied.** While walking the
"known-local plugins deactivated" and the `*.bak` drop-in rows above, keep the two lists that
came out of them:

- `clone_suppressed_plugins` — the slugs of the plugins that row found inactive (payment
  gateways, a CDN/page-cache plugin, an object-cache/Redis plugin, a mail plugin, a
  security/scanner plugin). Empty, never absent, when the clone deactivated none of them.
- `clone_parked_dropins` — the drop-in files found parked as `*.bak` (e.g.
  `object-cache.php.bak`, `advanced-cache.php.bak`). Empty, never absent, when none were
  parked.

These two lists are what Step 6 passes to the security agent so it knows which plugins and
drop-ins Step 2.3 already looked at, without re-deriving the clone rule itself. The
suppression they record reaches exactly one finding per item — "this plugin is deactivated",
"this drop-in is missing" — and nothing else: a plugin in `clone_suppressed_plugins` with a
known vulnerability, an outdated version, or a hardcoded credential is still a finding: the
clone rule silences "it is off", never "it is off *and* it is broken."

### Live checks need a public URL, and you ask for it

Some checks can only be answered against the running production site: response headers, and
whether a paid file is reachable without a purchase. The **local clone must never be probed
for these** — a local Apache reads `.htaccess` and would pass a rule a production nginx
ignores, turning a real exposure into a false PASS.

So when a live check needs a URL and `local_clone` is true:

1. Use `--host` when it was given.
2. Otherwise, **ask the user for the production URL**, proposing `production_url`
   (`wordpress.url_origin`) as the default when the manifest has one. Do not fire an
   external request at a host the user has not confirmed this run.
3. If no production URL is available, the live check is `UNMEASURED` with "needs the public
   URL", never `PASS`.

Print the two facts before tier detection, next to the adopted-site block when there is one:

```
=== Site ===
  Type          <commerce (WooCommerce) | non-commerce>
  Local clone   <yes — production: https://… | no>
```

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

**Re-probe Tier 3 here** rather than trusting `audit.browser_measurement_available` —
capability recorded once in the past is not capability now. The recorded value is an input
to the drift report, never to the tier decision. A manifest written before this key existed
carries the legacy `audit.web_quality_skills_available` instead: read it as the recorded
value, report it as drift like any other, and write the current key back.

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

**On an adopted site, skip this question.** The manifest records the i18n strategy as a
measurement (Step 2.2), not a fallback. Compare it with the signals above anyway: Polylang
active with `none` recorded, or inactive with `polylang` recorded, is drift. Report it as a
drift line under 2.5b and write the measured value.

### 2.5d — Category coverage matrix

`audit.categories_run` records which categories have ever run on this project. Read it back
and diff it against the categories this plugin version offers — `security`, `seo`, `a11y`,
`performance`, `best-practices`, `geo`, `usability`:

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
`agents/wp-audit-performance.md`, `GEO-*` in `agents/wp-audit-geo.md`, `UX-*` in
`agents/wp-audit-ux.md`. Read the agent, not a
list kept anywhere else: a stored list is a second copy that goes stale, and a stale copy
here would report a green coverage line for checks nobody has run — the exact failure this
diff exists to prevent, reproduced by the thing preventing it.

**A check whose rule changed is a check this project has not run.** An ID is an address,
not a version: `SEC-036` in `checks_run` said "this project measured the thing SEC-036
named", and stayed true after SEC-036 was rewritten to look for something else. The
project's coverage then read green for a rule it had never been measured against — the same
failure the catalog diff above exists to prevent, one level down.

So a catalog entry may carry a **revision**: `SEC-036@2`. An ID written without one is
revision 1, which is what every existing entry and every existing `checks_run` value means,
so nothing has to be re-tagged and no project's history is invalidated by this paragraph.
Bump the revision when the rule changes what it would report on an unchanged site — a
reworded finding message is not a bump, a widened pattern is.

Match on ID **and** revision when diffing. A project holding `SEC-036` (revision 1) against
a catalog offering `SEC-036@2` has not measured the current rule, and is reported as such,
with the distinction visible so nobody reads it as a check that never ran at all:

```
  coverage    security last ran 2026-03-21; 1 check has been revised since
              SEC-036 was measured at revision 1; the catalog is at revision 2.
              Run: /wp-audit --security
```

Record what ran, at the revision it ran at: write `SEC-036@2` into `checks_run` when the
catalog said `SEC-036@2`. Writing the bare ID after running a revised check is what makes
the record lie, and it is the easy mistake here.

**This is a warning, not a block.** A never-run category is blocking because nothing in it
has been examined; a category missing two checks out of forty has been examined, just not
completely. A revised check is the mildest of the three — the project measured *something*
for that rule. All of them print at the top of the Step 8 report.

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

**When `.wp-audit-findings.json` exists, name them instead of counting them.** The ledger
(Step 7.5) holds each carried-over finding by check and resource, so the line becomes what
the operator can act on:

```
  carry-over  25 findings were found and never fixed
              oldest: SEC-036 wp_options.siteurl — first seen 2026-03-21, 6 runs ago
              3 are accepted and are not counted above
```

Arithmetic is the fallback for a project with no ledger yet, not the preferred answer. A
count says something is wrong; an identity says what.

Write the whole reconciliation block into the Step 8 report as its own section. When every
line is clean, print one line instead:

```
  Manifest reconciled — no drift, all categories have run, record is current.
```

## Step 2.7: Fix the page scope

The audit reads the theme. A client reads a site, page by page, and several criteria exist
only by comparing pages: a logo that moves between templates, a type scale that changes, a
menu item that is marked active on one page and not another. None of those is visible from
a single template, and none of them has a `file:line`.

So before any page-level check runs, fix the list of pages. Skip this step entirely when
the scope is `none`.

**`auto` derives the list, in this order, and stops at the first that yields pages:**

1. `.wp-create.json` `pages`, if the project records one.
2. The primary menu — `$WP menu item list <menu> --format=json` at Tier 2.
3. `sitemap.xml` (or `sitemap_index.xml`) from the site URL.
4. The internal links on the home page.

Then **always** add, if they exist: the 404, and any page carrying a form. They are where a
third of the usability catalog lives and no derivation finds them by ranking.

- **The 404** is a URL that cannot resolve — `<site>/<a path nothing serves>`. Do not look
  for it; construct it.
- **The form page**, at Tier 2, from the site itself rather than by fetching every candidate:

  ```bash
  bash -c "$WP post list --post_type=page --fields=ID,post_name,post_title --format=csv \
    --s='[contact-form-7' --meta_key=_wp_page_template"
  ```

  Repeat for the form plugin actually installed (`[gravityform`, `[wpforms`, `<form`). With
  no Tier 2, fetch the pages already in the list and keep the first whose HTML contains a
  `<form>` that is not the search form; when none does, say the form page could not be found
  rather than reporting category A as passing.

**Cap the list at eight pages and say you capped it.** A representative set — home, a
listing, a detail, the page with the main form, the 404 — measures the templates; auditing
forty pages measures the same five templates eight times each and makes the report unusable
for the person who has to act on it. When the site has more, take one page per template and
name the templates covered.

**Grouping by template** is `_wp_page_template` at Tier 2:

```bash
bash -c "$WP post list --post_type=page --fields=ID,post_title --format=csv \
  --meta_key=_wp_page_template --meta_value=<template.php>"
```

Without Tier 2 there is no template metadata, so group by URL shape instead — one page per
path depth and per post type prefix — and say in the report that the grouping was inferred
from URLs. An inferred grouping that is announced is usable; one that is presented as
template coverage is not.

Print the scope before measuring:

```
=== Page Scope ===
Source: <manifest|menu|sitemap|home links>
Pages (N):
  /                      home
  /services/             listing
  /services/<one>/       detail
  /contact/              form
  /<404 probe>           404
<Capped from M pages — one per template.>
```

**A page-level criterion with no page list is `UNMEASURED`, never `PASS`.** This is the same
rule the tiers already follow, and it is worth restating here because the failure is quiet:
an audit that measured nothing page-level and printed no failures reads exactly like a site
with no page-level problems.

### Page-level and site-level are different answers

A criterion answered per page is reported on **every page it fails on** — the fix is per
template and a single row would hide which page is wrong. A criterion that can only be
answered by comparing pages is evaluated **once**, and when it fails it names the pages it
differs between. `skills/wp-audit-ux-standards/SKILL.md` holds the split; the same shape
applies to any other category that grows page-level checks.

### What a score means once pages exist

With a page list, the report scores: criteria passed over criteria that **applied**, per
page, per category and overall.

**`N/A` is excluded from the denominator and reported beside it, never inside it.** A site
is not worse for lacking a feature it was never meant to have, and 30/40 on what applied is
a measurement where 30/56 against a list including sixteen that never applied is a number
that punishes a site for its own shape. `UNMEASURED` is excluded too, and for the opposite
reason: it is work outstanding, and folding it into either side of the fraction hides it.

## Step 3: Detect Environment & Tier

Determine the audit tier:

**Tier 1 (always):** Code-only checks via Read, Grep, Glob.

**Tier 2 (if `.wp-create.json` exists):** Read `.wp-create.json` to get `$WP` wrapper. Set `$WP` to the value of `wp_cli.wrapper`. Enables WP-CLI runtime checks.

**Tier 3 (if a browser automation tool is available, or `--suite` brings its own):** Probe every run — Step 2.5b
already re-probed it, and `audit.browser_measurement_available` from a previous run is a
drift input, never the answer. Tier 3 is what actually loads the page, so it is gated on
the one thing that can: a browser.

**Tier 3 is available two ways, and they are not equivalent.**

1. *A browser tool in this session* — Playwright MCP (`mcp__playwright__browser_navigate`),
   Chrome DevTools MCP (`performance_start_trace`) or Claude in Chrome
   (`mcp__claude-in-chrome__navigate`). Whatever is here measures; nothing here means no
   measurement.
2. *The suite* (`--suite`) — a generated Playwright project that brings its own browser.

The first depends on who is running the audit, which is why the same project used to
measure differently depending on the session. The second does not, and it is the one that
can run unattended. Probe it with:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh --probe
```

Exit `0` means it can run, `2` means this machine has no Node or npm and Tier 3 stays
unmeasured — which is a skip, not a failure, and is reported as `UNMEASURED` exactly like
an absent browser tool.

The criteria themselves — budgets, Core Web Vitals thresholds, the WCAG 2.2 additions, the
HTML5 cross-check — live in the audit agents and in `wp-audit-standards`, and every check
that a file scan can answer runs at Tier 1 regardless. Tier 3 adds measurement, not
knowledge.

Print tier status:
```
=== Audit Tier Detection ===

Audit Tier: <Code | Code + Runtime | Code + Runtime + Lighthouse | Code + Runtime + Suite>
  ✓ Tier 1: Code analysis (always available)
  <✓|✗> Tier 2: WP-CLI runtime checks (<.wp-create.json found|.wp-create.json not found>)
  <✓|✗> Tier 3: Browser measurement (<browser tool detected|suite available|no browser tool available>)
```

**`--geo` needs Tier 2.** The GEO auditor's live HTTP checks and the `bin/geo-scan.sh`
verifier in Step 9 require `.wp-create.json` (for `$WP` and a reachable site URL). Without
Tier 2, `wp-audit-geo` still runs its code-only checks and reports the runtime GEO codes
`N/A`, and the live scan is skipped.

## Step 4: Dependency Check (Tier 2 only)

If Tier 2 is NOT available, skip this step entirely.

**With `--report-only`, this step installs nothing.** Print the dependency report below
without the Options block, then continue with option C (run with what is available). A
report-only run promises to leave the site unchanged, and installing a plugin changes it.

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

Browser measurement:
  <✓|✗> browser automation tool — <available|not available> (enables Core Web Vitals measurement)
  <✓|✗> suite (--suite) — <available|node/npm not available> (brings its own browser)

Either one is Tier 3. Print both: with `--suite` on a machine that has no MCP browser, a
line that says only "not available" contradicts the tier this run is actually at.

Options:
  [A] Install all recommended WordPress plugins
  [B] Let me pick which ones to install
  [C] Skip — run audit with what's available
```

Only show plugins relevant to the selected categories (don't prompt for Rank Math if `--security` only, don't prompt for AIOS if `--seo` only).

**On an adopted site, the stack decides what is offered** (Step 2.2):

- `stack.seo` names a plugin other than `rankmath`: do not list `seo-by-rank-math`. Print
  `✓ SEO owned by <stack.seo> — Rank Math not offered` instead.
- `stack.security` names a plugin other than `aios`: do not list
  `all-in-one-wp-security-and-firewall`. Print the same kind of line.
- `stack.fields` is `none`: do not list `secure-custom-fields`. A site with no field plugin
  has no field groups to audit. With `acf`, ACF is the field plugin, so SCF is not offered.
- A concern at `none` may still be offered its plugin (Rank Math, AIOS). Adding a plugin to
  a client site is the operator's decision, so option `[C] Skip` is listed first and marked
  recommended.

Use AskUserQuestion for the choice. If A: install all listed via `bash -c "$WP plugin install <slug> --activate"`. If B: ask which ones via AskUserQuestion and install selected. If C: continue without installing.

## Step 5: Security Level Selection

If `--security` or `--all` is selected AND `--report-only` is NOT set — and, on an adopted
site, `stack.security` is `aios`, or is `none` and AIOS was installed in Step 4:

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

**Dispatch order:** security → seo → a11y → performance → practices → geo → usability

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
| the page a person sees | `wp-audit-ux` | a required mark that is not there, a link that 404s, 142 characters to a line, a logo that moves between templates |

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
- Browser measurement: <available|not available>
- Origin: <created|adopted>
- Editable code: <code_scope.editable, or the theme path when created>
- Read-only code: <code_scope.read_only, or "none" when created>
- Stack: <seo=… security=… fields=… multilingual=… builder=… cache=…, or "plugin defaults" when created>
- Site type (commerce): <site.commerce value — woocommerce|none>
- Local clone: <yes|no>
- Clone-suppressed plugins: <clone_suppressed_plugins slugs, comma-separated, or "none">
- Parked drop-ins: <clone_parked_dropins files, comma-separated, or "none">

Step 2.3's clone suppression covers only the "deactivated"/"parked" finding for the items
above — nothing else about them is suppressed. A plugin listed under Clone-suppressed
plugins with a known vulnerability, an outdated version, or a hardcoded credential is still
a finding; only "this plugin is off because it is a clone" is already accounted for.

On an adopted site, audit every path in both code lists instead of <theme_path>. A finding
under a read-only path is always `Fix: manual`, `Owner: manual`, with a Method that works
around the vendor file (an override in editable code, a filter, a report upstream) and never
edits it. A check that reads one plugin's options is `N/A (stack: <name>)` when the stack
names a different plugin for that concern.

Any check that requests many URLs of the site — links followed, heads rendered, pages
walked — follows "Link and page sweeps against a site" in
skills/wp-audit-standards/SKILL.md: at most 4 requests in flight, internal targets resolved
through ${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/scripts/resolve-link-targets.php
before any HTTP, and ${CLAUDE_PLUGIN_ROOT}/bin/link-sweep.mjs for the rest. Never write a
crawler of your own. The local site shares its database and web server with every other
project on this machine.

Run all checks for your tier level. Output your findings as a structured report with the following format for each issue:

[<SEVERITY>] <CODE>: <message> (<file>:<line> if applicable)
  Resource: <the stable thing this is about — see the resource table in Step 7>
  Fix: <auto|manual>
  Owner: <code|setting|content|manual>
  Method: <description of fix>

Where SEVERITY is one of: CRITICAL, WARNING, INFO
Where Owner says where the fix LANDS, never whether you can apply it:
  code     — a file in the theme. Travels with the commit.
  setting  — a WordPress option, a plugin's configuration, a server rule. Applied with
             WP-CLI here and NOT carried by the commit, so it is a step to repeat on
             staging and production.
  content  — a text somebody has to write or decide.
  manual   — human judgement or an external tool.
A fix you apply automatically is still `setting` if it wrote to the database.
Where CODE follows the pattern: SEC-NNN, SEO-NNN, A11Y-NNN, PERF-NNN, BP-NNN, GEO-Dnn/Axx/Uxx/Pxx
```

Use these `subagent_type` values:
- `wp-audit-security` — security checks (file permissions, SQL injection, XSS, nonces, ABSPATH, wp-config hardening, AIOS configuration)
- `wp-audit-seo` — SEO checks (meta tags, schema markup, sitemap, robots.txt, Rank Math configuration, heading hierarchy, canonical URLs)
- `wp-audit-a11y` — accessibility checks (skip links, ARIA attributes, alt text, color contrast references, focus styles, semantic HTML, keyboard navigation)
- `wp-audit-performance` — performance checks (asset enqueuing, image optimization, caching headers, database queries, lazy loading, render-blocking resources)
- `wp-audit-practices` — best practices checks (ABSPATH guards, escaping, i18n, theme supports, coding standards, enqueue patterns, template hierarchy)
- `wp-audit-geo` — GEO/AI-agent readiness checks (ORA layers Discovery/Access/Usability/Payments, AI crawler allowlist, `llms.txt` and ARD catalog, rendered-head DOM checks, agent-skills index, is-agentic live scan)
- `wp-audit-ux` — usability checks (forms and data entry, navigation and task flow, links followed rather than inferred, hover and active states, rendered line length per breakpoint, logo and typography consistency across pages)

**`wp-audit-ux` is dispatched with the page list from Step 2.7, and its prompt says so.**
It is the only auditor whose scope is a set of URLs rather than the theme directory, and an
agent given no pages audits nothing while reporting cleanly.

**Error handling:** If an agent fails:
1. Note which agent failed and the error message
2. Continue with remaining agents (do not block the entire audit)
3. Mark the failed category in the report
4. Skip the failed category in the fix phase

## Step 6.5: Run the browser suite (`--suite` only)

The seven agents read code, the database and a rendered `<head>`. None of them loads the page
the way a visitor does, so the criteria that only exist in a rendered page — contrast as
measured, line width at each breakpoint, a form's validation, a broken link followed, a
Lighthouse score — were either unmeasured or asserted from the source. This runs them.

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh --url <public-url> --dir .wp-audit/suite \
  --site "<project name>" [--pages "/,/services/,/contact/"]
```

`<public-url>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` —
**unless `local_clone` is true (Step 2.3): the suite must not probe the clone's own host**,
so Step 2.3's live-check rule applies instead of that fallback — the confirmed production
URL (asked for, defaulting to `production_url`), or Tier 3 stays `UNMEASURED — needs the
public URL` and this run is skipped.
**Pass `--pages` with the list Step 2.7 fixed.** Without it the suite keeps whatever its
config already holds, which on a first run is the template's placeholder — so a run that
looks successful measures pages that are not this site's.
The first run scaffolds `.wp-audit/suite/` from `templates/audit-suite/` and installs the
suite's dependencies **once per machine**, into a shared cache keyed by the template's
`package.json`. Later runs and later projects reuse it.

| Exit | Meaning | What to report |
|---|---|---|
| `0` | the suite ran; `.wp-audit/suite/results/run.json` holds its findings | fold them in |
| `1` | it could not run, or produced nothing to convert | report the error; Tier 3 findings stay `UNMEASURED` |
| `2` | no Node, no npm, or the browser would not install | Tier 3 `UNMEASURED` — a skip, not a failure |
| `3` | crash | report it and continue |

**`audit.config.js` is written once and then left alone.** It carries the selectors
somebody inspected the real DOM to find, and a scaffold that overwrote it every run would
re-measure a different site each time without saying so. When a run reports selectors that
match nothing, edit that file — do not delete it.

### The suite's findings and the agents' findings can be the same defect

The suite measures accessibility with axe and reads the same `<head>` `wp-audit-seo` reads,
so a contrast failure or a missing description can arrive twice, once as `A11Y-AXE-*` or
`UX-*` and once as `A11Y-*` or `SEO-*`. Reporting **the same defect twice under two codes**
inflates every count and makes the ledger's identity useless, so Step 7's deduplication
owns it, with one rule:

- **A measurement beats an inference.** Where both describe the same resource, keep the
  suite's finding and drop the agent's — the agent reasoned about the code, the suite
  loaded the page. The kept finding's evidence notes that it superseded another source, and
  the sidecar keeps that evidence.
- Where they describe *different* resources, they are different findings. A contrast
  failure the suite measured on `/contact` and one the agent found in a stylesheet rule
  that no audited page uses are both real, and the second is the one nobody would find
  again.

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

## Step 6.10: Every fix is verified against the data that triggered the finding

§6.9 makes a *finding* a measurement. The same has to hold for the *fix*, and it is the half
that gets skipped: a page that still returns 200 after an edit proves the site did not break,
not that the defect is gone. The defect was on one record, one field, one template — reload
that one.

Every finding therefore carries the case that produced it, and the fix is re-measured on it:

| Finding shape | What to reload after the fix |
|---|---|
| a field on one post prints wrong | that post's permalink, not the archive |
| a template part misbehaves on some rows | the URL of a row that was wrong before |
| an option value reaches the rendered head | `curl` the page and read the head again |
| a query returns the wrong set | the same query, same arguments, and diff the ID list |

On one audited site a relationship field pointed at a deleted post, and the template painted an
empty card for it. Two pages using that template rendered correctly, because their fields held
no orphan. The fix could only be verified by finding the one record whose field held the
missing ID and reloading that page.

So: name the reproducing case when the finding is written, while the measurement is in hand.
Recovering it afterwards costs more than recording it, and a fix nobody could reproduce is a
fix nobody ran.

A fix whose reproducing case cannot be found is reported as `UNVERIFIED`, exactly like a
finding that could not be measured. It is not counted as resolved.

## Step 7: Aggregate Reports

Collect reports from all agents. For each agent's output, parse the findings into a unified list.

**Deduplication** runs on two different keys, because two different things collide here.

*Two agents reporting the same place.* If the same `file:line` appears in multiple reports:
- Keep the finding with the highest severity
- Remove duplicates from lower-severity reports
- Category claims: Security claims vulnerability checks, Practices claims coding-standards
  checks. ("Claims" is which auditor the check belongs to. It is not the finding's **owner**
  — that is Step 8.5's `code`/`setting`/`content`/`manual`, and it says who applies the fix.
  One word for two unrelated ideas is how a `setting` ends up rendered as `code`.)

*The suite and an agent reporting the same defect.* With `--suite`, a contrast failure or a
missing description arrives twice: once measured on a page, once inferred from the source.
**A measurement beats an inference.** They are the same defect only when the check **and**
the resource match — a contrast failure measured on `/contact` and one found in a stylesheet
rule no audited page uses are two real findings, and the second is the one nobody would find
again.

This one is not applied by hand. `bin/audit-report.mjs --merge` does it in Step 8.5, keeping
the measured finding and recording the loser's code in its evidence so the ledger still
shows the check ran. Do not also dedupe them here: doing it twice drops the second copy
without recording that it existed.

**The resource convention both sides must share.** The merge matches on `check` + `resource`,
so a resource written two ways never matches and the duplicate survives:

| What the finding is about | `resource` |
|---|---|
| a page | `page:/contact/` — the path, with its trailing slash as the site serves it |
| a record | `post:412`, `menu_item:88`, `wp_options.siteurl` |
| a place in the code | `template-parts/hero.php:34` |
| a site-level judgement | `site` |

**A page-level finding is one row per page, not one per occurrence.** Three broken links on
`/contact/` are one `UX-014 : page:/contact/` whose evidence lists all three. One row per
link would match nothing the suite emits, and would turn a page with a bad footer into
forty findings that are one fix.

Sort all issues: CRITICAL first, then WARNING, then INFO.

Count totals per category and overall.

## Step 7.5: Reconcile against the finding ledger

`issues_found`, `issues_fixed` and `carried_over` are three integers, and three integers
cannot answer the question every follow-up audit asks: **is this the same problem as last
time?** Fix one issue and find a new one and the count is unchanged while the contents
changed completely — Step 2.5e can report "25 carried over" and never say which 25. A number
that stays the same for two different reasons is not a measurement anyone can act on.

### A finding's identity is its check and its resource

```
SEC-036 : wp_options.siteurl
WP-048  : post:412.related_posts
SEO-054 : menu_item:88
A11Y-012: template-parts/hero.php:34
```

The resource comes from the evidence Step 6.9 already requires — the `$WP` call, the
`file:line`, the URL. **No new evidence is collected for this**; a finding that could not
name its resource could not have named its evidence either, and Step 6.9 already drops it.

The resource must be the most stable thing the evidence names. A `file:line` moves when
someone adds an import above it, so a rule that identifies its finding by line alone reports
every finding as resolved-and-new after any edit to the file. Prefer the record, the option
or the element; fall back to `file:line` only where nothing more stable exists, and accept
that those findings churn.

### Five statuses, and only one of them is a judgement

| Status | Meaning |
|---|---|
| `new` | not in the ledger before this run |
| `still_failing` | in the ledger, failing, and failing again now |
| `resolved` | in the ledger as failing, and **this run measured the same check and did not find it** |
| `accepted` | a human decided it stays; the audit stops re-raising it |
| `unmeasured` | the check did not run this time (wrong tier, no network) — its ledger entry is untouched |

**`resolved` is the one that can lie, so it is the one with a precondition.** A finding is
only resolved when the check that produced it actually ran and came back clean. A check that
did not run produces `unmeasured`, never `resolved` — otherwise running an audit without
Tier 2 would mark every Tier 2 finding fixed, and a report would show a site cleaning itself
up by being audited with less access than before.

`accepted` is set by a human and by nothing else. An audit never promotes its own finding to
accepted, and never demotes one: re-raising something a client has explicitly accepted, every
run, is how a report stops being read.

### Where the ledger lives, and why not in the manifest

`.wp-create.json` is a **configuration** record. Every command parses it on every run to find
a WP-CLI wrapper and a theme slug, and `bin/wp-config.mjs` validates the whole of it. A
findings ledger is **audit history**: one command reads it, and it grows without bound — a
single check found 70 orphan ACF ids on one real site, which is 70 entries from one rule.
Putting that in the manifest makes `/wp-section` parse an audit's history to learn a theme
slug.

So the ledger is its own file, beside the manifest:

```
.wp-audit-findings.json
```

`audit.findings_ledger` in the manifest records only its path and the run that last wrote it
— a pointer, fixed in size.

**A missing ledger means "no history", never "nothing ever failed".** It can be deleted,
gitignored, or simply never written by an older plugin version, and the audit cannot tell
those apart. Report it as absent and start one; do not report a first run as a project with
everything resolved.

### What the counts become

`issues_found` and `issues_fixed` stay in the manifest and are now **derived** from the
ledger rather than authoritative — kept because older reports and Step 2.5e read them, and
because a number is still the right thing to print in a summary. When the two disagree, the
ledger wins and the disagreement is worth reporting: it means a run wrote one and not the
other.

## Step 8: Present Report

Print the formatted report:

### Status vocabulary

Every check resolves to one of five statuses, and the last three are not interchangeable:

| Status | Means |
|---|---|
| `PASS` | ran, and the site satisfies it |
| `FAIL` | ran, and the site does not |
| `N/A` | does not apply to this site type — say why (e.g. "no WooCommerce", or "local clone", see Step 2.3) |
| `UNMEASURED` | applies, but was never measured — say what stopped it (e.g. "needs the public URL") |
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

[USABILITY] N issues (X critical, Y warnings, Z info) — M/A criteria passed of those that applied
  Pages: <the Step 2.7 scope, or "not measured — no page scope">
  ✗ CRITICAL: <message> (UX-014, /services/)
  ✗ WARNING: <message> (UX-006, desktop: 142 characters)
  ○ N/A: K — <the criteria this site genuinely lacks the feature for>
  ? UNMEASURED: J — <what stopped them: no page scope, no browser, no Tier 2>

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

## Step 8.5: Write the dated deliverable (if `--report` was given, or the run is report-only)

The console report above is for whoever ran the audit. It is gone when the scrollback is,
and `.wp-audit-findings.json` is a working file — nobody hands a client a JSON array of
check ids. When `--report` is given, or the run is report-only (Step 1 defaults `--report`
to `both` there), this step writes the same run as documents.

### Every finding says who applies it

Before rendering, assign each finding one of four owners. This is not a label for the
report; it is the answer to "how much of this can you do, and how much is mine?", and it is
the one question the counts cannot answer.

| Owner | What it is | Where it ends up |
|---|---|---|
| `code` | a file in the theme — CSS, `functions.php`, a template | **travels with the commit** |
| `setting` | a WordPress option, a plugin's configuration, a server rule (HTTPS, redirects, `.htaccess`) | applied with WP-CLI on the local clone, and **does not travel with the commit** |
| `content` | a text somebody has to write or decide — a title, a description, an `alt` | a person writes it; you may propose the text |
| `manual` | human judgment or an external tool | never automated |

**`setting` is the one that gets lost, and it is why the four exist rather than two.** A
`$WP option update` run against a local clone changes that clone's database and nothing
else. The commit carries no trace of it, the staging panel has no WP-CLI, and the next
deploy looks identical to the audit that "fixed" it. Every `setting` row is therefore a
step to repeat wherever the site is deployed, and the report says so in those words.

An owner comes from what the fix touches, never from whether the audit can do it: a fix
this run applies automatically is still a `setting` if it wrote to the database.

**Every agent reports its own owner** — the dispatch prompt in Step 6 asks for it, so this
step reads the field rather than classifying ~250 check codes at report time. When a finding
arrives without one, derive it from what its fix touches, and the category tells you where
to look first:

| Category | Almost always | The exceptions worth checking |
|---|---|---|
| `SEC-*` | `setting` — wp-config constants, `.htaccess`, AIOS options, file permissions | escaping and `$wpdb->prepare` in a template are `code` |
| `SEO-*` | `setting` — Rank Math options, permalinks, sitemap | hardcoded `<title>`/meta in a template are `code`; a missing description or a title to rewrite is `content` |
| `A11Y-*` | `code` — templates, CSS, ARIA | `alt` text and link text somebody has to write are `content` |
| `PERF-*` | `code` — enqueues, image attributes, `inc/performance.php` | object cache, autoload options, revisions, OPcache are `setting` |
| `WP-*` | `code` — it is the theme's own source by definition | — |
| `GEO-*` | `code` — `inc/agentic.php` and the surfaces it generates | the robots AI policy and anything written to an option are `setting`; trust-anchor prose is `content` |
| `UX-*` | read it from `skills/wp-audit-ux-standards/SKILL.md`, which gives an owner per criterion | — |

The table is a starting point, not the answer. **Ask what the fix writes to**: a file in the
theme is `code`, a row in the database or a server rule is `setting`, a sentence a person
must compose is `content`, a judgement is `manual`.

### Render it

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-report.mjs --run <run.json> --out .wp-audit \
  --format <md|html|both> --lang <en|es>
```

Write `<run.json>` first, into the session's scratch directory rather than the project —
it is an argument, not an artifact:

```json
{
  "site": "<project name>",
  "date": "<YYYY-MM-DD>",
  "tier": "<the same label Step 3 printed>",
  "categories": ["security", "seo", "usability"],
  "findings": [
    {
      "check": "SEC-036",
      "resource": "wp_options.siteurl",
      "severity": "CRITICAL",
      "ownership": "setting",
      "category": "security",
      "page": null,
      "message": "Development host in siteurl",
      "fix": "$WP option update siteurl https://…",
      "evidence": "$WP option get siteurl"
    }
  ],
  "unmeasured": [
    { "check": "PERF-LCP", "reason": "no browser tool and no suite — Tier 3 never ran" }
  ]
}
```

`check`, `severity`, `ownership` and `message` are required on every finding: the renderer
**refuses a finding with no `ownership`** and exits `1` naming it, because a plan whose last
column is blank is the plan this step exists to replace. `page` is the page a page-level finding is about and
`null` otherwise. An `UNVERIFIED` finding from Step 6.9 is **not** a finding here: it was
never measured, so it goes in `unmeasured` with the command that would settle it.

**With `--suite`, do not hand-merge.** Step 6.5 wrote a run file of its own; pass it:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-report.mjs --run <agents.json> \
  --merge .wp-audit/suite/results/run.json --out .wp-audit --format both --lang <en|es>
```

The renderer applies Step 7's second rule — same `check` **and** same `resource` keeps the
measured one, notes the superseded source in its evidence — which the dated sidecar keeps —
and prints how many collided.
Rendering the two separately instead would split one audit across two documents and two
baselines.

| Exit | Meaning |
|---|---|
| `0` | documents written — print the paths. A run with no findings is written too: the report says nothing was found, and its sidecar is the baseline the next audit diffs against |
| `1` | the run file is unusable, or a finding is incomplete — fix the run file and re-run |
| `3` | crash — report it and continue to Step 9 |

It writes `.wp-audit/informe-<AAAA-MM-DD>.md`, `.html`, and a machine sidecar `.json`.
The Markdown is for working and versioning; the HTML is a single self-contained file that
opens with a double click, forwards as an attachment and prints to PDF from the browser.
Hand over both and say which is which.

**The sidecar is what makes the next report comparable.** The renderer diffs this run
against the newest earlier sidecar and opens the document with resolved / new / still
failing, by finding identity rather than by count. It never parses its own Markdown back:
a report edited by hand would otherwise change what the next comparison claims happened.
The ledger and the sidecar are different records and both stay — the ledger is the
project's running history of every finding ever seen, a sidecar is one dated snapshot.

### The report goes out before anything is fixed

Run this step before Step 9, always, including when the user has already said to fix
everything. The dated report is the baseline the next audit measures against, so a run
that fixes first has no before to compare with, and the user cannot choose what gets
touched in their site without seeing the whole of it. Step 9 then works from the plan this
step wrote: tell the user how many rows are `code`, how many are `setting`, `content` and
`manual`, and that you can apply the first two and not the last two.

## Step 9: Offer to Fix (unless --report-only)

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
${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh <home-host>
```

`<home-host>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` (or
`$WP option get home`) — **unless `local_clone` is true (Step 2.3): the live scan must not probe
the clone's own host**, so Step 2.3's live-check rule applies instead of that fallback — the
confirmed production URL, or `UNMEASURED — needs the public URL` with no scan run. Exit codes:

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

After all fix agents complete, count how many issues were successfully fixed, and count
them by owner. Print the `setting` fixes again as a list of steps to repeat on staging and
production: they were applied to a database this deploy will not carry, and a fix nobody
repeats is indistinguishable from one that was never made.

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
    "categories_run": ["security", "seo", "a11y", "performance", "best-practices", "geo", "usability"],
    "checks_run": {
      "security": ["SEC-001", "SEC-002", "SEC-036"],
      "geo": ["GEO-A11"],
      "usability": ["UX-014", "UX-006"]
    },
    "issues_found": N,
    "issues_fixed": M,
    "carried_over": K,
    "findings_ledger": { "path": ".wp-audit-findings.json", "written": "<ISO 8601 timestamp>" },
    "browser_measurement_available": true
  },
  "manifest_version": 3
}
```

**Delete `audit.web_quality_skills_available` as you write this block** if the manifest still
carries it. Step 2.5b reads it once, to migrate a manifest written before the rename; leaving
it in place afterwards means every later run sees two keys for one capability and no rule
saying which wins.

Then write the ledger itself, beside the manifest:

```json
{
  "ledger_version": 1,
  "findings": [
    {
      "check": "SEC-036",
      "resource": "wp_options.siteurl",
      "status": "still_failing",
      "severity": "CRITICAL",
      "first_seen": "2026-03-21T09:14:02Z",
      "last_seen": "2026-09-19T16:40:11Z",
      "evidence": "$WP option get siteurl"
    },
    {
      "check": "WP-048",
      "resource": "post:412.related_posts",
      "status": "resolved",
      "severity": "WARNING",
      "first_seen": "2026-09-01T10:00:00Z",
      "last_seen": "2026-09-12T11:22:00Z",
      "evidence": "$WP post meta get 412 related_posts"
    }
  ]
}
```

`last_seen` on a `resolved` entry is the last run that still **found** it, not the run that
noticed it was gone — the useful question afterwards is when the problem stopped being
observed, and a timestamp that moves on every clean run cannot answer it. A `resolved` entry
is kept, not deleted: deleting it means the next recurrence reports as `new`, and a defect
that keeps coming back is a different thing from one that has never been seen.

`audit.findings_ledger` is a pointer and stays a pointer. If it ever grows to hold findings,
every command that reads the manifest pays for an audit's history.

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

Write the IDs exactly as the agent's catalog spells them, revision included (`SEC-036`, `GEO-A11`, `SEC-036@2`). This is the
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
Fixed: M/N auto-fixable issues (C in code, S in settings)
Remaining: K issues require manual attention

Report: .wp-audit/informe-<AAAA-MM-DD>.md
        .wp-audit/informe-<AAAA-MM-DD>.html  (single file — open, send, or print to PDF)

Repeat on staging and production (settings do not travel with the commit):
  1. <the setting fix, as the command that applied it>

Manual issues:
  1. [SEC-002] SQL injection in custom-query.php:45 — use $wpdb->prepare()
  2. [A11Y-003] Color contrast ratio 3.2:1 on .hero__subtitle — increase to 4.5:1
  ...

Next steps:
  - Review and test the applied fixes
  - Address the remaining manual issues listed above
  - Re-run the audit so the next dated report shows the improvement
  - Run /wp-finalize for pre-delivery validation
```

If `--report-only` was used:
```
=== Audit Report Complete ===
Total: N issues found (X critical, Y warnings, Z info)
Auto-fixable: M/N

Report: .wp-audit/informe-<AAAA-MM-DD>.md
        .wp-audit/informe-<AAAA-MM-DD>.html  (single file — open, send, or print to PDF)

To auto-fix issues, run: /wp-audit <same flags without --report-only>

Next steps:
  - Review the report written above
  - Run /wp-audit (without --report-only) to auto-fix issues
  - Run /wp-finalize for pre-delivery validation
```

**The `Report:` lines name only what Step 8.5 actually wrote**, in both summaries above.
`--report md` or `--report html` prints one line, not two. A run with no findings is still
written — the report says nothing was found — so its paths are printed like any other.
When the renderer failed (exit `1` or `3`), print `Report: not written — <the reason>`
instead of paths, and drop the line that tells the operator to review it. A summary that
points at a file which does not exist is worse than no summary.
