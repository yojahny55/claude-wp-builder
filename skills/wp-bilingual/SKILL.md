---
name: wp-bilingual
description: Bilingual/multilingual i18n methodology using ACF _suffix pattern with transparent translation helpers
user-invocable: false
---

# Bilingual / Multilingual i18n System

This skill defines the translation methodology for WordPress themes that need to support multiple languages. It uses the **ACF/SCF _suffix pattern** -- no WPML, no Polylang, no separate pages per language. One set of pages, one set of fields, with suffixed duplicates for secondary languages.

---

## Core Concept: The _suffix Pattern

For every translatable ACF/SCF field, the **primary language** (typically English) uses the base field name. Each **secondary language** gets a duplicate field with a language suffix appended.

| Primary Field (EN) | Spanish Field | French Field |
|---|---|---|
| `hero_title` | `hero_title_es` | `hero_title_fr` |
| `hero_subtitle` | `hero_subtitle_es` | `hero_subtitle_fr` |
| `cta_button_text` | `cta_button_text_es` | `cta_button_text_fr` |
| `service_description` | `service_description_es` | `service_description_fr` |

### Rules

- Primary language fields have **no suffix** and are always required
- Secondary language fields have `_<lang>` suffix and are **optional** (fall back to primary if empty)
- This applies to text, textarea, WYSIWYG, and any content field
- Non-translatable fields (images, URLs, numbers, booleans) do NOT get duplicated
- ACF field instructions for secondary fields should say: *"Leave empty to use English version"*

---

## Configuration Constants

Define supported languages and the default at the top of `inc/i18n.php`.

```php
// Define supported languages
define('PREFIX_SUPPORTED_LANGS', array('en', 'es'));
define('PREFIX_DEFAULT_LANG', 'en');
```

---

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

### Important Notes on Cookies

- `setcookie()` MUST be called **before any HTML output** (before headers are sent)
- The `i18n.php` file must be included early in `functions.php`, before any template rendering
- Cookie path is `/` so it works across all pages
- Cookie lifetime: 365 days

---

## Cookie Persistence

When the user clicks a language switcher link (e.g., `?lang=es`), the cookie is set in the `prefix_get_current_lang()` function. Subsequent page loads read the cookie, so the URL parameter is only needed once.

```php
// Cookie is set when URL param is detected
setcookie('prefix_lang', $current_lang, time() + (365 * 24 * 60 * 60), '/');
```

---

## Translation Helper Functions

### prefix_get_field() -- Auto-Translating Field Getter

This is the **primary function** for retrieving any ACF/SCF field. It checks the current language, tries the suffixed field first, and falls back to the primary field.

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

**Usage in templates:**

```php
<h1><?php echo esc_html(prefix_get_field('hero_title')); ?></h1>
<p><?php echo wp_kses_post(prefix_get_field('hero_description')); ?></p>

<!-- With post ID -->
<?php $logo = prefix_get_field('site_logo', 'option'); ?>

<!-- With specific post -->
<?php $title = prefix_get_field('custom_title', $post->ID); ?>
```

### prefix_get_repeater() -- Repeater Field Translation

Translates specific subfields within a repeater while leaving non-translatable subfields (images, URLs) untouched.

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

**Usage:**

```php
// Services repeater: translate 'title' and 'description', keep 'icon' and 'link' as-is
$services = prefix_get_repeater('services', array('title', 'description'));

foreach ($services as $service) : ?>
    <div class="service-card">
        <img src="<?php echo esc_url($service['icon']['url']); ?>" alt="">
        <h3><?php echo esc_html($service['title']); ?></h3>
        <p><?php echo esc_html($service['description']); ?></p>
    </div>
<?php endforeach;
```

### prefix_get_sub_field() -- Sub-field Translation Inside Loops

Used inside `have_rows()` loops (repeaters, flexible content) to get translated subfield values.

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

**Usage inside have_rows():**

```php
<?php if (have_rows('team_members')) : ?>
    <?php while (have_rows('team_members')) : the_row(); ?>
        <div class="team-member">
            <h3><?php echo esc_html(prefix_get_sub_field('name')); ?></h3>
            <p><?php echo esc_html(prefix_get_sub_field('bio')); ?></p>
        </div>
    <?php endwhile; ?>
<?php endif; ?>
```

### prefix_t() and prefix_e() -- Static UI String Translation

For hardcoded UI strings (navigation labels, button text, form labels) that do not come from ACF fields.

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

**Usage:**

```php
<!-- In templates -->
<a href="#services"><?php prefix_e('nav_services'); ?></a>
<button><?php prefix_e('btn_learn_more'); ?></button>

<!-- When you need the raw string (e.g., for attributes) -->
<a href="#" aria-label="<?php echo esc_attr(prefix__('nav_schedule')); ?>">
```

### prefix_is_lang() and prefix_get_current_lang()

Convenience helpers for language checks.

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

**Usage:**

```php
<?php if (prefix_is_spanish()) : ?>
    <html lang="es">
<?php else : ?>
    <html lang="en">
<?php endif; ?>
```

---

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

---

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

---

## Menu Locations: Per-Language Pattern

Register separate menu locations for each language. This allows admins to create fully localized menus in wp-admin.

### Registration

```php
function prefix_setup() {
    register_nav_menus(array(
        'primary-en' => __('Primary Navigation (EN)', 'theme-slug'),
        'primary-es' => __('Primary Navigation (ES)', 'theme-slug'),
        'mobile-en'  => __('Mobile Navigation (EN)', 'theme-slug'),
        'mobile-es'  => __('Mobile Navigation (ES)', 'theme-slug'),
        'footer-en'  => __('Footer Navigation (EN)', 'theme-slug'),
        'footer-es'  => __('Footer Navigation (ES)', 'theme-slug'),
    ));
}
add_action('after_setup_theme', 'prefix_setup');
```

