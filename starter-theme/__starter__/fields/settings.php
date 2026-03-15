<?php
/**
 * ACF Field Group: Site Settings (Options Page)
 *
 * @package __STARTER_NAME__
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!function_exists('acf_add_local_field_group')) {
    return;
}

acf_add_local_field_group(array(
    'key' => 'group_settings',
    'title' => '__STARTER_NAME__ Settings',
    'fields' => array(

        // ── General Tab ──────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_general',
            'label' => 'General',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_site_logo',
            'label' => 'Site Logo',
            'name' => 'site_logo',
            'type' => 'image',
            'return_format' => 'array',
            'preview_size' => 'medium',
            'instructions' => 'Upload the site logo. Recommended: SVG or transparent PNG.',
        ),
        array(
            'key' => 'field_settings_footer_brand_text',
            'label' => 'Footer Brand Text',
            'name' => 'footer_brand_text',
            'type' => 'textarea',
            'rows' => 3,
            'instructions' => 'Short brand description shown in the footer.',
        ),
        array(
            'key' => 'field_settings_copyright_text',
            'label' => 'Copyright Text',
            'name' => 'copyright_text',
            'type' => 'text',
            'instructions' => 'Copyright line. Use {year} for the current year.',
            'default_value' => '© {year} __STARTER_NAME__. All rights reserved.',
        ),

        // ── Contact Tab ──────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_contact',
            'label' => 'Contact',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_footer_email',
            'label' => 'Email Address',
            'name' => 'footer_email',
            'type' => 'text',
            'instructions' => 'Contact email displayed in the footer.',
        ),
        array(
            'key' => 'field_settings_footer_phone',
            'label' => 'Phone Number',
            'name' => 'footer_phone',
            'type' => 'text',
            'instructions' => 'Contact phone displayed in the footer.',
        ),
        array(
            'key' => 'field_settings_contact_form_shortcode',
            'label' => 'Contact Form Shortcode',
            'name' => 'contact_form_shortcode',
            'type' => 'text',
            'instructions' => 'Shortcode for the contact form (e.g., Contact Form 7).',
        ),

        // ── Legal Tab ────────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_legal',
            'label' => 'Legal',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_privacy_policy_page',
            'label' => 'Privacy Policy Page',
            'name' => 'privacy_policy_page',
            'type' => 'page_link',
            'post_type' => array('page'),
            'allow_null' => 1,
        ),
        array(
            'key' => 'field_settings_terms_page',
            'label' => 'Terms of Service Page',
            'name' => 'terms_page',
            'type' => 'page_link',
            'post_type' => array('page'),
            'allow_null' => 1,
        ),
        array(
            'key' => 'field_settings_legal_disclaimer',
            'label' => 'Legal Disclaimer',
            'name' => 'legal_disclaimer',
            'type' => 'textarea',
            'rows' => 4,
            'instructions' => 'Legal disclaimer text shown in the footer or legal pages.',
        ),

        // ── Address Tab ──────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_address',
            'label' => 'Address',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_business_address',
            'label' => 'Business Address',
            'name' => 'business_address',
            'type' => 'textarea',
            'rows' => 3,
            'instructions' => 'Full business address.',
        ),
        array(
            'key' => 'field_settings_address_map_link',
            'label' => 'Map Link',
            'name' => 'address_map_link',
            'type' => 'url',
            'instructions' => 'Google Maps or similar link to the business location.',
        ),

        // ── Social Tab ───────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_social',
            'label' => 'Social',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_social_instagram',
            'label' => 'Instagram URL',
            'name' => 'social_instagram',
            'type' => 'url',
        ),
        array(
            'key' => 'field_settings_social_facebook',
            'label' => 'Facebook URL',
            'name' => 'social_facebook',
            'type' => 'url',
        ),
        array(
            'key' => 'field_settings_social_tiktok',
            'label' => 'TikTok URL',
            'name' => 'social_tiktok',
            'type' => 'url',
        ),
        array(
            'key' => 'field_settings_social_youtube',
            'label' => 'YouTube URL',
            'name' => 'social_youtube',
            'type' => 'url',
        ),
        array(
            'key' => 'field_settings_social_linkedin',
            'label' => 'LinkedIn URL',
            'name' => 'social_linkedin',
            'type' => 'url',
        ),

        // ── Designer Tab ─────────────────────────────────────────
        array(
            'key' => 'field_settings_tab_designer',
            'label' => 'Designer',
            'type' => 'tab',
            'placement' => 'left',
        ),
        array(
            'key' => 'field_settings_designer_credit_text',
            'label' => 'Designer Credit Text',
            'name' => 'designer_credit_text',
            'type' => 'text',
            'instructions' => 'Text before the designer name, e.g., "Designed by".',
            'default_value' => 'Designed by',
        ),
        array(
            'key' => 'field_settings_designer_name',
            'label' => 'Designer Name',
            'name' => 'designer_name',
            'type' => 'text',
        ),
        array(
            'key' => 'field_settings_designer_url',
            'label' => 'Designer URL',
            'name' => 'designer_url',
            'type' => 'url',
        ),

        // ── Spanish Translations Tab ─────────────────────────────
        array(
            'key' => 'field_settings_tab_spanish',
            'label' => 'Spanish Translations',
            'type' => 'tab',
            'placement' => 'left',
        ),

        // General - Spanish
        array(
            'key' => 'field_settings_site_logo_es',
            'label' => 'Site Logo (ES)',
            'name' => 'site_logo_es',
            'type' => 'image',
            'return_format' => 'array',
            'preview_size' => 'medium',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_footer_brand_text_es',
            'label' => 'Footer Brand Text (ES)',
            'name' => 'footer_brand_text_es',
            'type' => 'textarea',
            'rows' => 3,
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_copyright_text_es',
            'label' => 'Copyright Text (ES)',
            'name' => 'copyright_text_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),

        // Contact - Spanish
        array(
            'key' => 'field_settings_footer_email_es',
            'label' => 'Email Address (ES)',
            'name' => 'footer_email_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_footer_phone_es',
            'label' => 'Phone Number (ES)',
            'name' => 'footer_phone_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_contact_form_shortcode_es',
            'label' => 'Contact Form Shortcode (ES)',
            'name' => 'contact_form_shortcode_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),

        // Legal - Spanish
        array(
            'key' => 'field_settings_privacy_policy_page_es',
            'label' => 'Privacy Policy Page (ES)',
            'name' => 'privacy_policy_page_es',
            'type' => 'page_link',
            'post_type' => array('page'),
            'allow_null' => 1,
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_terms_page_es',
            'label' => 'Terms of Service Page (ES)',
            'name' => 'terms_page_es',
            'type' => 'page_link',
            'post_type' => array('page'),
            'allow_null' => 1,
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_legal_disclaimer_es',
            'label' => 'Legal Disclaimer (ES)',
            'name' => 'legal_disclaimer_es',
            'type' => 'textarea',
            'rows' => 4,
            'instructions' => 'Leave empty to use English version.',
        ),

        // Address - Spanish
        array(
            'key' => 'field_settings_business_address_es',
            'label' => 'Business Address (ES)',
            'name' => 'business_address_es',
            'type' => 'textarea',
            'rows' => 3,
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_address_map_link_es',
            'label' => 'Map Link (ES)',
            'name' => 'address_map_link_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),

        // Social - Spanish (unlikely to differ, but included for completeness)
        array(
            'key' => 'field_settings_social_instagram_es',
            'label' => 'Instagram URL (ES)',
            'name' => 'social_instagram_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_social_facebook_es',
            'label' => 'Facebook URL (ES)',
            'name' => 'social_facebook_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_social_tiktok_es',
            'label' => 'TikTok URL (ES)',
            'name' => 'social_tiktok_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_social_youtube_es',
            'label' => 'YouTube URL (ES)',
            'name' => 'social_youtube_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_social_linkedin_es',
            'label' => 'LinkedIn URL (ES)',
            'name' => 'social_linkedin_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),

        // Designer - Spanish
        array(
            'key' => 'field_settings_designer_credit_text_es',
            'label' => 'Designer Credit Text (ES)',
            'name' => 'designer_credit_text_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_designer_name_es',
            'label' => 'Designer Name (ES)',
            'name' => 'designer_name_es',
            'type' => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key' => 'field_settings_designer_url_es',
            'label' => 'Designer URL (ES)',
            'name' => 'designer_url_es',
            'type' => 'url',
            'instructions' => 'Leave empty to use English version.',
        ),
    ),
    'location' => array(
        array(
            array(
                'param' => 'options_page',
                'operator' => '==',
                'value' => '__starter__-settings',
            ),
        ),
    ),
    'menu_order' => 0,
    'position' => 'normal',
    'style' => 'default',
    'label_placement' => 'top',
    'instruction_placement' => 'label',
    'active' => true,
));
