# Claude WP Builder — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that encodes a complete WordPress site-building methodology into reusable skills, commands, agents, and a starter theme.

**Architecture:** Plugin-based package at `/var/www/html/others/kairo/claude-wp-builder/` with skills (auto-invoked knowledge), agents (specialized subagents), commands (user-facing slash commands), and a starter theme (boilerplate with i18n, settings, CSS foundation). Reference implementation at `/var/www/html/others/kairo/kairosnew/wp-content/themes/kairo/`.

**Tech Stack:** Claude Code Plugin system (SKILL.md, agent .md, command .md, plugin.json)

---

## Chunk 1: Plugin Scaffold & Skills

### Task 1: Create Plugin Manifest

**Files:**
- Create: `claude-wp-builder/.claude-plugin/plugin.json`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "claude-wp-builder",
  "description": "WordPress site-building methodology: demo HTML → custom theme with ACF/SCF, bilingual support, section-by-section building",
  "version": "1.0.0",
  "author": {
    "name": "Yojahny"
  },
  "license": "MIT",
  "keywords": ["wordpress", "theme", "acf", "scf", "bilingual", "i18n"]
}
```

- [ ] **Step 2: Verify directory structure**

Run: `ls -la claude-wp-builder/.claude-plugin/`
Expected: `plugin.json` exists

---

### Task 2: Create `wp-theme-standards` Skill

**Files:**
- Create: `claude-wp-builder/skills/wp-theme-standards/SKILL.md`

- [ ] **Step 1: Write the skill file with the following complete content**

````markdown
---
name: wp-theme-standards
description: WordPress legacy theme best practices — proper enqueueing, escaping, hooks, security, and performance
user-invocable: false
---

# WordPress Legacy Theme Standards

This skill is auto-loaded when any `wp-*` command or agent runs. Follow these rules for ALL generated WordPress theme code.

## Theme Type

**Legacy theme only.** No blocks, no Full Site Editing (FSE), no `theme.json`. Use the classic WordPress template hierarchy.

## Required Files

Every theme MUST have:
- `style.css` — with Theme Name, Version, Description, Text Domain in the header comment
- `index.php` — required WordPress fallback template
- `functions.php` — theme setup, enqueues, includes
- `screenshot.png` — 1200x900 theme preview image

## Asset Enqueueing

ALWAYS enqueue assets properly. NEVER use inline `<style>` or `<script>` tags in templates.

```php
// Correct: enqueue with cache busting
wp_enqueue_style('theme-style',
    get_template_directory_uri() . '/assets/css/styles.css',
    array(),
    filemtime(get_template_directory() . '/assets/css/styles.css')
);

wp_enqueue_script('theme-main',
    get_template_directory_uri() . '/assets/js/main.js',
    array(),
    filemtime(get_template_directory() . '/assets/js/main.js'),
    true // in footer
);
```

## Pass data to JavaScript via `wp_localize_script()`

```php
wp_localize_script('theme-main', 'themeData', array(
    'lang'    => prefix_get_current_lang(),
    'langs'   => PREFIX_SUPPORTED_LANGS,
    'ajaxUrl' => admin_url('admin-ajax.php'),
));
```

## Theme Supports

Register in `after_setup_theme` hook:
- `add_theme_support('title-tag')` — let WP manage `<title>`
- `add_theme_support('post-thumbnails')` — enable featured images
- `add_theme_support('custom-logo', array('flex-height' => true, 'flex-width' => true))`
- `add_theme_support('html5', array('search-form', 'comment-form', 'comment-list', 'gallery', 'caption', 'style', 'script'))`
- `add_theme_support('automatic-feed-links')`

## Security — Output Escaping (MANDATORY)

ALL dynamic output in templates MUST be escaped:

| Context | Function | Example |
|---------|----------|---------|
| Text content | `esc_html()` | `<?php echo esc_html($title); ?>` |
| URLs | `esc_url()` | `href="<?php echo esc_url($link); ?>"` |
| HTML attributes | `esc_attr()` | `class="<?php echo esc_attr($class); ?>"` |
| Translations | `esc_html_e()` | `<?php esc_html_e('Text', 'textdomain'); ?>` |
| Rich HTML | `wp_kses_post()` | `<?php echo wp_kses_post($content); ?>` |

NEVER do: `echo $variable;` or `echo get_field('x');` without escaping.

## Security — Input Sanitization

All user input MUST be sanitized: `sanitize_text_field()`, `sanitize_email()`, `sanitize_url()`, `absint()`, `wp_kses()`.

## Hooks

Use proper WordPress hooks:
- `after_setup_theme` — theme setup, supports, menus
- `wp_enqueue_scripts` — front-end assets
- `init` — custom post types, taxonomies
- `acf/init` — ACF field registration, options pages
- `wp_head` — meta tags, preconnect, preloads (priority matters)
- `wp_footer` — footer scripts if needed

## Queries

NEVER use `query_posts()`. Use `WP_Query` for custom queries:

```php
$query = new WP_Query(array(
    'post_type'      => 'post',
    'posts_per_page' => 6,
));
```

## Performance Patterns

- Font preconnect: `<link rel="preconnect" href="https://fonts.googleapis.com">`
- LCP image preloading: `<link rel="preload" as="image" href="...">`
- Remove emoji scripts: `remove_action('wp_head', 'print_emoji_detection_script', 7)`
- Hide WP version: `remove_action('wp_head', 'wp_generator')`
- SVG upload support with proper mime type registration

## Page-Specific Assets

Conditionally enqueue page-specific CSS/JS:

```php
if (is_page_template('page-pricing.php')) {
    wp_enqueue_style('pricing-style', ...);
    wp_enqueue_script('pricing-script', ...);
}
```

## Plugin Dependencies

- **SCF/ACF is required.** Show admin notice if not active.
- Check with `function_exists('acf_add_local_field_group')`

## Recommended (Project-Specific)

- Schema.org structured data via `wp_head` hook
- Meta descriptions (skip if Yoast/RankMath active)
- Custom body classes via `body_class` filter
- Reading time calculation for blog posts
````

- [ ] **Step 2: Verify file exists and frontmatter is valid**

Run: `head -5 claude-wp-builder/skills/wp-theme-standards/SKILL.md`
Expected: YAML frontmatter with name, description, user-invocable: false

---

### Task 3: Create `wp-bilingual` Skill

**Files:**
- Create: `claude-wp-builder/skills/wp-bilingual/SKILL.md`

- [ ] **Step 1: Write the skill file with complete content**

Follow the same structure as the `wp-theme-standards` skill (Task 2). Include YAML frontmatter (`name: wp-bilingual`, `description: Bilingual/multilingual i18n methodology using ACF _suffix pattern with transparent translation helpers`, `user-invocable: false`) followed by full markdown documentation covering:

**All content from the Kairos reference at `/var/www/html/others/kairo/kairosnew/wp-content/themes/kairo/inc/i18n.php`, generalized as:**
- The `_suffix` pattern with examples table (primary field → `_es` → `_fr`)
- ALL helper function signatures with PHP code examples showing usage in templates:
  - `prefix_get_field($field_name, $post_id)` with fallback pattern
  - `prefix_get_repeater($field_name, $translatable_subfields, $post_id)` with foreach example
  - `prefix_get_sub_field($field_name)` inside `have_rows()` loop
  - `prefix_t($key)` / `prefix_e($key)` for static UI strings
  - `prefix_is_lang($lang)` / `prefix_get_current_lang()`
- Language detection priority chain with code
- Cookie persistence via `setcookie()` in PHP (before headers sent)
- Language switcher URL generation with `remove_query_arg`/`add_query_arg`
- ACF field creation rules (secondary field instructions, tab organization)
- Menu locations per-language pattern with `register_nav_menus()` and `wp_nav_menu()` examples
- Rule: templates use `prefix_get_field()` NEVER raw `get_field()` — translation is transparent

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/skills/wp-bilingual/SKILL.md`

