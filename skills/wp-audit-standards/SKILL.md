---
name: wp-audit-standards
description: Shared contract for every wp-audit-* agent — severity levels, report fields, check prefixes, N/A rules, link sweeps, pacing with bin/prod-gate.sh, Lighthouse traps. Use when writing, merging or scoring an audit finding, deciding if a check is N/A, or hitting a production host during /wp-audit. Not for a domain's own checks (wp-audit-seo-standards and siblings).
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
- [references/builder-elementor.md](references/builder-elementor.md) — where an Elementor fix
  belongs (widget data or child theme), the post-edit steps, widget false positives and the
  measurement rule. Read only when `stack.builder` is `elementor`.
- Check procedures moved out of two agents, each read on demand when the agent's index sends
  you there (the agents keep the check tables):
  - [references/perf-procedures-cache-and-render.md](references/perf-procedures-cache-and-render.md) —
    `wp-audit-performance`: multi-currency behind a page cache (PERF-065 to PERF-067) and the render
    path (PERF-047 to PERF-055, PERF-068, PERF-069, PERF-010, PERF-049 to PERF-053).
  - [references/perf-procedures-runtime.md](references/perf-procedures-runtime.md) —
    `wp-audit-performance`: page-cache drop-in, ICC profiles, Elementor (PERF-070, PERF-075 to PERF-077).
  - [references/perf-procedures-database.md](references/perf-procedures-database.md) —
    `wp-audit-performance`: database bloat and attribution (PERF-061 to PERF-064, PERF-071 to PERF-074).
  - [references/perf-fix-recipes.md](references/perf-fix-recipes.md) — `wp-audit-performance` Fix Phase
    boilerplate and per-finding fixes.
  - [references/sec-plugin-inventory.md](references/sec-plugin-inventory.md) — `wp-audit-security`:
    the plugin inventory SEC-041, SEC-042, SEC-043 share.
  - [references/sec-detection-details-advanced.md](references/sec-detection-details-advanced.md) —
    `wp-audit-security`: detection rules for SEC-043, SEC-044, SEC-045.
  - [references/sec-procedures-deploy-and-downloads.md](references/sec-procedures-deploy-and-downloads.md) —
    `wp-audit-security`: SEC-036 to SEC-039.
  - [references/sec-procedures-gateway-credentials.md](references/sec-procedures-gateway-credentials.md) —
    `wp-audit-security`: SEC-040.
  - [references/sec-procedures-mcp-endpoints.md](references/sec-procedures-mcp-endpoints.md) —
    `wp-audit-security`: SEC-046.
  - [references/sec-procedures-vulnerability-feed.md](references/sec-procedures-vulnerability-feed.md) —
    `wp-audit-security`: SEC-041, SEC-042.

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

**Aliases the aggregator accepts.** `bin/audit-report.mjs` (through `bin/lib/audit-schema.mjs`)
translates these, so a drifted key still renders; the left column is what to write.

| Canonical | Accepted instead |
|---|---|
| `check` | `code`, `id`, `check_id`, `check_code` |
| `ownership` | `owner`, `fix_owner` |
| `message` | `title`, `description`, `summary`, `problem` |
| `fix` (the text) | `method`, `remediation` |
| `auto_fixable` | `fix: auto` / `fix: true` (the dispatch line's `Fix: auto\|manual`) |
| `root_cause` | `rootCause` |
| `severity` | `ERROR`, `HIGH` (CRITICAL); `WARN`, `MEDIUM` (WARNING); `LOW`, `NOTE` (INFO); any case |

It also accepts three report shapes that agents drifted into in a real run:

- `not_applicable` and `unmeasured` written as a map keyed by check id,
  `{ "SEO-021": "no SEO plugin active" }`, read as the array form. Write the array form.
- A report with no `category` key takes it from its file name, `agents/wp-audit-<x>.json`.
  Write the key anyway: a shard file named another way has no other source.
- A scan note in `findings` (`check: "VENDOR"`, or a non-catalog id with `status: "INFO"`)
  is moved to the report's notes and never counted as a finding. A note about the scan goes
  in the top-level `notes` (or `vendor_notes`) array. A catalog id with `status: "INFO"`
  stays refused: that is a finding whose status was confused with its severity.

It refuses, with exit `1`, a finding that has no check id, an id that is not in any catalog, or
a check that is both a `FAIL` and a `PASS` (or listed in `passes`) for the same resource.
`bin/audit-coverage.mjs` reads the same reports, so `checks_executed` is the field it counts.

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

#### Unused and retired ids

These numbers were never assigned, or were retired. They are never reused: `checks_run`
history and ledger entries key by id, so a reused number would read old coverage as coverage
of a new rule. A new check takes the next number after its prefix's highest (UX: after UX-058, see
`skills/wp-audit-ux-standards/SKILL.md`). `A11Y-012`
appears in examples in the run references only as a sample id; it is not a live check.

