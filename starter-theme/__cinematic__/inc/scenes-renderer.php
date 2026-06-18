<?php
/**
 * Scene rendering helpers.
 *
 * Read once from ACF, render stage + scene blocks. Engine reads everything
 * else from `data-*` attributes — no client-side ACF re-fetch.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

/**
 * Return all cinematic scenes for the current page, normalized.
 *
 * @return array<int,array<string,mixed>>
 */
function __starter___cinematic_scenes(): array {
    if (! function_exists('have_rows')) {
        return [];
    }
    $rows = [];
    if (have_rows('cinematic_scenes')) {
        while (have_rows('cinematic_scenes')) {
            the_row();
            $rows[] = [
                'scene_id'        => get_sub_field('scene_id') ?: ('scene-' . (count($rows) + 1)),
                'video_desktop'   => __starter___media_url(get_sub_field('video_desktop')),
                'video_mobile'    => __starter___media_url(get_sub_field('video_mobile')),
                'poster'          => __starter___media_url(get_sub_field('poster')),
                'eyebrow'         => __starter___get_sub('eyebrow'),
                'headline'        => __starter___get_sub('headline'),
                'body'            => __starter___get_sub('body'),
                'cta_label'       => __starter___get_sub('cta_label'),
                'cta_url'         => get_sub_field('cta_url'),
                'align'           => get_sub_field('align') ?: 'left',
                'veil'            => get_sub_field('veil') ?: 'soft',
                'scrub_duration'  => (int) (get_sub_field('scrub_duration') ?: 100),
            ];
        }
    }
    return $rows;
}

/**
 * ACF file/image fields are configured as `return_format=array`.
 * This helper handles array | attachment ID | URL string defensively.
 *
 * @param mixed $field
 */
function __starter___media_url($field): string {
    if (empty($field)) {
        return '';
    }
    if (is_array($field) && isset($field['url'])) {
        return (string) $field['url'];
    }
    if (is_numeric($field)) {
        return (string) wp_get_attachment_url((int) $field);
    }
    return is_string($field) ? $field : '';
}

/**
 * Bilingual ACF sub-field retrieval. Looks for `{name}_es` when current lang is es.
 */
function __starter___get_sub(string $name): string {
    $lang  = function_exists('__starter___current_lang') ? __starter___current_lang() : 'en';
    $value = $lang === 'es' ? get_sub_field($name . '_es') : '';
    if (empty($value)) {
        $value = get_sub_field($name);
    }
    return (string) $value;
}

/**
 * Print the persistent stage: stacked <video> + <canvas> + poster layers.
 *
 * Two render engines share this markup (see the kit's
 * skills/07-scroll-scrub-rendering.md):
 *   - WebCodecs path  → the <canvas class="stage__c"> is driven by
 *     CinematicScrubber (frame-perfect, smooth reverse). body.webcodecs-scrub
 *     hides the <video> and shows the <canvas>.
 *   - Legacy fallback → the <video class="stage__v"> is driven by
 *     video.currentTime on browsers without WebCodecs.
 *   - Reduced motion  → the <picture class="stage__poster"> shows a still.
 *
 * @param array<int,array<string,mixed>> $scenes
 */
function __starter___cinematic_render_stage(array $scenes): void {
    if (empty($scenes)) {
        return;
    }
    echo '<section class="stage" aria-hidden="true">';
    foreach ($scenes as $i => $s) {
        $desktop = (string) $s['video_desktop'];
        $mobile  = (string) ($s['video_mobile'] ?: $desktop);

        if ($s['poster']) {
            printf(
                '<picture class="stage__poster" data-idx="%d"><img src="%s" alt="" loading="%s"></picture>',
                $i,
                esc_url($s['poster']),
                $i === 0 ? 'eager' : 'lazy'
            );
        }
        if ($desktop !== '') {
            // <video> for the legacy currentTime path …
            printf(
                '<video class="stage__v" data-idx="%d" data-src="%s" data-src-mobile="%s" preload="%s" muted playsinline tabindex="-1"></video>',
                $i,
                esc_url($desktop),
                esc_url($mobile),
                $i === 0 ? 'auto' : 'metadata'
            );
            // … and a <canvas> sibling for the WebCodecs path.
            printf(
                '<canvas class="stage__c" data-idx="%d" data-src="%s"></canvas>',
                $i,
                esc_url($desktop)
            );
        }
    }
    echo '<div class="stage__veil"></div>';
    echo '<div class="stage__veil stage__veil--right"></div>';
    echo '<div class="stage__veil stage__veil--center"></div>';
    echo '</section>';
}

/**
 * Print a single scene block (content layer that scrolls over the stage).
 *
 * @param array<string,mixed> $scene
 */
function __starter___cinematic_render_scene(array $scene, int $index): void {
    $part = locate_template('template-parts/cinematic/scene-' . $scene['scene_id'] . '.php');
    if ($part) {
        set_query_var('__cinematic_scene', $scene);
        set_query_var('__cinematic_index', $index);
        load_template($part, false);
        return;
    }
    set_query_var('__cinematic_scene', $scene);
    set_query_var('__cinematic_index', $index);
    get_template_part('template-parts/cinematic/scene');
}