---

### Task 4: Create `wp-css-system` Skill

**Files:**
- Create: `claude-wp-builder/skills/wp-css-system/SKILL.md`

- [ ] **Step 1: Write the skill file with complete content (follow wp-theme-standards structure from Task 2)**

Write full SKILL.md with YAML frontmatter + complete markdown documentation covering CSS design system standards:
- Custom property naming convention with full reference:
  - Colors: `--color-primary`, `--color-secondary`, `--color-tertiary`, `--color-neutral-50` through `--color-neutral-900`
  - Spacing: `--spacing-xs` (0.25rem), `--spacing-sm` (0.5rem), `--spacing-md` (1rem), `--spacing-lg` (1.5rem), `--spacing-xl` (2rem), `--spacing-2xl` (3rem), `--spacing-3xl` (4rem)
  - Typography: `--font-size-xs` through `--font-size-6xl`, `--font-family-primary`, `--font-family-secondary`
  - Shadows: `--shadow-sm`, `--shadow-md`, `--shadow-lg`
  - Radius: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-full`
  - Transitions: `--transition-base`, `--transition-slow`
- BEM naming: `.block__element--modifier` with examples
- CSS reset / normalize baseline
- No frameworks, no preprocessors, no build step
- Section comment delimiters: `/* ============ Section: <Name> ============ */`
- Page-specific CSS files conditionally enqueued when substantial
- Design system must be consistent between demo and theme
- All values from the design system must use custom properties (never hardcoded)

Frontmatter: `name: wp-css-system`, `description: CSS design system standards — custom properties, BEM naming, spacing/typography/color scales, no build tools`, `user-invocable: false`

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/skills/wp-css-system/SKILL.md`

---

### Task 5: Create `wp-demo` Skill

**Files:**
- Create: `claude-wp-builder/skills/wp-demo/SKILL.md`

- [ ] **Step 1: Write the skill file with complete content (follow wp-theme-standards structure from Task 2)**

Write full SKILL.md with YAML frontmatter + complete markdown documentation covering demo creation methodology:
- Single-file HTML structure with embedded CSS in `<style>` tag
- Sections separated by clear HTML comments: `<!-- ============ SECTION: Hero ============ -->`
- Design system variables defined in `:root` (these carry over to the WordPress theme later)
- Invoke `frontend-design` and `ui-ux-pro-max` skills for design quality (external dependencies)
- Each section should map 1:1 to a future `/wp-section` call
- Responsive: must work on all viewports using the breakpoint system from `wp-responsive`
- Accessible: semantic HTML5 elements (`<header>`, `<nav>`, `<main>`, `<section>`, `<footer>`), ARIA where needed, sufficient contrast ratios (WCAG AA)
- Include placeholder images with realistic dimensions
- Navigation should reflect the final site structure
- Footer should match the settings page pattern (logo, copyright, social, contact, legal)
- Demo filename convention: `demo/index.html` for homepage, `demo/<page-name>.html` for additional pages

Frontmatter: `name: wp-demo`, `description: Demo HTML creation methodology — single-file demos with section comments for 1:1 WordPress conversion`, `user-invocable: false`

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/skills/wp-demo/SKILL.md`

---

### Task 6: Create `wp-responsive` Skill

**Files:**
- Create: `claude-wp-builder/skills/wp-responsive/SKILL.md`

- [ ] **Step 1: Write the skill file with complete content (follow wp-theme-standards structure from Task 2)**

Write full SKILL.md with YAML frontmatter + complete markdown documentation covering responsive design patterns. Include CSS code examples for each pattern:
- Mobile-first breakpoint system (media queries use `min-width`):
  - `--bp-sm: 576px` — Small devices (landscape phones)
  - `--bp-md: 768px` — Tablets
  - `--bp-lg: 1024px` — Desktops
  - `--bp-xl: 1200px` — Large desktops
  - `--bp-2xl: 1440px` — Extra large screens
- Container max-widths per breakpoint
- Required responsive patterns with code examples:
  - Hamburger nav (mobile) ↔ horizontal nav (desktop)
  - CSS Grid/Flexbox that stacks on mobile
  - Fluid typography using `clamp()`: e.g., `font-size: clamp(1rem, 2.5vw, 1.5rem)`
  - Responsive images: `srcset` for resolution, `<picture>` for art direction, `sizes` attribute
  - Touch-friendly targets: minimum 44px tap area
- Every section MUST define styles for all breakpoints
- No horizontal scroll at any viewport (test at 320px minimum)
- Image handling best practices for WordPress: `wp_get_attachment_image()` with `srcset`
- Testing checklist: 375px (iPhone), 576px, 768px (iPad), 1024px, 1440px

Frontmatter: `name: wp-responsive`, `description: Responsive design patterns — mobile-first breakpoints, fluid typography, responsive images, touch targets`, `user-invocable: false`

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/skills/wp-responsive/SKILL.md`

