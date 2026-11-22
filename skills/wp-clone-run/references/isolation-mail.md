# /wp-clone — Step 5.4

`commands/wp-clone.md` sends the run here at Step 5.4.1. Follow it in order; nothing in it is optional background.

## Contents

- 5.4.1 — the mail-capture must-use plugin, why `pre_wp_mail`, what it does not stop

Write `wp-content/mu-plugins/00-clone-isolation.php` in the clone (create `mu-plugins/`
if absent):

```php
<?php
/**
 * CLONE ISOLATION — delete this file if this site ever becomes real.
 *
 * Written by /wp-clone. This site is a copy of another one and must not act
 * on its behalf. Mail is captured to wp-content/clone-mail.log instead of sent.
 */
defined( 'ABSPATH' ) || exit;

add_filter( 'pre_wp_mail', function ( $null, $atts ) {
    $to = is_array( $atts['to'] ) ? implode( ', ', $atts['to'] ) : (string) $atts['to'];
    error_log(
        sprintf( "[%s] BLOCKED to=%s subject=%s\n", gmdate( 'c' ), $to, (string) $atts['subject'] ),
        3,
        WP_CONTENT_DIR . '/clone-mail.log'
    );
    return true; // reported to the caller as sent; nothing leaves the machine
}, 0, 2 );
```

**`pre_wp_mail` is the right seam, and a mail plugin is not.** Every sender — core password
resets and new-user notices, WooCommerce order and subscription mail, Contact Form 7 —
goes through `wp_mail()`, and this filter short-circuits all of them at once. Disabling an
SMTP plugin instead does not stop sending: core falls back to PHP `mail()`, so the site
keeps mailing and merely stops logging it where anyone would look.

Returning `true` matters as much as intercepting. `wp_mail()` reports success to its caller,
so WooCommerce marks the order email sent and does not retry, and no plugin enters a failure
path that a real send would never have triggered. The clone behaves like the original
everywhere except at the wire.

**What this does not stop:** code that drives PHPMailer directly never calls `wp_mail()`, and
a plugin that replaces `wp_mail()` wholesale (SMTP plugins do) skips the filter. Redefining
`wp_mail()` in the mu-plugin is stronger: must-use plugins load before regular ones, so a
definition guarded by `function_exists` wins.

A **must-use** plugin, because it cannot be deactivated from wp-admin, survives any plugin
being reactivated, and cannot be undone by an option write. Its filename sorts first and its
header says what it is, so nobody mistakes it for part of the site.
