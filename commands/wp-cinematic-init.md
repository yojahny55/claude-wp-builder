---
name: wp-cinematic-init
description: Scaffold a cinematic-scroll WordPress theme from an existing demo or from scratch. Installs cinematic-scroll-kit as a recommended skill, picks the `__cinematic__` starter, then defers to `/wp-init` with `--mode=cinematic` for the rest of the bootstrap (project info, ACF flavor, server, vhost).
arguments:
  - name: --path
    description: Target WordPress install path (parent of wp-content/)
    required: true
  - name: --scenes
    description: Number of scenes to scaffold (default 9, min 1, max 12)
    required: false
  - name: --hybrid
    description: Allow trailing flex sections after the reel (default yes; pass --no-hybrid to disable)
    required: false
  - name: --skip-kit-install
    description: Skip `npx skills add` and use vendored fallback from starter-theme/__cinematic__/assets/cinematic-kit/
    required: false
---

# /wp-cinematic-init

Use this when the demo is **not** a standard sectioned page but a cinematic scroll-driven reel: persistent video stage, N scenes that crossfade/scrub as the user scrolls, mobile autoplay-loop fork, motion-toggle, reduced-motion guard.

This command is a thin shim. It does three things and hands off:

## Step 0 — Detect kit

Check in order:
1. Globally-installed skill: `~/.skills/yojahny55/cinematic-scroll-kit/schemas/scene.json`
2. Project-local: `./.cinematic-kit/schemas/scene.json`
3. Vendored fallback inside the plugin: `<plugin>/starter-theme/__cinematic__/assets/cinematic-kit/schemas/scene.json`

If none found AND `--skip-kit-install` not set → run:

```bash
npx skills add yojahny55/cinematic-scroll-kit -g -y
```

If `npx skills` is unavailable, fall back to:
```bash
git clone --depth 1 https://github.com/yojahny55/cinematic-scroll-kit .cinematic-kit
```

If both fail → use vendored fallback and log: "Using vendored kit copy (offline mode). Update later with `/wp-cinematic-init --update-kit`."

## Step 1 — Hand off to /wp-init

Invoke `/wp-init --path=<path> --mode=cinematic --starter=__cinematic__ --acf-flavor=<scf|acf-pro>` and let the standard bootstrap run:
- Project name/slug/text domain/languages
- Server choice (Nginx native, Docker, etc.)
- Database
- ACF flavor

When `/wp-init` reaches the "section scaffolding" phase, it **skips** the usual `/wp-section` loop and instead dispatches to step 2 below.

## Step 2 — Cinematic scaffold (dispatch `wp-cinematic` agent)

Pass to the `wp-cinematic` agent:

```json
{
  "schema_path": "<resolved kit path>/schemas/scene.json",
  "project_slug": "<from /wp-init>",
  "text_domain": "<from /wp-init>",
  "languages": ["en", "es"],
  "acf_flavor": "<scf|acf-pro>",
  "scene_count": 9,
  "hybrid": true
}
```

The agent produces every file listed in its `Outputs you produce` table.

## Step 3 — Wire and seed

1. Activate the theme via `wp theme activate <slug>`.
2. Run `wp eval-file inc/seed-cinematic.php` to populate the placeholder scenes.
3. Run `wp eval-file inc/seed-menus.php` if menus haven't been seeded yet.
4. Print next steps:
   - Replace placeholder videos: `/wp-cinematic-encode <input.mp4> --scene=N`
   - Author scene content: `/wp-cinematic-scene <n>`
   - Add trailing sections (pricing/contact): `/wp-section <name> --hybrid`
   - Preview demo: `/wp-cinematic-demo`

## Failure handling

| Symptom | Likely cause | Fix |
|---|---|---|
| `npx skills add` hangs | offline / firewall | rerun with `--skip-kit-install` |
| `Function name must not contain hyphens` | slug has `-` | confirm slug, agent converts to `_` for PHP prefix automatically — bail if it didn't |
| Black screen after first scroll | engine not loaded | check `body.has-cinematic` class in DevTools; verify `cinematic-loader.php` enqueued |
| Videos won't autoplay on mobile Safari | missing `muted` or `playsinline` | regenerate `scene.php` template part |
| `13: Permission denied` on vhost reload | SELinux on Fedora/RHEL | `restorecon -F <vhost>` (see `vhost-install` command) |

## Related commands

- `/wp-cinematic-demo` — generate or regenerate the HTML demo
- `/wp-cinematic-encode` — ffmpeg all-keyframe + 9:16 reframe
- `/wp-cinematic-scene` — author/replace a single scene
- `/wp-cinematic-seed` — re-seed all scenes from a manifest
- `/wp-section --hybrid` — add a trailing section after the reel
