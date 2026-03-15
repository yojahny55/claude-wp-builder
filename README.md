# Claude WP Builder

A Claude Code plugin that encodes a complete WordPress site-building methodology into reusable skills, commands, agents, and a starter theme.

**Workflow:** Demo HTML for client approval (create new or polish existing) → Custom WordPress theme built section-by-section with ACF/SCF fields → Bilingual support → Delivery.

## Installation

### Option 1: Plugin Marketplace (Recommended)

**Step 1 — Add the marketplace:**

```
/plugin marketplace add yojahny55/claude-wp-builder
```

**Step 2 — Install the plugin:**

```
/plugin install claude-wp-builder@claude-wp-builder
```

Or use the interactive UI: run `/plugin`, go to the **Discover** tab, and select **claude-wp-builder**.

### Option 2: Direct from CLI

```bash
claude --plugin-dir /path/to/claude-wp-builder
```

### Option 3: Project-level auto-install

Add to your project's `.claude/settings.json` so all collaborators get it automatically:

```json
{
  "extraKnownMarketplaces": {
    "claude-wp-builder": {
      "source": {
        "source": "github",
        "repo": "yojahny55/claude-wp-builder"
      }
    }
  },
  "enabledPlugins": {
    "claude-wp-builder@claude-wp-builder": true
  }
}
```

## Workflow

### 1. Scaffold the project

```
/wp-init
```

Prompts for project name, slug, languages, industry. Copies the starter theme, replaces placeholders, generates `.claude/CLAUDE.md` with project config.

### 2. Create the demo

```
/wp-demo
```

Generates a responsive HTML demo (`demo/index.html`) for client approval. Uses `frontend-design` and `ui-ux-pro-max` skills for design quality. Sections are clearly separated with comments for easy WordPress conversion.

```
/wp-demo iterate
```

Re-read existing demo and iterate on changes.

### 2b. Or polish an existing demo

```
/wp-polish path/to/existing-mockup.html
```

Normalizes any HTML file into a plugin-compatible demo: detects sections, adds section delimiters, normalizes semantic HTML5, adds BEM class naming. Preserves the original at `demo/original.html`.

```
/wp-polish
```

Polish the existing `demo/index.html` in place.

### 3. Build header and footer

```
/wp-header
/wp-footer
```

Each reads the demo, dispatches specialized agents (`wp-template`, `wp-css`, `wp-acf`) to generate:
- Template files (`header.php`, `footer.php`)
- Navigation walker and menu registration
- CSS styles
- ACF fields added to the **Header** and **Footer** tabs in the settings page

### 4. Build sections

```
/wp-section hero
/wp-section services
/wp-section values
/wp-section contact
```

Each command generates three files in parallel:
- `fields/<section>.php` — ACF field definitions with bilingual support
- `template-parts/section-<name>.php` — PHP template consuming those fields
- CSS block appended to `styles.css`

Provide a screenshot for visual reference:

```
/wp-section hero /path/to/screenshot.png
```

### 5. Add page templates

```
/wp-page blog       # archive.php, single.php, post card components
/wp-page legal       # Privacy policy + terms templates with ACF fields
/wp-page 404         # Custom 404 page
/wp-page generic     # Basic content page template
/wp-page custom pricing   # Custom named page template
```

### 6. Extend settings

```
/wp-settings Add a Google Calendar embed field and a newsletter signup URL
```

Adds fields to the settings page with automatic bilingual variants.

### 7. Validate

```
/wp-responsive-check http://localhost/mysite
```

Screenshots at 5 viewports (375px, 576px, 768px, 1024px, 1440px) and checks for layout issues.

```
/wp-finalize
```

Pre-delivery checklist: validates escaping, bilingual coverage, responsive breakpoints, menu registration, theme structure, and more.

## Commands Reference

