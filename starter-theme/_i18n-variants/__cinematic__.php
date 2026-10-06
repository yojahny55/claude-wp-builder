<?php
/**
 * Minimal bilingual layer — Polylang variant.
 *
 * Drop-in replacement for inc/i18n.php when the project was scaffolded with
 * Polylang. Same four function names and signatures as the file it replaces,
 * so no template changes.
 *
 * Note this starter's contract is deliberately smaller than __tailwind__'s:
 * four functions, not ten. Each starter's Polylang variant mirrors ITS OWN
 * i18n.php, and tests/checks/wp-polylang.sh asserts that pairing per starter
 * rather than across them.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

/**
 * Current language, from Polylang.
 *
 * Falls back to 'en' when Polylang is inactive or cannot resolve one, which
 * includes WP-CLI, where there is no request to derive a language from.
 */
function __starter___current_lang(): string {
    static $lang = null;
    if ($lang !== null) {
        return $lang;
    }

    if (function_exists('pll_current_language')) {
        $current = pll_current_language('slug');
        if (in_array($current, ['en', 'es'], true)) {
            $lang = $current;
            return $lang;
        }
    }

    $lang = 'en';
    return $lang;
}

/**
 * Bilingual literal. Allows br/em/strong/i/b/span via wp_kses
 * (esc_html was a prior bug — it escaped <br> as literal text).
 *
 * Unchanged from the _suffix variant on purpose: these are literals passed in
 * from a template, not stored content, so Polylang has nothing to resolve.
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
 *
 * Still suffix-based, and that is not an oversight: ACF options are global --
 * one set of values for the whole site, not one per language -- so Polylang's
 * one-post-per-language model does not reach them, and free Polylang does not
 * translate the options page. The suffix stays the only thing that works here.
 * Upgrade path, if a project needs it: register each option string with
 * pll_register_string() and read it back through pll__().
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
 * Menu location for the current language.
 *
 * Under Polylang each location is registered ONCE, with no language suffix
 * (commands/wp-init.md Step 6), and Polylang swaps in the menu assigned to it
 * for the current language -- so the answer is the bare name. The suffix
 * i18n.php returns '<location>-<lang>', which this model never registers.
 */
function __starter___nav_location(string $location): string {
    return $location;
}
