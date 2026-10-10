# /wp-section — Step 5

`commands/wp-section.md` sends the run here at Step 5 (the three-agent dispatch for a section that is not a contact section). Follow it in order; nothing in it is optional background.

## Contents

- Order of the three agents per template, and the tabs, accordion and filter markup contract
- Agent 1: wp-acf
- Agent 2: wp-template
- Agent 3: wp-css
- Agent 3 (tailwind path): wp-tailwind in author mode

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

**Tabs, accordions and filter bars are markup, not new scripts.** When the demo section
shows tabs, an accordion/FAQ or a directory filter bar, tell Agent 2 to write the markup
contract of the starter module that owns it (`assets/js/src/tabs.js`, `accordion.js`,
`directory-filter.js`, see `skills/wp-tailwind-system/references/components.md`, "Tabs, accordions and directory filters")
and to author no section script for it. A FAQ list is `data-accordion="single"`; a detail
page's fold blocks are standalone triggers that rest open. On a theme that predates these
modules, copy them from `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/js/src/`
and import them in `index.js` first.

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
>    it and add its `@import` to `main.css` in the same step, naming its cascade
>    layer (`layer(components)` for `components/<page-slug>.css`, `layer(utilities)`
>    for `utilities/site.css`) — a bare `@import` beats every Tailwind utility
>    regardless of specificity. Never leave an empty file.
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
