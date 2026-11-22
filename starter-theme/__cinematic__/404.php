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
            <h1 class="page-title"><?php echo esc_html(__starter___b('Oops! That page can’t be found.', '¡Vaya! No se encuentra esa página.')); ?></h1>
        </header>
        <div class="page-content">
            <p><?php echo esc_html(__starter___b('It looks like nothing was found at this location. Maybe try a search?', 'Parece que no hay nada en esta dirección. Prueba a hacer una búsqueda.')); ?></p>
            <?php get_search_form(); ?>
        </div>
    </section>
</main>

<?php
get_footer();
