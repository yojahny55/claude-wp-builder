<?php
/**
 * The main template file (fallback for every request no other template matches).
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

get_header();
?>

<main id="cinematic" class="site-main" role="main">
    <?php if (have_posts()) : ?>

        <?php if (is_home() && ! is_front_page()) : ?>
            <header>
                <h1 class="page-title screen-reader-text"><?php single_post_title(); ?></h1>
            </header>
        <?php endif; ?>

        <?php while (have_posts()) : the_post(); ?>
            <article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
                <h2 class="entry-title">
                    <a href="<?php echo esc_url(get_permalink()); ?>"><?php the_title(); ?></a>
                </h2>
                <div class="entry-summary"><?php the_excerpt(); ?></div>
            </article>
        <?php endwhile; ?>

        <?php the_posts_navigation(); ?>

    <?php else : ?>
        <p><?php esc_html_e('Nothing was found.', '__starter__'); ?></p>
    <?php endif; ?>
</main>

<?php
get_footer();
