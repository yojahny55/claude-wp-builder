<?php
/**
 * Internationalization (i18n) Functions
 *
 * Provides language switching support using ACF/SCF fields with _es suffix
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
 * Get current language from URL param, cookie, browser, or default
 *
 * Priority: URL param > Cookie > Browser > Default (en)
 *
 * @return string Language code ('en' or 'es')
 */
function __starter___get_current_lang() {
    static $current_lang = null;

    if ($current_lang !== null) {
        return $current_lang;
    }

    // 1. Check URL parameter
    if (isset($_GET['lang']) && in_array($_GET['lang'], __STARTER___SUPPORTED_LANGS)) {
        $current_lang = sanitize_text_field($_GET['lang']);
        // Set cookie for persistence
        setcookie('__starter___lang', $current_lang, time() + (365 * 24 * 60 * 60), '/');
        return $current_lang;
    }

    // 2. Check cookie
    if (isset($_COOKIE['__starter___lang']) && in_array($_COOKIE['__starter___lang'], __STARTER___SUPPORTED_LANGS)) {
        $current_lang = sanitize_text_field($_COOKIE['__starter___lang']);
        return $current_lang;
    }

    // 3. Check browser language (Accept-Language header)
    if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
        $browser_lang = substr($_SERVER['HTTP_ACCEPT_LANGUAGE'], 0, 2);
        if (in_array($browser_lang, __STARTER___SUPPORTED_LANGS)) {
            $current_lang = $browser_lang;
            return $current_lang;
        }
    }

    // 4. Default
    $current_lang = __STARTER___DEFAULT_LANG;
    return $current_lang;
}

/**
 * Get translated field value with English fallback
 *
 * @param string $field_name Base field name (without _es suffix)
 * @param mixed  $post_id    Post ID, 'option', or false for current post
 * @return mixed Field value in current language or English fallback
 */
function __starter___get_field($field_name, $post_id = false) {
    $lang = __starter___get_current_lang();

    // If non-default language, try translated field first
    if ($lang !== __STARTER___DEFAULT_LANG) {
        $translated_field = $field_name . '_' . $lang;
        $value = get_field($translated_field, $post_id);

        // If translated field has value, return it
        if (!empty($value)) {
            return $value;
        }
    }

    // Fallback to base (English) field
    return get_field($field_name, $post_id);
}

/**
 * Get translated repeater field with specific subfields translated
 *
 * @param string $field_name            Base repeater field name
 * @param array  $translatable_subfields Array of subfield names that have _es versions
 * @param mixed  $post_id               Post ID, 'option', or false for current post
 * @return array Repeater data with translated subfields
 */
function __starter___get_repeater($field_name, $translatable_subfields = array(), $post_id = false) {
    $lang = __starter___get_current_lang();
    $repeater = get_field($field_name, $post_id);

    if (!$repeater || !is_array($repeater)) {
        return array();
    }

    // If default language or no translatable subfields, return as-is
    if ($lang === __STARTER___DEFAULT_LANG || empty($translatable_subfields)) {
        return $repeater;
    }

    // Process each row for translations
    foreach ($repeater as $index => $row) {
        foreach ($translatable_subfields as $subfield) {
            $translated_key = $subfield . '_' . $lang;
            // If translated subfield exists and has value, use it
            if (isset($row[$translated_key]) && !empty($row[$translated_key])) {
                $repeater[$index][$subfield] = $row[$translated_key];
            }
        }
    }

    return $repeater;
}

/**
 * Get translated sub_field value with English fallback
 * Used inside ACF repeater/flexible content while(have_rows()) loops
 *
 * @param string $field_name Base sub-field name (without _es suffix)
 * @return mixed Sub-field value in current language or English fallback
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
 * @param string $key Translation key
 * @return string Translated string
 */
function __starter___t($key) {
    $lang = __starter___get_current_lang();
    $translations = __starter___get_translations();

    if (isset($translations[$key][$lang])) {
        return $translations[$key][$lang];
    }

    // Fallback to English
    if (isset($translations[$key]['en'])) {
        return $translations[$key]['en'];
    }

    // Return key if translation not found
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
 * Add your static UI translations here. Each key maps to an array of
 * language code => translated string.
 *
 * @return array Translations array
 */
function __starter___get_translations() {
    return array(
        // Navigation
        'nav_home' => array(
            'en' => 'Home',
            'es' => 'Inicio',
        ),
        'nav_about' => array(
            'en' => 'About',
            'es' => 'Acerca de',
        ),
        'nav_services' => array(
            'en' => 'Services',
            'es' => 'Servicios',
        ),
        'nav_contact' => array(
            'en' => 'Contact',
            'es' => 'Contacto',
        ),

        // Common UI
        'read_more' => array(
            'en' => 'Read More',
            'es' => 'Leer Más',
        ),
        'learn_more' => array(
            'en' => 'Learn More',
            'es' => 'Conocer Más',
        ),
        'back_to_home' => array(
            'en' => 'Back to Home',
            'es' => 'Volver al Inicio',
        ),

        // Footer
        'footer_rights' => array(
            'en' => 'All rights reserved.',
            'es' => 'Todos los derechos reservados.',
        ),
        'footer_privacy' => array(
            'en' => 'Privacy Policy',
            'es' => 'Política de Privacidad',
        ),
        'footer_terms' => array(
            'en' => 'Terms of Service',
            'es' => 'Términos de Servicio',
        ),

        // Language switcher
        'lang_en' => array(
            'en' => 'English',
            'es' => 'Inglés',
        ),
        'lang_es' => array(
            'en' => 'Spanish',
            'es' => 'Español',
        ),

        // Add more translations as needed...
    );
}

/**
 * Generate language switch URL
 *
 * @param string $lang Language code to switch to
 * @return string URL with lang parameter
 */
function __starter___get_lang_url($lang) {
    // Get current URL without lang param
    $url = remove_query_arg('lang');

    // Add new lang param
    return add_query_arg('lang', $lang, $url);
}
