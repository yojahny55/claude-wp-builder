# /wp-audit — Step 2.5

`commands/wp-audit.md` sends the run here at Step 2.5. Follow it in order; nothing in it is optional background.

## Contents

- 2.5a — Schema version
- 2.5b — Measure, do not trust (Tier 2 only)
- 2.5c — Recorded decisions that are missing, not defaulted
- 2.5d — Category coverage matrix
- 2.5e — Freshness and carry-over

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
`agents/wp-audit-performance.md`, `GEO-*` in `agents/wp-audit-geo.md`. Usability is the
one category whose table lives in its skill rather than its agent: `UX-*` is every **table
row** of `skills/wp-audit-ux-standards/SKILL.md` — a line starting `| UX-NNN |`. The agent
names only the handful its procedure measures, and the skill's prose names ids that are not
criteria (the suite-owned ones), so a bare id grep of either file is the wrong catalog. Read
the owning file, not a
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
