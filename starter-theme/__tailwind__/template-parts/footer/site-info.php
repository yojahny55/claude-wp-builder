<?php
/**
 * Site Info (Footer)
 *
 * @package __starter__
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<div class="site-info">
    <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. <?php __starter___e('footer_rights'); ?></p>
</div>
