<?php
/**
 * Contact Form 7 Helpers
 * Replaces %%placeholder%% tokens in CF7 email templates with ACF settings values.
 * Sets HTML content type for branded email templates.
 *
 * @package __STARTER_NAME__
 */
if (!defined('ABSPATH')) { exit; }

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

    // Build replacement map
    $logo = __starter___get_field('site_logo', 'option');
    $replacements = array(
        '%%site_url%%'         => home_url(),
        '%%site_logo%%'        => is_array($logo) ? ($logo['url'] ?? '') : ($logo ?: ''),
        '%%contact_email%%'    => __starter___get_field('contact_email' . $suffix, 'option')
                                  ?: __starter___get_field('contact_email', 'option') ?: get_option('admin_email'),
        '%%contact_phone%%'    => __starter___get_field('contact_phone' . $suffix, 'option')
                                  ?: __starter___get_field('contact_phone', 'option') ?: '',
        '%%copyright%%'        => __starter___get_field('copyright_text' . $suffix, 'option')
                                  ?: __starter___get_field('copyright_text', 'option') ?: '',
        '%%business_address%%' => __starter___get_field('business_address' . $suffix, 'option')
                                  ?: __starter___get_field('business_address', 'option') ?: '',
    );

    // Social links (not translatable — no suffix)
    $social_fields = array('facebook', 'instagram', 'tiktok', 'linkedin', 'youtube');
    foreach ($social_fields as $network) {
        $replacements['%%social_' . $network . '%%'] = __starter___get_field('social_' . $network, 'option') ?: '';
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