---

### Task 7: Commit Chunk 1

- [ ] **Step 1: Stage and commit**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git init
git add .claude-plugin/ skills/
git commit -m "feat: add plugin manifest and 5 auto-invoked skills

Skills: wp-theme-standards, wp-bilingual, wp-css-system, wp-demo, wp-responsive"
```

---

## Chunk 2: Agents

### Task 8: Create `wp-template` Agent

**Files:**
- Create: `claude-wp-builder/agents/wp-template.md`

- [ ] **Step 1: Write the agent file with complete YAML frontmatter + full system prompt in markdown**

The agent file is a markdown file with YAML frontmatter followed by the system prompt. The system prompt IS the markdown body — it's the ONLY prompt the agent receives.

Agent frontmatter:
```yaml
---
name: wp-template
description: PHP/WordPress template specialist — generates template parts, page templates, header, footer using WordPress best practices and project i18n helpers
tools: Read, Write, Edit, Grep, Glob
---
```

The system prompt body MUST include all of the following as structured markdown (with headers, code blocks, and examples):
- Role: WordPress PHP template specialist
- WordPress template hierarchy knowledge
- `get_template_part()` usage and template tags
- Proper escaping: always `esc_html()` for text, `esc_url()` for URLs, `esc_attr()` for attributes
- WP loops with `WP_Query` (never `query_posts()`)
- Custom nav walkers extending `Walker_Nav_Menu`
- Conditional tags: `is_front_page()`, `is_single()`, `is_page_template()`, etc.
- Pagination via `the_posts_pagination()` or custom `paginate_links()`

**Critical rules:**
- Read the project's `.claude/CLAUDE.md` first to get the function prefix and language config
- Always use `prefix_get_field()` helpers, NEVER raw `get_field()`
- Fallback pattern: `$value = prefix_get_field('field_name') ?: 'Default Value';`
- Repeaters: `$items = prefix_get_repeater('repeater_name', array('title', 'description'));`
- Settings: `$logo = prefix_get_field('site_logo', 'option');`
- Static strings: `prefix_e('translation_key');`
- All files start with `<?php // Prevent direct access` + `if (!defined('ABSPATH')) { exit; }`
- No inline styles or scripts
- Field naming convention: `<section>_<element>` (e.g., `hero_title`, `hero_image`)

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/agents/wp-template.md`

---

### Task 9: Create `wp-css` Agent

**Files:**
- Create: `claude-wp-builder/agents/wp-css.md`

- [ ] **Step 1: Write the agent file with complete YAML frontmatter + full system prompt in markdown (follow wp-template structure from Task 8)**

Agent frontmatter:
```yaml
---
name: wp-css
description: CSS design system specialist — generates BEM-named styles using custom properties, mobile-first responsive design, no build tools
tools: Read, Write, Edit, Grep, Glob
---
```

Agent system prompt covers:
- Role: CSS design system specialist for WordPress themes
- CSS custom properties for all design tokens
- BEM naming methodology with examples
- Mobile-first responsive design using `min-width` media queries
- No build tools, no frameworks, vanilla CSS only

**Critical rules:**
- Read the project's existing `styles.css` first to understand the design system variables
- Each section gets a clearly commented block: `/* ============ Section: <Name> ============ */`
- Follow the demo's visual design exactly — pixel-match the demo
- Base styles for mobile, then `@media (min-width: var)` for larger
- Use custom properties for ALL design system values (never hardcode colors, spacing, etc.)
- Fluid typography with `clamp()` where appropriate
- Page-specific CSS files allowed when a page has substantial unique styles, conditionally enqueued
- Ensure no horizontal scroll at any viewport
- Touch targets minimum 44px
- Transitions and animations use `prefers-reduced-motion` media query

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/agents/wp-css.md`

---

### Task 10: Create `wp-acf` Agent

**Files:**
- Create: `claude-wp-builder/agents/wp-acf.md`

- [ ] **Step 1: Write the agent file with complete YAML frontmatter + full system prompt in markdown (follow wp-template structure from Task 8)**

Agent frontmatter:
```yaml
---
name: wp-acf
description: ACF/SCF field architect — generates programmatic field definitions with bilingual support, one file per section
tools: Read, Write, Edit, Grep, Glob
---
```

Agent system prompt covers:
- Role: ACF/SCF field definition specialist
- `acf_add_local_field_group()` API with complete parameter reference
- Field types expertise: text, textarea, image, repeater, group, select, page_link, url, wysiwyg, true_false, number, color_picker, tab
- Tab organization within field groups
- Conditional logic between fields

**Critical rules:**
- Read the project's `.claude/CLAUDE.md` first to get function prefix, languages, and theme slug
- Strict field naming convention:
  - Field names: `<section>_<element>` (e.g., `hero_title`, `hero_description`)
  - Repeater names: `<section>_<plural>` (e.g., `services_cards`, `values_items`)
  - Repeater subfields: `<element>` without section prefix (e.g., `title`, `description`, `icon`)
  - Field keys: `field_<section>_<element>` (e.g., `field_hero_title`)
  - Group keys: `group_<section>` (e.g., `group_hero`)
- Automatically create bilingual variants: primary field + `_<lang>` suffix for each secondary language
- Secondary language field instructions: "Leave empty to use [primary language] version"
- Use tabs to organize: first tab for primary language content, subsequent tabs for each secondary language
- Settings fields use `'option'` as post ID
- One file per section in `fields/` directory
- Files contain bare `acf_add_local_field_group()` calls (no hooks — the auto-loader handles timing)
- Location rules: use `'param' => 'page_template'` for page-specific, `'param' => 'options_page'` for settings

Reference pattern from Kairos: `/var/www/html/others/kairo/kairosnew/wp-content/themes/kairo/inc/scf-fields.php`

- [ ] **Step 2: Verify file**

Run: `head -5 claude-wp-builder/agents/wp-acf.md`

---

### Task 11: Commit Chunk 2

- [ ] **Step 1: Stage and commit**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git add agents/
git commit -m "feat: add 3 specialized agents (wp-template, wp-css, wp-acf)"
```

---

## Chunk 3: Commands (Part 1 — Init, Demo, Header, Footer)

### Task 12: Create `/wp-init` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-init.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Scaffold a new WordPress project — copies starter theme, replaces placeholders, generates .claude/CLAUDE.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-name]"
---
```

