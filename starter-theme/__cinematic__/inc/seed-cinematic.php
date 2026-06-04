<?php
/**
 * AUTO-GENERATED seed script — populates the cinematic_scenes repeater
 * on the home page from a JSON manifest. Idempotent.
 *
 * Usage:
 *   wp eval-file inc/seed-cinematic.php
 *   CINEMATIC_MANIFEST=/path/to/scenes.json wp eval-file inc/seed-cinematic.php
 *
 * The full body is written by the wp-cinematic agent at scaffold time —
 * this placeholder bails cleanly until then.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

if (! function_exists('update_row')) {
    fwrite(STDERR, "[seed-cinematic] ACF Pro / SCF Pro required for repeater seeding.\n");
    return;
}

fwrite(STDERR, "[seed-cinematic] Placeholder seed script. Run /wp-cinematic-init to generate the real one.\n");