- `SEC-015..019`
- `SEO-013..019`, `SEO-047`
- `PERF-006..009`, `PERF-014`, `PERF-024`, `PERF-032..034`, `PERF-050`
- `A11Y-009..019`, `A11Y-035..039`, `A11Y-045..049`, `A11Y-054..059`
- `WP-009`, `WP-035..039`, `WP-056..059`
- `UX-022`, `UX-023` — see `skills/wp-audit-ux-standards/SKILL.md`

### Deduplication

When several agents report one defect:

- **Security agent** owns vulnerability-class checks (XSS, SQLi, CSRF)
- **Practices agent** owns coding-standards checks (escaping for theme review compliance)
- **SEO agent** owns heading hierarchy for search ranking context
- **A11y agent** owns heading hierarchy for screen reader navigation context
- **The command** deduplicates identical `file:line` findings, keeping the highest severity

#### Same defect, one owner

Some defects sit in the catalog of more than one agent under different ids, so the `file:line`
pass cannot see them. Each has one owner; the others are duplicates.

| Defect | Owner | Duplicates | `root_cause` |
|---|---|---|---|
| PHP version below the floor (`>= 8.2`; 8.1 is out of security support) | SEC-026@2 | PERF-040@2, WP-042@2 | `php-floor` |
| XML-RPC enabled | SEC-022 | PERF-029@2 | `xmlrpc` |
| `WP_DEBUG` on | SEC-008@2 | WP-040 | `wp-debug` |
| Unescaped output | SEC-001 | WP-001 | `unescaped-output:<file>:<line>` |
| Dangerous functions (SEC-004 also covers `serialize`/`unserialize`) | SEC-004 | WP-031 | `dangerous-function:<file>:<line>` |
| Missing `wp_body_open` | WP-018 | A11Y-063 | `wp-body-open` |
| Images missing alt in templates | A11Y-001 | SEO-006 | `img-alt:<file>:<line>` |

The PHP floor is written here and in the SEC-026 row, nowhere else: the duplicate rows say
"Not below SEC-026's floor", so a `--performance` or `--best-practices` run reads the number
from this table.

SEO-031 (alt text counted in the media library, a database measurement) is a separate check,
not a duplicate of A11Y-001 or SEO-006.

**The merge is the renderer's root-cause fold, not a hand edit.** Owner and duplicates set the
same `root_cause` from the last column. Site-wide defects (PHP floor, XML-RPC, `WP_DEBUG`,
`wp_body_open`) use the bare slug and `resource: site`; per-location defects put the
`file:line` into the slug, so two different lines never fold together.
`bin/audit-report.mjs` then folds findings that share a `root_cause` into one, which lists the
others under `also_affects`; totals count the defect once, whichever id came first on equal
severity. A duplicate whose owner did not fail on that resource (the owner passed, did not
run, or ran on another scope) has nothing to fold into and stays its own finding, at the
owner's severity: the detectors differ, so a defect only the duplicate sees is still a
measured defect. Duplicates keep their rows and stay in `checks_executed` as normal, so a
single-category audit still measures the defect and coverage does not change. An owner and
its duplicates carry the same severity.

**One defect, one fix, one `root_cause`.** A slug names a defect that a single fix
removes, never a place. Two defects with different fixes in the same function keep
different slugs, even on adjacent lines: a handler that concatenates a request value into
SQL and also skips the nonce check is `sqli:<file>:<line>` (fixed with `$wpdb->prepare()`)
and `missing-nonce:<file>:<line>` (fixed with `check_admin_referer()`). Sharing one slug
would fold the second defect under the first, and fixing the SQL would look like it closed
both. Share a slug only when the duplicates in the table above, or several findings of one
check, disappear with the same edit.

**A folded id is still failing.** The report's comparison counts every id under
`also_affects` as present, and the ledger does the same: a duplicate's open entry whose
finding was folded into another stays `still_failing`, never `resolved` (see
`skills/wp-audit-run/references/ledger.md`).

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
Against a public host, run `bin/prod-gate.sh`; never reimplement it. It serializes with `flock`, or with a
symlink-to-pid lock where `flock` is missing (macOS), and never sends unserialized.

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
   | the command's own | the command ran | judge its output. A wrapped command can itself exit `4` or `5`: read stderr, the gate prints `BLOCKED:` or `busy for more than` before its own |
   | `4` | the host is marked blocked; nothing was sent | report the check `UNMEASURED: production blocked the audit`. Never retry — a retry against a ban extends the ban |
   | `5` | another agent held the host past `--wait` (300 s); nothing was sent | call again, at most twice more; after a third `5`, report the check `UNMEASURED: production gate busy` |
   | `1` | a usage error, or the gate could not create its lock in the state directory (stderr: `cannot create lock`); nothing was sent | fix the call or the gate directory |

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
