# Claude WP Builder — Design Specification

**Date:** 2026-03-15
**Status:** Approved
**Package Type:** Claude Code Plugin
**Install Path:** `/var/www/html/others/kairo/claude-wp-builder`

---

## 1. Overview

A Claude Code plugin that encodes a complete WordPress site-building methodology into reusable skills, commands, agents, and a starter theme. The workflow follows a proven pattern: create a demo HTML mockup for client approval, then build a custom WordPress theme section-by-section using ACF/SCF for all editable content, with built-in multilingual support.

### Goals

- Eliminate repetitive prompting by encoding the methodology into commands and skills
- Ensure consistent quality through specialized agents and best-practice skills
- Support N languages with EN/ES as the optimized default
- Produce legacy WordPress themes (no blocks/FSE) with no build tools
- Standardize on CSS custom properties + BEM + vanilla CSS

---

## 2. Plugin Structure

```
claude-wp-builder/
  .claude-plugin/
    plugin.json                    # Plugin manifest
  skills/
    wp-theme-standards/SKILL.md    # WP legacy theme best practices
    wp-bilingual/SKILL.md          # i18n _suffix methodology
    wp-css-system/SKILL.md         # CSS design system standards
    wp-demo/SKILL.md               # Demo creation methodology
    wp-responsive/SKILL.md         # Responsive design patterns
  agents/
    wp-template.md                 # PHP/WP template specialist
    wp-css.md                      # CSS custom properties + BEM specialist
    wp-acf.md                      # ACF/SCF field architect
  commands/
    wp-init.md                     # Scaffold new project
    wp-demo.md                     # Create demo HTML
    wp-header.md                   # Build header + nav
    wp-footer.md                   # Build footer
    wp-section.md                  # One-shot section builder
    wp-page.md                     # Page template generator
    wp-settings.md                 # Extend settings page
    wp-responsive-check.md         # Responsive validation
    wp-finalize.md                 # Pre-delivery checklist
  starter-theme/
    __starter__/                   # Boilerplate theme (see Section 7)
```

---

## 3. Commands

### 3.1 `/wp-init` — Project Scaffolding

**Inputs (prompted interactively):**
- Project name (e.g., "Acme Corp")
- Theme slug (e.g., "acme")
- Primary language (default: "en")
- Secondary language(s) (default: "es", supports multiple)
- Client industry / type of company
- Brief project description

**Actions:**
1. Copy `starter-theme/__starter__/` to target `wp-content/themes/<slug>/`
2. Replace all placeholders:
   - `__starter__` → theme slug (function prefix)
   - `__STARTER__` → theme slug uppercase
   - `__STARTER_NAME__` → project name
3. Configure i18n.php with the specified languages
4. Generate `.claude/CLAUDE.md` at project root with project context
5. Activate theme if WordPress is available (via WP-CLI)

**Output:** Working, installable WP theme with i18n layer, settings page, and CSS foundation.

### 3.2 `/wp-demo` — Demo HTML Creation

**Inputs:**
- Client brief (text description)
- Reference screenshots/URLs (optional)
- Section list (what sections the site needs)

**Actions:**
1. Invoke `frontend-design` and `ui-ux-pro-max` skills (external dependencies — must be installed separately as Claude Code plugins/skills)
2. Use `wp-css-system` skill for CSS custom properties + BEM
3. Use `wp-responsive` skill for mobile-first responsive design
4. Generate `demo/index.html` with all sections clearly separated by comments
5. Additional pages as needed (e.g., `demo/pricing.html`)

**Output:** Single-file responsive demo HTML for client review. Iterate until approved.

### 3.3 `/wp-header` — Header/Navigation Builder

**Inputs:**
- Screenshot from demo
- Demo HTML file reference

**Actions:**
1. Orchestrate `wp-template` and `wp-css` agents
2. Generate `header.php` with responsive nav, logo from settings, language switcher
3. Register WordPress menus via `register_nav_menus()`
4. Create `inc/nav-walker.php` if custom markup is needed
5. Bilingual menu support: register per-language menu locations following the pattern `<location>-<lang>` (e.g., `primary-en`, `primary-es`, `mobile-en`, `mobile-es`). Menu rendering selects the appropriate location based on `prefix_get_current_lang()`.

**Output:** Working header tied to WP menu system.

