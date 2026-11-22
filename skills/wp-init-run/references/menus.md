# /wp-init — Step 6

`commands/wp-init.md` sends the run here at Step 6. Follow it in order; nothing in it is optional background.

Edit the theme's `register_nav_menus()` call — in `inc/theme-setup.php` on
`tailwind`, in `functions.php` on `cinematic` (that starter has no
`inc/theme-setup.php`).

Templates never build a location name. They call `<prefix>nav_location('primary')`
and `<prefix>nav_location('footer')`, which the `inc/i18n.php` installed in Step 5
answers for its strategy: `primary-<lang>` from the suffix helper, the bare
`primary` from the Polylang variant. So the registration below is the only half
that changes per strategy, and it has to match that answer exactly — a location
the helper asks for and nothing registers renders no menu at all, with no error
(`fallback_cb` is `false`).

### If `$I18N = polylang` (default)

Replace the starter's per-language entries with each location registered ONCE,
with no language suffix:

- `'primary' => 'Primary Navigation'`
- `'footer' => 'Footer Navigation'`

Polylang gives every registered location a per-language slot of its own and
swaps the right menu in at render time. Keeping `primary-en` and `primary-es`
as well would produce two competing systems for the same nav, and
`pll-verify.php` fails each of them for having no menu in the other language.

On `tailwind`, also register the theme's static strings so a client can edit
them under **Languages > Strings** instead of in code (the cinematic starter has
no `<prefix>get_translations()`; its literals are `<prefix>b()` pairs):

```php
add_action( 'init', function () {
    if ( ! function_exists( 'pll_register_string' ) ) {
        return;
    }
    foreach ( <prefix>get_translations() as $key => $values ) {
        pll_register_string( $key, $values['<primary_lang>'], '<Theme Name>' );
    }
} );
```

### If `$I18N = suffix`

- Keep the starter's per-language locations, named `<location>-<lang>` with a
  **hyphen** — the name the suffix `<prefix>nav_location()` builds. The starter
  ships them for `en` and `es`; make the list match the project's languages —
  one `primary-` and one `footer-` entry per language:
  - `'primary-en' => 'Primary Navigation (EN)'`
  - `'primary-es' => 'Primary Navigation (ES)'`
  - `'footer-en' => 'Footer Navigation (EN)'`
  - `'footer-es' => 'Footer Navigation (ES)'`
