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
     */
    add_filter('wpcf7_mail_components', function ($components, $form, $mail) {
        // Set HTML content type (requires CF7 5.7+)
        // Fallback: also hook wpcf7_mail_content_type if needed
        $components['content_type'] = 'text/html';

        // Determine language suffix based on form ID
        // ES form IDs are stored in theme mod by the wp-cf7 agent
        $es_form_id = get_theme_mod('__starter___cf7_form_es', 0);
        $suffix = ($form->id() === (int) $es_form_id) ? '_es' : '';

        // Build replacement map — use raw get_field() since we manually control language suffix
        $logo = __starter___get_field('site_logo', 'option');
        $replacements = array(
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
            $replacements['%%social_' . $network . '%%'] = get_field('social_' . $network, 'option') ?: '';
        }

        // Apply replacements to body and subject
        $components['body'] = str_replace(
            array_keys($replacements),
            array_values($replacements),
            $components['body']
        );
        $components['subject'] = str_replace(
            array_keys($replacements),
            array_values($replacements),
            $components['subject']
        );

        return $components;
    }, 10, 3);
});
