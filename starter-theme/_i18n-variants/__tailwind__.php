<?php
/**
 * Internationalization (i18n) Functions — Polylang variant
 *
 * Drop-in replacement for inc/i18n.php when the project was scaffolded with
 * Polylang instead of the ACF/SCF _suffix pattern. Every function below has
 * the SAME NAME AND SIGNATURE as its counterpart in i18n.php, which is the
 * whole point: templates, sections, header and footer call these helpers and
 * never get_field() directly, so swapping this file in switches the entire
 * theme's translation model without touching a single template.
 *
 * What actually changes is smaller than it looks:
 *
 *   - the current language comes from Polylang instead of ?lang / a cookie
 *   - the language switcher builds real per-language permalinks
 *   - static strings go through pll__() first, then the table below
 *
 * Field resolution is deliberately UNCHANGED. Trying `<name>_<lang>` and
 * falling back to `<name>` already does the right thing under both models:
 * on a translated post the suffixed field simply does not exist, so the
 * fallback returns the post's own value -- and the post is already the one
 * for the current language, because Polylang resolved it. On the OPTIONS
 * page the suffix does exist and is still the only thing that works, since
 * ACF options are global: there is one set of values for the whole site, not
 * one per language, and free Polylang does not translate them. Keeping one
 * code path for both is why this file is short.
 *
 * @package __STARTER_NAME__
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Define supported languages
define('__STARTER___SUPPORTED_LANGS', array('en', 'es'));
define('__STARTER___DEFAULT_LANG', 'en');

/**
 * Get current language from Polylang
 *
 * Falls back to the default when Polylang is inactive or cannot resolve a
 * language -- which is also the case under WP-CLI, where there is no request
 * to derive one from.
 *
 * @return string Language code ('en' or 'es')
 */
function __starter___get_current_lang() {
    static $current_lang = null;

    if ($current_lang !== null) {
        return $current_lang;
    }

    if (function_exists('pll_current_language')) {
        $lang = pll_current_language('slug');
        if ($lang && in_array($lang, __STARTER___SUPPORTED_LANGS, true)) {
            $current_lang = $lang;
            return $current_lang;
        }
    }

    $current_lang = __STARTER___DEFAULT_LANG;
    return $current_lang;
}

/**
 * Get field value for the current language
 *
 * @param string $field_name Base field name
 * @param mixed  $post_id    Post ID, 'option', or false for current post
 * @return mixed Field value
 */
function __starter___get_field($field_name, $post_id = false) {
    $lang = __starter___get_current_lang();

    // Only meaningful for the options page -- see the file header.
    if ($lang !== __STARTER___DEFAULT_LANG) {
        $value = get_field($field_name . '_' . $lang, $post_id);
        if (!empty($value)) {
            return $value;
        }
    }

    return get_field($field_name, $post_id);
}

/**
 * Get repeater field with subfields resolved for the current language
 *
 * @param string $field_name             Base repeater field name
 * @param array  $translatable_subfields Subfield names that may have suffixed versions
 * @param mixed  $post_id                Post ID, 'option', or false for current post
 * @return array Repeater rows
 */
function __starter___get_repeater($field_name, $translatable_subfields = array(), $post_id = false) {
    $lang     = __starter___get_current_lang();
    $repeater = get_field($field_name, $post_id);

    if (!$repeater || !is_array($repeater)) {
        return array();
    }

    if ($lang === __STARTER___DEFAULT_LANG || empty($translatable_subfields)) {
        return $repeater;
    }

    foreach ($repeater as $index => $row) {
        foreach ($translatable_subfields as $subfield) {
            $translated_key = $subfield . '_' . $lang;
            if (isset($row[$translated_key]) && !empty($row[$translated_key])) {
                $repeater[$index][$subfield] = $row[$translated_key];
            }
        }
    }

    return $repeater;
}

/**
 * Get sub_field value for the current language
 *
 * Used inside have_rows() loops.
 *
 * @param string $field_name Base sub-field name
 * @return mixed Sub-field value
 */
function __starter___get_sub_field($field_name) {
    $lang = __starter___get_current_lang();

    if ($lang !== __STARTER___DEFAULT_LANG) {
        $value = get_sub_field($field_name . '_' . $lang);
        if (!empty($value)) {
            return $value;
        }
    }

    return get_sub_field($field_name);
}

