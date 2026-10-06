# Suffix i18n helpers — what the starter file does not say

The implementation is the file `/wp-init` copies into the theme as `inc/i18n.php`, with
`__starter__` replaced by the project's prefix:

- `tailwind`: `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/inc/i18n.php`
- `cinematic`: `${CLAUDE_PLUGIN_ROOT}/starter-theme/__cinematic__/inc/i18n.php`

Read the project's own `inc/i18n.php` before changing it, and never rewrite it from memory or
from an example: the helper names are a contract every template calls, and one that does not
exist is a fatal error on the page. Below is what the code does not explain.

## Contents

- Why detection runs in this order
- The cookie, and why the first call is on `init`
- Fallbacks
- Adding a string, and strings for JavaScript
- A switcher template

## Why detection runs in this order

`prefix_get_current_lang()` takes the first of: the `?lang=` parameter, the `prefix_lang`
cookie, the first two letters of `Accept-Language`, `PREFIX_DEFAULT_LANG`. Each candidate is
accepted only if it is in `PREFIX_SUPPORTED_LANGS`.

- The parameter wins, so a shared `?lang=es` link opens in Spanish whatever the visitor's
  cookie says.
- The cookie beats the browser, so a visitor's explicit choice outlives their browser setting.
- The browser beats the default, so a first visit lands in a language the visitor reads.

## The cookie, and why the first call is on `init`

Only a request carrying `?lang=` sets the cookie, and only on the first call, because the result
is cached in a `static` for the rest of the request. `setcookie()` needs the headers unsent, so
the starter calls the function on `init`. Without that hook the first caller was
`wp_enqueue_scripts`, inside `wp_head()`, after `<!DOCTYPE html>` had gone out — and on a server
without output buffering the switch lasted one page.

The cinematic starter caches the same way but keeps its getter free of the side effect: a
separate `init` callback sets the cookie, and only when the language came from `?lang=` and
differs from the cookie already stored, so an ordinary page view sends no header.

## Fallbacks

- `prefix_get_field()`, `prefix_get_sub_field()` and `prefix_get_repeater()` try
  `<name>_<lang>` on a secondary-language request and fall back to `<name>` when it is
  `empty()` — an empty string, `null`, `0` and `'0'` all fall back.
- `prefix_t()` tries the current language, then the primary language, then `en`, and finally
  returns the key itself. It never returns `''`.

## Adding a string, and strings for JavaScript

Add the key to `prefix_get_translations()` with a value for every supported language, written as
UTF-8 literals (`'Leer Más'`, never `'Leer Mas'` and never `&aacute;`). Templates then call
`prefix_e( 'key' )` or `prefix_t( 'key' )`.

There is no JavaScript-strings helper. The starter already passes the current language to its
script as `lang` in `wp_localize_script( '__starter__-main', '__STARTER___data', … )`; to pass
strings, add the keys to that same array through `prefix_t()`:

```php
'strings' => array(
    'directory_clear' => prefix_t( 'directory_clear' ),
    'directory_empty' => prefix_t( 'directory_empty' ),
),
```

## A switcher template

Links built with `prefix_get_lang_url()`, labelled from the strings the starter already carries
(`lang_en`, `lang_es`), so the label is never a hard-coded English phrase:

```php
<div class="lang-switcher">
    <?php foreach (PREFIX_SUPPORTED_LANGS as $lang) : ?>
        <?php if ($lang !== prefix_get_current_lang()) : ?>
            <a href="<?php echo esc_url(prefix_get_lang_url($lang)); ?>"
               class="lang-switcher__link"
               hreflang="<?php echo esc_attr($lang); ?>"
               aria-label="<?php echo esc_attr(prefix_t('lang_' . $lang)); ?>">
                <?php echo esc_html(strtoupper($lang)); ?>
            </a>
        <?php endif; ?>
    <?php endforeach; ?>
</div>
```

A third language needs its own `lang_<code>` key in `prefix_get_translations()`.
