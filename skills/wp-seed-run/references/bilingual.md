# /wp-seed — Phase 5

`commands/wp-seed.md` sends the run here at Phase 5 (Seed Bilingual Content). Follow it in order; nothing in it is optional background.

## Contents

- If `i18n strategy` is `polylang`
- If `i18n strategy` is `suffix` (or the line is absent — see above)

### If `i18n strategy` is `polylang`

Do NOT write `_<lang>` fields. Under Polylang each language gets its OWN page,
and the two are joined by a translation group. For each page created in
Phase 2:

1. Assign the primary language:
   ```bash
   bash -c "$WP eval \"pll_set_post_language(<page_id>, '<primary_lang>');\""
   ```

2. **If the demo already carries the secondary language** — sections with
   `lang=""` attributes, or duplicate content blocks — create the counterpart
   page from THAT copy and link the two. The demo's own wording is what the
   client approved; re-translating it would throw away human copy and replace
   it with a machine's:
   ```bash
   COUNTERPART=$(bash -c "$WP post create --post_type=page --post_title='<translated title>' --post_status=publish --post_author=$AUTHOR --porcelain")
   bash -c "$WP eval \"pll_set_post_language($COUNTERPART, '<secondary_lang>');\""
   bash -c "$WP eval \"pll_save_post_translations(['<primary_lang>' => <page_id>, '<secondary_lang>' => $COUNTERPART]);\""
   ```
   Then seed that page's ACF fields with the demo's secondary-language values,
   using the **unsuffixed** field names — the page is already in its language.

3. **If a section has no secondary-language copy in the demo**, leave it and
   let `/wp-polylang` translate it afterwards. It exports exactly what is
   still untranslated, so anything seeded in step 2 is skipped rather than
   overwritten:
   ```
   /wp-polylang <primary_lang> <secondary_lang>
   ```

Report which pages came from the demo and which were left for `/wp-polylang`.
A page silently missing its counterpart is the failure mode to avoid here.

Menus and internal links are handled by `/wp-polylang`'s import; do not
hand-build translated menus under this strategy.

### If `i18n strategy` is `suffix` (or the line is absent — see above)

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
