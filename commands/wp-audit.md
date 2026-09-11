---
description: Comprehensive audit — security, SEO, accessibility, performance, best practices, GEO/AI-agent readiness
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "[--security] [--seo] [--a11y] [--performance] [--best-practices] [--geo] [--all] [--report-only] [--security-level basic|recommended|maximum]"
---

# WP Audit — Comprehensive Site Audit

Run a comprehensive audit across security, SEO, accessibility, performance, best practices, and GEO/AI-agent readiness. Reports issues with severity levels and offers to auto-fix what it can. Dispatches specialized audit agents and optionally configures Rank Math SEO and All-in-One WP Security.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
- **Category flags:** `--security`, `--seo`, `--a11y`, `--performance`, `--best-practices`, `--geo`
- **`--all` flag** (default if no category flags provided)
- **`--report-only` flag** (skip fix phase)
- **`--security-level basic|recommended|maximum`** (default: `recommended`, ignored if `--report-only`)

If `--all` or no category flags are present: enable all 6 categories (security, seo, a11y, performance, best-practices, geo).

## Step 2: Read Project Context

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

If `--geo` is selected and `.wp-create.json` exists, also note its `wordpress.url` — the live scan in Step 9 needs a reachable host.

## Step 3: Detect Environment & Tier

Determine the audit tier:

**Tier 1 (always):** Code-only checks via Read, Grep, Glob.

**Tier 2 (if `.wp-create.json` exists):** Read `.wp-create.json` to get `$WP` wrapper. Set `$WP` to the value of `wp_cli.wrapper`. Enables WP-CLI runtime checks.

**Tier 3 (if web-quality-skills installed):** Check these paths in order:
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

**`--geo` needs Tier 2.** The GEO auditor's live HTTP checks and the `bin/geo-scan.sh` verifier in Step 9 require `.wp-create.json` (for `$WP` and a reachable site URL). Without Tier 2, `wp-audit-geo` still runs its code-only checks and reports the runtime GEO codes `N/A`, and the live scan is skipped.

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

```
Audit the WordPress theme at <theme_path>.

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

```
=== WP Audit Report ===
Tier: <tier description>
Categories: <comma-separated selected categories>

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
  Live scan: <score|unavailable — skipped: <reason>>

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

`<home-host>` is `wordpress.url` from `.wp-create.json` (or `$WP option get home`). Exit codes: `0` = report returned, `2` = skipped (no network or tool), `1` = error. Exit `2` is a clean skip — neither a success nor a failure: report the live score as unavailable and continue. On exit `1`, record the error and continue. Only a returned report yields a score; map its failed ORA check ids back to GEO codes using the `wp-audit-geo-standards` skill. Advisory and off-site findings (GEO-D05 through GEO-D08, GEO-U10, GEO-P01 through GEO-P05) are left unfixed.

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
    "issues_found": N,
    "issues_fixed": M,
    "web_quality_skills_available": true
  }
}
```

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
