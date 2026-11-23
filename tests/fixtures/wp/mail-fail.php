<?php
/**
 * Fixture mail failure. Returns false from pre_wp_mail, so every wp_mail() fails as it does on a
 * host with no mail transport -- whatever this machine's PHP would otherwise deliver to (a local
 * catcher such as Mailpit makes mail() succeed).
 *
 * Copied into wp-content/mu-plugins by tests/checks/woo-verify-integration.sh for its
 * failed-email case, and removed before the mail sink goes in.
 */
add_filter( 'pre_wp_mail', '__return_false' );
