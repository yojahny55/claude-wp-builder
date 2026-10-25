<?php
/**
 * Fixture header.
 *
 * @package seeded
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<!doctype html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo( 'charset' ); ?>">
<!-- SEEDED A11Y-007: viewport blocks zoom -->
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<!-- SEEDED SEO-002: hardcoded title instead of title-tag support -->
<title>Seeded Defects Fixture</title>
<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