/**
 * Get static translation string
 *
 * Polylang's own string registry wins when the key is registered there, so a
 * client can edit these in Languages > Strings instead of in code. The table
 * below is the fallback and the seed.
 *
 * @param string $key Translation key
 * @return string Translated string
 */
function __starter___t($key) {
    $lang         = __starter___get_current_lang();
    $translations = __starter___get_translations();

    // Look the string up by the value it was REGISTERED under, which is the
    // PRIMARY language, not a hardcoded 'en'. inc/theme-setup.php registers
    // each string with pll_register_string( $key, $values[$primary_lang], ... )
    // (see commands/wp-init.md Step 6), so on a Spanish-primary project the
    // source value lives under the 'es' key. Asking pll__() for the 'en' value
    // instead never matches Polylang's registry: pll__() silently returns its
    // own argument unchanged, the block below falls through, and the table's
    // hardcoded fallback answers every call -- with no error, and a client's
    // edits under Languages > Strings permanently ignored.
    $source = isset($translations[$key][__STARTER___DEFAULT_LANG])
        ? $translations[$key][__STARTER___DEFAULT_LANG]
        : $key;

    if (function_exists('pll__')) {
        $translated = pll__($source);
        if ($translated !== $source) {
            return $translated;
        }
    }

    if (isset($translations[$key][$lang])) {
        return $translations[$key][$lang];
    }

    if (isset($translations[$key]['en'])) {
        return $translations[$key]['en'];
    }

    return $key;
}

/**
 * Echo static translation string (escaped)
 *
 * @param string $key Translation key
 */
function __starter___e($key) {
    echo esc_html(__starter___t($key));
}

/**
 * Check if current language matches
 *
 * @param string $lang Language code to check
 * @return bool
 */
function __starter___is_lang($lang) {
    return __starter___get_current_lang() === $lang;
}

/**
 * Get all static translations
 *
 * Registered with Polylang on init (see inc/theme-setup.php) so they appear
 * under Languages > Strings.
 *
 * @return array Translations array
 */
function __starter___get_translations() {
    return array(
        // Navigation
        'nav_home'        => array('en' => 'Home',     'es' => 'Inicio'),
        'nav_about'       => array('en' => 'About',    'es' => 'Acerca de'),
        'nav_services'    => array('en' => 'Services', 'es' => 'Servicios'),
        'nav_contact'     => array('en' => 'Contact',  'es' => 'Contacto'),

        // Common UI
        'read_more'       => array('en' => 'Read More',  'es' => 'Leer Más'),
        'learn_more'      => array('en' => 'Learn More', 'es' => 'Conocer Más'),
        'back_to_home'    => array('en' => 'Back to Home', 'es' => 'Volver al Inicio'),

        // Footer
        'footer_rights'   => array('en' => 'All rights reserved.', 'es' => 'Todos los derechos reservados.'),
        'footer_privacy'  => array('en' => 'Privacy Policy',       'es' => 'Política de Privacidad'),
        'footer_terms'    => array('en' => 'Terms of Service',     'es' => 'Términos de Servicio'),

        // Language switcher
        'lang_en'         => array('en' => 'English', 'es' => 'Inglés'),
        'lang_es'         => array('en' => 'Spanish', 'es' => 'Español'),

        // Add more translations as needed...
    );
}

/**
 * Generate language switch URL
 *
 * Points at the CURRENT page's counterpart in the requested language when one
 * exists -- the whole reason to use Polylang -- and falls back to that
 * language's home page when it does not. Returning the current URL with a
 * query arg, the way the _suffix model does, would be wrong here: under
 * Polylang the translated page is a different post at a different permalink.
 *
 * @param string $lang Language code to switch to
 * @return string URL
 */
function __starter___get_lang_url($lang) {
    if (!function_exists('pll_home_url')) {
        return home_url('/');
    }

    if (is_singular()) {
        $post_id = get_queried_object_id();
        if ($post_id && function_exists('pll_get_post')) {
            $translated = pll_get_post($post_id, $lang);
            if ($translated) {
                $permalink = get_permalink($translated);
                if ($permalink) {
                    return $permalink;
                }
            }
        }
    }

    return pll_home_url($lang);
}
