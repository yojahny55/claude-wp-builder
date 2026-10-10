# /wp-audit — Step 6

`commands/wp-audit.md` sends the run here at Step 6. Follow it in order; nothing in it is optional background.

## Contents

- What each agent is scoped to

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
- Quiet WP-CLI: <`${CLAUDE_PLUGIN_ROOT}/bin/wp-quiet.sh $WP`, or "not needed">
- Audit tier: <1|2|3>
- Browser measurement: <available|not available>
- Origin: <created|adopted>
- Editable code: <code_scope.editable, or the theme path when created>
- Read-only code: <code_scope.read_only, or "none" when created>
- Stack: <seo=… security=… fields=… multilingual=… builder=… cache=…, or "plugin defaults" when created>
- Site type (commerce): <site.commerce value — woocommerce|none>
- Store tier: <site.store_tier — catalog|store|full|unknown>
- Local clone: <yes|no>
- Clone-suppressed plugins: <clone_suppressed_plugins slugs, comma-separated, or "none">
- Parked drop-ins: <clone_parked_dropins files, comma-separated, or "none">
- Report-only: <yes|no>
- Measurement split: clone-safe checks run on the clone; production-only checks need the confirmed public URL (Step 2.3, "Clone-safe versus production-only measurement")

**One quiet wrapper for noisy sites.** When Step 2 or Step 3 saw a plugin print PHP notices or
deprecations into WP-CLI's stdout, pass `${CLAUDE_PLUGIN_ROOT}/bin/wp-quiet.sh $WP` as `Quiet
WP-CLI` and tell every agent to run `$WP` calls whose output it parses through it. It strips
the diagnostics from stdout, leaves stderr alone and keeps the exit code. An agent that builds
its own filter is writing the same thing nine times, differently. The wrapper is for the run:
it is never written into `.wp-create.json`.

**`Report-only: yes` means the audit writes nothing.** No agent deletes or sets a transient,
option, post or user, or activates or deactivates anything; it reads and measures. Where a read
would be stale (update transients), the agent reports the data's age, queries the source
directly, or reports `UNMEASURED`. A write found afterwards is a defect of the run, reported as
one.

**Clone-safe checks are measured, not skipped.** When `Local clone: yes`, the agents measure
every clone-safe check from the Step 2.3 table on the clone, with the browser when
`Browser measurement: available`; only production-only checks wait for the public URL.

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

Production host: <the public URL live checks use, or "none">. Gate dir: <scratch>/prod-gate.
Production runs fail2ban, CrowdSec and ModSecurity, and other audit agents are running beside
you. Run every command that reaches the production host through the gate, with exactly the
arguments you would have used otherwise:
  WP_AUDIT_GATE_DIR=<gate dir> ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh [--delay 10] <host> -- <command>
Use --delay 10 before readme, license, ?author=, the users REST route, xmlrpc or login.
Run sweeps against it with --concurrency 1 --delay-ms 1000 --stop-on-block and a --budget of at least one
second per link plus the timeout. Mark the host blocked on any of these:
  - a 429
  - a 403 carrying a WAF signature
  - ERR_CONNECTION_REFUSED in a browser
Use: prod-gate.sh --mark-blocked <host> "<reason>". If the gate exits 4, the host is blocked:
report that check UNMEASURED with the gate's reason, and never retry. If it exits 5,
another agent held the host. Nothing was sent, so call again, at most twice more; after a
third 5, report the check UNMEASURED: production gate busy. The local site is not gated.

Run all checks for your tier level. Output your findings as a structured report with the following format for each issue:

[<SEVERITY>] <CODE>: <message> (<file>:<line> if applicable)
  Resource: <the stable thing this is about — see the resource table in Step 7>
  Fix: <auto|manual>
  Owner: <code|setting|content|manual>
  Root cause: <optional short slug shared by every finding that one defect causes, e.g. display-errors>
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
Where CODE follows the pattern: SEC-NNN, SEO-NNN, A11Y-NNN, PERF-NNN, WP-NNN, GEO-Dnn/Axx/Uxx/Pxx, UX-NNN
```

Use these `subagent_type` values:
- `wp-audit-security` — security checks (file permissions, SQL injection, XSS, nonces, ABSPATH, wp-config hardening, AIOS configuration)
- `wp-audit-seo` — SEO checks (meta tags, schema markup, sitemap, robots.txt, Rank Math configuration, heading hierarchy, canonical URLs)
- `wp-audit-a11y` — accessibility checks (skip links, ARIA attributes, alt text, color contrast references, focus styles, semantic HTML, keyboard navigation)
- `wp-audit-performance` — performance checks (asset enqueuing, image optimization, caching headers, database queries, lazy loading, render-blocking resources)
- `wp-audit-practices` — best practices checks (ABSPATH guards, escaping, i18n, theme supports, coding standards, enqueue patterns, template hierarchy)
- `wp-audit-geo` — GEO/AI-agent readiness checks (ORA layers Discovery/Access/Usability/Payments, AI crawler allowlist, `llms.txt` and ARD catalog, rendered-head DOM checks, agent-skills index, is-agentic live scan)
- `wp-audit-ux` — usability checks (forms and data entry, navigation and task flow, links followed rather than inferred, hover and active states, rendered line length per breakpoint, logo and typography consistency across pages)

**Shard by surface when the read-only scope is large.** One agent per category cannot read a
parent theme plus two dozen plugins, and an agent that cannot narrows on its own and says so
only in a closing line. On an adopted site (Step 2.2), count `code_scope.read_only`: when it
holds more than 6 paths, or any path over ~5 MB of PHP/JS, dispatch each source-reading
category once per group instead of once per category:

| Group | Contents |
|---|---|
| editable | every `code_scope.editable` path |
| parent theme | the read-only theme path |
| large plugins | read-only plugins over ~5 MB (page builders, commerce, form suites) |
| mid-size plugins | ~500 KB to 5 MB, batched about 6 per agent |
| small plugins | under ~500 KB, batched about 12 per agent |

Every shard prompt names its own paths and says "your surface is exactly these paths; the
checks that are not about source files (rendered output, options, headers) run in the
`editable` shard only". Each shard returns its own `checks_executed`. Step 7 merges shards per
category: findings concatenate, `checks_executed` is the union, and Step 6.8's coverage is
computed on the union, so a check that no shard executed is reported as never run. Keep the
dispatch to at most 4 agents at a time. The rendered-surface categories (`seo`, `geo`,
`a11y` page checks, `usability`) are not sharded: their surface is the site, not a path list.

**`wp-audit-ux` is dispatched with the page list from Step 2.7, and its prompt says so.**
It is the only auditor whose scope is a set of URLs rather than the theme directory, and an
agent given no pages audits nothing while reporting cleanly.

**Error handling:** If an agent fails:
1. Note which agent failed and the error message
2. Continue with remaining agents (do not block the entire audit)
3. Mark the failed category in the report
4. Skip the failed category in the fix phase
