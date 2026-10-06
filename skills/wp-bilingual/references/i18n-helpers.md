# Suffix i18n helpers — reference implementations

The rules, and how templates call each helper, are in `../SKILL.md`. `prefix_` is the
project's function prefix.

## Contents

- Language Detection
- Translation Helper Functions — `prefix_get_field()`, `prefix_get_repeater()`,
  `prefix_get_sub_field()`, `prefix__()` / `prefix_e()`, `prefix_is_lang()`
- Static Translations Array, and JavaScript Translations
- Language Switcher URL Generation
- File Structure

## Language Detection

Language is detected using a strict priority chain. The first match wins.

**Priority: URL parameter > Cookie > Browser Accept-Language > Default**

```php
function prefix_get_current_lang() {
    static $current_lang = null;

    if ($current_lang !== null) {
        return $current_lang;
    }

    // 1. Check URL parameter
    if (isset($_GET['lang']) && in_array($_GET['lang'], PREFIX_SUPPORTED_LANGS)) {
        $current_lang = sanitize_text_field($_GET['lang']);
        // Set cookie for persistence (365 days)
        setcookie('prefix_lang', $current_lang, time() + (365 * 24 * 60 * 60), '/');
        return $current_lang;
    }

    // 2. Check cookie
    if (isset($_COOKIE['prefix_lang']) && in_array($_COOKIE['prefix_lang'], PREFIX_SUPPORTED_LANGS)) {
        $current_lang = sanitize_text_field($_COOKIE['prefix_lang']);
        return $current_lang;
    }

    // 3. Check browser language (Accept-Language header)
    if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
        $browser_lang = substr($_SERVER['HTTP_ACCEPT_LANGUAGE'], 0, 2);
        if (in_array($browser_lang, PREFIX_SUPPORTED_LANGS)) {
            $current_lang = $browser_lang;
            return $current_lang;
        }
    }

    // 4. Default language
    $current_lang = PREFIX_DEFAULT_LANG;
    return $current_lang;
}
```

## Translation Helper Functions

### prefix_get_field() -- Auto-Translating Field Getter

```php
function prefix_get_field($field_name, $post_id = null) {
    $lang = prefix_get_current_lang();

    // If secondary language, try suffixed field first
    if ($lang !== PREFIX_DEFAULT_LANG) {
        $translated_field = $field_name . '_' . $lang;
        $value = get_field($translated_field, $post_id);

        // If translated field has a value, return it
        if (!empty($value)) {
            return $value;
        }
    }

    // Fallback to primary (default) field
    return get_field($field_name, $post_id);
}
```

### prefix_get_repeater() -- Repeater Field Translation

```php
function prefix_get_repeater($field_name, $translatable_subfields = array(), $post_id = null) {
    $lang = prefix_get_current_lang();
    $repeater = get_field($field_name, $post_id);

    if (!$repeater || !is_array($repeater)) {
        return array();
    }

    // If default language or no translatable subfields, return as-is
    if ($lang === PREFIX_DEFAULT_LANG || empty($translatable_subfields)) {
        return $repeater;
    }

    // Process each row for translations
    foreach ($repeater as $index => $row) {
        foreach ($translatable_subfields as $subfield) {
            $translated_key = $subfield . '_' . $lang;
            // If translated subfield exists and has value, override the primary
            if (isset($row[$translated_key]) && !empty($row[$translated_key])) {
                $repeater[$index][$subfield] = $row[$translated_key];
            }
        }
    }

    return $repeater;
}
```

### prefix_get_sub_field() -- Sub-field Translation Inside Loops

```php
function prefix_get_sub_field($field_name) {
    $lang = prefix_get_current_lang();

    if ($lang !== PREFIX_DEFAULT_LANG) {
        $value = get_sub_field($field_name . '_' . $lang);
        if (!empty($value)) {
            return $value;
        }
    }

    return get_sub_field($field_name);
}
```

### prefix_t() and prefix_e() -- Static UI String Translation

```php
/**
 * Get static translation string (return)
 */
function prefix__($key) {
    $lang = prefix_get_current_lang();
    $translations = prefix_get_translations();

    if (isset($translations[$key][$lang])) {
        return $translations[$key][$lang];
    }

    // Fallback to default language
    if (isset($translations[$key][PREFIX_DEFAULT_LANG])) {
        return $translations[$key][PREFIX_DEFAULT_LANG];
    }

    // Return key if translation not found
    return $key;
}

/**
 * Echo static translation string (with escaping)
 */
function prefix_e($key) {
    echo esc_html(prefix__($key));
}
```

