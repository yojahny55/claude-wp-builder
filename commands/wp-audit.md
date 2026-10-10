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

### Ask for the browser suite up front when the flag is absent

If `--suite` was NOT passed, ask right after the report-only question, in the same
`AskUserQuestion` call when both are asked, and still before any other prompt of the run:

```
Also run the browser suite (web-portal-audit, Playwright: axe-core, Lighthouse, rendered-page criteria)?
  [A] Yes — run it in Step 6.5 against the public URL; first run on a machine installs its dependencies once
  [B] No — Tier 3 uses a browser tool in this session if there is one, otherwise UNMEASURED
```

On A, set `--suite` for the rest of the run, exactly as if it had been typed: `--pages`
defaults to `auto`, Step 3 counts the suite as a Tier 3 path, and Step 6.5 runs. The URL is
the one Step 6.5 already resolves (`--host`, then `wordpress.url`, or on a local clone the
confirmed production URL Step 2.3 asks for), so answering A asks for nothing more here. On B,
continue without it. When the flag was passed, do not ask.

The suite used to run only when someone remembered the flag, so the commonest invocation —
a bare `/wp-audit` — never loaded a page the way a visitor does, even on a machine that had
everything the suite needs. It is still not on by default: the first run installs packages
and every run drives a real browser against a public site, which is the operator's call.

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

**Validation checks the manifest's shape, not whether it is true.** A blank scaffold that a real
site was later restored over passes `validate` and describes the wrong site: `source: blank`,
a theme slug with no directory, no plugins, against ~25 active ones. When Tier 2 is reachable
(a `wp_cli.wrapper` that answers), also run:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs drift '${PROJECT_PATH}'"
```

Exit `0`: the manifest fits the site, continue. Exit `4`: it does not; each `drift:` line names
a disagreement (theme directory missing, active theme differs from `theme.slug`, active
plugins absent from `plugins.installed`). Print the lines and ask with `AskUserQuestion`:

```
.wp-create.json no longer describes this site.
  [A] Re-adopt it — read-only detection, keeps a timestamped backup of the old manifest (recommended)
  [B] Continue with the manifest as it is
```

On A, run `wp-adopt.md` Steps 2 to 5 with `--replace`. On B, continue, and say in the report
that every manifest-driven choice (plugin stack, theme slug, code scope) rests on a manifest
the drift check disputed. Exit `1` (the probe could not run) is not drift: report it and
continue. Skip the check when there is no Tier 2.

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

Read `origin`. When it is absent or `created`, skip this step: every later step behaves
exactly as it did before adoption existed. When it is `adopted`, read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/adopted-site.md` now and follow it — it is this step, not background.
It covers the code scope (editable and read-only), and what adoption changes in every later step.

## Step 2.3: Site type and local clone

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/site-context.md` now and follow it — it is this step, not background. It covers store detection, store tier, the local-clone rules, the public-URL question, clone-safe versus production-only checks, and the live mail transport finding.

## Step 2.5: Reconcile the Manifest

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/manifest-reconcile.md` now and follow it — it is this step, not background. It covers sub-steps 2.5a to 2.5e: schema version, measuring the stack, missing recorded decisions, the category coverage matrix, freshness and carry-over.

## Step 2.7: Fix the page scope

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/page-scope.md` now and follow it — it is this step, not background. It covers how the page list is chosen, page-level versus site-level criteria, and what a score means once pages exist.

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

If Tier 2 is NOT available, skip this step entirely. Otherwise read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/dependencies.md` now and follow it — it is this step, not background.
It covers the plugin check, the `--report-only` rule (install nothing), and which audit plugins are offered.

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

