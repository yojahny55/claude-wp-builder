# /wp-finalize — Demo-parity gate — Layer 1 (static)

`commands/wp-finalize.md` sends the run here at Demo-parity gate — Layer 1. Follow it in order; nothing in it is optional background.

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