### 3.4 `/wp-footer` — Footer Builder

**Inputs:**
- Screenshot from demo
- Demo HTML file reference

**Actions:**
1. Orchestrate `wp-template` and `wp-css` agents
2. Generate `footer.php` pulling from settings (logo, copyright, social links, contact info, legal links)
3. Bilingual support via `starter_get_field()`

**Output:** Working footer consuming settings page fields.

### 3.5 `/wp-section <section-name>` — One-Shot Section Builder

**Inputs:**
- Section name (e.g., "hero", "services", "values", "contact")
- Screenshot from demo
- Demo HTML file reference

**Actions (3 agents orchestrated in parallel):**
1. `wp-acf` agent → generates `fields/<section-name>.php` with bilingual fields
2. `wp-template` agent → generates `template-parts/section-<name>.php` consuming those fields
3. `wp-css` agent → generates section CSS appended to `styles.css`

**Field naming convention (enables parallel execution):**
Both `wp-acf` and `wp-template` agents follow a strict naming convention so they produce compatible output independently:
- Field names: `<section>_<element>` (e.g., `hero_title`, `hero_description`, `hero_image`)
- Repeater names: `<section>_<plural>` (e.g., `services_cards`, `values_items`)
- Repeater subfields: `<element>` without section prefix (e.g., `title`, `description`, `icon`)
- Field keys: `field_<section>_<element>` (e.g., `field_hero_title`)
- Group keys: `group_<section>` (e.g., `group_hero`)
- Bilingual variants: append `_<lang>` suffix (e.g., `hero_title_es`)

**Post-generation wiring:**
- The `fields/` auto-loader in `functions.php` picks up the new field file automatically
- Adds `get_template_part('template-parts/section', '<name>')` call to the appropriate page template

**Output:** Complete section — fields, template, CSS — ready to use.

### 3.6 `/wp-page <page-type>` — Page Template Generator

**Page types:**
- `blog` — `archive.php`, `single.php`, post card component (`template-parts/journal/`), category/tag support, pagination
- `generic` — `page-generic.php` for basic content pages
- `legal` — Privacy policy + terms & conditions templates with ACF fields
- `404` — Custom 404 page
- `custom <name>` — Custom page template (e.g., `page-pricing.php`)

**Inputs:**
- Page type
- Screenshot from demo (if applicable)

**Actions:**
- Generates template file(s)
- Creates ACF fields in `fields/` if needed
- Generates CSS
- Wires into theme

### 3.7 `/wp-settings` — Extend Settings Page

**Inputs:**
- Additional settings to add beyond the defaults

**Actions:**
- Updates `fields/settings.php` with new tabs/fields
- Automatically creates bilingual variants for each new field

### 3.8 `/wp-responsive-check` — Responsive Validation

**Inputs:**
- URL or local HTML file path

**Mechanism:** Requires browser automation tooling. Options (in priority order):
1. Playwright MCP server (if available) — preferred
2. Puppeteer via Bash — `npx puppeteer screenshot --viewport=<width>x<height> <url>`
3. Manual fallback — prompt user to provide screenshots at each viewport

**Actions:**
- Takes screenshots at 5 viewports: 375px, 576px, 768px, 1024px, 1440px
- Checks for: horizontal overflow, text truncation, overlapping elements, touch target sizes, image scaling, nav behavior, font readability
- Can run against the demo OR the live WP theme

**Output:** Visual report with issues flagged per breakpoint.

### 3.9 `/wp-finalize` — Pre-Delivery Checklist

**Inputs:** None

**Actions validates:**
- All sections have ACF fields defined
- All output properly escaped (`esc_html`, `esc_url`, `esc_attr`)
- Bilingual coverage (all fields have language variants)
- Responsive breakpoints for all sections
- Menu registration exists
- 404 page exists
- Blog templates exist (if applicable)
- Theme `style.css` headers are correct
- Runs `/wp-responsive-check` automatically
- SCF plugin dependency check

**Output:** Report — ready to deliver or list of issues.

---

## 4. Agents

### 4.1 `wp-template` — PHP/WordPress Template Specialist

**Tools:** Read, Write, Edit, Grep, Glob
**Model:** Inherits from parent