### prefix_is_lang() and prefix_get_current_lang()

```php
/**
 * Check if current language matches
 */
function prefix_is_lang($lang) {
    return prefix_get_current_lang() === $lang;
}

/**
 * Alias: check if current language is Spanish
 */
function prefix_is_spanish() {
    return prefix_get_current_lang() === 'es';
}
```

## Static Translations Array

Define all hardcoded UI strings in a central translations function. Each entry is an associative array keyed by language code.

```php
function prefix_get_translations() {
    return array(
        // Navigation
        'nav_home' => array(
            'en' => 'Home',
            'es' => 'Inicio',
        ),
        'nav_services' => array(
            'en' => 'Services',
            'es' => 'Servicios',
        ),
        'nav_pricing' => array(
            'en' => 'Pricing',
            'es' => 'Precios',
        ),
        'nav_contact' => array(
            'en' => 'Contact',
            'es' => 'Contacto',
        ),

        // Buttons
        'btn_learn_more' => array(
            'en' => 'Learn More',
            'es' => 'Saber Mas',
        ),
        'btn_get_started' => array(
            'en' => 'Get Started',
            'es' => 'Comenzar',
        ),
        'btn_schedule' => array(
            'en' => 'Schedule Appointment',
            'es' => 'Agendar Cita',
        ),

        // Footer
        'footer_services' => array(
            'en' => 'Services',
            'es' => 'Servicios',
        ),
        'footer_quick_links' => array(
            'en' => 'Quick Links',
            'es' => 'Enlaces Rapidos',
        ),
        'footer_privacy' => array(
            'en' => 'Privacy Policy',
            'es' => 'Politica de Privacidad',
        ),
        'footer_terms' => array(
            'en' => 'Terms & Conditions',
            'es' => 'Terminos y Condiciones',
        ),

        // Social
        'social_follow_us' => array(
            'en' => 'Follow Us',
            'es' => 'Siguenos',
        ),
    );
}
```

### JavaScript Translations

For strings needed in client-side JS, create a filtered subset and pass via `wp_localize_script()`.

```php
function prefix_get_js_translations() {
    $all = prefix_get_translations();
    $lang = prefix_get_current_lang();
    $js_strings = array();

    // Pick only the keys needed in JS
    $js_keys = array('btn_learn_more', 'btn_schedule', 'calc_per_month');
    foreach ($js_keys as $key) {
        if (isset($all[$key][$lang])) {
            $js_strings[$key] = $all[$key][$lang];
        }
    }

    return $js_strings;
}
```

## Language Switcher URL Generation

Use `remove_query_arg()` and `add_query_arg()` to build language toggle URLs.

```php
function prefix_get_lang_url($lang) {
    $url = remove_query_arg('lang');
    return add_query_arg('lang', $lang, $url);
}
```

**Language switcher in a template:**

```php
<div class="lang-switcher">
    <?php $current_lang = prefix_get_current_lang(); ?>
    <?php foreach (PREFIX_SUPPORTED_LANGS as $lang) : ?>
        <?php if ($lang !== $current_lang) : ?>
            <a href="<?php echo esc_url(prefix_get_lang_url($lang)); ?>"
               class="lang-switcher__link"
               aria-label="<?php echo esc_attr('Switch to ' . strtoupper($lang)); ?>">
                <?php echo esc_html(strtoupper($lang)); ?>
            </a>
        <?php endif; ?>
    <?php endforeach; ?>
</div>
```

## File Structure

The i18n system lives in a single file included early in `functions.php`, before the field loader's `acf/init` hook runs.

```php
// functions.php — i18n must load before the fields/*.php bootstrap
require get_template_directory() . '/inc/i18n.php';

// Field groups loaded via the acf/init bootstrap loader (fields/*.php seeds
// acf-json/, which becomes the dashboard-editable source of truth) —
// see wp-theme-standards SKILL.md for the full loader.
```

The `inc/i18n.php` file contains:
1. Language constants
2. `prefix_get_current_lang()`
3. `prefix_get_field()`
4. `prefix_get_repeater()`
5. `prefix_get_sub_field()`
6. `prefix__()` and `prefix_e()`
7. `prefix_get_lang_url()`
8. `prefix_is_spanish()` / `prefix_is_lang()`
9. `prefix_get_translations()` (the static strings array)
10. `prefix_get_js_translations()`
