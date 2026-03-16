---
description: Seed WordPress content from demo HTML — parses sections, creates pages, imports media, populates ACF fields, builds menus, supports bilingual content
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[demo-file.html]"
---

# WP Seed — Content Seeding from Demo HTML

Parse a demo HTML file (or multi-page demo directory), extract content via BEM class conventions, and seed it into WordPress using WP-CLI. Creates pages, imports media, populates ACF fields for all configured languages, and builds navigation menus.

## Step 0: Read Project Manifest

Read `.wp-create.json` from the project root to obtain the WP-CLI wrapper and language configuration.

```bash
bash -c "cat .wp-create.json"
```

Extract and store:
- **`$WP`** — the value of `wp_cli.wrapper` (e.g., `docker exec my-project-wp wp --allow-root`, `wp --path=/var/www/html/my-project`, `ddev wp`, `lando wp`, `npx wp-env run cli wp`)
- **Primary language** — `languages.primary` (e.g., `en`)
- **Additional languages** — `languages.additional` array (e.g., `["es"]`)
- **Project slug** — `project.slug`
- **Project path** — `project.path`

If `.wp-create.json` does not exist, abort with:
> "No `.wp-create.json` found. Run `/wp-create` first to set up the WordPress environment."

Verify WP-CLI connectivity before proceeding:

```bash
bash -c "$WP option get siteurl"
```

If this fails, abort with a message suggesting the user check that the WordPress environment is running.

---

## Phase 1: Parse Demo HTML

### Locate the demo file

- If `$ARGUMENTS` is provided and points to a file, use that file.
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

4. **Collect all image URLs** found in `img[src]` attributes and CSS `background-image: url(...)` declarations. Track which ACF field each image belongs to.

Print a summary of parsed content:

```
=== Parsed Demo Content ===
Pages found:    Home, About, Services, Contact
Sections:       Hero, About, Services, Testimonials, Contact
Fields:         23 text fields, 8 images, 2 repeaters
Nav items:      4 items
Languages:      en (primary), es (additional)
```

---

## Phase 2: Create Pages

Create a WordPress page for each page found in the navigation (or each HTML file in multi-page demos).

```bash
# Create each page and capture its ID
bash -c "HOME_ID=\$($WP post create --post_type=page --post_title='Home' --post_status=publish --porcelain) && echo \$HOME_ID"
bash -c "ABOUT_ID=\$($WP post create --post_type=page --post_title='About' --post_status=publish --porcelain) && echo \$ABOUT_ID"
bash -c "SERVICES_ID=\$($WP post create --post_type=page --post_title='Services' --post_status=publish --porcelain) && echo \$SERVICES_ID"
bash -c "CONTACT_ID=\$($WP post create --post_type=page --post_title='Contact' --post_status=publish --porcelain) && echo \$CONTACT_ID"
```

Assign page templates if corresponding template files exist in the theme:

```bash
bash -c "$WP post update <page_id> --page_template='page-about.php'"
```

Set the front page to the Home page:

```bash
bash -c "$WP option update show_on_front 'page'"
bash -c "$WP option update page_on_front <home_id>"
```

If a Blog/News page exists, set it as the posts page:

```bash
bash -c "$WP option update page_for_posts <blog_id>"
```

Store all page IDs for use in later phases (menu creation, page-specific field seeding).

---

## Phase 3: Import Media

Import all collected image URLs into the WordPress media library.

```bash
# Import each image and capture attachment ID
bash -c "HERO_IMG_ID=\$($WP media import 'https://images.unsplash.com/photo-xxx' --title='Hero Background' --porcelain) && echo \$HERO_IMG_ID"
```

**Failure handling:** If a media import fails for any URL (403, redirect loop, CDN block, timeout), do NOT abort. Instead:

1. Log a warning: `"WARNING: Failed to import <url> for field <field_name>. Skipping."`
2. Leave the ACF field empty for that image.
3. Continue with remaining imports.
4. Track all failed imports for the final seed report.

Store all successful attachment IDs mapped to their target ACF field names.

---

## Phase 4: Seed ACF Fields (Primary Language)

