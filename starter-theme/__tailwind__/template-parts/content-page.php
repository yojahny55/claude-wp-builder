<?php
/**
 * Template part for a generic page — legal pages, and anything else that is
 * prose the client edits in the WYSIWYG rather than a designed section built
 * from the demo.
 *
 * The demo a project is built from never draws one of these — there is no
 * section to convert — so this ships with its own small baseline instead of
 * the unstyled `entry-title` / `entry-content` underscores boilerplate: a
 * centered column capped at a comfortable reading width, and `@tailwindcss/
 * typography`'s `prose` class (already loaded by main.css) carrying headings,
 * lists, links and tables through the project's own `@theme` colors via its
 * `prose-*` modifiers. `wp-tailwind` may still promote this if a project's
 * `/wp-page legal` build wants a page-specific look — this is the fallback a
 * page keeps if nobody ever does.
 *
 * @link https://developer.wordpress.org/themes/basics/template-hierarchy/
 *
 * @package __starter__
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }
?>

<article class="mx-auto max-w-[720px] px-5 py-16 md:py-20" id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
	<header class="entry-header">
		<?php the_title( '<h1 class="text-3xl md:text-4xl font-bold text-primary">', '</h1>' ); ?>
	</header><!-- .entry-header -->

	<?php __starter___post_thumbnail(); ?>

	<div class="entry-content prose max-w-none mt-8 prose-headings:text-primary prose-a:text-accent">
		<?php
		the_content();

		wp_link_pages(
			array(
				'before' => '<div class="page-links mt-8">' . esc_html__( 'Pages:', '__starter__' ),
				'after'  => '</div>',
			)
		);
		?>
	</div><!-- .entry-content -->

	<?php if ( get_edit_post_link() ) : ?>
		<footer class="entry-footer mt-8 text-sm">
			<?php
			edit_post_link(
				sprintf(
					wp_kses(
						/* translators: %s: Name of current post. Only visible to screen readers */
						__( 'Edit <span class="screen-reader-text">%s</span>', '__starter__' ),
						array(
							'span' => array(
								'class' => array(),
							),
						)
					),
					wp_kses_post( get_the_title() )
				),
				'<span class="edit-link">',
				'</span>'
			);
			?>
		</footer><!-- .entry-footer -->
	<?php endif; ?>
</article><!-- #post-<?php the_ID(); ?> -->
