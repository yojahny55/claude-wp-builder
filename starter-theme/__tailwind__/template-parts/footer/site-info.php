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
    <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. <?php esc_html_e('All rights reserved.', '__starter__'); ?></p>
</div>
