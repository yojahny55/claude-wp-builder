---
name: wp-audit-standards
description: Shared contract for every wp-audit-* agent — severity levels, the report fields bin/audit-report.mjs reads (check, status, severity, ownership, resource), the SEC-, SEO-, A11Y-, PERF-, WP-, GEO- and UX- prefixes, deduplication, the N/A rules for a WooCommerce catalog store or a local clone of production, link sweeps through bin/link-sweep.mjs, pacing live checks through bin/prod-gate.sh behind fail2ban, CrowdSec or ModSecurity, Lighthouse measurement traps, page-weight budgets and the WCAG and Core Web Vitals thresholds. Use when writing, merging or scoring an audit finding, deciding whether a check is N/A, sweeping a site's links, sending any request to a production host during /wp-audit, or judging a Lighthouse or Core Web Vitals number. Not for a domain's own checks — Rank Math and SEO (wp-audit-seo-standards), local SEO (wp-audit-local-standards), GEO, llms.txt and AI crawlers (wp-audit-geo-standards), usability UX-NNN (wp-audit-ux-standards).
user-invocable: false
---

# WP Audit Standards

The contract every `wp-audit-*` agent shares: how a finding is graded, named and reported,
when a check is `N/A`, how a sweep and a production request are paced, and the thresholds
the agents measure against. Each domain's own check catalog lives in its agent, and in
`wp-audit-seo-standards`, `wp-audit-local-standards`, `wp-audit-geo-standards` and
`wp-audit-ux-standards`.

`$WP` throughout is the WP-CLI wrapper from the project's `.wp-create.json`
(`wp_cli.wrapper`).

## Reference files

- [references/performance-lessons.md](references/performance-lessons.md) — Lighthouse
  measurement traps (simulated against observed metrics, contention), the rejected
  inline-critical-CSS experiment with its numbers, WebP and right-sizing for images a theme
  prints from raw field URLs, and the AIOS × CF7 REST interaction. Read when filing or
  fixing a `PERF-xxx` finding from a Lighthouse run.

---

## Severity levels

| Severity | Meaning | Action |
|----------|---------|--------|
| **CRITICAL** | Security vulnerability, complete accessibility failure, broken core functionality | Fix immediately |
| **WARNING** | Best-practice violation, degraded UX, performance problem | Fix before delivery |
| **INFO** | Optimization opportunity, minor improvement | Fix when convenient |

---

## Report contract

Every agent reports each check it ran with the field names `bin/audit-report.mjs` reads, so
`/wp-audit` Step 8.5 copies a finding into the run file without renaming anything. A field
spelled differently is a field the renderer never sees, and it refuses a finding with no
`check`, `severity`, `ownership` or `message` (exit `1`).

| Field | Required | Value |
|---|---|---|
| `check` | always | the check id exactly as the agent's catalog spells it — `SEC-036`, `GEO-A13`, `SEC-036@2` |
| `status` | always | `PASS`, `FAIL`, `UNMEASURED` or `N/A` |
| `severity` | on `FAIL` | `CRITICAL`, `WARNING` or `INFO`, uppercase |
| `ownership` | on `FAIL` | `code`, `setting`, `content` or `manual` — where the fix lands (`/wp-audit` Step 8.5) |
| `message` | on `FAIL` | what is wrong, in one sentence |
| `resource` | on `FAIL` | the stable thing it is about: `page:/contact/`, `post:412`, `template-parts/hero.php:34`, `site` (`/wp-audit` Step 7) |
| `evidence` | on `FAIL` | the command, selector, URL or measured value that produced it |
| `reason` | on `UNMEASURED` and `N/A` | what stopped it, or why it does not apply |
| `fix` | no | how to fix it |
| `auto_fixable` | no | `true` when the agent can apply the fix without risk (see *Auto-fixable* below) |
| `root_cause` | no | a slug every finding of one defect shares, e.g. `display-errors`; the renderer folds them into one |
| `page`, `file`, `line` | no | where, when there is such a place |

Where each status goes:

- `FAIL` is a finding: a row in the run file's `findings`.
- `UNMEASURED` goes in the run file's `unmeasured` as `{ "check", "reason" }`. The report
  prints it under its own heading, and it is never a pass.
- `PASS` and `N/A` are not rows. A `PASS` is still listed in `checks_executed`; an `N/A`
  is reported with its reason and left out of the denominator.

