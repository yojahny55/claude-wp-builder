---
description: One-shot section builder — generates ACF fields + template part + CSS for a section from the demo
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<section-name> [screenshot-path] [--cf7] [--hybrid] [--page <slug>] [--target <template>] [--transcribe] [--block <name>] [--css <source>]"
---

# WP Section — One-Shot Section Builder

Generate ACF field definitions, a template part, and CSS for a single section — all in one command. On `basic` it dispatches three agents in parallel; on `tailwind`, `wp-tailwind` runs after `wp-template` returns (see File ownership below).

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:
- **First word** = section name (required, e.g., `hero`, `services`, `about`, `contact`)
- **Remaining non-flag word** = screenshot path (optional; a flag token or its value is never treated as the screenshot path)
- **`--cf7` flag** = force CF7 contact form integration (optional)
- **`--hybrid` flag** = cinematic projects only (`Template: cinematic`): build the section as a **trailing flex layout** appended to the `trailing_sections` flexible-content field in `fields/trailing-sections.php`, not as a standalone field group, and skip the page-template injection — `front-page.php`'s trailing loop already renders every layout (see the Hybrid overlay below). Error and exit if the project is not cinematic.
- **`--page <slug>`** = read the section from `demo/<slug>.html` instead of `demo/index.html` (optional, **default `index`** — existing behavior unchanged when omitted)
- **`--target <template>`** = inject the `get_template_part` call into `<template>` (e.g. `page-about.php`) instead of `front-page.php` (optional, **default `front-page.php`** — existing behavior unchanged when omitted)
- **`--transcribe` flag** = activate **faithful Transcription Mode** (optional). When set, the dispatched agents reproduce the demo's exact declared CSS/geometry instead of re-authoring fresh design-system styles. When omitted, behavior is unchanged (the current re-authoring / design-system path).
- **`--block <name>`** = the unique BEM block name to scope every generated selector under (optional; used with `--transcribe` so parallel section builds can never collide on a selector).
- **`--css <source>`** = the demo source the section is transcribed from (optional; required with `--transcribe`). What it means depends on the project's `Template:`, per the transcription overlay below:
  - `basic` → the section's **verbatim** demo CSS, and the SOURCE OF TRUTH for the transcription: an inline CSS blob or a path to a CSS file, whose declared values are copied exactly.
  - `tailwind` → the converted demo page itself (HTML, converted in place by `/wp-yolo` Step 2.6). Here it is a geometry reference, **not** a source of verbatim declarations — the overlay's instruction is "reproduce this geometry using Tailwind utilities", never "copy the declared values verbatim".

> **Note:** `/wp-yolo` sets `--transcribe --block <block> --css <css-source>` on every `/wp-section` dispatch (see `commands/wp-yolo.md` Step 4). When invoked by hand without these flags, `/wp-section` keeps its original design-system authoring behavior.

If no section name is provided, print an error:
```
Error: Section name is required.
Usage: /wp-section <section-name> [screenshot-path] [--cf7] [--hybrid] [--page <slug>] [--target <template>] [--transcribe] [--block <name>] [--css <source>]
Example: /wp-section hero
         /wp-section services /path/to/screenshot.png
         /wp-section contact --cf7
         /wp-section about-story --page about --target page-about.php
         /wp-section hero --transcribe --block home-hero --css demo/index.css
         /wp-section pricing --hybrid
```

## Step 2: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary — needed for bilingual field variants)
- **Theme directory path**

### Hybrid overlay (`--hybrid`)

Read `Template:` from `.claude/CLAUDE.md`. If `--hybrid` is set and the template is not
`cinematic`, stop:
```
Error: --hybrid is only valid on a cinematic project (Template: cinematic). Use /wp-section <name> without it.
```
If the template is `cinematic`, `--hybrid` is **absent** and no `--target` was given, warn
once and continue as if it were set — the default target is `front-page.php`, and on the
cinematic starter that file renders the reel plus the trailing loop, not a `<main>` section
list, so a standalone section injected there would never render. An explicit `--target`
(e.g. `--target page-pricing.php`) is a normal inner page on a cinematic site and is built
the standard way; `--hybrid` is never implied over it.

