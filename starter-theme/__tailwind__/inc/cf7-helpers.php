<?php
/**
 * Contact Form 7 Helpers
 * Replaces %%placeholder%% tokens in CF7 email templates with ACF settings values.
 * Sets HTML content type for branded email templates.
 *
 * @package __STARTER_NAME__
 */
if (!defined('ABSPATH')) { exit; }

/**
 * Render the options-page contact form, or return '' when it cannot render.
 *
 * `contact_form_shortcode` (read through __starter___get_field(), which returns the
 * current language's `_<lang>` twin when it is filled) is typed by a person, and the form it
 * names can be deleted or re-imported under a new id. CF7 then prints its own
 * `[contact-form-7 404 "Not Found"]` notice inside the page, which is what a real build
 * shipped. This resolves the form the way CF7's shortcode does (hash, then post id, then
 * title) and returns '' when none exists or CF7 is inactive, so the caller skips the
 * whole section:
 *
 *   $form = __starter___contact_form();
 *   if ( '' !== $form ) { ...section markup... echo $form; }
 *
 * A shortcode for another form plugin passes through unchanged.
 *
 * @return string Rendered form HTML, or ''.
 */
function __starter___contact_form() {
    $shortcode = trim((string) __starter___get_field('contact_form_shortcode', 'option'));
    if ('' === $shortcode) {
        return '';
    }
    if (preg_match('/^\[contact-form-7\b([^\]]*)\]/', $shortcode, $tag)) {
        if (!function_exists('wpcf7_contact_form')) {
            return '';
        }
        $atts = shortcode_parse_atts(trim($tag[1]));
        $atts = is_array($atts) ? $atts : array();
        $id    = isset($atts['id']) ? trim((string) $atts['id']) : '';
        $title = isset($atts['title']) ? trim((string) $atts['title']) : '';
        $form  = null;
        if ('' !== $id && function_exists('wpcf7_get_contact_form_by_hash')) {
            $form = wpcf7_get_contact_form_by_hash($id);
        }
        if (!$form && '' !== $id && ctype_digit($id)) {
            $form = wpcf7_contact_form((int) $id);
        }
        if (!$form && '' !== $title && function_exists('wpcf7_get_contact_form_by_title')) {
            $form = wpcf7_get_contact_form_by_title($title);
        }
        if (!$form) {
            return '';
        }
    }
    return do_shortcode($shortcode);
}

add_action('plugins_loaded', function() {
    if (!class_exists('WPCF7')) {
        return;
    }

    /**
     * Filter CF7 mail components to:
     * 1. Set content type to text/html
     * 2. Replace %%placeholder%% tokens with ACF settings values
     *
     * Only for mails the theme's forms declare as HTML (`use_html` on the mail
     * template, which is what the wp-cf7 agent writes). Any other CF7 form on the
     * site is the client's own, usually plain text, and forcing text/html on it makes
     * a visitor's [your-message] be parsed as markup: injected links and remote
     * images in a message the site owner trusts.
     *
     * Substituted values are escaped for the context they land in: the body is HTML,
     * the subject is a plain-text header.
     */
    add_filter('wpcf7_mail_components', function ($components, $form, $mail) {
        // get() with $replace = false returns the raw template flag, not a tag-expanded one.
        if (!is_object($mail) || !method_exists($mail, 'get') || !$mail->get('use_html', false)) {
            return $components;
        }

        // Set HTML content type (requires CF7 5.7+)
        // Fallback: also hook wpcf7_mail_content_type if needed
        $components['content_type'] = 'text/html';

        // Determine language suffix based on form ID
        // ES form IDs are stored in theme mod by the wp-cf7 agent
        $es_form_id = get_theme_mod('__starter___cf7_form_es', 0);
        $suffix = ($form->id() === (int) $es_form_id) ? '_es' : '';

        // Build the raw values — use raw get_field() since we manually control language suffix
        $logo = __starter___get_field('site_logo', 'option');
        $values = array(
            '%%site_url%%'         => home_url(),
            '%%site_logo%%'        => is_array($logo) ? ($logo['url'] ?? '') : ($logo ?: ''),
            '%%contact_email%%'    => get_field('contact_email' . $suffix, 'option')
                                      ?: get_field('contact_email', 'option') ?: get_option('admin_email'),
            '%%contact_phone%%'    => get_field('contact_phone' . $suffix, 'option')
                                      ?: get_field('contact_phone', 'option') ?: '',
            '%%copyright%%'        => get_field('copyright_text' . $suffix, 'option')
                                      ?: get_field('copyright_text', 'option') ?: '',
            '%%business_address%%' => get_field('business_address' . $suffix, 'option')
                                      ?: get_field('business_address', 'option') ?: '',
        );

        // Social links (not translatable — no suffix)
        $social_fields = array('facebook', 'instagram', 'tiktok', 'linkedin', 'youtube');
        foreach ($social_fields as $network) {
            $values['%%social_' . $network . '%%'] = get_field('social_' . $network, 'option') ?: '';
        }

        // URLs are escaped as URLs, everything else as text.
        $url_tokens = array('%%site_url%%', '%%site_logo%%');
        foreach ($social_fields as $network) {
            $url_tokens[] = '%%social_' . $network . '%%';
        }
        $html = array();
        $text = array();
        foreach ($values as $token => $value) {
            $value = (string) $value;
            if (in_array($token, $url_tokens, true)) {
                $html[$token] = esc_url($value);
                $text[$token] = esc_url_raw($value);
            } else {
                $html[$token] = esc_html($value);
                $text[$token] = wp_strip_all_tags($value);
            }
        }

        // Apply replacements to body (HTML) and subject (plain text)
        $components['body'] = str_replace(
            array_keys($html),
            array_values($html),
            $components['body']
        );
        $components['subject'] = str_replace(
            array_keys($text),
            array_values($text),
            $components['subject']
        );

        return $components;
    }, 10, 3);
});
