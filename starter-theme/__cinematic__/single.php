<?php
/**
 * The template for displaying a single post.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

get_header();
?>

<main id="cinematic" class="site-main" role="main">
    <?php while (have_posts()) : the_post(); ?>
        <article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
            <header class="entry-header">
                <h1 class="entry-title"><?php the_title(); ?></h1>
            </header>
            <div class="entry-content"><?php the_content(); ?></div>
        </article>

        <?php
        the_post_navigation(
            [
                'prev_text' => '<span class="nav-subtitle">' . esc_html__('Previous:', '__starter__') . '</span> <span class="nav-title">%title</span>',
                'next_text' => '<span class="nav-subtitle">' . esc_html__('Next:', '__starter__') . '</span> <span class="nav-title">%title</span>',
            ]
        );

        if (comments_open() || get_comments_number()) {
            comments_template();
        }
        ?>
    <?php endwhile; ?>
</main>

<?php
get_footer();
