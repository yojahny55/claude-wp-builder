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
3. **Settings group resolves at runtime** — the `acf/init` loader bootstraps `fields/*.php` and persists them to `acf-json/`, so don't grep for an individual `require` of settings.php. Instead confirm the group is live:
   ```bash
   $WP eval "\$g=acf_get_field_group('group_settings'); echo \$g && count(acf_get_fields('group_settings')) ? 'OK' : 'MISSING';"
   ```
4. **Field groups are dashboard-editable (Local JSON)** — verify no field group is stuck PHP-local (`ID=0`, invisible in the admin list):
   ```bash
   $WP eval "\$n=0; foreach(acf_get_field_groups() as \$g){ if((\$g['local']??'')==='php') \$n++; } echo \$n===0 ? 'OK: all groups editable' : \"FAIL: \$n php-local groups\";"
   ```
   If any are php-local, `acf-json/` is missing or unwritable — confirm the loader ran and the directory is writable.

**PASS** if the settings group resolves, has fields, and no group is php-local. **FAIL** with details.

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

### Demo-parity gate — Layer 1 (static)

Layer 1 of the 3-layer demo-parity gate (static / theme-file level). Runs against the theme's CSS, templates, and the manifest produced by `/wp-normalize` (`section.backgrounds`, `section.fonts`, `section.block`). Every check below is **critical** — a FAIL here blocks delivery.

1. **Undefined `var(--x)` scan** — `critical`

   Grep all theme CSS for `var(--` usages. For each custom property referenced, verify a matching definition exists in a `:root { }` block or `@theme { }` block (Tailwind starter). List any `var(--x)` used with no matching definition — these render as the property's fallback (or nothing) in the browser, silently breaking colors/spacing/fonts.

   **PASS** if every `var(--x)` resolves. **FAIL** with file:line and the undefined property name.

2. **CSS collision scan** — `critical`

   Grep all section CSS files for class selectors. Flag two cases:
   - The **same class block** (identical selector) defined in 2+ section files with **conflicting declarations** (different values for the same property).
   - A **known-generic block** (e.g. `.services`, `.hero`, `.card`, `.acc`, `.accordion`) used **unscoped**, outside its assigned owner section, where it could bleed into other pages.

   **IMPORTANT nuance:** a shared component class used under **different page-scoped parents** (e.g. `.sp-services .accordion` vs `.condos .accordion`) is **correct usage, not a collision** — the parent scope makes each rule apply only within its own section. The scan flags **unscoped** redefinition only (a bare `.accordion { }` with no page-scoped ancestor selector competing with another bare `.accordion { }`), never scoped-but-shared component classes.

   **PASS** if no unscoped collisions found. **FAIL** listing the colliding selector, the files/lines involved, and whether it's a raw conflict or an unscoped-generic-block issue.

3. **Font parity** — `critical`

   For every `font-family` used in theme CSS: verify it is either (a) bundled — a matching `@font-face` declaration exists AND the referenced font file is present under `assets/fonts/`, or (b) an intentional system-font stack (e.g. `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`) with no `@font-face` expected.

   Then, in reverse: for every `@font-face` recorded in the manifest's `section.fonts` (captured from the demo by `/wp-normalize`), verify a carried counterpart `@font-face` exists in the theme CSS with the file present in `assets/fonts/`.

   **PASS** if every used font resolves and every demo font was carried over. **FAIL** listing missing font files or demo fonts dropped during build.

4. **Background-image presence** — `critical`

   For every `background:url()` / `background-image:` entry recorded in the manifest's `section.backgrounds` (captured from the demo), verify it is present in the theme CSS as a transcribed `background:url()` rule, or seeded as an ACF image field on that section.

   **PASS** if every demo background is accounted for. **FAIL** listing which section's background was dropped.

