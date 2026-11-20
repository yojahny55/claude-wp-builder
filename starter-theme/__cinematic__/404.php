<?php
/**
 * The template for displaying 404 pages (not found).
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

get_header();
?>

<main id="cinematic" class="site-main" role="main">
    <section class="error-404 not-found">
        <header class="page-header">
            <h1 class="page-title"><?php esc_html_e('Oops! That page can&rsquo;t be found.', '__starter__'); ?></h1>
        </header>
        <div class="page-content">
            <p><?php esc_html_e('It looks like nothing was found at this location. Maybe try a search?', '__starter__'); ?></p>
            <?php get_search_form(); ?>
        </div>
    </section>
</main>

<?php
get_footer();