**Expertise:**
- WordPress template hierarchy
- `get_template_part()` and template tags
- Proper escaping: `esc_html()`, `esc_url()`, `esc_attr()`
- WP loops, `WP_Query`, pagination
- Custom nav walkers
- Conditional tags (`is_front_page()`, `is_single()`, etc.)

**Rules:**
- Always use the project's `_get_field()` helpers, never raw `get_field()`
- Fallback pattern: `$value = prefix_get_field('field') ?: 'Default';`
- Repeaters via `prefix_get_repeater()` with translatable subfield arrays
- All output must be escaped
- No inline styles or scripts

### 4.2 `wp-css` — CSS Design System Specialist

**Tools:** Read, Write, Edit, Grep, Glob
**Model:** Inherits from parent

**Expertise:**
- CSS custom properties (variables)
- BEM naming methodology
- Mobile-first responsive design
- No build tools, no frameworks, vanilla CSS only

**Rules:**
- Maintain design system variables (colors, spacing, typography, shadows, breakpoints)
- Each section gets a clearly commented block in `styles.css`, delimited by `/* ============ Section: <Name> ============ */`
- Page-specific CSS files are allowed when a page has substantial unique styles (e.g., `software.css`), conditionally enqueued via `is_page_template()`
- Follow the demo's visual design exactly
- Mobile-first: base styles for mobile, `min-width` media queries for larger
- Use custom properties for all values that belong to the design system

### 4.3 `wp-acf` — ACF/SCF Field Architect

**Tools:** Read, Write, Edit, Grep, Glob
**Model:** Inherits from parent

**Expertise:**
- `acf_add_local_field_group()` API
- Field types: text, textarea, image, repeater, group, select, page_link, url, wysiwyg, true_false, number, color_picker
- Tab organization within field groups
- Conditional logic between fields

**Rules:**
- Automatically create bilingual variants (primary field + `_suffix` for each secondary language)
- One file per section in `fields/`
- Instructions on secondary language fields: "Leave empty to use [primary language] version"
- Settings fields use `'option'` as post ID
- Use tabs to organize related fields
- Field keys must be unique and follow pattern: `field_<section>_<fieldname>`
- Group keys follow pattern: `group_<section>`

---

## 5. Skills

### 5.1 `wp-theme-standards` — WordPress Legacy Theme Best Practices

**Invocation:** Auto-invoked when any `wp-*` command runs
**user-invocable:** false

**Covers:**
- Proper enqueueing: `wp_enqueue_style()` / `wp_enqueue_script()`
- Cache busting with `filemtime()`
- Theme supports: `add_theme_support('title-tag')`, `post-thumbnails`, `custom-logo`, `html5`
- Proper hooks: `wp_head`, `wp_footer`, `after_setup_theme`, `init`
- Security: nonce verification, `sanitize_*()` on input, `esc_*()` on output
- No `query_posts()` — use `WP_Query`
- No blocks/FSE — legacy template approach
- No inline styles/scripts — everything enqueued
- Required files: `style.css` with theme headers, `index.php`, `screenshot.png`
- SCF/ACF as required plugin dependency
- SVG upload support (with sanitization)
- Custom body classes via `body_class` filter
- Font preconnect hints via `wp_head`
- LCP image preloading for hero sections
- Schema.org structured data (recommended, project-specific)
- SEO meta descriptions (recommended, project-specific)
- `wp_localize_script()` for passing PHP data to JavaScript
- Page-specific asset enqueueing via `is_page_template()` conditionals

### 5.2 `wp-bilingual` — i18n Methodology

**Invocation:** Auto-invoked when generating fields or templates
**user-invocable:** false

**Covers:**
- The `_suffix` pattern: primary language fields have no suffix, secondary languages get `_es`, `_fr`, etc.
- Helper functions: `prefix_get_field()`, `prefix_get_repeater()`, `prefix_get_sub_field()`, `prefix_t()` (get translated string), `prefix_e()` (echo translated string), `prefix_is_lang($lang)`, `prefix_get_current_lang()`
- Language detection priority: URL param → cookie → browser header → default
- Static string translation array for UI elements
- Language switcher URL generation (preserves other query params)
- Cookie persistence (365 days)
- Settings page: one tab per language for translations
- Supports N languages, optimized for EN/ES

### 5.3 `wp-css-system` — CSS Design System Standards

**Invocation:** Auto-invoked when generating CSS
**user-invocable:** false

