<?php
/**
 * Maintenance mode: a 503 page for visitors while editors keep working.
 * Copied by /wp-maintenance. PHP 7.4 floor.
 *
 * The switch is one option, `__prefix___maintenance`. Absent means off; present, it holds
 * the Retry-After in seconds. Nothing here runs a query or changes markup while the option
 * is absent, so a theme that carries this file renders exactly as one that does not.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Retry-After in seconds when maintenance is on, or 0 when it is off.
 * A value that is not a positive number falls back to one hour, never to "off": the
 * option existing is the switch, its value only tunes the header.
 */
function __prefix___maintenance_retry_after() {
    $value = get_option( '__prefix___maintenance', false );
    if ( false === $value ) {
        return 0;
    }
    $seconds = absint( $value );
    if ( $seconds < 60 ) {
        $seconds = 3600;
    }
    return min( $seconds, 7 * DAY_IN_SECONDS );
}

/**
 * Whether the current visitor sees the site rather than the maintenance page.
 * Editors (`edit_posts`) work through it; customers and subscribers do not.
 */
function __prefix___maintenance_bypass() {
    return (bool) apply_filters( '__prefix___maintenance_bypass', current_user_can( 'edit_posts' ) );
}

// Front end only: template_redirect never fires for wp-admin, wp-login.php, admin-ajax,
// cron or WP-CLI, so those stay reachable without listing them.
add_action( 'template_redirect', function () {
    $retry = __prefix___maintenance_retry_after();
    if ( 0 === $retry || __prefix___maintenance_bypass() ) {
        return;
    }
    status_header( 503 );
    nocache_headers();
    header( 'Retry-After: ' . $retry );
    __prefix___maintenance_render();
    exit;
}, 1 );

// The REST API would otherwise serve every page's content to an anonymous request while
// the front end says the site is closed.
add_filter( 'rest_authentication_errors', function ( $result ) {
    if ( null !== $result || 0 === __prefix___maintenance_retry_after() || __prefix___maintenance_bypass() ) {
        return $result;
    }
    return new WP_Error(
        '__prefix___maintenance',
        __( 'The site is under maintenance.', '__textdomain__' ),
        array( 'status' => 503 )
    );
} );

/**
 * The page itself: the site's logo or name and one line of copy. It deliberately skips
 * wp_head() and wp_footer(): those would print SEO meta claiming the page is indexable,
 * fire analytics on every closed-site hit and load theme scripts written for markup this
 * page does not have. The styles are inline and neutral.
 */
function __prefix___maintenance_render() {
    ?><!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo( 'charset' ); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title><?php echo esc_html( get_bloginfo( 'name' ) ); ?></title>
<style>
body{margin:0}
.maintenance{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1.5rem;padding:2rem;text-align:center;background:#fff;color:#1a1a1a;font-family:system-ui,sans-serif}
.maintenance__logo img{max-width:220px;height:auto}
.maintenance__title{margin:0;font-size:clamp(1.5rem,4vw,2.5rem)}
.maintenance__text{margin:0;max-width:40ch}
</style>
</head>
<body <?php body_class( 'maintenance-mode' ); ?>>
<main class="maintenance">
    <?php if ( has_custom_logo() ) : ?>
        <div class="maintenance__logo"><?php echo get_custom_logo(); // phpcs:ignore WordPress.Security.EscapeOutput -- core-escaped markup. ?></div>
    <?php else : ?>
        <p class="maintenance__logo"><?php echo esc_html( get_bloginfo( 'name' ) ); ?></p>
    <?php endif; ?>
    <h1 class="maintenance__title"><?php esc_html_e( 'We will be back soon', '__textdomain__' ); ?></h1>
    <p class="maintenance__text"><?php esc_html_e( 'The site is under maintenance. Please come back in a little while.', '__textdomain__' ); ?></p>
</main>
</body>
</html>
    <?php
}
