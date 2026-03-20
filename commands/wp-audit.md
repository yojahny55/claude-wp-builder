---
description: Comprehensive audit — security, SEO, accessibility, performance, best practices
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "[--security] [--seo] [--a11y] [--performance] [--best-practices] [--all] [--report-only] [--security-level basic|recommended|maximum]"
---

# WP Audit — Comprehensive Site Audit

Run a comprehensive audit across security, SEO, accessibility, performance, and best practices. Reports issues with severity levels and offers to auto-fix what it can. Dispatches specialized audit agents and optionally configures Rank Math SEO and All-in-One WP Security.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
- **Category flags:** `--security`, `--seo`, `--a11y`, `--performance`, `--best-practices`
- **`--all` flag** (default if no category flags provided)
- **`--report-only` flag** (skip fix phase)
- **`--security-level basic|recommended|maximum`** (default: `recommended`, ignored if `--report-only`)

If `--all` or no category flags are present: enable all 5 categories (security, seo, a11y, performance, best-practices).

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

**Dispatch order:** security → seo → a11y → performance → practices

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
Where CODE follows the pattern: SEC-NNN, SEO-NNN, A11Y-NNN, PERF-NNN, BP-NNN
```

Use these `subagent_type` values:
- `wp-audit-security` — security checks (file permissions, SQL injection, XSS, nonces, ABSPATH, wp-config hardening, AIOS configuration)
- `wp-audit-seo` — SEO checks (meta tags, schema markup, sitemap, robots.txt, Rank Math configuration, heading hierarchy, canonical URLs)
- `wp-audit-a11y` — accessibility checks (skip links, ARIA attributes, alt text, color contrast references, focus styles, semantic HTML, keyboard navigation)
- `wp-audit-performance` — performance checks (asset enqueuing, image optimization, caching headers, database queries, lazy loading, render-blocking resources)
- `wp-audit-practices` — best practices checks (ABSPATH guards, escaping, i18n, theme supports, coding standards, enqueue patterns, template hierarchy)

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
    "categories_run": ["security", "seo", "a11y", "performance", "best-practices"],
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
