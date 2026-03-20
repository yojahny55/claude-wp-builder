---
name: wp-audit-standards
description: Audit criteria, severity definitions, report JSON schema, and quality thresholds for wp-audit agents
user-invocable: false
---

# WP Audit Standards

This skill defines the audit criteria, severity levels, report format, and quality thresholds used by all wp-audit agents.

---

## Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| **CRITICAL** | Security vulnerability, complete accessibility failure, broken core functionality | Fix immediately |
| **WARNING** | Best-practice violation, degraded UX, performance issue | Fix before delivery |
| **INFO** | Optimization opportunity, minor improvement | Fix when convenient |

---

## Report JSON Schema

All audit agents MUST output findings in this format:

```json
{
  "category": "security|seo|a11y|performance|best-practices",
  "tier": 1,
  "issues": [
    {
      "severity": "critical|warning|info",
      "code": "SEC-001",
      "message": "Human-readable description",
      "file": "path/to/file.php",
      "line": 42,
      "auto_fixable": true,
      "fix_method": "Description of how to fix"
    }
  ],
  "summary": {
    "total": 0,
    "critical": 0,
    "warning": 0,
    "info": 0,
    "auto_fixable": 0
  }
}
```

### Field Requirements

- `category` — one of: `security`, `seo`, `a11y`, `performance`, `best-practices`
- `tier` — integer 1–3 indicating which audit tier produced the finding
- `issues` — array of issue objects (may be empty)
- `severity` — one of: `critical`, `warning`, `info`
- `code` — prefixed issue code (see Issue Code Prefixes below)
- `message` — human-readable description of the problem
- `file` — relative path to the affected file
- `line` — line number (0 if not applicable)
- `auto_fixable` — boolean indicating whether the agent can safely fix this
- `fix_method` — description of the fix approach
- `summary` — counts aggregated from the issues array

---

## Issue Code Prefixes

| Prefix | Domain |
|--------|--------|
| `SEC-xxx` | Security |
| `SEO-xxx` | SEO |
| `A11Y-xxx` | Accessibility |
| `PERF-xxx` | Performance |
| `WP-xxx` | Best Practices |

---

## Audit Tiers

### Tier 1 — Code-only (always available)

File scanning via Read, Grep, Glob. No runtime environment required.

### Tier 2 — + WP-CLI runtime (when `.wp-create.json` exists)

Plugin management, option reading, database queries. Requires a working WordPress installation with WP-CLI access.

### Tier 3 — + External skills (when web-quality-skills installed)

Lighthouse-style browser audits. Requires the web-quality-skills package for browser-based testing.

---

## Performance Budgets

| Resource | Budget |
|----------|--------|
| CSS compressed | <100KB |
| JS compressed | <300KB |
| Total page weight | <1.5MB |
| Images above-fold | <500KB |
| Fonts total | <100KB |

---

## Accessibility Thresholds

| Requirement | Minimum |
|-------------|---------|
| Normal text contrast | 4.5:1 |
| Large text contrast (>=18px or >=14px bold) | 3:1 |
| UI component contrast | 3:1 |
| Touch target size | 44x44 CSS pixels |
| Minimum gray on white passing 4.5:1 | `#767676` |

---

## Core Web Vitals Targets

| Metric | Good | Needs Work | Poor |
|--------|------|-----------|------|
| LCP | ≤2.5s | 2.5s–4s | >4s |
| INP | ≤200ms | 200ms–500ms | >500ms |
| CLS | ≤0.1 | 0.1–0.25 | >0.25 |

---

## Auto-Fix Classification

### Auto-fixable

Agent can safely fix without risk of breaking the site:

- Add missing attributes (e.g., `alt`, `aria-label`, `loading`)
- Append CSS rules
- Set wp-config constants
- Install/configure plugins via WP-CLI
- Add missing escaping wrappers
- Add missing nonce checks to simple forms

### Manual-only

Requires human judgment:

- Restructuring templates
- Changing application logic
- Removing code
- Design decisions
- Complex refactoring

---

## Deduplication Rules

When multiple agents find the same issue:

- **Security agent** owns vulnerability-class checks (XSS, SQLi, CSRF)
- **Practices agent** owns coding-standards checks (escaping for theme review compliance)
- **SEO agent** owns heading hierarchy for search ranking context
- **A11y agent** owns heading hierarchy for screen reader navigation context
- **Command** deduplicates identical file:line findings, keeping the highest severity

---

## Agent Interaction Model

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
