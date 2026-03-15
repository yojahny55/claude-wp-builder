---
description: Scaffold a new WordPress project — copies starter theme, replaces placeholders, generates .claude/CLAUDE.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-name]"
---

# WP Init — Project Scaffolding

Scaffold a new WordPress project from the starter theme, configure i18n, and generate the project CLAUDE.md.

## Step 0: Check for Existing Demo

Before asking any project questions, check if a demo already exists.

### If `$ARGUMENTS` looks like a file path (ends in `.html` or `.htm`):

1. Copy the file to `demo/index.html` (create `demo/` directory if needed).
2. Proceed to the **Demo-First Path** below — skip the confirmation prompt since the user's intent is clear.
3. If both `demo/index.html` already exists AND a path argument is given, the path argument takes priority (copies over the existing demo).

### If `$ARGUMENTS` is NOT a file path (or is empty):

1. Check if `demo/index.html` exists in the current working directory.
2. If found, ask the user:
   > "I found an existing demo at `demo/index.html`. Would you like to use it as the basis for this project? (Y/n)"
3. If the user confirms, proceed to the **Demo-First Path**.
4. If the user declines or no demo exists, proceed to **Step 1: Gather Project Details** (the normal flow).

### Demo-First Path

**Step D1 — Delimiter check:**
- Read `demo/index.html` and scan for `<!-- ============ SECTION:` delimiters.
- If NO delimiters are found, inform the user:
  > "This demo doesn't have section delimiters. Running /wp-polish to prepare it..."
- Run the `/wp-polish` command on `demo/index.html`, then re-read the polished file.
- If SOME delimiters exist but sections appear to be missing them, also run `/wp-polish`.

**Step D2 — Extract project info from demo:**

Parse the demo HTML and extract as much as possible:

| Field | How to extract |
|-------|---------------|
| Project name | `<title>` tag content (remove suffixes like " — Home", " \| Homepage"). Fall back to `<h1>` content, then folder name. |
| Slug | Slugify the project name (lowercase, hyphens for spaces, strip special chars). |
| Industry | Analyze headings and body text for industry keywords. Examples: "patients"/"medical" → healthcare, "cases"/"legal" → law, "menu"/"dishes" → restaurant, "portfolio"/"design" → creative. If uncertain, set to "general". |
| Primary language | Read the `<html lang="">` attribute. Fall back to content language detection. Default: `en`. |
| Secondary language | Look for `lang=""` attributes on sub-elements, or content in a second language. Default: `es`. |
| Sections | List all section names from `<!-- ============ SECTION: Name ============ -->` delimiters (exclude Header and Footer). |
| Color palette | Read `:root` CSS custom properties for `--color-*` values. If no `:root`, scan for dominant colors in inline styles. |
| Fonts | Read `font-family` declarations from `:root` or `<style>`. Check for Google Fonts `<link>` tags. |

**Step D3 — Present pre-filled defaults:**

Show all extracted values in a summary and ask the user to confirm or adjust:

```
=== Extracted from Demo ===
  Project name:     Kairo Consulting
  Theme slug:       kairo-consulting
  Industry:         consulting
  Primary lang:     en
  Secondary lang:   es
  Sections:         Hero, Services, About, Testimonials, Contact
  Colors:           #1a5632, #c9a84c, #fafafa, #262626
  Fonts:            Inter, Playfair Display

Confirm these values? (Enter to accept, or type the field name to change it)
```

The user can override any field. Once confirmed, use these values for the rest of the init process.

**Step D4 — Continue with normal scaffolding:**

Proceed to **Step 2: Locate wp-content/themes/** and continue the normal flow (Steps 2-8) using the confirmed values from Step D3 instead of asking for them in Step 1.

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

**If this is a demo-first project** (demo existed before init), add the following to the generated CLAUDE.md:

After the `## Project Details` section, add:

```markdown
## Demo
- **Source:** Existing demo (original preserved at demo/original.html)
- **Sections:** <comma-separated list of detected sections>
- **Colors:** <extracted color values>
- **Fonts:** <extracted font families>
```

And in the `## Workflow` section, replace:
```
1. `/wp-demo` — Create a demo HTML mockup for client approval
```
With:
```
1. ~~`/wp-demo`~~ — Demo already exists, skip to /wp-header
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

**If this is a demo-first project**, adjust the summary:

```
=== Project Initialized (from existing demo) ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
Sections:   <detected sections>
CLAUDE.md:  <path-to-claude-md>
Demo:       demo/index.html (original at demo/original.html)

Next step: Run /wp-header to build the site header.
```
