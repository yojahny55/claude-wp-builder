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
        setcookie('__starter___lang', $current_lang, array( 'expires' => time() + (365 * 24 * 60 * 60), 'path' => '/', 'samesite' => 'Lax', 'httponly' => true, 'secure' => is_ssl() ));
        return $current_lang;
    }

    // 2. Check cookie
    if (isset($_COOKIE['__starter___lang']) && in_array($_COOKIE['__starter___lang'], __STARTER___SUPPORTED_LANGS)) {
        $current_lang = sanitize_text_field($_COOKIE['__starter___lang']);
        return $current_lang;
    }

    // 3. Check browser language (Accept-Language header), by q-value: `fr,es;q=0.9`
    //    is Spanish (the first two characters alone named unsupported French and fell
    //    through). q=0 is refused, equal q-values keep header order, `es-MX` matches `es`.
    //    Inline rather than a helper: every function here is template-facing, and the
    //    Polylang variant would have to define it too.
    if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
        $ranked = array();
        foreach (explode(',', sanitize_text_field(wp_unslash($_SERVER['HTTP_ACCEPT_LANGUAGE']))) as $i => $part) {
            $bits = explode(';', trim($part));
            $tag  = strtolower(trim($bits[0]));
            $q    = 1.0;
            foreach (array_slice($bits, 1) as $param) {
                $param = trim($param);
                if (strncasecmp($param, 'q=', 2) === 0) {
                    $q = (float) substr($param, 2);
                }
            }
            if ($tag !== '' && $q > 0) {
                $ranked[] = array($q, $i, substr($tag, 0, 2));
            }
        }
        usort($ranked, function ($a, $b) {
            return $a[0] === $b[0] ? $a[1] - $b[1] : ($a[0] < $b[0] ? 1 : -1);
        });
        foreach ($ranked as $entry) {
            if (in_array($entry[2], __STARTER___SUPPORTED_LANGS, true)) {
                $current_lang = $entry[2];
                return $current_lang;
            }
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

    // Fall back to the primary language (the one the demo was written in), then
    // to English only when the table has no primary-language entry at all.
    // While DEFAULT_LANG is still 'en' — the unscaffolded starter's value — the
    // two branches below test the same key, so the second is unreachable and
    // reads as dead code. It is not: it goes live as soon as /wp-init Step 5
    // sets DEFAULT_LANG to a non-English primary, and dropping it would leave
    // such a project with no English fallback at all.
    if (isset($translations[$key][__STARTER___DEFAULT_LANG])) {
        return $translations[$key][__STARTER___DEFAULT_LANG];
    }
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

        // Directory filter (assets/js/src/directory-filter.js)
        'directory_count' => array(
            'en' => '{count} results',
            'es' => '{count} resultados',
        ),
        'directory_count_one' => array(
            'en' => '1 result',
            'es' => '1 resultado',
        ),
        'directory_clear' => array(
            'en' => 'Clear filters',
            'es' => 'Limpiar filtros',
        ),
        'directory_empty' => array(
            'en' => 'No results match these filters.',
            'es' => 'Ningún resultado coincide con estos filtros.',
        ),
        'directory_search' => array(
            'en' => 'Search',
            'es' => 'Buscar',
        ),
        'directory_all' => array(
            'en' => 'All',
            'es' => 'Todos',
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

        // Chrome that used to go through gettext (header, 404): gettext follows
        // the site locale, not ?lang=, and Polylang ships no .mo for the theme
        'skip_to_content' => array(
            'en' => 'Skip to content',
            'es' => 'Saltar al contenido',
        ),
        'main_menu' => array(
            'en' => 'Main menu',
            'es' => 'Menú principal',
        ),
        'error_404_title' => array(
            'en' => 'Oops! That page can’t be found.',
            'es' => '¡Vaya! No se encuentra esa página.',
        ),
        'error_404_text' => array(
            'en' => 'It looks like nothing was found at this location. Maybe try one of the links below or a search?',
            'es' => 'Parece que no hay nada en esta dirección. Prueba alguno de los enlaces de abajo o haz una búsqueda.',
        ),
        'error_404_categories' => array(
            'en' => 'Most Used Categories',
            'es' => 'Categorías más usadas',
        ),
        'error_404_archives' => array(
            'en' => 'Try looking in the monthly archives. %1$s',
            'es' => 'Prueba a buscar en los archivos mensuales. %1$s',
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

/**
 * Menu location for the current language
 *
 * inc/theme-setup.php registers one location per language (primary-en,
 * primary-es, ...), so a template asks for the current language's own. The
 * Polylang variant returns the bare name instead, because that model registers
 * each location once and swaps the menu in per language. Templates call this
 * rather than building the name, so swapping this file switches both.
 *
 * @param string $location Base location name ('primary', 'footer')
 * @return string Registered location name
 */
function __starter___nav_location($location) {
    return $location . '-' . __starter___get_current_lang();
}

/*
 * Make the first call before any output. It is the call that sets the language
 * cookie, and setcookie() fails once header.php has started printing; left to
 * the templates, the first call came from wp_enqueue_scripts inside wp_head(),
 * so a ?lang= switch lasted one page.
 */
add_action('init', '__starter___get_current_lang');

/*
 * Page caches. Without ?lang the language comes from a cookie or from
 * Accept-Language, so one URL serves two languages: a proxy or CDN must key on
 * both (Vary), and a WordPress page cache, which ignores Vary, must not store a
 * response that is not the default language or that sets the language cookie
 * (DONOTCACHEPAGE, honoured by the common cache plugins, plus no-cache headers).
 * A cache that already holds the default-language page still serves it to a
 * returning visitor whose cookie says otherwise: that needs the cache's own
 * cookie rule, which the theme cannot set.
 */
add_action('send_headers', function () {
    if (is_admin()) {
        return;
    }
    header('Vary: Accept-Language, Cookie', false);
    if (isset($_GET['lang']) || __starter___get_current_lang() !== __STARTER___DEFAULT_LANG) {
        if (!defined('DONOTCACHEPAGE')) {
            define('DONOTCACHEPAGE', true);
        }
        nocache_headers();
    }
});

/*
 * <html lang> follows the request, not the site locale. header.php prints
 * language_attributes(), which reads the locale: the primary language on every
 * request of a suffix site, ?lang=es included (WCAG 3.1.1).
 */
add_filter('language_attributes', function ($output) {
    // Front end only: wp-admin and the login screen follow the user's locale,
    // not a visitor's ?lang or cookie.
    if (is_admin() || did_action('login_init')) {
        return $output;
    }
    return (string) preg_replace('/lang="[^"]*"/', 'lang="' . esc_attr(__starter___get_current_lang()) . '"', $output);
});