Command instructions:
1. If `$ARGUMENTS` provided, use as project name. Otherwise ask interactively:
   - Project name (e.g., "Acme Corp")
   - Theme slug (e.g., "acme") — suggest lowercase, no spaces, from project name
   - Primary language (default: "en")
   - Secondary language(s) (default: "es", comma-separated for multiple)
   - Client industry / type of company
   - Brief project description
2. Determine target path: Look for `wp-content/themes/` in current directory or parent directories. If not found, ask user for WordPress installation path.
3. Copy `starter-theme/__starter__/` from the plugin directory (`${CLAUDE_PLUGIN_ROOT}/starter-theme/__starter__/`) to `wp-content/themes/<slug>/`
4. Replace placeholders in ALL files recursively:
   - `__starter__` → theme slug lowercase
   - `__STARTER__` → theme slug UPPERCASE
   - `__STARTER_NAME__` → project name
5. Rename the theme directory from `__starter__` to `<slug>`
6. Configure `inc/i18n.php`: update `SUPPORTED_LANGS` constant and `DEFAULT_LANG` with specified languages
7. Configure `inc/theme-setup.php`: update `register_nav_menus()` to register per-language menus for all specified languages
8. Generate `.claude/CLAUDE.md` at the WordPress root with project context (see spec Section 8)
9. If WP-CLI available (`wp --info`), activate the theme: `wp theme activate <slug>`
10. Print summary of what was created

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-init.md`

---

### Task 13: Create `/wp-demo` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-demo.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Create a demo HTML mockup for client approval — responsive, section-separated, ready for WordPress conversion
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[brief or 'iterate']"
---
```

Command instructions:
1. Read the project's `.claude/CLAUDE.md` to get project context (industry, description, languages)
2. If no brief provided in `$ARGUMENTS`, ask for:
   - Client brief / description of the website
   - Reference screenshots or URLs (optional — user can paste images)
   - List of sections needed (e.g., hero, about, services, testimonials, contact)
3. Invoke the `wp-demo` skill for methodology
4. Invoke `frontend-design` and `ui-ux-pro-max` skills for design quality (note: these are external dependencies)
5. Invoke `wp-css-system` skill for CSS custom properties + BEM
6. Invoke `wp-responsive` skill for responsive patterns
7. Create `demo/` directory at project root if it doesn't exist
8. Generate `demo/index.html` with:
   - Embedded CSS in `<style>` tag using design system from `:root`
   - Clear section comments: `<!-- ============ SECTION: Hero ============ -->`
   - Semantic HTML5 structure
   - Responsive design (mobile-first)
   - Placeholder images with realistic dimensions
   - Navigation matching planned site structure
   - Footer matching settings page pattern
9. Generate additional demo pages if needed (e.g., `demo/pricing.html`)
10. If `$ARGUMENTS` is "iterate", read existing demo and ask what to change
11. Print: "Demo created at demo/index.html — open in browser to review with client"

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-demo.md`

---

### Task 14: Create `/wp-header` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-header.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Build the WordPress header — responsive nav, logo, language switcher, WP menu system integration
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[screenshot-path]"
---
```

Command instructions:
1. Read project's `.claude/CLAUDE.md` for prefix and language config
2. Read the demo HTML file (`demo/index.html`) to extract header/nav section
3. If `$ARGUMENTS` provided, read it as a screenshot reference
4. Dispatch `wp-template` agent to generate:
   - `header.php` — `<!DOCTYPE html>`, `<head>` with `wp_head()`, opening `<body>`, site header with:
     - Logo from settings: `prefix_get_field('site_logo', 'option')`
     - Navigation using `wp_nav_menu()` with per-language menu location
     - Language switcher component
     - Mobile hamburger toggle
   - `inc/nav-walker.php` — custom Walker_Nav_Menu if the demo nav requires custom markup
   - Update `inc/theme-setup.php` — ensure `register_nav_menus()` has per-language locations
5. Dispatch `wp-css` agent to generate header/nav CSS in `styles.css`:
   - Responsive nav (hamburger on mobile, horizontal on desktop)
   - Sticky/fixed header if demo shows it
   - Language switcher styling
6. Print summary of files created/modified

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-header.md`

---

### Task 15: Create `/wp-footer` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-footer.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Build the WordPress footer — pulling from settings page (logo, copyright, social, contact, legal)
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[screenshot-path]"
---
```

Command instructions:
1. Read project's `.claude/CLAUDE.md` for prefix and language config
2. Read the demo HTML file (`demo/index.html`) to extract footer section
3. If `$ARGUMENTS` provided, read it as a screenshot reference
4. Dispatch `wp-template` agent to generate `footer.php`:
   - Pulls all data from settings page via `prefix_get_field('field_name', 'option')`:
     - Logo / brand text
     - Copyright text
     - Contact info (email, phone, address)
     - Social links (Instagram, Facebook, TikTok, YouTube, LinkedIn)
     - Legal links (privacy policy, terms & conditions)
     - Designer credit
   - All text bilingual via `prefix_get_field()` (transparent translation)
   - Closes `</body>` with `wp_footer()` before closing tag
5. Dispatch `wp-css` agent to generate footer CSS in `styles.css`
6. Print summary of files created/modified

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-footer.md`

---

### Task 16: Commit Chunk 3

- [ ] **Step 1: Stage and commit**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git add commands/wp-init.md commands/wp-demo.md commands/wp-header.md commands/wp-footer.md
git commit -m "feat: add commands — wp-init, wp-demo, wp-header, wp-footer"
```

---

## Chunk 4: Commands (Part 2 — Section, Page, Settings, Responsive Check, Finalize)

