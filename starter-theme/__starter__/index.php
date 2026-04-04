<?php
/**
 * Main Index Template (required WordPress fallback)
 * @package __STARTER_NAME__
 */

// Exit if accessed directly.
defined( 'ABSPATH' ) || exit;

get_header();
?>
<main id="main-content">
    <?php if (have_posts()) : ?>
        <?php while (have_posts()) : the_post(); ?>
        <article class="post">
            <div class="container">
                <h2 class="post__title">
                    <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                </h2>
                <div class="post__excerpt">
                    <?php the_excerpt(); ?>
                </div>
            </div>
        </article>
        <?php endwhile; ?>
        <div class="container">
            <?php the_posts_navigation(); ?>
        </div>
    <?php else : ?>
        <div class="container">
            <p><?php esc_html_e('No posts found.', '__starter__'); ?></p>
        </div>
    <?php endif; ?>
</main>
<?php get_footer(); ?>