Under `--hybrid`, four things change and nothing else does:

1. **Fields** — `wp-acf` does not write `fields/<section>.php`. It appends one flexible-content
   **layout** named `<section>` (label `<Section Name>`) to the `trailing_sections` field in
   `fields/trailing-sections.php`, carrying the section's sub-fields under the normal
   `<section>_<element>` / `field_<section>_<element>` naming. If that file does not exist yet
   (init ran with `--no-hybrid`), create it with the `trailing_sections` flexible-content field
   attached to the front page, then add the layout.
2. **Template** — `template-parts/section-<section>.php` is rendered from inside the trailing
   `have_rows()` loop (see `starter-theme/__cinematic__/front-page.php`), so it reads its values
   with `get_sub_field('<field>')` — appending `_<lang>` for the secondary language the same way
   `prefix_get_field()` does — never `prefix_get_field()` / `get_field()`, which would resolve
   against the page, not the row.
3. **CSS** — the cinematic starter has no `assets/css/styles.css`; the CSS agent appends the
   section block to `assets/css/cinematic.css` under `/* ====== Section: <Name> ====== */`.
4. **Injection** — skip Step 6 entirely. The layout renders because the loop maps every
   `get_row_layout()` to `template-parts/section-<layout>.php`. Passing `--hybrid` with an explicit `--target` is a contradiction — error out
   and ask for one or the other.

## Step 3: Read Demo Section

Read the demo page for this section — `demo/<slug>.html` where `<slug>` is the `--page`
value (**default `index`**, i.e. `demo/index.html` when `--page` is omitted) — and extract
the section matching:
```
<!-- ============ SECTION: <Name> ============ -->
...
<!-- ============ END SECTION: <Name> ============ -->
```

The match should be case-insensitive on the section name. If the section is not found in the demo, warn the user but continue — ask them to describe the section content.

Analyze the extracted section for:
- All text content (headings, paragraphs, labels, CTAs)
- Images and their roles
- Repeating patterns (cards, list items, team members, etc.)
- Links and buttons
- Layout structure (grid, columns, etc.)

## Step 3.5: Detect Contact Section

Check if this is a contact section:
1. Section name matches `contact`, `contact-us`, `contacto`, or `get-in-touch` (case-insensitive)
2. OR the `--cf7` flag is present in `$ARGUMENTS`
3. OR the extracted demo HTML contains a `<form>` element with `<input type="email">` and `<textarea>`

If any condition is true, set `is_contact_section = true`. This changes the dispatch flow in Step 5.

## Step 4: Determine Target Page Template

The section will be included in a page template. Default is `front-page.php`. If `--target <template>` is provided, inject into that template instead (e.g. `page-about.php`). Everywhere below that names `front-page.php` refers to this resolved target template.

## Step 5: Dispatch Agents

### FIELD NAMING CONVENTION (include in ALL agent prompts):

```
Field names:    <section>_<element>     (e.g., hero_title, hero_image)
Repeaters:      <section>_<plural>      (e.g., services_cards, team_members)
Subfields:      <element> only          (e.g., title, description, icon — NO section prefix)
Field keys:     field_<section>_<element>
Group keys:     group_<section>
```

---

### TRANSCRIPTION MODE OVERLAY (only when `--transcribe` is set)

When `--transcribe` is present (the `/wp-yolo` path), layer these instructions onto every
agent prompt below. When it is absent, skip this overlay entirely — the agents run their
normal design-system authoring path unchanged.

