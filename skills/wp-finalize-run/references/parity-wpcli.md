# /wp-finalize — Demo-parity gate — Layer 2 (WP-CLI, when WordPress is reachable)

`commands/wp-finalize.md` sends the run here at Demo-parity gate — Layer 2. Follow it in order; nothing in it is optional background.

Layer 2 runs when `.wp-create.json` exists and WordPress is reachable (reuse `$WP` from Check 7). Every check below is **critical**.

1. **`site_logo` + critical options non-empty** — `critical`

   ```bash
   $WP eval "echo get_field('site_logo','option') ? 'OK' : 'EMPTY';"
   $WP option get blogname
   $WP option get blogdescription
   ```
   The logo is stored as the ACF options field `options_site_logo` (seeded via `update_field('site_logo', $LOGO_ID, 'option')`), NOT the WordPress core `site_logo` option — read it with `get_field('site_logo','option')`, matching the `inner_hero_image` check below. **PASS** if `site_logo` and every other critical site option return a non-empty value. **FAIL** listing which option is empty/unset.

2. **`inner_hero_image` seeded per in-scope page** — `critical`

   For each in-scope page (from the manifest / scope file), find its post ID and check the ACF field:
   ```bash
   $WP post list --post_type=page --format=ids
   $WP eval "echo get_field('inner_hero_image', <post_id>) ? 'OK' : 'EMPTY';"
   ```
   **PASS** if every in-scope page has `inner_hero_image` seeded. **FAIL** listing which pages are missing it.

3. **Menus assigned to locations** — `critical`

   ```bash
   $WP menu location list --format=table
   ```
   **PASS** if every registered nav location has a menu assigned — the list depends on the `i18n strategy` (under `suffix`: `primary-en`, `primary-es`, `footer-en`, `footer-es`; under `polylang`: bare `primary`, `footer`). **FAIL** listing unassigned locations.

4. **In-scope pages exist** — `critical`

   ```bash
   $WP post list --post_type=page --format=table
   ```
   **PASS** if every in-scope page from the manifest has a corresponding WordPress page. **FAIL** listing missing pages.

**PASS** if all 4 checks pass. **FAIL** listing every offending check with its details. If WordPress is not reachable (no `.wp-create.json`, or `$WP` calls fail to connect), **SKIP** Layer 2 with a noted reason — this is not a failure, but Layers 1 and 3 still gate.
