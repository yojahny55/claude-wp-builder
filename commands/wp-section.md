---
description: One-shot section builder — generates ACF fields + template part + CSS for a section from the demo
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<section-name> [screenshot-path]"
---

# WP Section — One-Shot Section Builder

Generate ACF field definitions, a template part, and CSS for a single section — all in one command. Dispatches three agents in parallel.

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:
- **First word** = section name (required, e.g., `hero`, `services`, `about`, `contact`)
- **Remaining words** = screenshot path (optional)

If no section name is provided, print an error:
```
Error: Section name is required.
Usage: /wp-section <section-name> [screenshot-path]
Example: /wp-section hero
         /wp-section services /path/to/screenshot.png
```

## Step 2: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary — needed for bilingual field variants)
- **Theme directory path**

## Step 3: Read Demo Section

Read `demo/index.html` and extract the section matching:
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

## Step 4: Determine Target Page Template

The section will be included in a page template. Default is `front-page.php`. If the user specifies a different target, use that instead.

## Step 5: Dispatch Three Agents IN PARALLEL

Launch all three agents simultaneously. Provide each agent with the demo section HTML, the project prefix, languages, and the field naming convention.

### FIELD NAMING CONVENTION (include in ALL agent prompts):

```
Field names:    <section>_<element>     (e.g., hero_title, hero_image)
Repeaters:      <section>_<plural>      (e.g., services_cards, team_members)
Subfields:      <element> only          (e.g., title, description, icon — NO section prefix)
Field keys:     field_<section>_<element>
Group keys:     group_<section>
```

---

### Agent 1: wp-acf

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

### Agent 2: wp-template

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
> 6. Uses BEM class naming: `.<section>__<element>`
> 7. Wraps in a `<section>` tag with appropriate id and class
> 8. Uses semantic HTML5
>
> Demo HTML for this section:
> ```html
> <paste extracted section HTML here>
> ```

---

### Agent 3: wp-css

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

## Step 6: Add to Page Template

After all three agents complete, check if the target page template (e.g., `front-page.php`) already includes this section:

```php
get_template_part('template-parts/section', '<name>');
```

If not present, add the `get_template_part()` call inside the `<main>` element, in a logical order relative to other sections.

If the page template does not exist yet, create it with `get_header()`, `<main>`, the `get_template_part()` call, `</main>`, and `get_footer()`.

## Step 7: Print Summary

```
=== Section "<Name>" Built ===
Files created/updated:
  - fields/<section-name>.php (ACF field definitions)
  - template-parts/section-<name>.php (template part)
  - assets/css/styles.css (<Name> section CSS)
  - <page-template>.php (added get_template_part call)

Fields registered:
  - <list of field names>

Next: Run /wp-section <next-section> for the next section.
```
