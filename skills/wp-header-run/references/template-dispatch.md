# /wp-header — Step 4

> Generate the following files in the theme directory:
>
> ### header.php
> - Start with `<!DOCTYPE html>`, `<html <?php language_attributes(); ?>>`, `<head>`, `<meta charset>`, `<meta viewport>`, `<?php wp_head(); ?>`, `</head>`
> - `<body <?php body_class(); ?>>`
> - Site header with:
>   - Logo from settings: `prefix_get_field('site_logo', 'option')` with fallback to `get_bloginfo('name')`
>   - `wp_nav_menu()` with `'theme_location' => prefix_nav_location('primary')`, on
>     both strategies. The helper in `inc/i18n.php` returns the location the
>     project's `i18n strategy` registers: under `suffix`, the per-language
>     location (`primary-<lang>`, hyphenated); under `polylang`, the bare
>     location (`primary`) — Step 7 registers one location per name there.
>     Never build the name yourself (`'primary-' . …`): it is right on one
>     strategy and renders no menu on the other
>   - Use the custom nav walker class
>   - Language switcher per the project's `i18n strategy`: under `suffix`,
>     render all configured languages (from `SUPPORTED_LANGS`) with active
>     state, linking through `prefix_get_lang_url()`; under `polylang`,
>     render it with `pll_the_languages()` — Step 7 says why (it marks the
>     current language and hides languages with no counterpart).
>     **Never transcribe the demo's switcher markup.** A demo's switcher is a
>     mockup — typically two `href="#"` links with `aria-current` hardcoded on
>     one — and it renders as a working control, which is why copying it across
>     survives review. Take its *styling* from the demo and its *behaviour* from
>     the helper above. `demo/.demo-plan.json`'s `inert[]` declares it when the
>     demo came from `/wp-demo`; a demo from elsewhere declares nothing, so
>     assume the switcher is inert unless its markup proves otherwise — and
>     **the proof is the `href`, never the trappings.** A mock switcher carries
>     `hreflang` on both links and `aria-current="true"` on one, which is
>     precisely what a working one carries; a measured demo had both. Only where
>     each link points distinguishes them
>   - Mobile hamburger toggle button with aria attributes
>   - Skip-to-content link for accessibility
>   - The `<header>` keeps `id="masthead"`. When the demo header is sticky or fixed, in-page
>     anchors must land below it: the tailwind starter's `index.js` writes the header's live
>     `top` + height into `--header-offset` (so an `.admin-bar #masthead { top: 32px }` rule
>     counts the admin bar) and `base/reset.css` sets
>     `html { scroll-padding-top: calc(var(--header-offset, 0px) + 1.25rem) }`, so both
>     depend on that id. On a non-starter theme, write the same `scroll-padding-top` from the
>     measured desktop and mobile header heights. Verify at both widths by opening a
>     `#section` link: the section heading sits fully below the header
>
> ### inc/nav-walker.php
> - Custom Walker_Nav_Menu extension named `Prefix_Nav_Walker` (using actual prefix)
> - Every menu item's `<a>` renders at least 24x24 at desktop and mobile (WCAG 2.2 AA
>   2.5.8). When the demo's line is shorter, add padding plus an equal negative margin so
>   the hit area grows and the text does not move. For a 20px line: `tailwind` →
>   `py-0.5 -my-0.5` on the `<a>`; `basic` → `.nav__link { padding-block: 2px; margin-block: -2px; }`
> - Support for dropdown/submenu items if the demo has them
> - Proper escaping on all output
>
> ### Class naming — include the line matching the project's `Template:`, drop the other
> Both files above are yours on both paths; only the class system changes.
> - `basic` → BEM class naming on output elements
> - `tailwind` → keep the Tailwind utility classes already on the demo header you were
>   handed, element for element. Never replace them with BEM names and never invent new
>   class names: `wp-tailwind` runs after you and renames only the groups its promotion
>   ladder promotes. See "File ownership" under "CSS agent routing" below.
>
> Make sure to match the visual layout from the demo as closely as possible.
