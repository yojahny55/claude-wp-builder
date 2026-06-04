<?php
/**
 * Default per-scene block.
 *
 * Override per scene by creating `template-parts/cinematic/scene-<scene_id>.php`.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

$scene = (array) get_query_var('__cinematic_scene', []);
$index = (int) get_query_var('__cinematic_index', 0);

if (empty($scene)) {
    return;
}
?>
<article
    class="scene scene--align-<?php echo esc_attr($scene['align']); ?> scene--veil-<?php echo esc_attr($scene['veil']); ?>"
    id="<?php echo esc_attr($scene['scene_id']); ?>"
    data-scene-id="<?php echo esc_attr($scene['scene_id']); ?>"
    data-scene-index="<?php echo esc_attr((string) ($index + 1)); ?>"
    data-scrub-duration="<?php echo esc_attr((string) $scene['scrub_duration']); ?>"
    style="--scene-duration: <?php echo esc_attr((string) $scene['scrub_duration']); ?>vh"
>
    <?php if (! empty($scene['video_mobile'])) : ?>
        <video
            class="scene__video-mobile"
            preload="metadata"
            autoplay muted loop playsinline
            poster="<?php echo esc_url($scene['poster']); ?>"
        >
            <source src="<?php echo esc_url($scene['video_mobile']); ?>" type="video/mp4">
        </video>
    <?php endif; ?>

    <div class="scene__content">
        <?php if (! empty($scene['eyebrow'])) : ?>
            <p class="scene__eyebrow"><?php echo esc_html($scene['eyebrow']); ?></p>
        <?php endif; ?>

        <?php if (! empty($scene['headline'])) : ?>
            <h2 class="scene__headline">
                <?php echo wp_kses($scene['headline'], ['br' => [], 'em' => [], 'strong' => [], 'span' => ['class' => true]]); ?>
            </h2>
        <?php endif; ?>

        <?php if (! empty($scene['body'])) : ?>
            <div class="scene__body"><?php echo wp_kses_post($scene['body']); ?></div>
        <?php endif; ?>

        <?php if (! empty($scene['cta_label']) && ! empty($scene['cta_url'])) : ?>
            <a class="scene__cta" href="<?php echo esc_url($scene['cta_url']); ?>">
                <?php echo esc_html($scene['cta_label']); ?>
                <span aria-hidden="true">→</span>
            </a>
        <?php endif; ?>
    </div>
</article>