**When a production host is in play** (`--host`, or a production URL confirmed in Step 2.3),
create `<scratch>/prod-gate` before dispatching and pass it as the gate dir in every prompt.
The agents still run in parallel, and each measures exactly what it measured before. The
gate makes the production server see one request at a time, paced, and stops all of them at
the first block. Without it, one run against a server running fail2ban, CrowdSec and
ModSecurity sent seven agents' traffic at once. The server banned the auditing IP within
five minutes, and the run lost every live check. See "Production sits behind a WAF" in
`skills/wp-audit-standards/SKILL.md`. A local-only run creates no gate and changes nothing.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/dispatch.md` now and follow it — it is this step, not background. It covers the prompt template every agent gets, with its scope, the Owner rule, the subagent_type values, sharding, and error handling.

## Step 6.2: Live GEO scan (when `geo` is selected)

The is-agentic scan is read-only on the site, so it runs here, in every mode including
`--report-only`, and not only in the Step 9 fix phase. Run it once the public host is
confirmed by Step 2.3 (`--host`, or `wordpress.url` when the site is not a local clone):

```bash
${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh <home-host> --start
```

Use a Bash timeout of at least 150000 ms. The exit-code table in Step 9 ("GEO fixes") applies
unchanged, and so does its rule that none of them is a pass. The returned score, or the reason
there is none, fills the report's `Live scan:` line at Step 8; it is never left `pending` by a
run that skips Step 9. Step 9 runs the scan again only to report the before → after score.

## Step 6.5: Run the browser suite (`--suite` only)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/browser-suite.md` now and follow it — it is this step, not background. It covers how the browser suite runs, and how its findings merge with the agents' findings.

## Step 6.8: Coverage gate — UNMEASURED is not an answer until it is justified

Before Step 7, read each returned report's `UNMEASURED` list and its measurement evidence.

1. **Browser evidence is required.** When `Browser measurement: available`, an `a11y`, `ux` or
   `performance` report with no browser-measured evidence (no `getComputedStyle`, bounding box,
   screenshot or trace line) is rejected and its agent re-dispatched with the reason.
2. **Each `UNMEASURED` is classified by its stated reason.** Acceptable, and kept: needs
   credentials, needs the network or a third party, needs production (Step 2.3's
   production-only column), needs a tier the run does not have. Anything else — "not run",
   "no browser measurement", "clone", or no reason at all — is measurable with tools already
   present.
3. **Re-dispatch once.** Every `UNMEASURED` with an unacceptable reason goes back to its agent
   once, together, with the measurement split restated. What is still unmeasured after that
   keeps the agent's second reason.
4. **Compute coverage against the catalog.** Every agent returns `checks_executed` as a field
   (check ids, passes included), not in prose. For each category compute
   `executed ∩ catalog / catalog`, with the catalog read where Step 2.5d reads it — the
   agent's file, and for usability the table rows of its skill — and print it in the report
   header:
   `security 31/44 checks executed — never run: SEC-0xx, SEC-0yy…`.
   An agent that returns no `checks_executed` counts as 0 and is re-dispatched. A category
   under 90% blocks "audit complete": re-dispatch the missing ids once, then list what is
   left, each id with its specific blocker. Without a recorded blocker for every missing id
   the report says `INCOMPLETE`, never "complete". Ids that are `N/A` by site type or clone
   are out of the denominator, as in Step 2.5d.
5. **Say what happened.** The report records how many checks were re-dispatched and how many
   stayed `UNMEASURED` for each acceptable reason, so a reader sees the coverage the run
   actually reached rather than a summary that calls it complete.

## Step 6.9: Every finding is a measurement

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/measurement.md` now and follow it — it is this step, not background. It covers what counts as a finding.

## Step 6.10: Every fix is verified against the data that triggered the finding

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/fix-verification.md` now and follow it — it is this step, not background. It covers how each fix is verified against the data that triggered its finding.

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

**One defect is one finding.** A production `display_errors` leak surfaces as a notice before
the document in security, both SEO files, the GEO head and performance. Agents tag these with
the same `Root cause:` slug, and `bin/audit-report.mjs` folds findings that share one into the
most severe, which lists the others under `also_affects` ("same cause: SEC-0xx site, …"). The
totals count the defect once. When no agent tagged it, the aggregator does: two findings whose
evidence quotes the same output line (the same notice text, the same header) get a shared slug
here, before the report runs. Findings with no root cause pass through untouched.

Sort all issues: CRITICAL first, then WARNING, then INFO.

Count totals per category and overall.

## Step 7.5: Reconcile against the finding ledger

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/ledger.md` now and follow it — it is this step, not background. It covers finding identity, the five ledger statuses, where the ledger lives, and the derived counts.

## Step 8: Present Report

Print the formatted report:

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/status-vocabulary.md` now and follow it — it is this step, not background. It covers the five statuses and the console report format.

## Step 8.5: Write the dated deliverable (if `--report` was given, or the run is report-only)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/deliverable.md` now and follow it — it is this step, not background. It covers finding ownership, rendering with bin/audit-report.mjs, and why the report goes out before any fix.

## Step 9: Offer to Fix (unless --report-only)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/fix.md` now and follow it — it is this step, not background. It covers the report-only exit, the fix offer, and the rules each fix follows.

## Step 10: Update Manifest

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/manifest-update.md` now and follow it — it is this step, not background. It covers the audit block written back to .wp-create.json.