### Task 17: Create `/wp-section` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-section.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: One-shot section builder — generates ACF fields + template part + CSS for a section from the demo
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<section-name> [screenshot-path]"
---
```

Command instructions:
1. Parse `$ARGUMENTS`: first word is section name (required), rest is optional screenshot path
2. If no section name, error: "Usage: /wp-section <section-name> [screenshot-path]"
3. Read project's `.claude/CLAUDE.md` for prefix, slug, and language config
4. Read `demo/index.html` and extract the section matching `<!-- ============ SECTION: <Name> ============ -->`
5. Determine which page template this section belongs to (default: `front-page.php`)
6. Dispatch 3 agents IN PARALLEL:
   - **`wp-acf` agent**: "Generate `fields/<section-name>.php` for the '<section-name>' section. Follow the field naming convention: field names use `<section>_<element>`, repeaters use `<section>_<plural>`. Create bilingual variants for languages: [from CLAUDE.md]. Analyze the demo HTML to determine what fields are needed (text, images, repeaters, etc.). Location rule: [page template]. Reference: [extracted demo HTML]"
   - **`wp-template` agent**: "Generate `template-parts/section-<name>.php` for the '<section-name>' section. Use `prefix_get_field()` with field names following `<section>_<element>` convention. Use `prefix_get_repeater()` for any repeating content. Include fallback defaults from the demo. All output escaped. Reference: [extracted demo HTML]"
   - **`wp-css` agent**: "Add CSS for the '<section-name>' section to `assets/css/styles.css`. Use a comment delimiter `/* ============ Section: <Name> ============ */`. Follow BEM naming `.section-name__element`. Mobile-first responsive for all breakpoints. Match the demo design exactly. Reference: [extracted demo HTML/CSS]"
7. After agents complete, wire up the section:
   - Verify `fields/<section-name>.php` was created (auto-loaded by functions.php glob)
   - Add `get_template_part('template-parts/section', '<name>');` to the page template if not already present
8. Print summary: "Section '<name>' created: fields/<name>.php, template-parts/section-<name>.php, CSS added to styles.css"

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-section.md`

---

### Task 18: Create `/wp-page` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-page.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Generate page templates — blog, generic, legal, 404, or custom page types
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<type> [name] [screenshot-path]"
---
```

Command instructions:
1. Parse `$ARGUMENTS`: first word is page type (required). Valid types: `blog`, `generic`, `legal`, `404`, `custom`
2. If type is `custom`, second word is the page name (required)
3. Read project's `.claude/CLAUDE.md` for context

**For each type, dispatch appropriate agents:**

**`blog`:**
- `wp-template` agent generates: `archive.php` (post listing with `WP_Query`, pagination), `single.php` (single post view), `template-parts/journal/content-journal-card.php` (post card), `template-parts/journal/content-single-post.php` (post content)
- `wp-acf` agent generates: `fields/blog.php` (blog page title, subtitle, post-level fields like `post_excerpt_es` for bilingual excerpts)
- `wp-css` agent generates: blog CSS block in `styles.css`

**`generic`:**
- `wp-template` agent generates: `page-generic.php` with `/* Template Name: Generic Page */` header
- `wp-css` agent generates: generic page CSS

**`legal`:**
- `wp-template` agent generates: `page-legal.php` with `/* Template Name: Legal Page */`
- `wp-acf` agent generates: `fields/legal.php` (privacy policy content, terms content, bilingual)
- `wp-css` agent generates: legal page CSS

**`404`:**
- `wp-template` agent generates: `404.php` with search form, navigation suggestions
- `wp-css` agent generates: 404 page CSS

**`custom <name>`:**
- `wp-template` agent generates: `page-<name>.php` with `/* Template Name: <Name> */`
- `wp-acf` agent generates: `fields/<name>.php` if content fields needed
- `wp-css` agent generates: page-specific CSS (in `styles.css` or separate file if substantial)

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-page.md`

---

### Task 19: Create `/wp-settings` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-settings.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Extend the theme settings page with additional ACF fields beyond the defaults
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[description of settings to add]"
---
```

Command instructions:
1. Read project's `.claude/CLAUDE.md` for prefix and language config
2. Read current `fields/settings.php` to understand existing fields
3. If `$ARGUMENTS` provided, use as description of what to add. Otherwise ask what settings to add.
4. Dispatch `wp-acf` agent to update `fields/settings.php`:
   - Add new tabs and fields as requested
   - Automatically create bilingual variants for each new field
   - Follow the existing tab organization pattern
   - New fields use `'option'` as post ID
5. Print summary of fields added

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-settings.md`

---

### Task 20: Create `/wp-responsive-check` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-responsive-check.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Responsive validation — screenshots at 5 viewports, checks for layout issues
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<url-or-file-path>"
---
```

Command instructions:
1. Get target from `$ARGUMENTS` (URL or local HTML file path). If not provided, ask.
2. Determine screenshot mechanism (try in order):
   a. Check if Playwright MCP is available
   b. Check if Puppeteer is available: `npx puppeteer --version`
   c. If neither, use manual fallback
3. **If automated tooling available:**
   - Take screenshots at 5 viewports: 375px, 576px, 768px, 1024px, 1440px
   - Save screenshots to `responsive-check/` directory
   - Analyze each screenshot for:
     - Horizontal overflow / horizontal scrollbar
     - Text truncation or overflow
     - Overlapping elements
     - Touch target sizes (< 44px)
     - Image scaling issues
     - Navigation behavior (hamburger on mobile, expanded on desktop)
     - Font readability (too small on mobile)
4. **If manual fallback:**
   - Ask user to provide screenshots at each viewport
   - Analyze provided screenshots
5. Generate report: list of issues per viewport with severity (critical, warning, info)
6. Print: "Responsive check complete. [N] issues found." or "All viewports pass."

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-responsive-check.md`

---

### Task 21: Create `/wp-finalize` Command

**Files:**
- Create: `claude-wp-builder/commands/wp-finalize.md`

- [ ] **Step 1: Write the command file**

Frontmatter:
```yaml
---
description: Pre-delivery checklist — validates escaping, bilingual coverage, responsive design, menus, and theme requirements
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---
```

Command instructions:
1. Read project's `.claude/CLAUDE.md` for prefix, slug, and language config
2. Determine theme directory path
3. Run validation checks (use Grep and Glob tools):

**Escaping validation:**
- Grep for `echo` statements in template files that don't use `esc_html()`, `esc_url()`, `esc_attr()`, or `wp_kses()`
- Flag any raw `echo get_field()` or `echo $variable` without escaping

**Bilingual coverage:**
- For each field in `fields/*.php`, check that bilingual variants exist for all configured languages
- Check that all template files use `prefix_get_field()` not raw `get_field()`

**Responsive validation:**
- Check that `styles.css` contains media queries for all breakpoints
- Run `/wp-responsive-check` if a URL is available

