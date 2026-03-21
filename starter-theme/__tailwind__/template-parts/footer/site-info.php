<?php
/**
 * Site Info (Footer)
 *
 * @package __starter__
 */
?>
<div class="site-info">
    <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. <?php esc_html_e('All rights reserved.', '__starter__'); ?></p>
    <p><?php printf( esc_html__('Theme by %s.', '__starter__'), '<a href="https://example.com" rel="designer">Your Name</a>' ); ?></p>
</div>