5. **Nav-contract match** — `critical`

   Read the header CSS (`.nav`, `.nav__menu`, `.nav__item`, etc. — see the nav-class contract in `skills/wp-theme-standards/SKILL.md`). For each class the header CSS targets, verify the class appears in the actual `wp_nav_menu()` walker output (check `inc/` for a custom `Walker_Nav_Menu` or the `wp_nav_menu` args' `menu_class`/`items_wrap`).

   **PASS** if every CSS-targeted nav class exists in the walker output. **FAIL** listing CSS classes with no matching walker output (dead selectors — usually the sign the walker was never updated to match the CSS).

**PASS** if all 5 static checks pass. **FAIL** listing every offending check with its details — do not stop at the first failure, collect all of them so the user gets one full punch list.

---

### Demo-parity gate — Layer 2 (WP-CLI, when WordPress is reachable)

Layer 2 runs when `.wp-create.json` exists and WordPress is reachable (reuse `$WP` from Check 7). Every check below is **critical**.

1. **`site_logo` + critical options non-empty** — `critical`

   ```bash
   $WP eval "echo get_field('site_logo','option') ? 'OK' : 'EMPTY';"
   $WP option get blogname
   $WP option get blogdescription
   ```
   The logo is stored as the ACF options field `options_site_logo` (seeded via `update_field('site_logo', $LOGO_ID, 'option')`), NOT the WordPress core `site_logo` option — read it with `get_field('site_logo','option')`, matching the `inner_hero_image` check below. **PASS** if `site_logo` and every other critical site option return a non-empty value. **FAIL** listing which option is empty/unset.

2. **`inner_hero_image` seeded per in-scope page** — `critical`

   For each in-scope page (from the manifest / scope file), find its post ID and check the ACF field:
   ```bash
   $WP post list --post_type=page --format=ids
   $WP eval "echo get_field('inner_hero_image', <post_id>) ? 'OK' : 'EMPTY';"
   ```
   **PASS** if every in-scope page has `inner_hero_image` seeded. **FAIL** listing which pages are missing it.

3. **Menus assigned to locations** — `critical`

   ```bash
   $WP menu location list --format=table
   ```
   **PASS** if every registered nav location (e.g. `primary_en`, `primary_es`, `footer_en`, `footer_es`) has a menu assigned. **FAIL** listing unassigned locations.

4. **In-scope pages exist** — `critical`

   ```bash
   $WP post list --post_type=page --format=table
   ```
   **PASS** if every in-scope page from the manifest has a corresponding WordPress page. **FAIL** listing missing pages.

**PASS** if all 4 checks pass. **FAIL** listing every offending check with its details. If WordPress is not reachable (no `.wp-create.json`, or `$WP` calls fail to connect), **SKIP** Layer 2 with a noted reason — this is not a failure, but Layers 1 and 3 still gate.

---

### Demo-parity gate — Layer 3 (measured visual parity, claude-in-chrome)

Layer 3 is the backstop that measures **computed styles**, not just screenshots, so divergence is caught at build time instead of weeks later.

1. **Detect claude-in-chrome availability.** Call the extension's tabs/context tool (e.g. `tabs_context_mcp`). If the claude-in-chrome MCP tools are unavailable, not connected, or the built site / demo URL is unreachable, **SKIP Layer 3 with a noted reason — this is NOT a failure.** Layers 1-2 still gate delivery on their own.

2. **Load demo + built page.** For each in-scope page, navigate to the demo URL and to the corresponding built (local WordPress) URL.

3. **Measure computed styles.** Via `javascript_tool`, run `getComputedStyle()` on matching selectors on both pages (hero, nav, section backgrounds, headings, buttons) and compare the results.

4. **Classify every delta:**
   - **Hard delta (BLOCK)** — critical:
     - A `background-image` present in the demo is missing in the build.
     - `color` / `background-color` resolves to a **different hex** between demo and build.
     - A fixed `height` / `width` differs by **more than 3% or 8px** (whichever is larger).
     - `font-family` resolves to a **system fallback stack** instead of the demo's actual font face.
   - **Soft delta (WARN, non-blocking):**
     - Sub-pixel geometry differences.
     - Antialiasing / font-smoothing rendering variance.
     - Any value within the 3%/8px threshold.

5. **Confirm logo + hero rendering.** Verify the logo renders as an actual image (not a text fallback) and that hero section background images are visible (not blank/broken).

**PASS** if no hard deltas found (soft deltas are reported but do not block). **FAIL** listing every hard delta (selector, property, demo value vs. built value). **SKIP** (not a failure) if claude-in-chrome or either URL is unavailable — state the reason (e.g. "claude-in-chrome not connected", "demo URL unreachable", "built site not running").

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
