---
description: Scaffold a new WordPress project — copies starter theme, replaces placeholders, generates .claude/CLAUDE.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-name]"
---

# WP Init — Project Scaffolding

Scaffold a new WordPress project from the starter theme, configure i18n, and generate the project CLAUDE.md.

## Step 0.5: Select Starter Template

Ask the user to choose a starter template:

> **Select a starter template:**
> 1. **Tailwind Starter** — Tailwind CSS 4 + WordPress Scripts build pipeline, BrowserSync
> 2. **Cinematic Starter** — Scroll-driven cinematic reel (persistent video stage, scene scrub on desktop, autoplay-loop on mobile). Requires the [cinematic-scroll-kit](https://github.com/yojahny55/cinematic-scroll-kit) skill.

Store the selection as `$TEMPLATE`:
- Option 1 → `tailwind`
- Option 2 → `cinematic`

Default: `tailwind` (if user presses Enter without selecting).

There is no "Basic Starter" any more. `starter-theme/__starter__/` was removed
in 3600552 as superseded by the Tailwind template, but this command kept
offering it as option 1 AND as the Enter-key default — so the most likely path
through `/wp-init` copied a directory that does not exist. Treat `basic` as an
alias for `tailwind` if a caller still passes `--template=basic`, rather than
failing on it.

### If `$TEMPLATE = cinematic`

This branch follows a different scaffolding shape — the page is one continuous reel, not discrete sections. After Step 0.6, dispatch to `/wp-cinematic-init` for the cinematic-specific flow:

1. Resolve `cinematic-scroll-kit` (globally-installed skill → `./.cinematic-kit/` → vendored fallback in `starter-theme/__cinematic__/assets/cinematic-kit/`).
2. If none present, offer: `npx skills add yojahny55/cinematic-scroll-kit -g -y` (recommended). Decline → use vendored fallback.
3. Copy `starter-theme/__cinematic__/` as the theme.
4. Run the `wp-cinematic` agent against `schemas/scene.json` to generate `fields/scenes.php`, `fields/trailing-sections.php` (if hybrid), `inc/seed-cinematic.php`, and per-scene template fragments.
5. Skip the per-section `/wp-section` loop. Author scenes via `/wp-cinematic-scene <n>` and append trailing flex sections via `/wp-section <name> --hybrid` if hybrid mode is on.
6. Seed with `/wp-cinematic-seed` (uses kit sample videos).

Hybrid mode is **on by default** for cinematic — pass `--no-hybrid` to disable trailing sections.

## Step 0.6: Select Custom Fields Plugin

Ask the user to choose a custom fields plugin:

> **Select custom fields plugin:**
> 1. **SCF** (Secure Custom Fields) — Free, community fork
> 2. **ACF Pro** — Premium, requires license

Store the selection as `$CF_PLUGIN`:
- Option 1 → `scf`
- Option 2 → `acf`

Default: `scf` (if user presses Enter without selecting).

## Step 0.7: Select i18n Strategy

Ask the user how the site should handle its languages:

> **Select translation strategy:**
> 1. **Field suffixes** — one page per site, ACF/SCF fields duplicated as `_es`. No extra plugin.
> 2. **Polylang** — one page per language, joined by translation groups. Installs the Polylang plugin.

Store the selection as `$I18N`:
- Option 1 → `suffix`
- Option 2 → `polylang`

Default: `suffix` (if the user presses Enter without selecting).

The default is deliberate. `suffix` is what every existing project uses, so
updating the plugin must not silently change how a new project is built, and
it pulls in no plugin the user did not ask for. Polylang is opt-in.

Skip this question entirely when `$ARGUMENTS` contains `--i18n=suffix` or
`--i18n=polylang`, so `/wp-yolo` and other non-interactive callers can pass it
straight through.

## Pre-Step: Check for `.wp-create.json` Manifest

Before anything else, check if `.wp-create.json` exists in the current working directory or parent directories (same search pattern as `wp-content/themes/`).

### If `.wp-create.json` exists:

Read the manifest and extract:
- `project.name` → use as project name (skip asking in Step 1)
- `project.slug` → use as theme slug
- `languages.primary` → use as primary language
- `languages.additional` → use as secondary language(s)
- `wp_cli.wrapper` → use for WP-CLI commands instead of bare `wp`
- `project.domain` → use for site URL references

**Skip Step 1 entirely** — all project details come from the manifest.

### If `.wp-create.json` does NOT exist:

Proceed with the normal flow (Step 0 → Step 1 → ...). No changes to existing behavior.

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

**Step D4 — Inject colors/fonts into theme (template-aware):**

- If `$TEMPLATE` is `tailwind`: replace values in the `@theme` block in
  `assets/css/src/tailwindcss/main.css`:

  The `@theme` block lives in the compiled entry point `tailwindcss/main.css`;
  mapping the colours into any other file silently ships the default palette.

  | Extracted | Target variable |
  |-----------|----------------|
  | Primary/brand color | `--color-primary` |
  | Secondary color | `--color-secondary` |
  | Accent/CTA color | `--color-accent` |
  | Dark text/bg color | `--color-dark` |
  | Light bg color | `--color-light` |
  | Muted/gray color | `--color-gray` |
  | Heading font | `--font-primary` |
  | Body font | `--font-secondary` |

  If fewer than 6 colors are extracted, leave unmatched variables at their defaults.

  Then **run `/wp-tailwindify`** on the demo — do not merely suggest it. On the
  tailwind template the build transcribes from the demo, so a plain-CSS demo yields a
  plain-CSS theme. Whether to skip is decided on positive evidence that the demo is
  already Tailwind-native, never on the absence of a `<style>` block: a demo that keeps
  its rules in an external stylesheet carries no inline CSS at all and still has to be
  converted. This is `/wp-yolo` Step 2.6's rule, stated here in the same terms on
  purpose — do not restate it a third way:

  - **Plain-CSS evidence — any one of these means convert.** A `<style>` block; a static
    `style="` attribute; or a `<link rel="stylesheet"` pointing at the project's own
    `.css` file — a relative path (`assets/styles.css`), a site-rooted path
    (`/css/main.css`) or an absolute URL on the project's own domain all count the same,
    because the delivery route is not what matters. Only three hosts are exempt:
    `fonts.googleapis.com`, `fonts.gstatic.com` and `cdn.tailwindcss.com`. A `<link>` to
    any of those is not plain-CSS evidence; every other stylesheet `<link>` is.
  - **Tailwind evidence — what an already-converted demo looks like.** Its `class`
    attributes are predominantly Tailwind utilities: layout (`flex`, `grid`, `hidden`),
    spacing and sizing (`px-4`, `mt-8`, `w-full`), typography (`text-lg`, `font-bold`),
    colour (`bg-slate-900`, `text-white`) and variant prefixes (`md:`, `hover:`).
    Semantic or BEM class names (`site-header__logo`, `hero`, `card__title`) are the
    plain-CSS shape, not Tailwind evidence.
  - **Skip only on Tailwind evidence and no plain-CSS evidence.** Then, and only then,
    leave the demo alone and report `demo already tailwind-native — conversion skipped`.
    Everything else converts, a demo you cannot classify with confidence included: a
    redundant conversion costs one pass over markup already in the target form, while a
    wrong skip ships a plain-CSS theme and reports success. Say which case applied.

  `/wp-yolo` Step 2.6 repeats this check, so a skip here is safe.

**Step D5 — Continue with normal scaffolding:**

Proceed to **Step 2: Locate wp-content/themes/** and continue the normal flow (Steps 2-9) using the confirmed values from Step D3 instead of asking for them in Step 1.

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

Copy the selected starter theme to the new theme directory:

- If `$TEMPLATE` is `tailwind` (or the legacy alias `basic`):
  ```
  cp -r ${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/ <themes-dir>/<slug>/
  ```

- If `$TEMPLATE` is `cinematic`:
  ```
  cp -r ${CLAUDE_PLUGIN_ROOT}/starter-theme/__cinematic__/ <themes-dir>/<slug>/
  ```

Where `<slug>` is the theme slug from Step 1.

Only the two directories above exist. Copying anything else — `__starter__` in
particular — silently produces an empty theme directory, because `cp -r` on a
missing source fails while the rest of the flow carries on.

## Step 3.5: Wire Motion for the Recorded Demo Mode

Read `demo mode` from `.wp-create.json` (written by `/wp-demo` or `/wp-yolo`). Applies
to the Tailwind template only (the cinematic template has its own motion engine).

- **craft**: keep `motion.js`, the GSAP import in `assets/js/src/index.js`, and the
  `gsap` dependency in `package.json` as copied. If the demo has a
  `<script id="signature">` block, lift its contents into `assets/js/signature.js` and
  enqueue it after the main bundle.
- **plain**: delete `assets/js/src/motion.js`, remove the GSAP import from
  `assets/js/src/index.js` and the `gsap` dependency from `package.json`, and note in
  the summary that `wp-aos-animator` is the animation route for this project.
- If `demo mode` is absent (no `/wp-demo` or `/wp-yolo` run yet), leave `motion.js` in
  place: treat the project as undecided rather than guessing.

## Step 4: Replace All Placeholders

Recursively replace placeholders in ALL files within the new theme directory:

1. `__starter__` → theme slug (e.g., `kairo-consulting`)
2. `__STARTER__` → theme slug uppercase with underscores (e.g., `KAIRO_CONSULTING`)
3. `__STARTER_NAME__` → project display name (e.g., `Kairo Consulting`)
4. `__STARTER_DOMAIN__` → site domain from `.wp-create.json` manifest `project.domain`, or `<slug>.local` if no manifest (Tailwind template only — present in `package.json`)

Use `find` + `sed` or equivalent to do this across all files (`.php`, `.css`, `.js`, `.json`, etc.).

## Step 5: Configure i18n

### If `$I18N = polylang`

Overwrite the suffix-based helper with the Polylang one for this template,
keeping the filename `functions.php` already requires:

```
cp ${CLAUDE_PLUGIN_ROOT}/starter-theme/_i18n-variants/__<template>__.php <theme-dir>/inc/i18n.php
```

Where `__<template>__` is `__tailwind__` or `__cinematic__`, matching
`$TEMPLATE` — the only two starters that exist. Then re-run the placeholder
replacement from Step 4 over this one file, since it was copied in after that
step ran.

If a new starter is ever added, it needs its own variant in
`starter-theme/_i18n-variants/` before it can offer Polylang;
`tests/checks/wp-polylang.sh` fails until it has one, which is the point.

Both files expose the same helper names and signatures, which is what makes
the swap safe — templates call `<prefix>get_field()` and friends and never
`get_field()` directly, so no template, section, header or footer changes.
`tests/checks/wp-polylang.sh` enforces that pairing per template.

### If `$I18N = suffix` (default)

Nothing to do — the starter already ships the suffix helper.

### Both strategies

Edit `inc/i18n.php` in the new theme directory:

- Set the `SUPPORTED_LANGS` constant to an array containing all specified languages (primary + secondary). Example: `['en', 'es']`
- Set the `DEFAULT_LANG` constant to the primary language. Example: `'en'`

#### Then rewrite the field suffix — MANDATORY when the secondary language is not `es`

The starter ships its translation twins hardcoded as `_es`, because it was
written for an English-primary site. `<prefix>get_field()` does NOT read that
suffix: it appends the suffix of the **current non-default language**. So on a
Spanish-primary site the helper looks for `_en` while the field group defines
`_es`, and **every twin field is dead** — the client fills them in and the front
end never reads a single one. This is silent: no error, no empty group, just a
translation tab that does nothing.

Rewrite the suffix wherever it appears — field `name`, field `key`, and the tab
label — so it names the **secondary** language:

```bash
# $SECONDARY is the non-default language, e.g. 'en' on a Spanish-primary site.
[ "$SECONDARY" != "es" ] && \
  find <theme>/fields -name '*.php' \
    -exec sed -i "s/_es'/_${SECONDARY}'/g; s/_es\"/_${SECONDARY}\"/g" {} +
```

Then relabel the tab and the `(ES)` field labels for the real language, and
verify before moving on:

```bash
grep -c "_es" <theme>/fields/*.php     # must be 0 unless the secondary language IS es
grep -c "_$SECONDARY" <theme>/fields/*.php  # must equal the twin count
```

With three or more languages, one twin suffix per secondary language is needed;
the helper resolves whichever is current.

## Step 6: Configure Theme Setup

Edit `inc/theme-setup.php` in the new theme directory.

### If `$I18N = polylang`

Register each menu location ONCE, with no language suffix:

- `'primary' => 'Primary Menu'`
- `'footer' => 'Footer Menu'`

Polylang gives every registered location a per-language slot of its own and
swaps the right menu in at render time. Registering `primary_en` and
`primary_es` as well would produce two competing systems for the same nav.

Also register the theme's static strings so a client can edit them under
**Languages > Strings** instead of in code:

```php
add_action( 'init', function () {
    if ( ! function_exists( 'pll_register_string' ) ) {
        return;
    }
    foreach ( <prefix>get_translations() as $key => $values ) {
        pll_register_string( $key, $values['<primary_lang>'], '<Theme Name>' );
    }
} );
```

### If `$I18N = suffix` (default)

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
- **Template:** <tailwind|cinematic>
- **Custom Fields:** <SCF|ACF Pro>
- **i18n strategy:** <suffix|polylang>
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
- If `basic`: CSS class naming: BEM — `.block__element--modifier`
- If `tailwind`: CSS: Tailwind utility classes; component styles use `@apply` in `assets/css/src/tailwindcss/components/`
- If `tailwind`: Colors/fonts: Defined in `@theme` block in `assets/css/src/tailwindcss/main.css`
- If `tailwind`: Build: `npm run preview` for development, `npm run build` for production
- Template parts: `template-parts/section-<name>.php`
- Use `<prefix>get_field()` for bilingual fields, never raw `get_field()`
- Use `<prefix>get_repeater()` for bilingual repeaters
- Use `<prefix>e()` for translated static strings

## Workflow
1. `/wp-demo` — Create a demo HTML mockup for client approval
2. `/wp-header` — Build header.php from the demo
3. `/wp-footer` — Build footer.php from the demo
4. `/wp-section <name>` — Build each section (ACF fields + template + CSS)
Or: `/wp-yolo <demo-folder>` — build the whole site from an existing HTML demo in one pass.
5. `/wp-page <type>` — Generate page templates (blog, generic, legal, 404)
6. `/wp-settings` — Extend the settings/options page
7. `/wp-responsive-check <url>` — Validate responsive design
8. `/wp-finalize` — Pre-delivery checklist
```

**If `.wp-create.json` manifest exists**, also add the following section to the generated CLAUDE.md (after `## Conventions`):

```markdown
## WP-CLI
- Wrapper: `<wp_cli.wrapper from manifest>`
- Always use this wrapper for all wp commands
- Environment: <environment.type from manifest>
```

**If this is a demo-first project** (demo existed before init), add the following to the generated CLAUDE.md:

After the `## Project Details` section, add:

```markdown
## Demo
- **Source:** Existing demo (unpolished copy preserved at demo/.prepolish/index.html)
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

## Step 8: Gather project docs (if present)

Check if a docs folder exists in the project root. If docs directory exists, run `/wp-context` to extract project
constraints and the scope manifest now (so every later command — especially `/wp-yolo` —
builds with the client's approved scope, integrations like IDX, and constraints in context).
If there is no `docs/` folder, skip this step silently.

## Step 9: Activate Theme and Install Dependencies

### Custom Fields Plugin

- If `$CF_PLUGIN` is `scf`:
  ```bash
  $WP plugin install secure-custom-fields --activate
  ```
  > Note: Verify the correct WordPress.org slug. If it fails, try `developer-starter-templates`.

- If `$CF_PLUGIN` is `acf`:
  ```bash
  $WP eval "echo function_exists('acf_add_options_page') ? 'ACF OK' : 'ACF MISSING';"
  ```
  If ACF is missing, print: "ACF Pro is not installed. Please install it manually from your ACF account."

### Translation Plugin

- If `$I18N` is `polylang`:
  ```bash
  $WP plugin is-active polylang || $WP plugin activate polylang || $WP plugin install polylang --activate
  ```
  Then create the languages, using the same script `/wp-polylang` uses rather
  than a second implementation of the same thing:
  ```bash
  $WP eval-file ${CLAUDE_PLUGIN_ROOT}/skills/wp-polylang/scripts/pll-setup.php <primary_lang> <secondary_lang>
  ```
  Repeat the `pll-setup.php` call for each additional secondary language.
  The script is idempotent — a language that already exists is left alone.

  Then assign the primary language to existing content, or every page created
  later lands with no language at all and Polylang treats it as untranslatable:
  ```bash
  $WP eval "if (function_exists('pll_set_post_language')) { foreach (get_posts(['post_type'=>'any','numberposts'=>-1,'post_status'=>'any','fields'=>'ids']) as \$id) { if (!pll_get_post_language(\$id)) { pll_set_post_language(\$id, '<primary_lang>'); } } }"
  ```

- If `$I18N` is `suffix`: nothing to install.

### Verification (both):
```bash
$WP eval "echo function_exists('acf_add_options_page') ? 'CF OK' : 'CF MISSING';"
```

### Theme Activation

#### If `.wp-create.json` exists:

Use the WP-CLI wrapper from the manifest (stored as `$WP`):

```bash
$WP theme activate <slug>
$WP rewrite flush
```

Then update the manifest: set `theme.initialized` to `true`.

#### If `.wp-create.json` does NOT exist:

Check if WP-CLI is available by running `wp --info` or `which wp`. If available:

```bash
wp theme activate <slug> --path=<wordpress-root>
```

If WP-CLI is not available, skip this step silently.

### Tailwind Build Dependencies

If `$TEMPLATE` is `tailwind`:
```bash
cd <theme-dir> && npm install && npm run build
```
This generates `assets/css/dist/main.css` and `assets/js/dist/index.js` needed for the theme to function.

## Step 9.5: Initialize git repository

The theme directory is the versioned deliverable and `/wp-yolo` requires a git repo
(for a rollback baseline and worktree-based isolation). Initialize one if absent:

```bash
cd <theme-dir>
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  git init -q
  printf 'node_modules/\n.DS_Store\n*.log\n' > .gitignore
  # Tailwind build output is regenerable — ignore dist if this is the tailwind template
  git add -A && git commit -q -m "chore: scaffold <slug> theme from starter"
}
```

Idempotent: if `<theme-dir>` is already inside a git work tree (e.g. the whole
site is versioned), skip init and leave the existing repo untouched.

## Step 10: Print Summary

Print a summary:

```
=== Project Initialized ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Template:   <Tailwind Starter|Cinematic Starter>
CF Plugin:  <SCF|ACF Pro>
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
CLAUDE.md:  <path-to-claude-md>

Next step: Run /wp-demo to create a demo mockup.
```

If `$TEMPLATE` is `tailwind`, add after "Next step":
```
Live view:  In a second terminal, `cd <theme-dir> && npm run preview` and keep it running.
            It recompiles CSS/JS on every file the builders write and reloads the browser
            through BrowserSync (http://localhost:3000, proxying <domain>). Without it,
            each builder recompiles once when it finishes; reload manually.
```

**If this is a demo-first project**, adjust the summary:

```
=== Project Initialized (from existing demo) ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Template:   <Tailwind Starter|Cinematic Starter>
CF Plugin:  <SCF|ACF Pro>
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
Sections:   <detected sections>
CLAUDE.md:  <path-to-claude-md>
Demo:       demo/index.html (pre-polish copy at demo/.prepolish/index.html)

Next step: Run /wp-header to build the site header.
```
