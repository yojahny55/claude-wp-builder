<?php
/**
 * Default Page Template
 * @package __STARTER_NAME__
 */

// Exit if accessed directly.
defined( 'ABSPATH' ) || exit;

get_header();
?>
<main id="main-content" class="page">
    <?php while (have_posts()) : the_post(); ?>
    <article class="page__article">
        <div class="container">
            <header class="page__header">
                <h1 class="page__title"><?php the_title(); ?></h1>
            </header>
            <div class="page__content">
                <?php the_content(); ?>
            </div>
        </div>
    </article>
    <?php endwhile; ?>
</main>
<?php get_footer(); ?>