**Covers:**
- Custom property naming: `--color-primary`, `--spacing-md`, `--font-size-lg`, `--shadow-sm`, `--radius-md`, `--transition-base`
- Color palette structure: primary, secondary, tertiary, neutrals (50-900)
- Spacing scale: xs (0.25rem) through 3xl (4rem)
- Typography scale: xs through 6xl
- BEM naming: `.block__element--modifier`
- CSS reset / normalize baseline
- No frameworks, no preprocessors, no build step
- Consistent with demo and theme

### 5.4 `wp-demo` — Demo Creation Methodology

**Invocation:** Auto-invoked by `/wp-demo` command
**user-invocable:** false

**Covers:**
- Single-file HTML structure with embedded CSS
- Sections separated by clear HTML comments (`<!-- SECTION: Hero -->`)
- Use `frontend-design` and `ui-ux-pro-max` skills for design quality
- Responsive: must work on all viewports
- Accessible: semantic HTML, ARIA where needed, sufficient contrast
- Each section should map 1:1 to a future `/wp-section` call
- Design system variables defined in `:root` (carried to theme later)

### 5.5 `wp-responsive` — Responsive Design Patterns

**Invocation:** Auto-invoked when generating CSS, templates, header, footer, sections
**user-invocable:** false

**Covers:**
- Mobile-first breakpoint system:
  - `--bp-sm: 576px`
  - `--bp-md: 768px`
  - `--bp-lg: 1024px`
  - `--bp-xl: 1200px`
  - `--bp-2xl: 1440px`
- Required patterns: hamburger nav, stacked grids on mobile, fluid typography (`clamp()`), responsive images (`srcset`, `sizes`, `<picture>`), touch-friendly targets (min 44px)
- Every section MUST define styles for all breakpoints
- No horizontal scroll at any viewport
- Image handling: proper `srcset` for resolution switching, `<picture>` for art direction
- Container max-widths per breakpoint

---

## 6. Workflow

The full lifecycle of a project:

```
Step 1: /wp-init
   └─ Interactive prompts → copy starter → replace placeholders → .claude/CLAUDE.md

Step 2: /wp-demo
   └─ Brief + references → frontend-design + ui-ux-pro-max → demo/index.html
   └─ Client reviews → iterate until approved

Step 3: /wp-header
   └─ Screenshot + demo ref → wp-template + wp-css agents → header.php, nav-walker

Step 4: /wp-footer
   └─ Screenshot + demo ref → wp-template + wp-css agents → footer.php

Step 5: /wp-section <name> (repeat per section)
   └─ Screenshot + demo ref → wp-acf + wp-template + wp-css agents in parallel
   └─ Output: fields/<name>.php + template-parts/section-<name>.php + CSS

Step 6: /wp-page <type> (as needed)
   └─ blog, legal, 404, generic, custom → templates + fields + CSS

Step 7: /wp-settings (if needed)
   └─ Add project-specific settings beyond defaults

Step 8: /wp-responsive-check
   └─ Screenshots at 5 viewports → issue report

Step 9: /wp-finalize
   └─ Full validation → ready or issues list
```

---

## 7. Starter Theme

The `starter-theme/__starter__/` directory contains the boilerplate that `/wp-init` copies and customizes.

### File Structure

```
__starter__/
  style.css                        # Theme headers: __STARTER_NAME__, version, description
  functions.php                    # Enqueues, includes, field auto-loader, SCF dependency check
  header.php                       # Minimal shell (replaced by /wp-header)
  footer.php                       # Minimal shell (replaced by /wp-footer)
  front-page.php                   # Empty, sections added by /wp-section
  page.php                         # Default page template
  index.php                        # Required WP fallback
  screenshot.png                   # Placeholder
  inc/
    theme-setup.php                # register_nav_menus (per-language: primary-en, primary-es, etc.),
                                   #   add_theme_support, image sizes, SVG upload, body classes,
                                   #   font preconnect, LCP preload hook
    i18n.php                       # Translation layer:
                                   #   __starter___get_field()
                                   #   __starter___get_repeater()
                                   #   __starter___get_sub_field()
                                   #   __starter___t($key) — get translated static string
                                   #   __starter___e($key) — echo translated static string
                                   #   __starter___is_lang($lang) — check current language
                                   #   __starter___get_current_lang()
                                   #   __starter___get_translations()
                                   #   Language cookie logic
    nav-walker.php                 # Placeholder (replaced by /wp-header)
  fields/
    settings.php                   # Options page: logo, copyright, contact info,
                                   #   social links, legal links, designer credit
                                   #   — with bilingual tabs per language
  template-parts/                  # Empty — /wp-section adds files here
  assets/
    css/
      styles.css                   # CSS reset, custom property placeholders
                                   #   (colors, spacing, typography, shadows,
                                   #   breakpoints), base utilities, responsive foundation
    js/
      main.js                      # Language switcher, mobile nav toggle,
                                   #   scroll animations (IntersectionObserver)
    images/                        # Empty
```

