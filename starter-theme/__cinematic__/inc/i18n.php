<?php
/**
 * Minimal bilingual layer. Same shape as __starter__ basic theme.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

function __starter___current_lang(): string {
    static $lang = null;
    if ($lang !== null) {
        return $lang;
    }
    // URL > cookie > Accept-Language > default. An unsupported value at one
    // step falls through to the next, as in the Tailwind starter: ?lang=fr
    // keeps a visitor's stored Spanish instead of resetting it to English.
    $supported = ['en', 'es'];
    $lang      = 'en';
    $url       = isset($_GET['lang']) ? sanitize_key(wp_unslash($_GET['lang'])) : '';
    $cookie    = isset($_COOKIE['__starter___lang']) ? sanitize_key(wp_unslash($_COOKIE['__starter___lang'])) : '';
    if (in_array($url, $supported, true)) {
        $lang = $url;
    } elseif (in_array($cookie, $supported, true)) {
        $lang = $cookie;
    } elseif (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
        // By q-value: `fr,es;q=0.9` is Spanish. q=0 is refused, equal q-values keep
        // header order, `es-MX` matches `es`. Inline, as in the Tailwind starter: every
        // function here is template-facing and the Polylang variant would need it too.
        $ranked = [];
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
                $ranked[] = [$q, $i, substr($tag, 0, 2)];
            }
        }
        usort($ranked, fn ($a, $b) => $a[0] === $b[0] ? $a[1] <=> $b[1] : $b[0] <=> $a[0]);
        foreach ($ranked as $entry) {
            if (in_array($entry[2], $supported, true)) {
                $lang = $entry[2];
                break;
            }
        }
    }
    return $lang;
}

/*
 * Persist a ?lang= switch in the cookie __starter___current_lang() reads, or the
 * choice lasts one request. On init, because setcookie() fails once header.php
 * has started printing; and only when the language came from the URL and is not
 * already the stored one, so an ordinary page view sends no header.
 */
add_action('init', function (): void {
    if (!isset($_GET['lang'])) {
        return;
    }
    $lang   = __starter___current_lang();
    $stored = isset($_COOKIE['__starter___lang']) ? sanitize_key(wp_unslash($_COOKIE['__starter___lang'])) : '';
    if ($lang === sanitize_key(wp_unslash($_GET['lang'])) && $lang !== $stored && !headers_sent()) {
        setcookie('__starter___lang', $lang, array( 'expires' => time() + (365 * 24 * 60 * 60), 'path' => '/', 'samesite' => 'Lax', 'httponly' => true, 'secure' => is_ssl() ));
    }
});

/*
 * Page caches: same contract as the Tailwind starter. One URL serves two
 * languages through the cookie and Accept-Language, so proxies get Vary, and a
 * response that is not the default language or that carries ?lang (and so a
 * Set-Cookie) is kept out of WordPress page caches.
 */
add_action('send_headers', function (): void {
    if (is_admin()) {
        return;
    }
    header('Vary: Accept-Language, Cookie', false);
    if (isset($_GET['lang']) || __starter___current_lang() !== 'en') {
        if (!defined('DONOTCACHEPAGE')) {
            define('DONOTCACHEPAGE', true);
        }
        nocache_headers();
    }
});

/**
 * Bilingual literal. Allows br/em/strong/i/b/span via wp_kses
 * (esc_html was a prior bug — it escaped <br> as literal text).
 */
function __starter___b(string $en, string $es = ''): string {
    $value = __starter___current_lang() === 'es' && $es !== '' ? $es : $en;
    return wp_kses($value, [
        'br'     => [],
        'em'     => [],
        'strong' => [],
        'i'      => [],
        'b'      => [],
        'span'   => ['class' => true],
    ]);
}

/**
 * Read a settings-page option with bilingual fallback.
 */
function __starter___setting(string $name): string {
    $lang  = __starter___current_lang();
    $value = $lang === 'es' ? (string) get_field($name . '_es', 'option') : '';
    if ($value === '') {
        $value = (string) get_field($name, 'option');
    }
    return $value;
}

/**
 * Menu location for the current language: functions.php registers one per
 * language (primary-en, footer-es, ...). The Polylang variant returns the bare
 * name, which is all that model registers, so templates call this instead of
 * building the name and swapping this file switches both.
 */
function __starter___nav_location(string $location): string {
    return $location . '-' . __starter___current_lang();
}

/**
 * <html lang> follows the request, not the site locale. header.php prints
 * language_attributes(), which reads the locale: English on every request,
 * ?lang=es included (WCAG 3.1.1).
 */
add_filter('language_attributes', function (string $output): string {
    // Front end only: wp-admin and the login screen follow the user's locale.
    if (is_admin() || did_action('login_init')) {
        return $output;
    }
    return (string) preg_replace('/lang="[^"]*"/', 'lang="' . esc_attr(__starter___current_lang()) . '"', $output);
});

/**
 * Language switcher entries: one row per language with its label, URL and
 * whether it is the current one, so a template renders the switcher without
 * knowing which i18n model is installed. Suffix model: the current URL with
 * ?lang=<slug>. The Polylang variant answers from pll_the_languages().
 *
 * @return array<int, array{slug: string, label: string, url: string, active: bool}>
 */
function __starter___lang_switcher(): array {
    $current = __starter___current_lang();
    $rows    = [];
    foreach (['en', 'es'] as $slug) {
        $rows[] = [
            'slug'   => $slug,
            'label'  => strtoupper($slug),
            'url'    => add_query_arg('lang', $slug),
            'active' => $current === $slug,
        ];
    }
    return $rows;
}
