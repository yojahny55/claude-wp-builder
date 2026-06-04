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
    $candidate = '';
    if (isset($_GET['lang'])) {
        $candidate = sanitize_key(wp_unslash($_GET['lang']));
    } elseif (isset($_COOKIE['__starter___lang'])) {
        $candidate = sanitize_key(wp_unslash($_COOKIE['__starter___lang']));
    } elseif (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
        $candidate = strtolower(substr(sanitize_text_field(wp_unslash($_SERVER['HTTP_ACCEPT_LANGUAGE'])), 0, 2));
    }
    $lang = in_array($candidate, ['en', 'es'], true) ? $candidate : 'en';
    return $lang;
}

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
