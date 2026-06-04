<?php
/**
 * Cinematic front page.
 *
 *   1. nav (lockup + hamburger + motion toggle)
 *   2. stage (persistent video layer)
 *   3. scene loop (content layer that scrolls over stage)
 *   4. optional trailing flex sections (hybrid mode)
 *   5. footer
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

get_header();

$scenes = __starter___cinematic_scenes();
set_query_var('__cinematic_scenes', $scenes);
?>

<?php get_template_part('template-parts/cinematic/nav'); ?>

<main id="cinematic" class="cinematic" role="main">

    <?php __starter___cinematic_render_stage($scenes); ?>

    <div class="reel">
        <?php foreach ($scenes as $i => $scene) :
            __starter___cinematic_render_scene($scene, $i);
        endforeach; ?>
    </div>

    <?php
    // Hybrid: trailing flex sections rendered AFTER the reel.
    if (function_exists('have_rows') && have_rows('trailing_sections')) :
        echo '<div class="trailing">';
        while (have_rows('trailing_sections')) :
            the_row();
            $layout = get_row_layout();
            // Each layout maps to template-parts/section-<layout>.php
            $part = locate_template('template-parts/section-' . sanitize_file_name($layout) . '.php');
            if ($part) {
                load_template($part, false);
            }
        endwhile;
        echo '</div>';
    endif;
    ?>

</main>

<?php
get_footer();
