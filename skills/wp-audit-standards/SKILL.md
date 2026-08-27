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

## Performance — Hard-won Lessons (Tier 3 / Lighthouse)

Interpretation traps and fixes that actually move production bytes. Consult before filing or fixing a `PERF-xxx` finding from a Lighthouse run.

### Read *observed* metrics before chasing a bad *simulated* score

Lighthouse's default (`throttlingMethod: "simulate"`) reports **Lantern-simulated** LCP/FCP/TTI on a modeled slow-4G + 4× CPU. On a **dev server** this is dominated by local TTFB + the throttle model and can read 6–7 s while the page is actually instant. Before treating a high LCP as real, open the full JSON and compare:

- `audits.metrics.details.items[0].largestContentfulPaint` (simulated) **vs** `...observedLargestContentfulPaint` (real paint).
- If observed is ~200–900 ms and simulated is multi-second, the number is a **simulation/dev-server artifact** — the score barely moves regardless of theme changes, and production (with page cache + real CDN/TTFB) differs. Say so in the finding instead of burning effort chasing it. **Real byte reductions (WebP, right-sizing) still help production** and still shrink the *LCP resource*, so do those — just set score expectations.
- `image-delivery-insight`, `render-blocking-insight`, `lcp-discovery-insight` etc. are **weight-0** in the Performance score (informative). Only the 5 metric audits (FCP/LCP/TBT/CLS/SI) carry weight. Fixing a weight-0 insight is a production win, not a score win — label it accordingly.

### WebP: `image_editor_output_format` only covers NEW, attachment-pipeline images

`add_filter('image_editor_output_format', ...)` converts uploads to WebP **only on new uploads**, and **only images that flow through WP's attachment functions** (`wp_get_attachment_image`, `the_post_thumbnail`). Themes that print **raw SCF/ACF field URLs** (`echo $field['url']`) or CSS `background-image: url(<field>)` bypass it entirely, so existing hero/about/neighborhood/banner images stay JPEG/PNG.

To serve WebP for **existing + SCF-driven** images without touching every template:

1. Pre-generate `.webp` siblings for existing uploads (one-time): `find uploads -iname '*.jpg' -o -iname '*.png'` → `magick "$f" -quality 82 "${f%.*}.webp"` (hero/LCP images can go lower, ~q68, since they sit behind scrims or are video-replaced).
2. Add a front-end output-buffer that rewrites finished HTML — covers `src`, `srcset`, and inline `background-image` in one pass:

```php
add_action( 'template_redirect', function () {
    if ( is_admin() || is_feed() || is_robots() ) return;
    $u = wp_get_upload_dir(); $base = $u['baseurl']; $dir = $u['basedir'];
    ob_start( function ( $html ) use ( $base, $dir ) {
        $pat = '#' . preg_quote( $base, '#' ) . '/[^"\'\)\s]+?\.(?:jpe?g|png)#i';
        return preg_replace_callback( $pat, function ( $m ) use ( $base, $dir ) {
            $webp = preg_replace( '/\.(?:jpe?g|png)$/i', '.webp', $m[0] );
            return file_exists( $dir . substr( $webp, strlen( $base ) ) ) ? $webp : $m[0];
        }, $html );
    } );
} );
```

`template_redirect` is front-end-only, and with a page cache (WP Super Cache) the buffer runs once per cache build. WebP is universally supported by target browsers — matching the theme's existing unconditional `image_editor_output_format` policy — so no `Accept`-header branching is needed.

### Right-size — never print `$field['url']` for a fixed slot

Lighthouse "responsive-size" waste = serving a 2200px original in a 400px slot. Raw SCF field URLs (`$image['url']`) always emit the **full original**. Use the attachment ID so the browser gets a `srcset`:

```php
echo wp_get_attachment_image( (int) $image['id'], 'large', false, array(
    'class' => 'about__bg', 'alt' => $heading, 'loading' => 'lazy',
    'sizes' => '(max-width: 899px) 100vw, 136vw', // match the real CSS display width
) );
```

Pick `sizes` from the element's actual rendered width (full-bleed → `100vw`; a 136%-wide bg → `136vw`; a 136px logo → `136px`). This composes with the WebP buffer above (the srcset `.jpg` URLs are rewritten to `.webp`).

### Hero LCP pattern (poster-first, video deferred)

Make the LCP element a **small poster image**, not the video: `<img fetchpriority="high" width/height>` + a `<link rel="preload" as="image">` for it in `wp_head`; lazy-load the background `<video>` via JS on **desktop only** (`min-width:1024px`), after the poster paints (`requestIdleCallback`), and **never** on mobile / `navigator.connection.saveData`. Preload the poster's WebP so the preload and the rendered `src` match (else the preload is wasted).

### Render-blocking CSS

Dequeue the near-empty theme `style.css` on the front end (it usually carries only the WP header comment; runtime styles live in the compiled bundle). Async-load below-the-fold plugin CSS (e.g. Contact Form 7) via `style_loader_tag` → `media='print' onload="this.media='all'"`.

### AIOS × Lighthouse gotcha (Tier 2 ↔ Tier 3 interaction)

If the security agent sets AIOS `aiowps_disallow_unauthorized_rest_requests = 1`, it returns **403** on CF7's REST endpoints (`/wp-json/contact-form-7/v1/...`). Lighthouse then **hangs up to 45 s** on those pending requests and logs console errors → Best-Practices drops (often 100 → 96) and metrics inflate. If a CF7 form is present, leave that AIOS setting off (or whitelist the CF7 REST namespace). Symptom in the JSON: `errors-in-console` / pending `Fetch` requests to `contact-form-7` with `statusCode: 403`.

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
