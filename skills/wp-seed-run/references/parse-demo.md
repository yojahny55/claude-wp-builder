# /wp-seed — Phase 1

`commands/wp-seed.md` sends the run here at Phase 1 (Parse Demo HTML). Follow it in order; nothing in it is optional background.

## Contents

- Parse arguments
- Locate the demo file
- Single-page vs. multi-page detection
- Parse each HTML file

### Parse arguments

- **First non-flag word** = demo file path (optional). If provided and it points to a file, use that file.
- **`--exclude-slugs <slug,slug,...>`** = optional comma-separated list of page slugs to
  **skip** when creating WP Pages in Phase 2 (default: none — existing behavior unchanged).
  Use this to avoid creating a WP Page for a slug that is served by a CPT archive
  (`archive-<slug>.php` / `has_archive`), which would otherwise collide.

### Locate the demo file

- If a demo file path was provided in `$ARGUMENTS`, use that file.
- Otherwise, check for `demo/index.html` in the current working directory.
- If no demo file is found, abort with:
  > "No demo file found. Provide a path as argument or ensure `demo/index.html` exists."

### Single-page vs. multi-page detection

**Multi-page demos:** If a `demo/` directory exists with multiple `.html` files (e.g., `demo/index.html`, `demo/about.html`, `demo/services.html`), process each file. The filename (without extension) maps to the page slug. `index.html` maps to the Home page.

**Single-page demos:** Process only the one demo file. All content goes to the Home page.

### Parse each HTML file

1. **Split by section delimiters** — look for `<!-- ============ SECTION: <Name> ============ -->` markers. Each delimiter starts a new section. Content between one delimiter and the next (or `<!-- ============ END SECTION: <Name> ============ -->`) belongs to that section.

2. **Extract content using the BEM class-to-ACF field mapping table:**

| Demo HTML Class | ACF Field Name | Type |
|----------------|----------------|------|
| `.hero__title` | `hero_title` | text |
| `.hero__subtitle` | `hero_subtitle` | text |
| `.hero__description` | `hero_description` | textarea |
| `.hero__image img[src]` | `hero_image` | image (import) |
| `.hero__cta` (text content) | `hero_cta_text` | text |
| `.hero__cta[href]` | `hero_cta_link` | url |
| `.about__title` | `about_title` | text |
| `.about__subtitle` | `about_subtitle` | text |
| `.about__description` | `about_description` | textarea |
| `.about__image img[src]` | `about_image` | image (import) |
| `.services__title` | `services_title` | text |
| `.services__subtitle` | `services_subtitle` | text |
| `.services__card` (repeated) | `services_cards` | repeater |
| `.services__card .card__title` | subfield: `title` | text |
| `.services__card .card__description` | subfield: `description` | textarea |
| `.services__card .card__icon img[src]` | subfield: `icon` | image (import) |
| `.services__card .card__link[href]` | subfield: `link` | url |
| `.testimonials__title` | `testimonials_title` | text |
| `.testimonials__card` (repeated) | `testimonials_cards` | repeater |
| `.testimonials__card .card__name` | subfield: `name` | text |
| `.testimonials__card .card__role` | subfield: `role` | text |
| `.testimonials__card .card__quote` | subfield: `quote` | textarea |
| `.testimonials__card .card__avatar img[src]` | subfield: `avatar` | image (import) |
| `.contact__title` | `contact_title` | text |
| `.contact__description` | `contact_description` | textarea |
| `.contact__email` | `contact_email` | text |
| `.contact__phone` | `contact_phone` | text |
| `.contact__address` | `contact_address` | textarea |
| `.footer__copyright` | `copyright_text` | text (settings) |
| `.footer__description` | `footer_description` | textarea (settings) |

**General mapping rule:** For any section not listed above, follow the pattern:
- `.{section}__{element}` text content maps to `{section}_{element}` (text)
- `.{section}__{element} img[src]` maps to `{section}_{element}` (image — import the URL)
- `.{section}__{element}[href]` maps to `{section}_{element}_link` (url)
- Repeated `.{section}__card` elements map to `{section}_cards` repeater

3. **Extract navigation** — parse `<nav>` elements for page names and links. These determine which pages to create and what menu items to build.

4. **Collect all image sources** found in `img[src]` attributes and CSS `background-image: url(...)`
   declarations. Track which ACF field each image belongs to. A source beginning `http://`,
   `https://` or `//` is remote; anything else is demo-relative — a craft build's generated plates
   are written to `assets/img/gen-<hash>.jpg` and referenced from the markup that way, not as a URL.
   When a source is demo-relative, resolve it against the demo folder before Phase 3 imports it:
   `wp media import` accepts a local file path, but it cannot resolve one that is relative to the
   shell's working directory.

Print a summary of parsed content:

```
=== Parsed Demo Content ===
Pages found:    Home, About, Services, Contact
Sections:       Hero, About, Services, Testimonials, Contact
Fields:         23 text fields, 8 images, 2 repeaters
Nav items:      4 items
Languages:      en (primary), es (additional)
```
