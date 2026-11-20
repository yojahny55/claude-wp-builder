---
description: Author, replace, or regenerate a single cinematic scene. Updates the matching `cinematic_scenes` repeater row (eyebrow, headline, body, CTA, videos, poster) and — if the scene needs a non-default layout — emits a per-scene template fragment override at `template-parts/cinematic/scene-<id>.php`. Cinematic equivalent of `/wp-section`.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<n> [--eyebrow <eyebrow>] [--headline <headline>] [--body <body>] [--cta <cta>] [--video <video>] [--align <left|center|right>] [--veil <none|soft|heavy>] [--regenerate-schema] [--force-adopted]"
---

# /wp-cinematic-scene

## Arguments

| Argument | Required | Meaning |
|---|---|---|
| `<n>` | yes | Scene number (1..N) OR scene_id (e.g. scene-intro) |
| `--eyebrow` | no | Inline kicker text (bilingual via `--eyebrow-es`) |
| `--headline` | no | Headline text (bilingual via `--headline-es`) |
| `--body` | no | Path to a markdown file OR inline string |
| `--cta` | no | `Label\|URL` pair |
| `--video` | no | Path to source video — triggers `/wp-cinematic-encode` first |
| `--align` | no | left \| center \| right (default left) |
| `--veil` | no | none \| soft \| heavy (default soft) |
| `--regenerate-schema` | no | Re-read schemas/scene.json and rewrite fields/scenes.php (preserves @user-block markers) |
| `--force-adopted` | no | Build on an adopted site (third-party theme) on purpose; otherwise the command stops |


Replaces the per-scene `/wp-section` workflow when the theme is cinematic. ACF row updates run via `wp eval-file` so the change is live immediately — no admin click-through.

## Adopted-site guard

Run this before anything else. This command builds a theme, sections or content on the assumption
that the theme is one this plugin scaffolded; on an adopted site (a third-party theme) it would
overwrite that theme or generate one that does not belong. `${PROJECT_PATH}` is the WordPress project
root, the directory that holds the project manifest.

```bash
bash -c 'node "$1/bin/wp-config.mjs" require-origin "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Exit `0` continue. Exit `5` stop and print the message verbatim: `adopted site with a third-party theme:
use /wp-audit, /wp-debug or /wp-update`. If `$ARGUMENTS` contains `--force-adopted`, append it to the
call (and ignore it everywhere else): the operator chose to build on an adopted site on purpose.

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
4. Run `wp cache flush` and (if WP Super Cache active) `wp super-cache flush` (local file cache only; on a clone never run a CDN-backed purge such as `wp cfcache purge_cache`, see *Purging caches on a clone* in `wp-cli-patterns`).

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