Populate all extracted content into ACF fields using WP-CLI. Primary language fields use **no suffix** (e.g., `hero_title`, not `hero_title_en`).

### Preferred method: ACF's `update_field()` via `wp eval`

This approach is storage-format-agnostic and works regardless of how ACF stores the data internally.

**Simple text fields (options page):**

```bash
bash -c "$WP eval \"update_field('hero_title', 'Building Digital Excellence', 'option');\""
bash -c "$WP eval \"update_field('hero_subtitle', 'We create websites that work', 'option');\""
bash -c "$WP eval \"update_field('hero_description', 'Full-service digital agency...', 'option');\""
bash -c "$WP eval \"update_field('hero_cta_text', 'Get Started', 'option');\""
bash -c "$WP eval \"update_field('hero_cta_link', '#contact', 'option');\""
```

**Image fields (use the attachment ID from Phase 3):**

```bash
bash -c "$WP eval \"update_field('hero_image', 42, 'option');\""
```

**Repeater fields:**

```bash
bash -c "$WP eval \"
\\\$rows = array(
  array('title' => 'Web Design', 'description' => 'Custom websites...', 'icon' => 43),
  array('title' => 'SEO', 'description' => 'Search optimization...', 'icon' => 44),
  array('title' => 'Branding', 'description' => 'Visual identity...', 'icon' => 45),
);
update_field('services_cards', \\\$rows, 'option');
\""
```

**Page-specific fields (post meta, not options page):**

```bash
bash -c "$WP eval \"update_field('about_hero_title', 'Our Story', <about_id>);\""
bash -c "$WP eval \"update_field('about_hero_description', 'Founded in 2010...', <about_id>);\""
```

### Alternative method: Direct `wp_options` (faster for bulk, but coupled to ACF internals)

Use only when the ACF API is unavailable or for bulk seeding performance:

```bash
# ACF stores options page fields in wp_options with 'options_' prefix
bash -c "$WP option update options_hero_title 'Building Digital Excellence'"
bash -c "$WP option update options_hero_image 42"

# Repeater fields use indexed subfields
bash -c "$WP option update options_services_cards_0_title 'Web Design'"
bash -c "$WP option update options_services_cards_0_description 'Custom websites...'"
bash -c "$WP option update options_services_cards_0_icon 43"
bash -c "$WP option update options_services_cards_1_title 'SEO'"
bash -c "$WP option update options_services_cards_1_description 'Search optimization...'"
bash -c "$WP option update options_services_cards_1_icon 44"
bash -c "$WP option update options_services_cards 2"  # total row count

# Page-specific fields use post meta
bash -c "$WP post meta update <about_id> about_hero_title 'Our Story'"
```

### Verification

After seeding primary language fields, verify a sample field was stored correctly:

```bash
bash -c "$WP eval \"echo get_field('hero_title', 'option');\""
```

---

## Phase 5: Seed Bilingual Content

For each additional language in `.wp-create.json` `languages.additional` array, seed translated content. **Secondary language fields append the language code as a suffix** (e.g., `hero_title_es`). This matches the i18n helper convention in `inc/i18n.php`.

Claude translates the primary language content into each additional language. If the demo HTML contains bilingual sections (elements with `lang=""` attributes or duplicate content blocks), use those translations instead.

**Text fields:**

```bash
bash -c "$WP eval \"update_field('hero_title_es', 'Construyendo Excelencia Digital', 'option');\""
bash -c "$WP eval \"update_field('hero_subtitle_es', 'Creamos sitios web que funcionan', 'option');\""
bash -c "$WP eval \"update_field('hero_description_es', 'Agencia digital de servicio completo...', 'option');\""
bash -c "$WP eval \"update_field('hero_cta_text_es', 'Comenzar', 'option');\""
bash -c "$WP eval \"update_field('copyright_text_es', '© 2026 Mi Proyecto. Todos los derechos reservados.', 'option');\""
```

**Image fields:** Images are shared across languages — no re-import needed. Use the same attachment IDs:

```bash
bash -c "$WP eval \"update_field('hero_image_es', 42, 'option');\""
```