### Usage in Templates

Select the menu location dynamically based on the current language.

```php
<?php
$lang = prefix_get_current_lang();

wp_nav_menu(array(
    'theme_location' => 'primary-' . $lang,
    'container'      => false,
    'fallback_cb'    => 'prefix_nav_fallback',
    'items_wrap'     => '%3$s',
    'walker'         => new Prefix_Nav_Walker(),
));
?>
```

The pattern is: `<location>-<lang>` (e.g., `primary-en`, `primary-es`, `mobile-en`, `mobile-es`).

---

## ACF Field Creation Rules

When defining fields in `inc/scf-fields.php` for a bilingual site:

### Field Organization

Use **Tab fields** to organize languages in the admin UI.

```php
// English Tab
array(
    'key'       => 'field_hero_tab_en',
    'label'     => 'English',
    'type'      => 'tab',
    'placement' => 'top',
),
array(
    'key'          => 'field_hero_title',
    'label'        => 'Hero Title',
    'name'         => 'hero_title',
    'type'         => 'text',
    'required'     => 1,
),
array(
    'key'          => 'field_hero_description',
    'label'        => 'Hero Description',
    'name'         => 'hero_description',
    'type'         => 'textarea',
    'required'     => 1,
),

// Spanish Tab
array(
    'key'       => 'field_hero_tab_es',
    'label'     => 'Espanol',
    'type'      => 'tab',
    'placement' => 'top',
),
array(
    'key'          => 'field_hero_title_es',
    'label'        => 'Hero Title (ES)',
    'name'         => 'hero_title_es',
    'type'         => 'text',
    'instructions' => 'Leave empty to use English version.',
    'required'     => 0,
),
array(
    'key'          => 'field_hero_description_es',
    'label'        => 'Hero Description (ES)',
    'name'         => 'hero_description_es',
    'type'         => 'textarea',
    'instructions' => 'Leave empty to use English version.',
    'required'     => 0,
),
```

### Repeater Subfields

Inside repeaters, add suffixed subfields for each translatable text subfield.

```php
array(
    'key'        => 'field_services',
    'label'      => 'Services',
    'name'       => 'services',
    'type'       => 'repeater',
    'sub_fields' => array(
        array(
            'key'   => 'field_service_icon',
            'label' => 'Icon',
            'name'  => 'icon',
            'type'  => 'image',
        ),
        array(
            'key'   => 'field_service_title',
            'label' => 'Title (EN)',
            'name'  => 'title',
            'type'  => 'text',
        ),
        array(
            'key'          => 'field_service_title_es',
            'label'        => 'Title (ES)',
            'name'         => 'title_es',
            'type'         => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key'   => 'field_service_description',
            'label' => 'Description (EN)',
            'name'  => 'description',
            'type'  => 'textarea',
        ),
        array(
            'key'          => 'field_service_description_es',
            'label'        => 'Description (ES)',
            'name'         => 'description_es',
            'type'         => 'textarea',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key'   => 'field_service_link',
            'label' => 'Link',
            'name'  => 'link',
            'type'  => 'url',
            // No _es version — URLs are typically language-neutral
        ),
    ),
),
```

---

## Critical Rule: Templates ALWAYS Use prefix_get_field()

Templates must **NEVER** call `get_field()` directly. Always use the translation-aware wrapper.

```php
// WRONG — bypasses translation system
$title = get_field('hero_title');

// CORRECT — auto-translates based on current language
$title = prefix_get_field('hero_title');
```

This rule applies everywhere:
- `prefix_get_field()` instead of `get_field()`
- `prefix_get_sub_field()` instead of `get_sub_field()`
- `prefix_get_repeater()` instead of raw `get_field()` on repeaters
- `prefix__()` / `prefix_e()` instead of hardcoded strings

The only place `get_field()` is called directly is **inside** the helper functions themselves.

---

## Setting the HTML lang Attribute

In `header.php`, set the document language dynamically.

```php
<!DOCTYPE html>
<html <?php language_attributes(); ?> lang="<?php echo esc_attr(prefix_get_current_lang()); ?>">
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
```

---

## File Structure

The i18n system lives in a single file included early in `functions.php`.

```php
// functions.php — i18n must load before SCF fields
require get_template_directory() . '/inc/i18n.php';
require get_template_directory() . '/inc/scf-fields.php';
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

---

## Summary Checklist

- [ ] `PREFIX_SUPPORTED_LANGS` and `PREFIX_DEFAULT_LANG` constants defined
- [ ] Language detection follows priority: URL param > cookie > browser > default
- [ ] Cookie set with 365-day expiry on language switch
- [ ] `prefix_get_field()` used in ALL templates (never raw `get_field()`)
- [ ] `prefix_get_repeater()` used for repeater fields with translatable subfields specified
- [ ] `prefix_get_sub_field()` used inside `have_rows()` loops
- [ ] `prefix__()` / `prefix_e()` used for all static UI strings
- [ ] All secondary ACF fields have `_<lang>` suffix and "Leave empty to use English version" instruction
- [ ] Tab organization per language in ACF field groups
- [ ] Menu locations registered per language: `<location>-<lang>`
- [ ] Language switcher uses `remove_query_arg` / `add_query_arg`
- [ ] HTML `lang` attribute set dynamically