### Placeholder Tokens

| Token | Replaced With | Example |
|-------|--------------|---------|
| `__starter__` | theme slug (lowercase) | `acme` |
| `__STARTER__` | theme slug (uppercase) | `ACME` |
| `__STARTER_NAME__` | project name | `Acme Corp` |

### ACF Field Auto-Loader in functions.php

The auto-loader MUST be hooked to `acf/init` to ensure ACF is initialized before field registration. Individual field files contain bare `acf_add_local_field_group()` calls without their own hooks.

```php
// Load all ACF/SCF field definitions after ACF is initialized
add_action('acf/init', function() {
    foreach (glob(get_template_directory() . '/fields/*.php') as $field_file) {
        require_once $field_file;
    }
});
```

### ACF Options Page Registration

The options page MUST be registered in `functions.php` via `acf/init` so that `fields/settings.php` fields have an admin UI:

```php
add_action('acf/init', function() {
    if (function_exists('acf_add_options_page')) {
        acf_add_options_page(array(
            'page_title' => '__STARTER_NAME__ Settings',
            'menu_title' => '__STARTER__ Settings',
            'menu_slug'  => '__starter__-settings',
            'capability' => 'manage_options',
            'redirect'   => false,
        ));
    }
});
```

### SCF Dependency Check

```php
// Admin notice if SCF/ACF not active
add_action('admin_notices', function() {
    if (!function_exists('acf_add_local_field_group')) {
        echo '<div class="notice notice-error"><p><strong>__STARTER_NAME__</strong> requires Secure Custom Fields plugin.</p></div>';
    }
});
```

---

## 8. Project-Level CLAUDE.md

Generated by `/wp-init` at the project root `.claude/CLAUDE.md`:

```markdown
# Project: {project_name}

## Details
- **Theme slug:** {slug}
- **Function prefix:** {slug}_
- **Primary language:** {primary_lang}
- **Secondary language(s):** {secondary_langs}
- **Industry:** {industry}
- **Description:** {description}

## Conventions
- All ACF field helpers use the `{slug}_` prefix
- Bilingual fields use `_{lang}` suffix (e.g., `_es`)
- CSS follows custom properties + BEM
- All output must be escaped
- One field file per section in `fields/`
- One template part per section in `template-parts/`

## Workflow
Use claude-wp-builder commands: /wp-demo, /wp-header, /wp-footer,
/wp-section, /wp-page, /wp-settings, /wp-responsive-check, /wp-finalize
```

---

## 9. Technical Decisions

- **No build tools:** Vanilla CSS, vanilla JS. No npm, no webpack, no Tailwind.
- **Legacy theme:** No blocks, no FSE, no `theme.json`. Classic template hierarchy.
- **ACF/SCF in code:** All field definitions via `acf_add_local_field_group()`. No JSON sync.
- **One file per section:** Fields, templates, and CSS are modular per section.
- **N-language support:** Architecture supports any number of languages via suffix pattern. EN/ES is the default but not hardcoded.
- **Plugin format:** Claude Code plugin for portability and namespacing (`claude-wp-builder:*`).
- **External skill dependencies:** `frontend-design` and `ui-ux-pro-max` skills must be installed separately (used by `/wp-demo` only). All other commands work independently.
- **page.php vs custom templates:** `page.php` is the WP default fallback for pages without a specific template. `/wp-page generic` creates `page-generic.php` as a named template selectable in the admin. `/wp-page custom <name>` creates additional named templates (e.g., `page-pricing.php`).
- **CSS file strategy:** Single `styles.css` by default with comment-delimited sections. Page-specific CSS files allowed when substantial, conditionally enqueued.
