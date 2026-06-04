<?php
/**
 * Persistent fixed stage layer.
 *
 * Receives scenes via the `__starter___cinematic_render_stage()` helper.
 * This template is the FALLBACK shape if helpers are bypassed.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

$scenes = (array) get_query_var('__cinematic_scenes', []);
if (empty($scenes)) {
    return;
}
__starter___cinematic_render_stage($scenes);
