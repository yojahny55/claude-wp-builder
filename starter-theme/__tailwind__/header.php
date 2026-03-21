<?php
/**
 * The header for the theme
 *
 * @package __starter__
 */
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo( 'charset' ); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="profile" href="https://gmpg.org/xfn/11">
    <?php wp_head(); ?>
</head>

<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<!-- Replace with /wp-header output -->
<header id="masthead" class="site-header">
    <?php get_template_part( 'template-parts/header/site-branding' ); ?>
    <?php get_template_part( 'template-parts/header/navigation' ); ?>
</header>

<main id="primary" class="site-main">
