<?php
/**
 * Customer emails in the language the order was placed in.
 *
 * The checkout records the shopper's language on the order. Emails often go out from a
 * request with no language at all (a payment callback, an admin status change), so
 * WooCommerce's usual switch to the site locale would always pick the default language.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function store_pll_register_emails() {
	add_action( 'woocommerce_checkout_create_order', 'store_pll_record_order_lang' );
	add_action( 'woocommerce_store_api_checkout_update_order_from_request', 'store_pll_record_order_lang' );
	add_filter( 'woocommerce_allow_switching_email_locale', 'store_pll_mark_email_pending', 10, 2 );
	add_action( 'woocommerce_email', 'store_pll_add_email_recipient_filters' );
	add_filter( 'woocommerce_allow_restoring_email_locale', 'store_pll_restore_email_locale', 10, 2 );
	add_action( 'init', 'store_pll_register_email_footer_string' );
	add_filter( 'woocommerce_email_footer_text', 'store_pll_translate_email_footer', 5 ); // Before WC_Emails::replace_placeholders (10).
}

/**
 * Order meta keys holding the order's language. The first is written; the rest are read
 * as fallbacks: a site that recorded the language under another key adds it here.
 */
function store_pll_order_lang_meta_keys() {
	return (array) apply_filters( 'store_pll_order_lang_meta_keys', array( '_store_pll_order_lang' ) );
}

/** Language slug stored on an order, or ''. */
function store_pll_order_lang( $order ) {
	if ( ! is_object( $order ) || ! method_exists( $order, 'get_meta' ) ) {
		return '';
	}
	foreach ( store_pll_order_lang_meta_keys() as $key ) {
		$slug = (string) $order->get_meta( $key );
		if ( '' !== $slug ) {
			return $slug;
		}
	}
	return '';
}

/**
 * Language a checkout is placed in.
 *
 * The classic checkout posts to a page in the shopper's language. The block checkout posts
 * to the Store API under /wp-json/, which carries no language, so Polylang answers false
 * there (measured); its `pll_language` cookie still holds the language of the last page
 * the shopper saw, and is accepted only when it names a language of this site.
 *
 * @param string|false $current   pll_current_language().
 * @param string       $cookie    The pll_language cookie, or ''.
 * @param string[]     $languages Slugs of the site's languages.
 */
function store_pll_checkout_lang( $current, $cookie, array $languages ) {
	if ( $current ) {
		return (string) $current;
	}
	$cookie = (string) $cookie;
	return in_array( $cookie, $languages, true ) ? $cookie : '';
}

/** Classic checkout and Store API checkout alike. */
function store_pll_record_order_lang( $order ) {
	if ( ! function_exists( 'pll_current_language' ) || ! is_object( $order ) || ! method_exists( $order, 'update_meta_data' ) ) {
		return;
	}
	$cookie = isset( $_COOKIE['pll_language'] ) ? sanitize_key( wp_unslash( $_COOKIE['pll_language'] ) ) : ''; // phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotValidated
	$lang   = store_pll_checkout_lang( pll_current_language(), $cookie, (array) pll_languages_list() );
	if ( '' !== $lang ) {
		$order->update_meta_data( store_pll_order_lang_meta_keys()[0], $lang );
	}
}

/**
 * Per-email switch state: '', 'pending', 'none' or 'switched'.
 *
 * WooCommerce calls setup_locale() before it sets $email->object, so that hook only marks
 * the email as pending. The switch happens on the first recipient lookup, which runs once
 * the order is attached and before subject and body are built. restore_locale() undoes
 * it on its way out.
 */
function store_pll_email_lang_state( $email, $state = null ) {
	static $states = array();
	$key = spl_object_id( $email );
	if ( null !== $state ) {
		$states[ $key ] = $state;
	}
	return $states[ $key ] ?? '';
}

function store_pll_mark_email_pending( $allow, $email ) {
	if ( $allow && $email instanceof WC_Email && $email->is_customer_email() ) {
		store_pll_email_lang_state( $email, 'pending' );
	}
	return $allow;
}

function store_pll_add_email_recipient_filters( $mailer ) {
	foreach ( $mailer->get_emails() as $email ) {
		if ( $email->is_customer_email() ) {
			add_filter( 'woocommerce_email_recipient_' . $email->id, 'store_pll_switch_email_locale', 10, 3 );
		}
	}
}

/**
 * WC_Settings_API::get_option() caches the translated default subject and heading in
 * $email->settings the first time it builds them, so settings are reloaded on every
 * switch; otherwise a second email in the same request keeps the first one's language.
 */
function store_pll_switch_email_locale( $recipient, $object, $email ) {
	if ( ! $email instanceof WC_Email || 'pending' !== store_pll_email_lang_state( $email ) ) {
		return $recipient;
	}
	store_pll_email_lang_state( $email, 'none' );
	$slug = $object instanceof WC_Order ? store_pll_order_lang( $object ) : '';
	$lang = ( $slug && function_exists( 'PLL' ) ) ? PLL()->model->get_language( $slug ) : null;
	if ( $lang && switch_to_locale( $lang->locale ) ) {
		store_pll_lang( $lang->slug );
		store_pll_email_lang_state( $email, 'switched' );
		$email->init_settings(); // Drop subject/heading defaults cached in the previous language.
	}
	return $recipient;
}

function store_pll_restore_email_locale( $allow, $email ) {
	if ( $email instanceof WC_Email && 'switched' === store_pll_email_lang_state( $email ) ) {
		restore_previous_locale();
		store_pll_lang( false );
		$email->init_settings();
	}
	if ( $email instanceof WC_Email ) {
		store_pll_email_lang_state( $email, '' );
	}
	return $allow;
}

/** The email footer is a stored string; its translations live in Languages > Translations. */
function store_pll_register_email_footer_string() {
	if ( function_exists( 'pll_register_string' ) ) {
		pll_register_string( 'woocommerce_email_footer_text', get_option( 'woocommerce_email_footer_text', '' ), 'WooCommerce', true );
	}
}

function store_pll_translate_email_footer( $text ) {
	$lang = store_pll_lang();
	return ( $lang && function_exists( 'pll_translate_string' ) ) ? pll_translate_string( $text, $lang ) : $text;
}
