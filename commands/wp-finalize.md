---
description: Pre-delivery checklist — validates escaping, bilingual coverage, responsive design, menus, and theme requirements
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# WP Finalize — Pre-Delivery Checklist

Run a comprehensive validation checklist on the theme before delivery. This command does NOT fix issues — it reports them so you can address them.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (all configured languages)
- **Theme directory path**

If `.claude/CLAUDE.md` does not exist, tell the user to run `/wp-init` first and stop.

## Step 2: Determine Theme Directory

Use the theme directory from `.claude/CLAUDE.md`. Verify it exists. If not, search for it under `wp-content/themes/`.

## Step 3: Run All Validation Checks

Run each check category using Grep and Glob. Track pass/fail status and collect issues.

---

### Check 1: Escaping Validation

Search all `.php` files in the theme directory for unescaped output:

1. **Find `echo` statements that are NOT followed by `esc_html`, `esc_url`, `esc_attr`, `wp_kses_post`, `wp_kses`, or `wp_kses_allowed_html`:**
   - Search pattern: `echo\s+\$` (echo followed directly by a variable)
   - Search pattern: `echo\s+[^e][^s][^c]` and exclude safe functions
   - Exclude: `echo esc_html`, `echo esc_url`, `echo esc_attr`, `echo wp_kses`

2. **Allowlist:** These are safe and should NOT be flagged:
   - `echo get_template_part` (no output)
   - `echo wp_nav_menu` (self-escaping)
   - `echo get_search_form` (self-escaping)
   - `the_content()`, `the_title()`, `the_excerpt()` (WordPress auto-escapes)

**PASS** if no unescaped echo statements found. **FAIL** with file:line list if any found.

---

### Check 2: Bilingual Coverage

For each configured language (e.g., `en`, `es`):

1. **Field files check:** Glob `fields/*.php`, for each file search for field names ending in `_en`. Verify corresponding `_es` (or other language) variants exist.

2. **Template helper check:** Search all template `.php` files for `get_field(` calls that are NOT wrapped in `prefix_get_field()`. The raw `get_field()` bypasses bilingual logic.
   - Search pattern: `get_field\(` but NOT `prefix_get_field\(`
   - Exclude: files in `vendor/`, `node_modules/`, `inc/i18n.php` (the helper itself)

**PASS** if all fields have all language variants and no raw `get_field()` in templates. **FAIL** with details.

---

### Check 3: Responsive Breakpoints

Read `assets/css/styles.css` and check for media queries:

1. Search for `@media` rules
2. Verify queries exist for these breakpoints (at least 3 of 5):
   - `576px`
   - `768px`
   - `1024px`
   - `1440px`
3. Check each major section (HEADER, FOOTER, and every SECTION delimiter) has at least one responsive media query

**PASS** if breakpoints are covered. **FAIL** with missing breakpoints or sections without responsive rules.

---

### Check 4: Theme Structure

Verify required WordPress theme files and configurations:

1. **style.css** exists at theme root with proper headers (Theme Name, Version, Description, Author, Text Domain)
2. **index.php** exists (required WordPress fallback)
3. **screenshot.png** exists (theme preview image)
4. **SCF/ACF dependency:** Check `functions.php` or `inc/theme-setup.php` for SCF/ACF dependency notice or check
5. **register_nav_menus** is called in `inc/theme-setup.php` with per-language locations

**PASS** if all present. **FAIL** listing missing items.

---

### Check 5: Content Templates

1. **404.php** exists
2. **Blog templates** (if blog is part of the project): `archive.php`, `single.php` exist
3. **get_template_part() references:** For every `get_template_part()` call in any `.php` file, verify the referenced template-part file actually exists
4. **front-page.php** exists (if this is a site with a static front page)

**PASS** if all template references resolve. **FAIL** listing broken references or missing templates.

---

### Check 6: Settings Page

1. **acf_add_options_page** (or `acf_add_options_sub_page`) is called somewhere in `functions.php` or `inc/` files
2. **fields/settings.php** exists and is not empty
3. **Settings file is included** — check that `fields/settings.php` is `require`d or `include`d from `functions.php` or another loaded file

**PASS** if settings page is properly registered and has fields. **FAIL** with details.

---

### Check 7: WP-CLI Runtime Validation (when `.wp-create.json` exists)

If `.wp-create.json` exists in the project, read `wp_cli.wrapper` and run runtime checks:

1. **Pages exist with correct templates:**
   ```bash
   $WP post list --post_type=page --format=table
   ```
   Verify each page referenced in `front-page.php` `get_template_part()` calls has a corresponding WordPress page.

2. **Menus assigned to locations:**
   ```bash
   $WP menu location list --format=table
   ```
   Verify all registered locations (primary_en, primary_es, footer_en, footer_es) have menus assigned.

3. **ACF fields return values:**
   For each section's field file in `fields/`, extract the primary field name and verify:
   ```bash
   $WP eval "echo get_field('<section>_title', 'option') ? 'OK' : 'EMPTY';"
   ```

4. **Permalinks work:**
   ```bash
   $WP rewrite flush
   ```

5. **No PHP errors:**
   ```bash
   $WP eval "error_reporting(E_ALL); echo 'Clean';"
   ```
   Also check `wp-content/debug.log` for recent errors.

6. **All plugins active:**
   ```bash
   $WP plugin list --status=active --format=table
   ```
   Compare against `plugins.installed` in manifest.

**PASS** if all runtime checks succeed. **FAIL** with details.

---

## Step 4: Print Report

```
=== WP Finalize Report ===

[PASS] Escaping validation
  All echo statements properly escaped.

[FAIL] Bilingual coverage
  - fields/hero.php: missing hero_title_es variant
  - template-parts/section-about.php:12: raw get_field('about_title') used

[PASS] Responsive breakpoints
  Media queries found for: 576px, 768px, 1024px, 1440px

[PASS] Theme structure
  All required files present.

[FAIL] Content templates
  - template-parts/section-pricing.php referenced but does not exist

[PASS] Settings page
  Options page registered, fields/settings.php loaded.

[PASS] WP-CLI runtime validation
  Pages, menus, ACF fields, permalinks, PHP errors, and plugins all verified.
  (Skipped if .wp-create.json not found)

---
Result: 4/7 checks passed — 3 issues found (with .wp-create.json)
Result: 4/6 checks passed — 2 issues found (without .wp-create.json)

Note: Check 7 (WP-CLI Runtime Validation) only runs when `.wp-create.json` exists.
If absent, the total is out of 6 instead of 7.

Issues to fix:
1. Add Spanish field variants in fields/hero.php
2. Replace get_field() with prefix_get_field() in section-about.php
3. Create template-parts/section-pricing.php or remove the reference
```

If all checks pass:
```
---
Result: Ready to deliver! All 7 checks passed. (or 6/6 if no .wp-create.json)
```