**Theme structure:**
- Verify `style.css` has required theme headers (Theme Name, Version, Description)
- Verify `index.php` exists (required by WordPress)
- Verify `screenshot.png` exists
- Verify `functions.php` has SCF dependency check
- Verify `register_nav_menus()` is called with per-language locations

**Content templates:**
- Check if `404.php` exists
- Check if blog templates exist (`archive.php`, `single.php`) if blog is likely needed
- Check all `get_template_part()` calls reference existing files

**Settings page:**
- Verify `acf_add_options_page()` is registered
- Verify `fields/settings.php` exists

4. Print report:
```
=== WP Finalize Report ===
[PASS] / [FAIL] Escaping validation
[PASS] / [FAIL] Bilingual coverage
[PASS] / [FAIL] Responsive breakpoints
[PASS] / [FAIL] Theme structure
[PASS] / [FAIL] Content templates
[PASS] / [FAIL] Settings page
---
Result: Ready to deliver / X issues found
```

- [ ] **Step 2: Verify file**

Run: `head -10 claude-wp-builder/commands/wp-finalize.md`

---

### Task 22: Commit Chunk 4

- [ ] **Step 1: Stage and commit**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git add commands/wp-section.md commands/wp-page.md commands/wp-settings.md commands/wp-responsive-check.md commands/wp-finalize.md
git commit -m "feat: add commands — wp-section, wp-page, wp-settings, wp-responsive-check, wp-finalize"
```

---

## Chunk 5: Starter Theme

### Task 23: Create `style.css` (Theme Headers)

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/style.css`

- [ ] **Step 1: Write the file**

```css
/*
Theme Name: __STARTER_NAME__
Theme URI:
Author: Yojahny
Author URI:
Description: Custom WordPress theme for __STARTER_NAME__
Version: 1.0.0
License: GNU General Public License v2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html
Text Domain: __starter__
*/
```

This file is WordPress-required for theme identification. Actual styles live in `assets/css/styles.css`.

---

### Task 24: Create `functions.php`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/functions.php`

- [ ] **Step 1: Write the file**

Based on the Kairos reference (`/var/www/html/others/kairo/kairosnew/wp-content/themes/kairo/functions.php`), include:

```php
<?php
/**
 * __STARTER_NAME__ Theme Functions
 *
 * @package __STARTER_NAME__
 * @version 1.0.0
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Theme setup
require get_template_directory() . '/inc/theme-setup.php';

// Internationalization (i18n) - must load before field definitions
require get_template_directory() . '/inc/i18n.php';

// Custom nav walker
require get_template_directory() . '/inc/nav-walker.php';

// Load all ACF/SCF field definitions after ACF is initialized
add_action('acf/init', function() {
    foreach (glob(get_template_directory() . '/fields/*.php') as $field_file) {
        require_once $field_file;
    }
});

// Register ACF Options Page
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

// Admin notice if SCF/ACF not active
add_action('admin_notices', function() {
    if (!function_exists('acf_add_local_field_group')) {
        echo '<div class="notice notice-error"><p><strong>__STARTER_NAME__</strong> requires the Secure Custom Fields plugin to be installed and activated.</p></div>';
    }
});

/**
 * Enqueue theme styles and scripts
 */
function __starter___enqueue_assets() {
    // Main stylesheet
    wp_enqueue_style(
        '__starter__-style',
        get_template_directory_uri() . '/assets/css/styles.css',
        array(),
        filemtime(get_template_directory() . '/assets/css/styles.css')
    );

    // Main script
    wp_enqueue_script(
        '__starter__-main',
        get_template_directory_uri() . '/assets/js/main.js',
        array(),
        filemtime(get_template_directory() . '/assets/js/main.js'),
        true
    );

    // Pass PHP data to JavaScript
    wp_localize_script('__starter__-main', '__starter__Data', array(
        'lang'    => __starter___get_current_lang(),
        'langs'   => __STARTER___SUPPORTED_LANGS,
        'ajaxUrl' => admin_url('admin-ajax.php'),
    ));
}
add_action('wp_enqueue_scripts', '__starter___enqueue_assets');

/**
 * Add meta description for SEO (skipped if Yoast/RankMath active)
 */
function __starter___add_meta_description() {
    if (defined('WPSEO_VERSION') || defined('RANK_MATH_VERSION')) {
        return;
    }
    // Project-specific meta descriptions added here
}
add_action('wp_head', '__starter___add_meta_description', 1);

/**
 * Add font preconnect for performance
 */
function __starter___add_preconnect() {
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
}
add_action('wp_head', '__starter___add_preconnect', 1);

/**
 * Preload LCP image on front page
 */
function __starter___preload_lcp_image() {
    if (is_front_page()) {
        $hero_image = __starter___get_field('hero_image');
        if ($hero_image && isset($hero_image['url'])) {
            echo '<link rel="preload" as="image" href="' . esc_url($hero_image['url']) . '">' . "\n";
        }
    }
}
add_action('wp_head', '__starter___preload_lcp_image', 2);

/**
 * Get theme asset URL
 *
 * @param string $path Relative path to asset
 * @return string Full URL to asset
 */
function __starter___asset($path) {
    return get_template_directory_uri() . '/assets/' . ltrim($path, '/');
}

/**
 * Get site logo with fallback
 *
 * @return array|false Logo image array or false
 */
function __starter___get_logo() {
    $logo = __starter___get_field('site_logo', 'option');
    return $logo ?: false;
}
```

---

### Task 25: Create `inc/theme-setup.php`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/inc/theme-setup.php`

- [ ] **Step 1: Write the file**

Based on Kairos reference, include:
- `__starter___setup()` hooked to `after_setup_theme`:
  - `add_theme_support('automatic-feed-links')`
  - `add_theme_support('title-tag')`
  - `add_theme_support('post-thumbnails')`
  - `register_nav_menus()` with per-language locations (primary-en, primary-es, mobile-en, mobile-es, footer-links)
  - `add_theme_support('html5', ...)` for search-form, comment-form, comment-list, gallery, caption, style, script
  - `add_theme_support('custom-logo', ...)` with flex dimensions
