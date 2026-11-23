<?php
/**
 * Blog language: one select field on posts, and the blog lists filtered by it.
 * Copied by /wp-page blog when the project's i18n strategy is suffix. PHP 7.4 floor.
 *
 * Under the suffix strategy one page carries every language, but a blog post is usually
 * written in one. `post_language` records which; the blog index, archives and search then
 * list the posts in the visitor's language plus every post with no language set. A post
 * with no language is shown in every language, so a site that adds this file to a blog
 * that already has posts lists exactly what it listed before, until an editor sets one.
 *
 * Polylang projects never get this file: Polylang already carries a language per post.
 */

defined( 'ABSPATH' ) || exit;

/**
 * The languages the theme supports, from inc/i18n.php. Empty when that file does not
 * define them, and then the field is not registered and no query is filtered.
 *
 * @return string[]
 */
function __prefix___blog_languages() {
    if ( ! defined( '__PREFIX___SUPPORTED_LANGS' ) ) {
        return array();
    }
    $langs = (array) constant( '__PREFIX___SUPPORTED_LANGS' );
    return array_values( array_filter( $langs, 'is_string' ) );
}

// The field. Registered in code, not as Local JSON: it is part of this file's contract
// with the query filter below, so it is not meant to be edited in the dashboard.
add_action( 'acf/init', function () {
    $langs = __prefix___blog_languages();
    if ( ! $langs || ! function_exists( 'acf_add_local_field_group' ) ) {
        return;
    }
    $choices = array( '' => __( 'All languages', '__textdomain__' ) );
    foreach ( $langs as $lang ) {
        $choices[ $lang ] = strtoupper( $lang );
    }
    acf_add_local_field_group( array(
        'key'      => 'group_post_language',
        'title'    => __( 'Post language', '__textdomain__' ),
        'fields'   => array(
            array(
                'key'           => 'field_post_language',
                'label'         => __( 'Language', '__textdomain__' ),
                'name'          => 'post_language',
                'type'          => 'select',
                'instructions'  => __( 'Lists this post only for visitors reading in this language. All languages lists it for everyone.', '__textdomain__' ),
                'choices'       => $choices,
                'default_value' => '',
                'allow_null'    => 0,
                'return_format' => 'value',
            ),
        ),
        'location' => array(
            array(
                array(
                    'param'    => 'post_type',
                    'operator' => '==',
                    'value'    => 'post',
                ),
            ),
        ),
        'position' => 'side',
    ) );
} );

/**
 * Whether a query lists blog posts: the blog index, a post archive (category, tag, author,
 * date) or search. A custom post type archive is left alone; its posts carry no field.
 *
 * @param WP_Query $query
 * @return bool
 */
function __prefix___blog_language_applies( $query ) {
    if ( is_admin() || ! $query->is_main_query() ) {
        return false;
    }
    if ( $query->is_singular() || $query->is_feed() ) {
        return false;
    }
    if ( $query->is_post_type_archive() ) {
        return false;
    }
    return $query->is_home() || $query->is_category() || $query->is_tag()
        || $query->is_author() || $query->is_date() || $query->is_search();
}

add_action( 'pre_get_posts', function ( $query ) {
    if ( ! __prefix___blog_language_applies( $query ) ) {
        return;
    }
    if ( ! __prefix___blog_languages() || ! function_exists( '__prefix___get_current_lang' ) ) {
        return;
    }
    $lang = __prefix___get_current_lang();

    // The visitor's language, or no language at all. NOT EXISTS also keeps every page and
    // every other post type in search results: they never carry the key.
    $clause = array(
        'relation' => 'OR',
        array(
            'key'     => 'post_language',
            'value'   => $lang,
            'compare' => '=',
        ),
        array(
            'key'     => 'post_language',
            'value'   => '',
            'compare' => '=',
        ),
        array(
            'key'     => 'post_language',
            'compare' => 'NOT EXISTS',
        ),
    );

    $existing = $query->get( 'meta_query' );
    if ( is_array( $existing ) && $existing ) {
        $query->set( 'meta_query', array( 'relation' => 'AND', $existing, $clause ) );
    } else {
        $query->set( 'meta_query', array( $clause ) );
    }
} );
