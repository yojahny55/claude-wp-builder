---
description: One-shot section builder — generates ACF fields + template part + CSS for a section from the demo
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<section-name> [screenshot-path] [--cf7]"
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

## Step 3.5: Detect Contact Section

Check if this is a contact section:
1. Section name matches `contact`, `contact-us`, `contacto`, or `get-in-touch` (case-insensitive)
2. OR the `--cf7` flag is present in `$ARGUMENTS`
3. OR the extracted demo HTML contains a `<form>` element with `<input type="email">` and `<textarea>`

If any condition is true, set `is_contact_section = true`. This changes the dispatch flow in Step 5.

## Step 4: Determine Target Page Template

The section will be included in a page template. Default is `front-page.php`. If the user specifies a different target, use that instead.

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

### For NON-CONTACT sections: Three Agents IN PARALLEL

Launch all three agents simultaneously. Provide each agent with the demo section HTML, the project prefix, languages, and the field naming convention.

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
> 6. Uses BEM class naming: `.<section>__<element>`
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

### For CONTACT sections: Two-Phase Dispatch

**Phase 1:** Launch three agents IN PARALLEL:

#### Agent 1: wp-acf

(Same prompt as non-contact above)

#### Agent 3: wp-css

(Same prompt as non-contact above)

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
> $form_id = prefix_is_spanish() ? <FORM_ID_ES> : <FORM_ID_EN>;
> echo do_shortcode('[contact-form-7 id="' . $form_id . '" html_class="contact__form"]');
> ?>
> ```
>
> For monolingual sites (no Spanish), use the form ID directly:
> ```php
> <?php echo do_shortcode('[contact-form-7 id="<FORM_ID_EN>" html_class="contact__form"]'); ?>
> ```

## Step 6: Add to Page Template

After all three agents complete, check if the target page template (e.g., `front-page.php`) already includes this section:

```php
get_template_part('template-parts/section', '<name>');
```

If not present, add the `get_template_part()` call inside the `<main>` element, in a logical order relative to other sections.

If the page template does not exist yet, create it with `get_header()`, `<main>`, the `get_template_part()` call, `</main>`, and `get_footer()`.

## Step 7: Print Summary

### For non-contact sections:
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

### For contact sections:
```
=== Section "Contact" Built ===
Files created/updated:
  - fields/contact.php (ACF field definitions)
  - template-parts/section-contact.php (template part)
  - assets/css/styles.css (Contact section CSS)
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
