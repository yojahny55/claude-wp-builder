---
description: Scaffold a new WordPress project — copies starter theme, replaces placeholders, generates .claude/CLAUDE.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-name]"
---

# WP Init — Project Scaffolding

Scaffold a new WordPress project from the starter theme, configure i18n, and generate the project CLAUDE.md.

## Step 1: Gather Project Details

If `$ARGUMENTS` is provided, use it as the project name. Then prompt the user for any missing details:

- **Project name** (display name, e.g., "Kairo Consulting")
- **Theme slug** (lowercase-hyphenated, e.g., "kairo-consulting") — suggest one derived from the project name
- **Primary language** (default: `en`)
- **Secondary language(s)** (default: `es`, comma-separated if multiple)
- **Client industry** (e.g., "consulting", "restaurant", "healthcare")
- **Brief description** (one sentence describing the site)

If `$ARGUMENTS` was the project name, still ask for the remaining fields.

## Step 2: Locate wp-content/themes/

Search for the `wp-content/themes/` directory:

1. Check if `./wp-content/themes/` exists in the current working directory
2. Check if `../wp-content/themes/` exists (parent directory)
3. Check if `../../wp-content/themes/` exists (grandparent)
4. If not found, ask the user for the WordPress root path

Store the full path to `wp-content/themes/` for later use.

## Step 3: Copy Starter Theme

Copy the starter theme skeleton to the new theme directory:

```
cp -r ${CLAUDE_PLUGIN_ROOT}/starter-theme/__starter__/ <themes-dir>/<slug>/
```

Where `<slug>` is the theme slug from Step 1.

## Step 4: Replace All Placeholders

Recursively replace placeholders in ALL files within the new theme directory:

1. `__starter__` → theme slug (e.g., `kairo-consulting`)
2. `__STARTER__` → theme slug uppercase with underscores (e.g., `KAIRO_CONSULTING`)
3. `__STARTER_NAME__` → project display name (e.g., `Kairo Consulting`)

Use `find` + `sed` or equivalent to do this across all files (`.php`, `.css`, `.js`, `.json`, etc.).

## Step 5: Configure i18n

Edit `inc/i18n.php` in the new theme directory:

- Set the `SUPPORTED_LANGS` constant to an array containing all specified languages (primary + secondary). Example: `['en', 'es']`
- Set the `DEFAULT_LANG` constant to the primary language. Example: `'en'`

## Step 6: Configure Theme Setup

Edit `inc/theme-setup.php` in the new theme directory:

- In `register_nav_menus()`, register menu locations for EACH language. Pattern:
  - `'primary_en' => 'Primary Menu (English)'`
  - `'primary_es' => 'Primary Menu (Spanish)'`
  - `'footer_en' => 'Footer Menu (English)'`
  - `'footer_es' => 'Footer Menu (Spanish)'`

## Step 7: Generate .claude/CLAUDE.md

Create `.claude/CLAUDE.md` at the **project root** (the directory containing `wp-content/`). Content:

```markdown
# <Project Name>

## Project Details
- **Theme slug:** <slug>
- **Function prefix:** <slug_with_underscores>_ (e.g., kairo_consulting_)
- **Primary language:** <primary_lang>
- **Secondary language(s):** <secondary_langs>
- **Industry:** <industry>
- **Description:** <description>

## Theme Directory
<full-path-to-theme>

## Conventions
- All PHP functions prefixed with `<prefix>`
- ACF field names: `<section>_<element>` (e.g., `hero_title`)
- ACF repeater names: `<section>_<plural>` (e.g., `services_cards`)
- ACF repeater subfields: `<element>` only, no section prefix
- ACF field keys: `field_<section>_<element>`, group keys: `group_<section>`
- CSS class naming: BEM — `.block__element--modifier`
- Template parts: `template-parts/section-<name>.php`
- Use `<prefix>get_field()` for bilingual fields, never raw `get_field()`
- Use `<prefix>get_repeater()` for bilingual repeaters
- Use `<prefix>e()` for translated static strings

## Workflow
1. `/wp-demo` — Create a demo HTML mockup for client approval
2. `/wp-header` — Build header.php from the demo
3. `/wp-footer` — Build footer.php from the demo
4. `/wp-section <name>` — Build each section (ACF fields + template + CSS)
5. `/wp-page <type>` — Generate page templates (blog, generic, legal, 404)
6. `/wp-settings` — Extend the settings/options page
7. `/wp-responsive-check <url>` — Validate responsive design
8. `/wp-finalize` — Pre-delivery checklist
```

## Step 8: Activate Theme (Optional)

Check if WP-CLI is available by running `wp --info` or `which wp`. If available:

```bash
wp theme activate <slug> --path=<wordpress-root>
```

If WP-CLI is not available, skip this step silently.

## Step 9: Print Summary

Print a summary:

```
=== Project Initialized ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
CLAUDE.md:  <path-to-claude-md>

Next step: Run /wp-demo to create a demo mockup.
```