- `__starter___content_width()` — set content width to 1280
- `__starter___disable_emojis()` — remove WP emoji scripts
- `remove_action('wp_head', 'wp_generator')` — hide WP version
- `__starter___allow_svg_upload()` — add SVG to allowed mime types (with sanitization note)
- `__starter___body_classes()` — add custom classes: language class, page template class
- No custom image sizes registered by default — project-specific sizes added by `/wp-section` or `/wp-page` commands as needed

---

### Task 26: Create `inc/i18n.php`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/inc/i18n.php`

- [ ] **Step 1: Write the file**

Generalize from Kairos i18n.php (`/var/www/html/others/kairo/kairosnew/wp-content/themes/kairo/inc/i18n.php`):

- Constants: `__STARTER___SUPPORTED_LANGS` (default: `array('en', 'es')`), `__STARTER___DEFAULT_LANG` (default: `'en'`)
- `__starter___get_current_lang()` — detect language: URL param → cookie → browser → default (with static cache). **Cookie is set via PHP `setcookie()` when URL param detected — this runs early, before headers are sent. Use `static $cache` to avoid re-detection.**
- `__starter___get_field($field_name, $post_id = false)` — if non-default language, try `$field_name . '_' . $lang` first, fall back to base field
- `__starter___get_repeater($field_name, $translatable_subfields = array(), $post_id = false)` — get repeater with translated subfields
- `__starter___get_sub_field($field_name)` — inside repeater loop, get translated subfield
- `__starter___t($key)` — get translated static string from translations array
- `__starter___e($key)` — echo translated static string
- `__starter___is_lang($lang)` — check if current language matches
- `__starter___get_translations()` — return translations array (nav labels, button text, common UI strings)
- `__starter___get_lang_url($lang)` — generate URL for language switch (preserves query params, updates/adds `lang` param)

---

### Task 27: Create `inc/nav-walker.php` (Placeholder)

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/inc/nav-walker.php`

- [ ] **Step 1: Write minimal placeholder**

```php
<?php
/**
 * Custom Navigation Walker
 *
 * This file is replaced by /wp-header with a project-specific walker.
 *
 * @package __STARTER_NAME__
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Default: uses WordPress built-in walker
// /wp-header will generate a custom walker based on the demo design
```

---

### Task 28: Create `fields/settings.php`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/fields/settings.php`

- [ ] **Step 1: Write the file**

Based on the Kairos settings pattern, create the ACF field group for the options page:
- Location: `__starter__-settings` options page
- **General Tab:** site_logo (image), footer_brand_text (textarea), copyright_text (text)
- **Contact Tab:** footer_email (text), footer_phone (text), contact_form_shortcode (text)
- **Legal Tab:** privacy_policy_page (page_link), terms_page (page_link), legal_disclaimer (textarea)
- **Address Tab:** business_address (textarea), address_map_link (url)
- **Social Tab:** social_instagram (url), social_facebook (url), social_tiktok (url), social_youtube (url), social_linkedin (url)
- **Designer Tab:** designer_credit_text (text), designer_name (text), designer_url (url)
- **Spanish Translations Tab** (or configured secondary language): all above fields duplicated with `_es` suffix, instructions: "Leave empty to use English version"

All field keys follow: `field_settings_<fieldname>`
Group key: `group_settings`

---

### Task 29: Create Template Shell Files

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/header.php`
- Create: `claude-wp-builder/starter-theme/__starter__/footer.php`
- Create: `claude-wp-builder/starter-theme/__starter__/front-page.php`
- Create: `claude-wp-builder/starter-theme/__starter__/page.php`
- Create: `claude-wp-builder/starter-theme/__starter__/index.php`

- [ ] **Step 1: Write header.php (minimal shell)**

```php
<?php
/**
 * Header Template
 *
 * This is a minimal shell. Use /wp-header to generate the full header
 * based on your demo design.
 *
 * @package __STARTER_NAME__
 */
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<!-- Use /wp-header to generate the site header and navigation -->
```

- [ ] **Step 2: Write footer.php (minimal shell)**

```php
<?php
/**
 * Footer Template
 *
 * This is a minimal shell. Use /wp-footer to generate the full footer
 * based on your demo design.
 *
 * @package __STARTER_NAME__
 */
?>
<!-- Use /wp-footer to generate the site footer -->
<?php wp_footer(); ?>
</body>
</html>
```

- [ ] **Step 3: Write front-page.php**

```php
<?php
/**
 * Front Page Template
 *
 * Sections are added here by /wp-section commands.
 *
 * @package __STARTER_NAME__
 */

get_header();
?>

<main id="main-content">
    <!-- Use /wp-section <name> to add sections here -->
</main>

<?php
get_footer();
```

- [ ] **Step 4: Write page.php**

```php
<?php
/**
 * Default Page Template
 *
 * @package __STARTER_NAME__
 */

get_header();
?>

<main id="main-content">
    <?php
    while (have_posts()) :
        the_post();
    ?>
    <article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
        <div class="page-content">
            <h1 class="page-content__title"><?php the_title(); ?></h1>
            <div class="page-content__body">
                <?php the_content(); ?>
            </div>
        </div>
    </article>
    <?php endwhile; ?>
</main>

<?php
get_footer();
```

- [ ] **Step 5: Write index.php**

```php
<?php
/**
 * Main Index Template (WordPress fallback)
 *
 * @package __STARTER_NAME__
 */

get_header();
?>

<main id="main-content">
    <?php
    if (have_posts()) :
        while (have_posts()) :
            the_post();
            the_content();
        endwhile;
    endif;
    ?>
</main>

<?php
get_footer();
```

---

### Task 30: Create `assets/css/styles.css`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/assets/css/styles.css`

- [ ] **Step 1: Write the CSS foundation**

Include:
- CSS reset (modern normalize)
- `:root` with design system custom property placeholders:
  - Colors: `--color-primary`, `--color-secondary`, `--color-tertiary`, neutrals 50-900
  - Spacing scale: `--spacing-xs` through `--spacing-3xl`
  - Typography: `--font-size-xs` through `--font-size-6xl`, `--font-family-primary`, `--font-family-secondary`
  - Shadows: `--shadow-sm`, `--shadow-md`, `--shadow-lg`
  - Radius: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-full`
  - Transitions: `--transition-base`, `--transition-slow`
  - Breakpoints (for reference, CSS can't use vars in media queries): `--bp-sm: 576px`, etc.
  - Container: `--container-max: 1280px`
- Base styles: box-sizing, body typography, smooth scrolling
- Utility classes: `.container`, `.sr-only` (screen reader only), `.text-center`
- Responsive container with max-widths
- Comment: `/* ============ Section styles added by /wp-section ============ */`

---

### Task 31: Create `assets/js/main.js`

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/assets/js/main.js`

