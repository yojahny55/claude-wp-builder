# /wp-init — Step 9

`commands/wp-init.md` sends the run here at Step 9. Follow it in order; nothing in it is optional background.

## Contents

- Custom Fields Plugin
- Translation Plugin
- Verification (both)
- Theme Activation
- Site Identity
- Tailwind Build Dependencies

### Custom Fields Plugin

- If `$CF_PLUGIN` is `scf`:
  ```bash
  $WP plugin install secure-custom-fields --activate
  ```
  > Note: Verify the correct WordPress.org slug. If it fails, try `developer-starter-templates`.

- If `$CF_PLUGIN` is `acf`:
  ```bash
  $WP eval "echo function_exists('acf_add_options_page') ? 'ACF OK' : 'ACF MISSING';"
  ```
  If ACF is missing, print: "ACF Pro is not installed. Please install it manually from your ACF account."

### Translation Plugin

- If `$I18N` is `polylang`:
  ```bash
  $WP plugin is-active polylang || $WP plugin activate polylang || $WP plugin install polylang --activate
  ```
  Then create the languages, using the same script `/wp-polylang` uses rather
  than a second implementation of the same thing:
  ```bash
  $WP eval-file ${CLAUDE_PLUGIN_ROOT}/skills/wp-polylang/scripts/pll-setup.php <primary_lang> <secondary_lang>
  ```
  Repeat the `pll-setup.php` call for each additional secondary language.
  The script is idempotent — a language that already exists is left alone.

  Then assign the primary language to existing content, or every page created
  later lands with no language at all and Polylang treats it as untranslatable:
  ```bash
  $WP eval "if (function_exists('pll_set_post_language')) { foreach (get_posts(['post_type'=>'any','numberposts'=>-1,'post_status'=>'any','fields'=>'ids']) as \$id) { if (!pll_get_post_language(\$id)) { pll_set_post_language(\$id, '<primary_lang>'); } } }"
  ```

- If `$I18N` is `suffix`: nothing to install.

### Verification (both):
```bash
$WP eval "echo function_exists('acf_add_options_page') ? 'CF OK' : 'CF MISSING';"
```

### Theme Activation

#### If `.wp-create.json` exists:

Use the WP-CLI wrapper from the manifest (stored as `$WP`):

```bash
$WP theme activate <slug>
$WP rewrite flush
```

Then update the manifest: set `theme.initialized` to `true`.

#### If `.wp-create.json` does NOT exist:

Check if WP-CLI is available by running `wp --info` or `which wp`. If available:

```bash
wp theme activate <slug> --path=<wordpress-root>
```

If WP-CLI is not available, skip this step silently.

### Site Identity

WordPress core install sets `blogname` from `--title` only when `/wp-create` created the site;
an adopted or hand-installed site keeps whatever it had, and `blogdescription` is never set by
anything and defaults to **"Just another WordPress site."** Both are `critical` in
`/wp-finalize`'s Layer 2 gate, so write them here, from the values confirmed in Step 1 / Step D3:

```bash
$WP option update blogname "<Project Name>"
$WP option update blogdescription "<Tagline>"
```

Without a `.wp-create.json` manifest, use `wp option update … --path=<wordpress-root>` the same
way Theme Activation does, and skip silently when WP-CLI is unavailable.

Do not skip this because the site already has a name: an adopted site's `blogname` is the
previous project's, which is exactly the case this step exists for. Verify:

```bash
$WP option get blogname
$WP option get blogdescription
```

Read both back, not just the tagline: an adopted site's `blogname` is the one this step is
most likely to be changing, and a failed update there is the failure it exists to catch.

If `$I18N = polylang`, this writes the primary language only. Polylang keeps `blogname` and
`blogdescription` as translatable strings under its `WordPress` context, and **an empty option
is absent from that string table entirely** — so writing them here is what makes them
translatable at all. `/wp-polylang` picks them up in its export/translate/import pass; this
step does not translate them. Say so in the summary rather than leaving the user to discover
the second language's tagline is empty.

### Tailwind Build Dependencies

If `$TEMPLATE` is `tailwind`:
```bash
cd <theme-dir> && npm install && npm run build
```
This generates `assets/css/dist/main.css` and `assets/js/dist/index.js` needed for the theme to function.