Beside its checks, every agent returns `checks_executed`: the id of every check that ran,
passes included (`/wp-audit` Step 6.8). The line format of the `/wp-audit` Step 6 dispatch
prompt carries the same fields under other labels: `Owner` is `ownership`, `Method` is `fix`,
`Fix: auto` is `auto_fixable: true`, `Root cause` is `root_cause`.

GEO's tables grade an ORA `required`-tier failure `ERROR`. The renderer knows three
severities, so a GEO `ERROR` is written `CRITICAL` in a finding.

One finding of each status:

```json
{
  "category": "security",
  "tier": 2,
  "checks_executed": ["SEC-001", "SEC-036"],
  "findings": [
    { "check": "SEC-036", "status": "FAIL", "severity": "CRITICAL", "ownership": "setting",
      "resource": "wp_options.siteurl", "message": "Development host stored in siteurl",
      "evidence": "$WP option get siteurl", "fix": "$WP option update siteurl <production URL>",
      "auto_fixable": true },
    { "check": "SEC-001", "status": "PASS" },
    { "check": "SEC-023", "status": "UNMEASURED", "reason": "needs production: no public URL confirmed" },
    { "check": "SEC-039", "status": "N/A", "reason": "no WooCommerce" }
  ]
}
```

### Auto-fixable

`auto_fixable: true` only when the fix cannot break the site: adding a missing attribute
(`alt`, `aria-label`, `loading`), appending a CSS rule, setting a wp-config constant,
installing or configuring a plugin through WP-CLI, adding a missing escaping wrapper, adding
a nonce check to a simple form. Restructuring a template, changing application logic,
removing code and design decisions are never auto-fixable.

### Check id prefixes

| Prefix | Domain |
|--------|--------|
| `SEC-NNN` | Security |
| `SEO-NNN` | SEO |
| `A11Y-NNN` | Accessibility |
| `PERF-NNN` | Performance |
| `WP-NNN` | Best Practices |
| `GEO-Dnn`, `GEO-Ann`, `GEO-Unn`, `GEO-Pnn` | GEO / AI-agent readiness, by ORA layer |
| `UX-NNN` | Usability |
| `A11Y-AXE-*`, `PERF-LH-*` | Evidence rows from the browser suite — measurements of an existing criterion, never criteria of their own |

### Deduplication

When several agents report one defect:

- **Security agent** owns vulnerability-class checks (XSS, SQLi, CSRF)
- **Practices agent** owns coding-standards checks (escaping for theme review compliance)
- **SEO agent** owns heading hierarchy for search ranking context
- **A11y agent** owns heading hierarchy for screen reader navigation context
- **The command** deduplicates identical `file:line` findings, keeping the highest severity

---

## Site type and local clones

Two properties of the project change which checks apply. `/wp-audit` Step 2.3 (*Site type
and local clone*) reads them once and every agent honours the result; this is the
methodology behind that step.

### Gate by site type, do not delete

A store (WooCommerce active) has surfaces a generic site does not: a cart, a checkout, an
account area, priced-per-currency markup, protected paid files. Checks written for those
surfaces are **`N/A` on a non-commerce site**, reported with the reason and excluded from
the denominator — never silently dropped, and never counted as failures. The inverse also
holds: a commerce check must not fire on a site with no WooCommerce, or the score punishes a
site for lacking a feature it never claimed. Adding commerce depth therefore leaves a
generic site's score unchanged, because every commerce check reads `N/A` on it.

A catalog store (`site.store_tier` = `catalog`, read from the `store` block by the same
step) has no cart, checkout or payment, so a check on one of those surfaces is
`N/A ("catalog: nothing purchasable")` there, excluded from the denominator, exactly as a
commerce check is on a site with no WooCommerce.

### A local clone is audited for production's posture

A project restored from a backup to run locally (`.wp-create.json` `project.source:
"restore"`, a `wordpress.url_origin`, or a non-public `wordpress.url` — see the same step
for the exact field paths and the host list) has been deliberately altered to work
in isolation. Those alterations — a dev host in the database, deactivated payment/cache/mail
plugins, `DISABLE_WP_CRON`, absent object-cache drop-ins, debug logging on, media uploaded
after the file backup was taken — are the price of the copy, not defects of the site. On a
clone they are **`N/A (local clone)`**, out of the denominator, and not printed as findings.
The catalog and the exact rule live in that step. The one test that keeps this
honest: *would this also be true on production?* If yes, it is a finding; if it exists only
because this is a copy, suppress it.