- **wp-css:** append to its prompt the literal word **"transcribe"**, the `--css` source
  (the section's verbatim demo CSS — inline it, or tell the agent to read the given path),
  and the `--block` name. This activates wp-css **Transcription Mode** (see
  `agents/wp-css.md`): the demo CSS is the SOURCE OF TRUTH — copy its exact declared values
  and geometry, do NOT re-author, and scope every selector under `--block`.
- **wp-tailwind (tailwind path):** the `--css` source is the *converted* demo, so
  the instruction is "reproduce this geometry using Tailwind utilities", never
  "copy the declared values verbatim". Scope any `@apply` class under `--block`,
  exactly as `wp-css` scopes its BEM selectors. `wp-css` is not dispatched at all
  on this path.
- **wp-template (basic path):** instruct it to scope all BEM classes under the `--block`
  name (use `<block>__<element>` instead of `<section>__<element>`) so the transcribed
  CSS and the markup share the same unique block and parallel sections never collide.
- **wp-template (tailwind path):** there are no BEM classes to scope — the section HTML
  it is handed is already Tailwind-native, and it carries those utilities over
  unchanged. Pass `--block` anyway, as the name for the section wrapper's own class, so
  the `@apply` promotion `wp-tailwind` may perform afterwards has a block to hang on.
- Because each section's `--block` is unique, parallel agents can never clash on a selector.

---

### CSS agent routing — read the template first

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

| Template | Agent 3 | Output surface |
|----------|---------|----------------|
| `basic` | `wp-css` | `assets/css/styles.css` (BEM + `:root` tokens) |
| `tailwind` | `wp-tailwind` in **author** mode | Utility classes in the markup; `@apply` rules only where the `wp-tailwind-system` ladder demands them |

Dispatch exactly one of the two. Never both — they write incompatible CSS systems.
Agents 1 (`wp-acf`) and 4 (`wp-cf7`) are identical on both paths. Agent 2
(`wp-template`) runs on both paths too, but its class-naming instruction differs — see
**File ownership** immediately below, which is the rule the rest of this command follows.

---

### File ownership — one writer per file, on both paths

| File | Written by | On `tailwind`, also edited by |
|------|-----------|-------------------------------|
| `fields/<name>.php` | `wp-acf` | — |
| `template-parts/section-<name>.php` | `wp-template` | `wp-tailwind`, class names only, afterwards |
| `assets/css/styles.css` | `wp-css` (`basic` only) | — |
| `components/…css`, `utilities/site.css`, `main.css` | — | `wp-tailwind` |

**`wp-template` owns `template-parts/section-<name>.php` on BOTH paths, and it is the only
agent that may create it.** It is the only agent carrying the ACF, escaping and i18n
contract — `prefix_get_field()`, the `?:` fallbacks, `esc_html()` / `esc_url()` /
`esc_attr()`, the `@package` header, the ABSPATH check. `agents/wp-tailwind.md` describes
none of them, so a section authored there ships with no ACF wiring, no escaping and no
i18n, and `/wp-finalize` then reports it as a bilingual failure.

What the `tailwind` path changes is the class system, not the owner: `wp-template` keeps
the Tailwind utility classes already on the section HTML it was handed — Step 2.6 of
`/wp-yolo` converted the demo before this walk, so they are there — instead of inventing
BEM names. Agent 2's prompt below carries that instruction.

**`wp-tailwind` in author mode runs AFTER `wp-template` returns, never beside it**, and
owns only four things: applying the `wp-tailwind-system` promotion ladder, creating the
`@apply` files the ladder demands, registering their `@import` in `main.css`, and renaming
the promoted groups inside the template part `wp-template` already wrote. Dispatched in
parallel with `wp-template`, the two write the same path and the last writer wins with no
error anywhere — and the loss is not symmetric, because `wp-tailwind` winning takes the
ACF wiring and the escaping with it.

The invariant, on both paths: **no section may ship without its ACF wiring and escaping,
and no section may ship on BEM class names in a Tailwind theme.**

The `tailwind` dispatch carries this line, verbatim, inside its quoted prompt — Agent 3's
block below already opens with it:

> Mode: **author**

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, so an ordinary demo page named after the word cannot
flip the mode by accident. Drop the line and the agent runs Demo Conversion Mode instead.

---

### For NON-CONTACT sections: three agents, and the order depends on the template

Provide each agent with the demo section HTML, the project prefix, languages, and the
field naming convention.

- **`basic`** — launch all three agents simultaneously. `wp-acf`, `wp-template` and
  `wp-css` write three different files, so nothing can collide.
- **`tailwind`** — launch Agents 1 (`wp-acf`) and 2 (`wp-template`) simultaneously, then
  **wait for Agent 2 to return before dispatching Agent 3** (`wp-tailwind` in author
  mode). Agent 3 edits the template part Agent 2 writes; run them in parallel and the two
  writes race on one file. See **File ownership** above for why that race is not
  survivable.

#### Agent 1: wp-acf

> Generate `fields/<section-name>.php` in the theme directory.
>
> Create an ACF/SCF field group for the "<Section Name>" section with:
>
> **Field naming convention:**
> - Field names: `<section>_<element>` (e.g., `hero_title`, `hero_image`)
> - Repeaters: `<section>_<plural>` (e.g., `services_cards`)
> - Subfields: `<element>` only, no section prefix (e.g., `title`, `description`)
> - Field keys: `field_<section>_<element>`
> - Group key: `group_<section>`
>
> **Bilingual fields:**
> For every text/textarea/wysiwyg field, create variants for each language:
> - `<section>_<element>_en` (English)
> - `<section>_<element>_es` (Spanish)
> - Wrap each language variant in a conditional tab or group named by language
>
> **Location rule:** Show on front page (or specified page template).
>
> Analyze the demo HTML provided and create fields for every piece of dynamic content. Use appropriate field types: text, textarea, wysiwyg, image, url, repeater, etc.
>
> Demo HTML for this section:
> ```html
> <paste extracted section HTML here>
> ```

---

#### Agent 2: wp-template

> Generate `template-parts/section-<name>.php` in the theme directory.
>
> **Field naming convention:**
> - Field names: `<section>_<element>`
> - Repeaters: `<section>_<plural>`
> - Subfields: `<element>` only
>
> Create a template part that:
> 1. Starts with the standard file header (`@package`, ABSPATH check)
> 2. Retrieves all fields using `prefix_get_field('<section>_<element>')` — NEVER raw `get_field()`
> 3. Provides fallback values from the demo content using the `?: 'fallback'` pattern
> 4. Uses `prefix_get_repeater()` for any repeating content
> 5. Escapes all output: `esc_html()`, `esc_url()`, `esc_attr()`, `wp_kses_post()`
> 6. Class naming — include the line matching the project's `Template:` and drop the
>    other. This file is yours on both paths; only the class system changes:
>    - `basic` → uses BEM class naming: `.<section>__<element>`
>    - `tailwind` → keeps the Tailwind utility classes already on the section HTML
>      below, element for element. Never replace them with BEM names and never invent
>      new class names: `wp-tailwind` runs after you and renames only the groups its
>      promotion ladder promotes.
> 7. Wraps in a `<section>` tag with appropriate id and class
> 8. Uses semantic HTML5
>
> Demo HTML for this section:
> ```html
> <paste extracted section HTML here>
> ```

---

#### Agent 3: wp-css

> Add CSS for the `<section-name>` section to `assets/css/styles.css`.
>
> Requirements:
> 1. Add within delimiter comments:
>    ```css
>    /* ============ SECTION: <Name> ============ */
>    ...
>    /* ============ END SECTION: <Name> ============ */
>    ```
> 2. Mobile-first responsive approach
> 3. Use CSS custom properties from :root (colors, spacing, typography, etc.)
> 4. BEM naming: `.<section>`, `.<section>__<element>`, `.<section>__<element>--<modifier>`
> 5. Include breakpoints: 576px, 768px, 1024px, 1440px (as needed)
> 6. Match the layout and visual design from the demo
> 7. Append to the end of the existing file (before any footer CSS if present)
>
> Demo HTML/CSS for this section:
> ```html
> <paste extracted section HTML here>
> ```

---

#### Agent 3 (tailwind path): wp-tailwind — author mode

Dispatch this agent **only after Agent 2 has returned** — it edits the file Agent 2
writes. See **File ownership** above.

> Promote the `<section-name>` section's repeated utility groups for this Tailwind theme.
>
> Mode: **author**
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Page slug: `--page <page-slug>` (decides `components/<page-slug>.css`)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: the file `template-parts/section-<section-name>.php`, which the
>   `wp-template` agent has already written and which is quoted below.
>
> Requirements:
> 1. `template-parts/section-<section-name>.php` belongs to `wp-template`. Edit it in
>    place; do not create it and do not rewrite it. The only thing you change in it is
>    class names. Leave every `prefix_get_field()` call, every `esc_html()` /
>    `esc_url()` / `esc_attr()` wrapper, every `?:` fallback and every PHP control
>    structure exactly as you found it.
> 2. Tailwind utility classes in the markup are the default. Most sections need no
>    CSS file entry at all, and the template part comes back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `components/<page-slug>.css`
>    if it is local to this one. Grep the theme's other `components/*.css` and
>    `*.php` before choosing.
> 4. Name a class you write into `components/<page-slug>.css` `<block>__<element>`.
>    Name one you write into `utilities/site.css` `site__<element>` instead — it
>    qualified for that file precisely because it spans more than one block, so no
>    single block's name can carry it.
> 5. If a target CSS file does not exist, create it with its first rule already in
>    it and add its `@import` to `main.css` in the same step. Never leave an empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`). No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Section HTML (already Tailwind-native):
> ```html
> <paste extracted section HTML here>
> ```

---

### For CONTACT sections: Two-Phase Dispatch

**File ownership** above holds here unchanged: `wp-template` writes
`template-parts/section-contact.php`, and on `tailwind` `wp-tailwind` in author mode
edits it afterwards. That is why Agent 3 sits in a different phase on each path — on
`basic` it writes a file nobody else touches, on `tailwind` it edits the file Phase 2
has not produced yet.

**Phase 1:** Launch three agents IN PARALLEL (two on `tailwind` — see Agent 3):

#### Agent 1: wp-acf

(Same prompt as non-contact above)

#### Agent 3 (routed by template): wp-css or wp-tailwind

Follow the "CSS agent routing" table above — the same table governs both dispatch
blocks. Dispatch `wp-css` or `wp-tailwind` in author mode (never both) using the
same prompt as non-contact above.

**On `basic`, `wp-css` runs here, in Phase 1.** It writes `assets/css/styles.css`, which
no other agent in this flow touches.

**On `tailwind`, `wp-tailwind` does NOT run here.** It edits
`template-parts/section-contact.php`, which Phase 2's `wp-template` has not written yet;
dispatched in Phase 1 it would either find no file or race the one being written. It runs
in Phase 3 below instead.

#### Agent 4: wp-cf7

> Generate CF7 contact forms and branded email templates for the contact section.
>
> **Project context:**
> - Function prefix: `<prefix>`
> - Languages: `<languages from CLAUDE.md>`
> - Theme directory: `<theme path>`
> - WP-CLI wrapper: `<$WP from .wp-create.json>`
>
> **Demo HTML for the contact section:**
> ```html
> <paste extracted section HTML here>
> ```
>
> Parse the demo form fields, generate CF7 form markup per language, create branded HTML email templates (admin notification + user confirmation), save all files to `cf7/` directory, and create the forms via WP-CLI.
>
> Return the form IDs as your final output in this exact format:
> ```
> FORM_ID_EN=<id>
> FORM_ID_ES=<id>
> ```
> (Only include ES line if bilingual)

Wait for all Phase 1 agents to complete. Extract form IDs from wp-cf7 output.

**Phase 2:** Launch wp-template agent with form IDs:

#### Agent 2: wp-template

> Generate `template-parts/section-contact.php` in the theme directory.
>
> [standard wp-template prompt — same field naming convention, escaping rules, BEM classes, semantic HTML, etc.]
>
> **IMPORTANT — CF7 Form Integration:**
> This is a contact section with CF7 forms. The form IDs are:
> - English form ID: `<FORM_ID_EN>`
> - Spanish form ID: `<FORM_ID_ES>` (if bilingual)
>
> Render the CF7 form in the template using language detection:
> ```php
> <?php
> $form_id = prefix_is_lang('es') ? <FORM_ID_ES> : <FORM_ID_EN>;
> echo do_shortcode('[contact-form-7 id="' . $form_id . '" html_class="contact__form"]');
> ?>
> ```
>
> For monolingual sites (no Spanish), use the form ID directly:
> ```php
> <?php echo do_shortcode('[contact-form-7 id="<FORM_ID_EN>" html_class="contact__form"]'); ?>
> ```

**Phase 3 (`tailwind` only):** once Agent 2 has returned, dispatch `wp-tailwind` in author
mode with Agent 3's prompt from the non-contact block above, naming
`template-parts/section-contact.php` as the file it edits. On `basic` there is no Phase 3
— `wp-css` already ran in Phase 1.

## Step 6: Add to Page Template

**Skip this step under `--hybrid`** — the trailing loop in `front-page.php` renders the layout.

After all agents complete, check if the resolved target page template (the `--target` value, default `front-page.php`) already includes this section:

```php
get_template_part('template-parts/section', '<name>');
```

If not present, add the `get_template_part()` call inside the `<main>` element, in a logical order relative to other sections.

If the page template does not exist yet, create it with `get_header()`, `<main>`, the `get_template_part()` call, `</main>`, and `get_footer()`.

## Step 6.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Motion attribute assertion (craft mode only)

When `.wp-create.json` records `"demo mode": "craft"`, after writing the template
part, compare it against the demo section it came from: every `data-motion*`
attribute present in the demo must be present in the template part. A missing
attribute is a **build failure**, not a warning. Report the section, the attribute
and the demo line, and fix it before continuing.

## Step 7: Print Summary

The `[basic only]` / `[tailwind only]` markers below are report annotations, not literal
output: print the line that matches the project's `Template:` and drop the other. On
`tailwind` the section's styling lives in the template part's utility classes, so a CSS
file appears in the report only when the `wp-tailwind-system` ladder demanded an
`@apply` rule.

### For non-contact sections:
```
=== Section "<Name>" Built ===
Files created/updated:
  - fields/<section-name>.php (ACF field definitions)
  - template-parts/section-<name>.php (template part)
  - assets/css/styles.css (<Name> section CSS)                       [basic only]
  - components/<page-slug>.css or utilities/site.css (only if a rule was needed) [tailwind only]
  - <page-template>.php (added get_template_part call)

Fields registered:
  - <list of field names>

Next: Run /wp-section <next-section> for the next section.
```

### For contact sections:
```
=== Section "Contact" Built ===
Files created/updated:
  - fields/contact.php (ACF field definitions)
  - template-parts/section-contact.php (template part)
  - assets/css/styles.css (Contact section CSS)                      [basic only]
  - components/<page-slug>.css or utilities/site.css (only if a rule was needed) [tailwind only]
  - <page-template>.php (added get_template_part call)
  - cf7/form-en.html (CF7 form markup — English)
  - cf7/form-es.html (CF7 form markup — Spanish)
  - cf7/email-admin-en.html (Admin email template — English)
  - cf7/email-admin-es.html (Admin email template — Spanish)
  - cf7/email-user-en.html (User confirmation — English)
  - cf7/email-user-es.html (User confirmation — Spanish)

CF7 Forms created:
  - Contact EN (ID: <id>)
  - Contact ES (ID: <id>)

Next: Run /wp-section <next-section> for the next section.
```
