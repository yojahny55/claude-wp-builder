# /wp-page — The `tailwind` prompt body

`commands/wp-page.md` sends the run here at "The `tailwind` prompt body", on a `tailwind` theme only (the file ownership between `wp-template` and `wp-tailwind`, and the author-mode prompt every dispatch site hands `wp-tailwind`). Follow it in order; nothing in it is optional background.

**File ownership.** `wp-template` owns every `.php` file this command generates, on both
paths — it is the only agent carrying the ACF, escaping and i18n contract
(`prefix_get_field()`, the `?:` fallbacks, `esc_html()` / `esc_url()` / `esc_attr()`, the
`@package` header, the ABSPATH check), none of which `agents/wp-tailwind.md` describes.
On `tailwind`, `wp-template` keeps the Tailwind utility classes already on the markup it
was handed instead of inventing BEM names, and `wp-tailwind` runs **after** it returns —
never beside it — editing only class names in the file `wp-template` wrote. The invariant:
no page ships without its ACF wiring and escaping, and no page ships on BEM class names in
a Tailwind theme.

> Mode: **author**
>
> Promote the `<type>` page's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Page slug: `--page <slug>` (decides `components/<slug>.css`)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: the template files the wp-template agent has just written for this
>   page type, already carrying Tailwind utility classes — quoted below.
>
> Requirements:
> 1. Those template files belong to wp-template. Edit them in place; do not create
>    them and do not rewrite them. The only thing you change is class names. Leave
>    every `prefix_get_field()` call, every `esc_html()` / `esc_url()` / `esc_attr()`
>    wrapper, every fallback and every PHP control structure exactly as you found it.
> 2. Tailwind utility classes in the markup are the default. Most pages need no CSS
>    file entry at all, and the templates come back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `components/<slug>.css` if it
>    is local to this one. Grep the theme's other `components/*.css` and `*.php`
>    before choosing.
> 4. Name a class you write into `components/<slug>.css` `<block>__<element>`. Name
>    one you write into `utilities/site.css` `site__<element>` instead — it qualified
>    for that file precisely because it spans more than one block.
> 5. If a target CSS file does not exist, create it with its first rule already in it
>    and add its `@import` to `main.css` in the same step, naming its cascade layer
>    (`layer(components)` for `components/<slug>.css`, `layer(utilities)` for
>    `utilities/site.css`) — a bare `@import` beats every Tailwind utility regardless
>    of specificity. Never leave an empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`). No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Page markup:
> ```php
> <paste the generated template files here>
> ```
