# Cinematic mode

Build scroll-driven, cinematic WordPress sites where each scroll position drives a frame of an AI-generated video reel — on desktop. On mobile the same reel becomes a stack of autoplay-loop 9:16 clips. This is the workflow the plugin offers when the demo isn't a sectioned page but a continuous storytelling reel.

This document covers what cinematic mode is, when to use it, and the end-to-end pipeline from raw videos to a deployed WordPress theme.

## When to use cinematic mode

Pick cinematic when **all** of the following are true:

- The page tells one continuous story, not a list of discrete sections.
- AI-generated video (Kling, Runway, Sora, Luma) is part of the brand surface.
- Scroll is the primary interaction — there's no traditional fold.
- Editorial typography, hairline UI, motion-aware accessibility matter to the brand.

Pick **basic** or **tailwind** otherwise — they're more economical for landing pages, marketing sites, blogs, and most B2B work.

Hybrid mode (default-on) lets you mix: the reel for the hero/story portion, then normal sections (pricing, contact, FAQ) after. Most real cinematic builds are hybrid.

## Dependency: cinematic-scroll-kit

The runtime engine, ffmpeg scripts, demo skeleton, and scene contract live in [`cinematic-scroll-kit`](https://github.com/yojahny55/cinematic-scroll-kit). The plugin reads from it and never extends locally — adding fields means a PR upstream.

```bash
# Recommended
npx skills add yojahny55/cinematic-scroll-kit -g -y

# Fallback (no network)
git clone --depth 1 https://github.com/yojahny55/cinematic-scroll-kit .cinematic-kit
```

If neither works, `/wp-cinematic-init` falls back to the vendored copy in `starter-theme/__cinematic__/assets/cinematic-kit/` (pinned at plugin release time).

## End-to-end pipeline

```
   ┌──────────────┐   ┌────────────┐   ┌──────────────┐   ┌─────────────────┐
   │ brand brief  │ → │ storyboard │ → │  AI videos   │ → │ /wp-cinematic-  │
   │ (markdown)   │   │ (kit)      │   │ (Kling/etc.) │   │  demo (HTML)    │
   └──────────────┘   └────────────┘   └──────────────┘   └─────────────────┘
                                                                   │
                                                                   ▼
   ┌──────────────────────┐   ┌────────────────────────┐   ┌──────────────────┐
   │ /wp-cinematic-encode │   │ /wp-cinematic-init     │   │ /wp-cinematic-   │
   │ (ffmpeg → MP4 +      │ ← │ (theme + ACF + seed)   │ ← │  seed (placeholders)│
   │  9:16 + poster)      │   │                        │   │                  │
   └──────────────────────┘   └────────────────────────┘   └──────────────────┘
              │                          │
              ▼                          ▼
   ┌──────────────────────┐   ┌────────────────────────┐
   │ /wp-cinematic-scene  │   │ /wp-section --hybrid   │
   │ (one scene at a time)│   │ (pricing, contact, ...)│
   └──────────────────────┘   └────────────────────────┘
```

## Step 1 — Demo

Generate the HTML demo first, send it to the client, and only then commit to WordPress. The demo proves the scroll feel.

```bash
/wp-cinematic-demo --scenes=9 --brand=./brand-brief.md
```

Output lands at `<theme>/demo/` with `<!-- SECTION: scene-N -->` delimiters so `/wp-polish` and `/wp-responsive-check` work on it like any other plugin demo.

## Step 2 — Real videos

Encode source videos into the two variants the engine needs.

```bash
# Desktop scroll-scrub: all-keyframe MP4 (-g 1 -bframes 0)
# Mobile autoplay: 9:16 portrait crop, standard GOP, +faststart
# Optional poster: frame 30 → JPG for prefers-reduced-motion fallback
/wp-cinematic-encode ./raw/scene-3.mp4 --scene=3 --poster
```

Verification: `ffprobe` confirms ≥10 I-frames in the first 10 frames of the desktop file (sanity check that all-keyframe took). Mobile dimensions are validated to be 9:16.

All-keyframe MP4 is 2-3× the size of streaming MP4. That's the price of frame-perfect scrub. Mobile uses the smaller standard-GOP file.

## Step 3 — WordPress

```bash
/wp-cinematic-init --path=./wp-site --scenes=9
```

This:

1. Resolves the kit (skill → local → vendored).
2. Hands off to `/wp-init` for project bootstrap (name, slug, languages, server, DB, ACF flavor).
3. Copies `starter-theme/__cinematic__/` as the theme.
4. Dispatches the `wp-cinematic` agent to read `schemas/scene.json` and emit:
   - `fields/scenes.php` — ACF repeater with bilingual sub-fields
   - `fields/trailing-sections.php` — flex content for hybrid mode
   - `inc/seed-cinematic.php` — idempotent WP-CLI seed
   - `template-parts/cinematic/scene-<id>.php` overrides where needed
5. Activates the theme, seeds menus, seeds scenes with kit samples.

## Step 4 — Author scenes

```bash
/wp-cinematic-scene 1 \
  --eyebrow "Field log — 01" \
  --eyebrow-es "Bitácora — 01" \
  --headline "Where the work begins." \
  --headline-es "Donde empieza el trabajo." \
  --body ./copy/scene-1.md \
  --cta "Begin diagnostic|#diagnostic" \
  --video ./raw/scene-1.mp4
```

`--video` chains into `/wp-cinematic-encode` so a single command can swap a placeholder for a finished clip and update the ACF row.

## Step 5 — Trailing sections (hybrid)

Cinematic page, but with normal pricing + contact blocks after the reel:

```bash
/wp-section pricing --hybrid
/wp-section contact --hybrid
```

`--hybrid` appends to the `trailing_sections` flex content field instead of creating a standalone field group. Each flex layout maps 1:1 to `template-parts/section-<layout>.php`, so all existing section conventions still apply.

## Engine architecture

```
┌─ wp_head ────────────────────────────────────────────────────────────┐
│ <link rel=preconnect href=https://cdn.jsdelivr.net>                  │
│ <script>prefers-reduced-motion guard sets <html class>               │
└──────────────────────────────────────────────────────────────────────┘
┌─ <body class="has-cinematic is-mobile-cinematic? has-trailing?"> ────┐
│                                                                       │
│  <nav> lockup · links · hamburger · motion-toggle                    │
│                                                                       │
│  <section class="stage" position:fixed>                              │
│    <picture × N> posters (reduced-motion fallback)                   │
│    <video × N>   desktop reels (currentTime fallback path)           │
│    <canvas × N>  WebCodecs render targets (default path)             │
│  </section>                                                          │
│                                                                       │
│  <div class="reel">                                                  │
│    <article data-scene-id data-scrub-duration> ← scene 1             │
│      <video> 9:16 mobile (autoplay+muted+loop+playsinline)           │
│      <div class="scene__content"> eyebrow · headline · body · cta    │
│    </article>                                                        │
│    × N                                                               │
│  </div>                                                              │
│                                                                       │
│  <div class="trailing"> ← hybrid only                                │
│    template-parts/section-pricing.php, section-contact.php, ...      │
│  </div>                                                              │
│                                                                       │
│  <footer>                                                            │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Desktop path

GSAP + ScrollTrigger + Lenis. Each scene block has `data-scrub-duration` (vh). The default render engine is **WebCodecs → canvas**: `CinematicScrubber` decodes the exact frame for the current scroll position and paints it to a `<canvas class="stage__c">` (frame-perfect, smooth in both directions). On browsers without WebCodecs (Safari < 16.4, Firefox < 132) it **falls back to `video.currentTime`** on the `<video class="stage__v">`. `body.webcodecs-scrub` decides which element is visible.

Why not `video.currentTime` everywhere: it is not frame-accurate and cannot decode backward — reverse scroll stutters and the video can jump-to-end-and-freeze. See cinematic-scroll-kit `skills/07-scroll-scrub-rendering.md` for the full rationale and decision tree.

### Mobile path

GSAP/Lenis are **not loaded**. IntersectionObserver with `rootMargin: -35% 0% -35% 0%` toggles `.is-active` per scene; the inline 9:16 video autoplay-loops while active.

### Reduced-motion path

If `(prefers-reduced-motion: reduce)`, the inline script adds `prefers-reduced-motion` to `<html>` before any JS loads. The engine bails. The stage renders posters only.

### Motion toggle

The header `[data-action="toggle-motion"]` button writes a body class and pauses all `<video>` elements. State persists across page loads via `localStorage`.

## Schema-driven generation

`cinematic-scroll-kit/schemas/scene.json` is the contract. Every ACF field, every template `data-*` attribute, every seed manifest validates against it.

When the kit adds a field (e.g., `audio_track`):

```bash
/wp-cinematic-scene --regenerate-schema
```

The `wp-cinematic` agent:

1. Re-reads `scene.json`.
2. Diffs the existing `fields/scenes.php` against a freshly-generated version.
3. Preserves any `// @user-block:start/end` ranges verbatim.
4. Prints a migration summary (added / removed / changed).
5. Leaves existing ACF data in the DB for removed fields (orphan, non-destructive).

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Scrub stutters | GOP didn't apply | `ffprobe` for I-frame count; re-encode with kit script |
| Mobile video won't autoplay (Safari) | missing `muted` or `playsinline` | regenerate `scene.php` template part |
| Black screen after deploy | cache stale; engine didn't boot | `wp super-cache flush` + check `body.has-cinematic` in DevTools |
| Function name contains hyphen (PHP fatal) | slug like `my-site` reached PHP prefix | confirm agent converted to `my_site_` everywhere |
| ACF field empty after seed | `return_format` mismatch | seeds always write attachment IDs into array-shape `file` fields |
| `<br>` rendering as literal text | wrong escaper | bilingual helper uses `wp_kses`, not `esc_html` |
| Mobile menu won't open | nav handler behind `if (isMobile) return` | handler must run BEFORE the desktop early-exit |
| SELinux blocks vhost reload | `/tmp`-staged conf inherits `user_tmp_t` | `restorecon -F <vhost>` or use the plugin's `vhost-install` |

## File map

After `/wp-cinematic-init` completes:

```
wp-content/themes/<slug>/
├── style.css
├── functions.php
├── header.php · footer.php · front-page.php
├── assets/
│   ├── css/cinematic.css           ← vendored from kit
│   ├── js/cinematic-engine.js      ← dual-path scrub controller
│   └── js/cinematic-scrubber.js    ← WebCodecs module (vendored from kit)
├── fields/
│   ├── scenes.php                  ← AUTO-GENERATED from scene.json
│   └── trailing-sections.php       ← AUTO-GENERATED (hybrid only)
├── inc/
│   ├── i18n.php
│   ├── cinematic-loader.php
│   ├── scenes-renderer.php
│   ├── performance.php
│   └── seed-cinematic.php          ← AUTO-GENERATED
└── template-parts/cinematic/
    ├── nav.php
    ├── stage.php
    └── scene.php                   ← optional scene-<id>.php overrides
```

## Related

- [`commands/wp-cinematic-init.md`](../commands/wp-cinematic-init.md)
- [`commands/wp-cinematic-demo.md`](../commands/wp-cinematic-demo.md)
- [`commands/wp-cinematic-encode.md`](../commands/wp-cinematic-encode.md)
- [`commands/wp-cinematic-scene.md`](../commands/wp-cinematic-scene.md)
- [`commands/wp-cinematic-seed.md`](../commands/wp-cinematic-seed.md)
- [`agents/wp-cinematic.md`](../agents/wp-cinematic.md)
- [cinematic-scroll-kit](https://github.com/yojahny55/cinematic-scroll-kit) — upstream contract + runtime