### Link and page sweeps against a site

Any check that requests many URLs of the audited site — broken links, a rendered-head
snapshot, a page walk — follows these steps. A local site shares one database and one web
server with every other project on the machine, and an uncached WordPress page is
expensive: an improvised crawler with 25 concurrent `curl -L` workers over a store's term
archives once held MariaDB at ~18 cores and load 18, slowing every site on the box.

1. **Resolve internal targets through WP-CLI or the database first.** Whether a post or term
   exists and is published is a query, not a page render.
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/scripts/resolve-link-targets.php` does it: a
   link counts as resolved only when the object is published and its own canonical URL has
   the link's path, so it may send a good link to HTTP but never marks a broken one resolved.
   Only what it cannot answer — drafts, query strings, redirects, external links, rewrite
   rules a plugin owns — needs a real request.
2. **Sample term archives: 20 per taxonomy**, unless the operator asked for a full sweep.
   Hundreds of author or category archives are one template; twenty of them say whether it
   works. The resolver tags each link it passes on with its taxonomy, and the sweep samples
   by that tag (falling back to the first path segment for untagged links).
3. **Sweep the rest with `bin/link-sweep.mjs`** — run it, never write a crawler. It needs
   node. It holds every limit for you: **At most 4 requests in flight**, whatever
   `--concurrency` asks for, never a pool sized to the machine; status only, no body (`HEAD`,
   or `curl -r 0-0` where a server refuses `HEAD`); the clone-origin host (the
   `wordpress.url_origin` host) never requested from a clone unless it was confirmed this
   run; a CDN bot challenge reported `UNMEASURED` instead of broken; and a wall-clock budget.

   ```bash
   # links.txt: one href per line, TAB, the page it was found on
   $WP eval-file ${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/scripts/resolve-link-targets.php \
     links.txt resolved.json > http.txt
   node ${CLAUDE_PLUGIN_ROOT}/bin/link-sweep.mjs --site "$SITE_URL" --urls http.txt \
     --clone-origin "$URL_ORIGIN" --budget 120 > sweep.json
   ```

   | Exit | Meaning |
   |---|---|
   | `0` | the sweep ran; its findings are in the JSON |
   | `2` | usage error — fix the arguments |
   | `4` | `--stop-on-block` stopped it at a block: mark the production host blocked (below) |

4. **Report what was not requested as `UNMEASURED`, with the count.** Links sampled out, over
   budget, challenged or clone-origin come back `unmeasured` with the reason; none of them is
   a pass. `resolved.json` lists what the database answered, with the pages carrying each
   link — those are resolved, not unmeasured.

This protects a local machine. A production host is paced by *Production sits behind a WAF*
below.

### Live checks target production, and the URL is confirmed

Response headers and paid-file reachability can only be judged against the running
production site. A local server answers them differently — it reads `.htaccess` a production
nginx ignores — so a live check run against the clone is a false result, not a lenient one.
These checks use `--host`, or ask the user for the production URL (defaulting to
`wordpress.url_origin`) and fire no external request until it is confirmed; with no public
URL they are `UNMEASURED`, never `PASS`.

### Production sits behind a WAF: same measurements, one request at a time

Production servers run fail2ban, CrowdSec and ModSecurity, and an audit must not trip them
unless the operator asks for it explicitly. Seven agents in parallel once sent up to 28
requests at once to one production host, plus Lighthouse and Playwright loads and a burst of
reconnaissance probes; leaky-bucket rules count requests per window, the host banned the
auditing IP within five minutes, and every live check of the run was lost (the header of
`bin/prod-gate.sh` has the full account).

The fix changes **the pace, never the measurement**. Every check still runs the same command
against the same host, with the same headers and user agents — Lighthouse, Playwright, the
suite, the GEO probes with AI user agents and `Accept: text/markdown`, the security probes.
Against a public host, run `bin/prod-gate.sh`; never reimplement it. It needs `flock` and
refuses to send unserialized without it.

1. **Send every request through the gate**, with the gate directory `/wp-audit` passes in the
   dispatch prompt. The directory is the shared lock: every agent of the run must use the same
   one, or each holds a lock of its own and production sees them all at once.

   ```bash
   WP_AUDIT_GATE_DIR=<gate dir> ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh [--delay 10] <host> -- <command> [args...]
   ```

   The gate runs one command at a time per host and waits 2 s between commands. Pass
   `--delay 10` before reconnaissance-shaped paths: readme, license, `?author=`, the users
   REST route, xmlrpc and login. A Lighthouse run or a Playwright launch is one gated
   command; browsers load a page's assets in parallel, as any visitor's would.
2. **Sweep at `--concurrency 1 --delay-ms 1000 --stop-on-block`**, with a `--budget` of at
   least one second per link plus the timeout, so the slower pace does not turn links into
   `budget exhausted`. The suite runs with one Playwright worker: `bin/audit-suite.sh` does
   this itself for a public URL.
3. **The first block ends all production traffic, with no retry.** The gate marks the host
   blocked itself on curl's refused or reset codes, and on two curl timeouts in a row. Mark it
   yourself on any of these:
   - a `429`
   - a `403` carrying a WAF signature (`mod_security`, `crowdsec`, `cf-mitigated`, a captcha)
   - `ERR_CONNECTION_REFUSED` in a browser
   - link-sweep exit `4`

   ```bash
   WP_AUDIT_GATE_DIR=<gate dir> ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh --mark-blocked <host> "<reason>"
   ```

4. **Read the gate's exit code:**

   | Exit | Meaning | Then |
   |---|---|---|
   | the command's own | the command ran | judge its output |
   | `4` | the host is marked blocked; nothing was sent | report the check `UNMEASURED: production blocked the audit`. Never retry — a retry against a ban extends the ban |
   | `5` | another agent held the host past `--wait` (300 s); nothing was sent | call again, at most twice more; after a third `5`, report the check `UNMEASURED: production gate busy` |
   | `1` | a usage error, or `flock` is missing | fix the call; without `flock`, nothing may be sent and the check is `UNMEASURED` |

**A local site keeps its own limits, unchanged.** `prod-gate.sh` passes a development host
straight through, and nothing above applies to it. The local rule is *Link and page sweeps
against a site*, above.

---

## Audit tiers

### Tier 1 — Code-only (always available)

File scanning via Read, Grep, Glob. No runtime environment required.

### Tier 2 — + WP-CLI runtime (when `.wp-create.json` exists)

Plugin management, option reading, database queries. Requires a working WordPress installation with WP-CLI access.

### Tier 3 — + Browser measurement (when a browser automation tool is available)

Lighthouse-style browser audits: Core Web Vitals, rendered-page checks, performance traces.
Use the browser tool the session has. With more than one, use Chrome DevTools MCP for a
Lighthouse run or a performance trace, Playwright MCP for everything else, and Claude in
Chrome only when neither is present. It adds measurement, never criteria: every threshold
Tier 3 measures against is recorded in this skill and in the audit agents, and a check a file
scan can answer runs at Tier 1 whether or not a browser is present.

---

## Performance budgets

| Resource | Budget |
|----------|--------|
| CSS compressed | <100KB |
| JS compressed | <300KB |
| Total page weight | <1.5MB |
| Images above-fold | <500KB |
| Fonts total | <100KB |

---

## Accessibility thresholds

| Requirement | Minimum |
|-------------|---------|
| Normal text contrast | 4.5:1 |
| Large text contrast (≥24px, or ≥18.66px bold — WCAG's 18pt / 14pt bold) | 3:1 |
| UI component contrast | 3:1 |
| Touch target size | Smaller than 24x24 CSS pixels fails (WCAG 2.2 AA 2.5.8), measured at desktop and mobile; 44x44 is AAA advice (INFO) |
| Minimum gray on white passing 4.5:1 | `#767676` |

---

## Core Web Vitals targets

| Metric | Good | Needs Work | Poor |
|--------|------|-----------|------|
| LCP | ≤2.5s | 2.5s–4s | >4s |
| INP | ≤200ms | 200ms–500ms | >500ms |
| CLS | ≤0.1 | 0.1–0.25 | >0.25 |

Read a Lighthouse number against [references/performance-lessons.md](references/performance-lessons.md)
before filing it: a simulated LCP on a development host, or one measured beside another
process, is not a regression.

---

## Agent interaction model

All plugin interaction via WP-CLI options/meta, never PHP APIs:

| Operation | Command |
|-----------|---------|
| Read plugin config | `$WP option get <option_name>` |
| Write plugin config | `$WP option update/patch` |
| Seed data | `$WP post meta update` |
| Complex operations | `$WP eval "php code"` |
| Install plugins | `$WP plugin install --activate` |
| Theme modifications | Direct file Edit/Write |
| wp-config changes | `$WP config set` |
