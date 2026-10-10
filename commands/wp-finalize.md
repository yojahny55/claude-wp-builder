---
description: Pre-delivery checklist — validates escaping, bilingual coverage, responsive design, menus, and theme requirements
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# WP Finalize — Pre-Delivery Checklist

Run a comprehensive validation checklist on the theme before delivery. This command does NOT fix issues — it reports them so you can address them.

## Step 1: Read Project Context

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

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

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/bilingual.md` now and follow it in order.

---

### Check 3: Responsive Breakpoints

Branch on the project's `Template:` (read it from `.claude/CLAUDE.md`):

- If `Template:` is `basic`: read `assets/css/styles.css` and check for media queries.
  1. Search for `@media` rules
  2. Verify queries exist for at least 3 of the four:
     - `576px`
     - `768px`
     - `1024px`
     - `1440px`
  3. Check each major section (HEADER, FOOTER, and every SECTION delimiter) has at least one responsive media query

- If `Template:` is `tailwind`: there is no `assets/css/styles.css` to read — the
  Tailwind convention check below fails delivery if one exists — and hand-written
  `@media` is forbidden by `skills/wp-tailwind-system/SKILL.md`. Verify responsive
  coverage on the template's own terms instead: grep `template-parts/`,
  `header.php` and `footer.php` for Tailwind responsive prefixes (`sm:`, `md:`,
  `lg:`, `xl:`, `2xl:`). The nav collapse, the home hero and every section
  template must carry at least one responsive prefix. Flag any hand-written
  `@media` block found in theme CSS as a convention violation.

**PASS** if breakpoints are covered on the template's own terms. **FAIL** with missing breakpoints or sections without responsive rules.

**Cross-engine contours (both templates).** Verification renders Chromium and, when a build
exists, Linux Firefox; neither shows the notched corners Firefox on Windows draws on a thin
rounded border. Run the static guard over the theme and, when present, the demo:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/css-contour-lint.mjs" <theme-dir> [<demo-dir>]
```

It fails on a 1px `border` + `border-radius` on a transparent or white control (outline
button, focused or error field, ringed icon link: draw it with
`box-shadow: inset 0 0 0 1px <color>`), on `drop-shadow` over a bordered rounded ring, and on
a `type="search"` whose native clear button is not hidden (Chromium shows it, Firefox never
does; with a custom clear control Chromium shows two). Each finding is a visual change to
the site: report it with its file and line and ask before changing it.

---

### Check 4: Theme Structure

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/theme-structure.md` now and follow it in order.

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

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/wp-cli-runtime.md` now and follow it in order.

---

### Check 8: GEO & agent-readiness (report only)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/geo.md` now and follow it in order.

---

### Tailwind convention (tailwind template only)

Skip when `Template:` is `basic`, or when it is anything other than `tailwind`
— a `cinematic` project has its own `assets/css/cinematic.css`, not the
Tailwind tree. When `Template:` is `tailwind`, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh" <theme-dir>
```

The script lives in the plugin, not in the project. `/wp-finalize` runs with the
working directory set to the user's WordPress project, so a bare relative `bin/…`
path resolves to nothing there and exits 127 — always invoke it through
`${CLAUDE_PLUGIN_ROOT}`.

It fails the delivery on: a leftover `assets/css/styles.css`, an empty or
comment-only `.css`, a `.css` with no live `@import` in `main.css` — a commented-out
one does not count, because the file then ships unbuilt — any directory under
`assets/css/src/tailwindcss/` other than `base`, `components`, `layouts` and
`utilities`, **including one nested inside those four**, an inline `<style>` block in
a template, or a compiled theme whose templates carry class attributes but no Tailwind
utilities among them.

That last rule scales to the theme instead of demanding a fixed three templates: it
wants utilities in every class-carrying template up to a ceiling of three, so a
correct two-template theme passes it. Fix every finding before delivering — each one
means part of the build fell back to the plain-CSS path, and none of them is a known
false positive on a correct theme.

---

### Demo-parity gate — Layer 1 (static)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/parity-static.md` now and follow it in order.

---

### Demo-parity gate — Layer 2 (WP-CLI, when WordPress is reachable)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/parity-wpcli.md` now and follow it in order.

---

### Demo-parity gate — Layer 3 (measured visual parity, claude-in-chrome)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/parity-visual.md` now and follow it in order.

---

### Craft gate (craft mode only)

When `.wp-create.json` records `"demo mode": "craft"`, run
`/wp-demo-verify <live-site-url>` against the built theme, not against the demo.
Dead scroll or horizontal overflow at any width is a **fail**: the approved demo
moved and the shipped page does not. Report the findings and the contact sheet
path alongside the rest of the checklist.

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

[PASS] Tailwind convention
  No leftover assets/css/styles.css, no empty or comment-only .css, every .css
  really imported by main.css, no unsanctioned or nested directory, utilities
  present in the markup.
  (Skipped when Template: is basic)

[PASS] GEO & agent-readiness
  Raw-HTML content and heading order, metadata, JSON-LD identity, robots AI policy,
  sitemap lastmod, trust anchors, 404 status, well-known discovery, and llms.txt
  all verified.

---
Result: 5/9 checks passed — 4 issues found (with .wp-create.json, tailwind template)
Result: 5/7 checks passed — 2 issues found (without .wp-create.json, basic template)

Note: two checks are conditional. Check 7 (WP-CLI Runtime Validation) only runs when
`.wp-create.json` exists, and the Tailwind convention check only runs when `Template:`
is `tailwind`. The denominator is 7, 8 or 9 accordingly — count the checks you actually
ran, and never report a total that omits a check that did run.

Issues to fix:
1. Add Spanish field variants in fields/hero.php
2. Replace get_field() with prefix_get_field() in section-about.php
3. Create template-parts/section-pricing.php or remove the reference
```

If all checks pass:
```
---
Result: Ready to deliver! All 9 checks passed. (8/8 on the basic template, 7/7 if
there is also no .wp-create.json — state the denominator you actually ran)
```