**Repeater bilingual subfields:**

```bash
bash -c "$WP eval \"
\\\$rows = get_field('services_cards', 'option');
\\\$rows[0]['title_es'] = 'Diseno Web';
\\\$rows[0]['description_es'] = 'Sitios web personalizados...';
\\\$rows[1]['title_es'] = 'SEO';
\\\$rows[1]['description_es'] = 'Optimizacion de busqueda...';
update_field('services_cards', \\\$rows, 'option');
\""
```

**Page-specific bilingual fields:**

```bash
bash -c "$WP eval \"update_field('about_hero_title_es', 'Nuestra Historia', <about_id>);\""
```

Repeat for every additional language configured in the manifest.

---

## Phase 6: Create Menus

Create navigation menus for each configured language. Menu location names use **underscore-separated** format matching `theme-setup.php` `register_nav_menus()`.

### Create menu structures

```bash
# Create a menu for each language
bash -c "$WP menu create 'Primary EN'"
bash -c "$WP menu create 'Primary ES'"

# Optionally create footer menus
bash -c "$WP menu create 'Footer EN'"
bash -c "$WP menu create 'Footer ES'"
```

### Add menu items

Add each page to its language menu, using the page IDs from Phase 2:

```bash
# English primary menu
bash -c "$WP menu item add-post primary-en <home_id> --title='Home'"
bash -c "$WP menu item add-post primary-en <about_id> --title='About'"
bash -c "$WP menu item add-post primary-en <services_id> --title='Services'"
bash -c "$WP menu item add-post primary-en <contact_id> --title='Contact'"

# Spanish primary menu
bash -c "$WP menu item add-post primary-es <home_id> --title='Inicio'"
bash -c "$WP menu item add-post primary-es <about_id> --title='Acerca'"
bash -c "$WP menu item add-post primary-es <services_id> --title='Servicios'"
bash -c "$WP menu item add-post primary-es <contact_id> --title='Contacto'"
```

### Assign menus to theme locations

Use underscore-separated location names that match `register_nav_menus()` in the theme:

```bash
# Assign to theme locations (underscore-separated names)
bash -c "$WP menu location assign 'Primary EN' primary_en"
bash -c "$WP menu location assign 'Primary ES' primary_es"
bash -c "$WP menu location assign 'Footer EN' footer_en"
bash -c "$WP menu location assign 'Footer ES' footer_es"
```

### Verify menu assignment

```bash
bash -c "$WP menu location list --format=table"
```

---

## Phase 7: Final Setup

### Flush rewrite rules and cache

```bash
bash -c "$WP rewrite flush"
bash -c "$WP cache flush"
```

### Delete default WordPress content

Remove the default "Hello World" post, sample page, and sample comment if they still exist:

```bash
bash -c "$WP post delete 1 --force 2>/dev/null || true"
bash -c "$WP post delete 2 --force 2>/dev/null || true"
bash -c "$WP comment delete 1 --force 2>/dev/null || true"
```

### Set timezone

```bash
bash -c "$WP option update timezone_string 'America/New_York'"
```

### Close comments by default

```bash
bash -c "$WP option update default_comment_status 'closed'"
```

---

## Seed Report

Print a summary of everything that was seeded:

```
=== Seed Complete ===
Pages created:     Home (ID: 5), About (ID: 6), Services (ID: 7), Contact (ID: 8)
Front page:        Home (ID: 5)
Media imported:    12 of 14 succeeded
  WARNING:         2 images failed (see below)
ACF fields seeded: 23 fields (primary: en)
Bilingual fields:  23 fields (es)
Menus created:     Primary EN, Primary ES, Footer EN, Footer ES
Menu locations:    primary_en, primary_es, footer_en, footer_es
Timezone:          America/New_York
Default content:   Deleted

Failed media imports:
  - hero_background: https://example.com/image1.jpg (403 Forbidden)
  - team_photo: https://example.com/image2.jpg (timeout)
  → Upload these manually in wp-admin > Media

Next step: Visit <site_url> to verify, then run /wp-finalize for the pre-delivery checklist.
```
