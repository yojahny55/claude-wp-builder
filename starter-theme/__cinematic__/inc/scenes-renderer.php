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
 * Print the persistent stage: stacked <video> elements + posters.
 *
 * @param array<int,array<string,mixed>> $scenes
 */
function __starter___cinematic_render_stage(array $scenes): void {
    if (empty($scenes)) {
        return;
    }
    echo '<section class="stage" aria-hidden="true">';
    foreach ($scenes as $i => $s) {
        $idx = $i + 1;
        printf(
            '<picture class="stage__poster" data-scene-index="%d"><img src="%s" alt="" loading="%s"></picture>',
            $idx,
            esc_url($s['poster']),
            $i === 0 ? 'eager' : 'lazy'
        );
        if (! empty($s['video_desktop'])) {
            printf(
                '<video class="stage__video" data-scene-index="%d" preload="%s" muted playsinline><source src="%s" type="video/mp4"></video>',
                $idx,
                $i === 0 ? 'auto' : 'metadata',
                esc_url($s['video_desktop'])
            );
        }
    }
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
