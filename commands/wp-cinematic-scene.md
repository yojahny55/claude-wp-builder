---
name: wp-cinematic-scene
description: Author, replace, or regenerate a single cinematic scene. Updates the matching `cinematic_scenes` repeater row (eyebrow, headline, body, CTA, videos, poster) and — if the scene needs a non-default layout — emits a per-scene template fragment override at `template-parts/cinematic/scene-<id>.php`. Cinematic equivalent of `/wp-section`.
arguments:
  - name: <n>
    description: Scene number (1..N) OR scene_id (e.g. scene-intro)
    required: true
  - name: --eyebrow
    description: Inline kicker text (bilingual via `--eyebrow-es`)
    required: false
  - name: --headline
    description: Headline text (bilingual via `--headline-es`)
    required: false
  - name: --body
    description: Path to a markdown file OR inline string
    required: false
  - name: --cta
    description: `Label|URL` pair
    required: false
  - name: --video
    description: Path to source video — triggers `/wp-cinematic-encode` first
    required: false
  - name: --align
    description: left | center | right (default left)
    required: false
  - name: --veil
    description: none | soft | heavy (default soft)
    required: false
  - name: --regenerate-schema
    description: Re-read schemas/scene.json and rewrite fields/scenes.php (preserves @user-block markers)
    required: false
---

# /wp-cinematic-scene

Replaces the per-scene `/wp-section` workflow when the theme is cinematic. ACF row updates run via `wp eval-file` so the change is live immediately — no admin click-through.

## Pipeline

1. Resolve scene by id or index. If scene number > current repeater length, **append** a new row (bounded by `scene.json` `x-acf` max 12).
2. If `--video` provided, dispatch `/wp-cinematic-encode --scene=<n> --poster` first.
3. Build an update payload:
   ```php
   $row = [
     'scene_id'        => 'scene-<n>',
     'eyebrow'         => $args['eyebrow'] ?? $existing,
     'eyebrow_es'      => $args['eyebrow-es'] ?? $existing,
     'headline'        => $args['headline'] ?? $existing,
     'headline_es'     => $args['headline-es'] ?? $existing,
     'body'            => $body_html,         // markdown → HTML via Parsedown
     'cta_label'       => $cta_label,
     'cta_url'         => $cta_url,
     'video_desktop'   => $attachment_id_desktop,
     'video_mobile'    => $attachment_id_mobile,
     'poster'          => $attachment_id_poster,
     'align'           => $args['align'] ?? 'left',
     'veil'            => $args['veil'] ?? 'soft',
     'scrub_duration'  => 100,
   ];
   update_row('cinematic_scenes', $index, $row, $page_id);
   ```
4. Run `wp cache flush` and (if WP Super Cache active) `wp super-cache flush`.

## Custom per-scene template

If the user wants a scene to render differently from the default (e.g. split layout, embedded data viz), pass `--custom-template`:

```
/wp-cinematic-scene 4 --custom-template
```

This creates `template-parts/cinematic/scene-scene-4.php` from `template-parts/cinematic/scene.php` with `// @user-block:start custom-layout` / `// @user-block:end custom-layout` markers. The default renderer looks for `scene-<id>.php` first and falls back to `scene.php`.

## --regenerate-schema flow

When the kit publishes a new `scene.json` (added fields, changed defaults):

```
/wp-cinematic-scene --regenerate-schema
```

1. Re-invoke `wp-cinematic` agent with current `scene.json` version.
2. Diff old `fields/scenes.php` against newly-generated.
3. Preserve any `@user-block` ranges verbatim.
4. Print a migration summary: added/removed/changed fields.
5. If a field was removed, leave existing ACF data in DB (orphan, not destructive) but stop emitting it.

## Failure handling

- ACF function `update_row` undefined → ACF Pro/SCF Pro not installed. Bail with install hint.
- `wp eval-file` fails with permission error → check `wp-content/themes/<slug>` owned by PHP-FPM user (documented prior issue: `nginx` group + 775).
- Scene N exists but repeater length < N → most likely seed never ran; suggest `/wp-cinematic-seed`.