- [ ] **Step 1: Write the JavaScript foundation**

Include:
- Language switcher functionality (reads current `?lang=` param, generates switch URLs)
- Mobile nav toggle (hamburger menu open/close with aria attributes)
- Scroll reveal animations using IntersectionObserver
- Smooth scroll for anchor links
- Sticky header behavior (add class on scroll)
- All in an IIFE, no global pollution
- `DOMContentLoaded` wrapper

---

### Task 32: Create Placeholder Files

**Files:**
- Create: `claude-wp-builder/starter-theme/__starter__/screenshot.png`
- Create: `claude-wp-builder/starter-theme/__starter__/template-parts/.gitkeep`
- Create: `claude-wp-builder/starter-theme/__starter__/assets/images/.gitkeep`

- [ ] **Step 1: Create placeholder screenshot**

Use a simple 1200x900 placeholder PNG (can be generated via ImageMagick or a minimal binary).
If ImageMagick not available, create a minimal valid PNG file.

- [ ] **Step 2: Create .gitkeep files for empty directories**

```bash
touch claude-wp-builder/starter-theme/__starter__/template-parts/.gitkeep
touch claude-wp-builder/starter-theme/__starter__/assets/images/.gitkeep
```

---

### Task 33: Commit Chunk 5

- [ ] **Step 1: Stage and commit**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git add starter-theme/
git commit -m "feat: add starter theme with i18n layer, settings fields, CSS foundation, and JS base"
```

---

## Chunk 6: Verification & Documentation

### Task 34: Verify Complete Plugin Structure

- [ ] **Step 1: Verify all files exist**

Run:
```bash
find claude-wp-builder -type f | sort
```

Expected output should include:
```
claude-wp-builder/.claude-plugin/plugin.json
claude-wp-builder/agents/wp-acf.md
claude-wp-builder/agents/wp-css.md
claude-wp-builder/agents/wp-template.md
claude-wp-builder/commands/wp-demo.md
claude-wp-builder/commands/wp-finalize.md
claude-wp-builder/commands/wp-footer.md
claude-wp-builder/commands/wp-header.md
claude-wp-builder/commands/wp-init.md
claude-wp-builder/commands/wp-page.md
claude-wp-builder/commands/wp-responsive-check.md
claude-wp-builder/commands/wp-section.md
claude-wp-builder/commands/wp-settings.md
claude-wp-builder/skills/wp-bilingual/SKILL.md
claude-wp-builder/skills/wp-css-system/SKILL.md
claude-wp-builder/skills/wp-demo/SKILL.md
claude-wp-builder/skills/wp-responsive/SKILL.md
claude-wp-builder/skills/wp-theme-standards/SKILL.md
claude-wp-builder/starter-theme/__starter__/assets/css/styles.css
claude-wp-builder/starter-theme/__starter__/assets/images/.gitkeep
claude-wp-builder/starter-theme/__starter__/assets/js/main.js
claude-wp-builder/starter-theme/__starter__/fields/settings.php
claude-wp-builder/starter-theme/__starter__/footer.php
claude-wp-builder/starter-theme/__starter__/front-page.php
claude-wp-builder/starter-theme/__starter__/functions.php
claude-wp-builder/starter-theme/__starter__/header.php
claude-wp-builder/starter-theme/__starter__/inc/i18n.php
claude-wp-builder/starter-theme/__starter__/inc/nav-walker.php
claude-wp-builder/starter-theme/__starter__/inc/theme-setup.php
claude-wp-builder/starter-theme/__starter__/index.php
claude-wp-builder/starter-theme/__starter__/page.php
claude-wp-builder/starter-theme/__starter__/screenshot.png
claude-wp-builder/starter-theme/__starter__/style.css
claude-wp-builder/starter-theme/__starter__/template-parts/.gitkeep
```

- [ ] **Step 2: Verify plugin loads**

Run:
```bash
cd /path/to/any/project
claude --plugin-dir /var/www/html/others/kairo/claude-wp-builder
```

Then test: type `/wp-` and verify autocomplete shows all 9 commands.

---

### Task 35: Test `/wp-init` End-to-End

- [ ] **Step 1: Create a test project**

```bash
mkdir -p /tmp/test-wp/wp-content/themes
cd /tmp/test-wp
```

- [ ] **Step 2: Run `/wp-init`**

In Claude Code with the plugin loaded, run `/wp-init` and provide:
- Project name: "Test Company"
- Slug: "testco"
- Primary language: en
- Secondary: es
- Industry: technology
- Description: Test project

- [ ] **Step 3: Verify output**

```bash
ls /tmp/test-wp/wp-content/themes/testco/
```

Expected: All starter theme files with `__starter__` replaced by `testco`.

- [ ] **Step 4: Verify no placeholder remnants**

```bash
grep -r "__starter__" /tmp/test-wp/wp-content/themes/testco/
grep -r "__STARTER__" /tmp/test-wp/wp-content/themes/testco/
grep -r "__STARTER_NAME__" /tmp/test-wp/wp-content/themes/testco/
```

Expected: No matches.

- [ ] **Step 5: Verify function prefixes**

```bash
grep -r "testco_" /tmp/test-wp/wp-content/themes/testco/functions.php
```

Expected: Functions like `testco_enqueue_assets`, `testco_get_field`, etc.

- [ ] **Step 6: Clean up**

```bash
rm -rf /tmp/test-wp
```

---

### Task 36: Final Commit

- [ ] **Step 1: Stage and commit any remaining changes**

```bash
cd /var/www/html/others/kairo/claude-wp-builder
git add -A
git commit -m "feat: complete claude-wp-builder plugin v1.0.0

Plugin includes:
- 5 auto-invoked skills (theme-standards, bilingual, css-system, demo, responsive)
- 3 specialized agents (wp-template, wp-css, wp-acf)
- 9 commands (wp-init, wp-demo, wp-header, wp-footer, wp-section, wp-page, wp-settings, wp-responsive-check, wp-finalize)
- Starter theme with i18n layer, settings page, CSS foundation"
```