| Command | Description |
|---------|-------------|
| `/wp-init` | Scaffold new project from starter theme |
| `/wp-demo` | Create demo HTML for client approval |
| `/wp-polish [path]` | Normalize external HTML into plugin-compatible demo |
| `/wp-header` | Build header with nav, logo, language switcher |
| `/wp-footer` | Build footer from settings page fields |
| `/wp-section <name>` | One-shot section: ACF fields + template + CSS |
| `/wp-page <type>` | Page template generator (blog, legal, 404, generic, custom) |
| `/wp-settings` | Extend the settings page with new fields |
| `/wp-responsive-check` | Responsive validation at 5 viewports |
| `/wp-finalize` | Pre-delivery validation checklist |

## Architecture

### Skills (auto-invoked, encode best practices)

| Skill | Purpose |
|-------|---------|
| `wp-theme-standards` | WordPress legacy theme best practices (enqueueing, escaping, hooks, security) |
| `wp-bilingual` | i18n methodology using ACF `_suffix` pattern with transparent helpers |
| `wp-css-system` | CSS design system: custom properties, BEM naming, scales |
| `wp-demo` | Demo HTML creation methodology |
| `wp-responsive` | Mobile-first responsive patterns, fluid typography, touch targets |

### Agents (specialized subagents dispatched by commands)

| Agent | Role |
|-------|------|
| `wp-template` | PHP/WordPress template specialist — generates template parts, pages, header, footer |
| `wp-css` | CSS design system specialist — BEM naming, custom properties, responsive |
| `wp-acf` | ACF/SCF field architect — programmatic field definitions with bilingual support |

### Starter Theme

Minimal boilerplate copied by `/wp-init`. Includes:

- **i18n layer** — `prefix_get_field()`, `prefix_get_repeater()`, `prefix_t()`, `prefix_e()`, language detection (URL → cookie → browser → default)
- **Settings page** — Tabs: General, Header, Footer, Contact, Address, Social, Legal, Designer, Spanish Translations
- **CSS foundation** — Reset, custom property placeholders (colors, spacing, typography, shadows), utilities
- **JS base** — Language switcher, mobile nav, scroll animations, sticky header
- **ACF auto-loader** — `fields/*.php` files loaded automatically via `acf/init` hook

Placeholder tokens (`__starter__`, `__STARTER__`, `__STARTER_NAME__`) are replaced with the project name/slug during init.

## Conventions

### Field Naming

| Pattern | Example |
|---------|---------|
| Field names | `<section>_<element>` → `hero_title` |
| Repeaters | `<section>_<plural>` → `services_cards` |
| Subfields | `<element>` (no prefix) → `title`, `icon` |
| Field keys | `field_<section>_<element>` → `field_hero_title` |
| Group keys | `group_<section>` → `group_hero` |
| Bilingual | Append `_<lang>` → `hero_title_es` |

### CSS

- Custom properties for all design tokens (never hardcode)
- BEM naming: `.block__element--modifier`
- Mobile-first: base styles for mobile, `min-width` media queries for larger
- Section delimiters: `/* ============ Section: Hero ============ */`

### Templates

- Always use `prefix_get_field()`, never raw `get_field()`
- Fallback pattern: `$value = prefix_get_field('field') ?: 'Default';`
- All output escaped: `esc_html()`, `esc_url()`, `esc_attr()`

## Tech Stack

- **WordPress** legacy theme (no blocks, no FSE)
- **ACF/SCF** for custom fields (programmatic, one file per section)
- **Vanilla CSS** with custom properties + BEM (no build tools)
- **Vanilla JS** (no frameworks)
- **Bilingual** via field suffix pattern (supports N languages, optimized for EN/ES)

## External Dependencies

The `/wp-demo` command works best with these skills installed. All other commands work independently.

| Skill | Repository | Install |
|-------|-----------|---------|
| `frontend-design` | [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins) | `/plugin install frontend-design@anthropics-claude-code` |
| `ui-ux-pro-max` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` |
