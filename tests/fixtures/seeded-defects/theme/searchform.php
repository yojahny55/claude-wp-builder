<?php
/**
 * Fixture search form.
 *
 * @package seeded
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<form method="get" action="/">
	<!-- SEEDED A11Y-042: input without a label or aria-label -->
	<input type="text" name="s" placeholder="Search">
	<button type="submit">Go</button>
</form>
