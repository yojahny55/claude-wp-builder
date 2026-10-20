---
description: Generate every favicon size from one image, write favicon.ico and site.webmanifest, and set the WordPress Site Icon
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<image> [--force]"
---

# /wp-favicon — one image to a complete favicon set

A site with no icon shows the browser's blank tile, and `/favicon.ico` answers 302 instead of
an image. This command takes one source image, writes the sizes browsers and devices ask for,
and sets the WordPress Site Icon so core emits the `<link rel="icon">` tags itself.

## Step 1: Gate

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Read the WP-CLI wrapper once and use it as `$WP` below:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs get '${PROJECT_PATH}' wp_cli.wrapper"
```

Read `.claude/CLAUDE.md` for the theme directory. If it is missing, tell the user to run
`/wp-init` first and stop.

## Step 2: Check the source

`$ARGUMENTS` starts with the image path (PNG, JPG, WebP or SVG). No path: print the usage line
and stop. Tooling is `magick` (ImageMagick 7); an SVG also needs the librsvg delegate, or
`rsvg-convert` to rasterize it first. If neither is on the machine, say so and stop — never
install one.

```bash
magick identify -format '%w %h\n' "<image>[0]"
```

- **Not square**: refuse and say the size. Cropping picks which part of a logo survives, and
  that is the client's design decision, not this command's.
- **Raster under 512 px**: refuse. WordPress crops a Site Icon from at least 512x512, and an
  upscaled 512 is a blurry icon. An SVG has no size and passes.

## Step 3: Generate

Write into `<theme>/assets/img/favicon/`:

| File | Size | Used by |
|---|---|---|
| `favicon-16x16.png` | 16 | browser tab, legacy |
| `favicon-32x32.png` | 32 | browser tab, retina |
| `apple-touch-icon.png` | 180 | iOS home screen |
| `icon-192.png` | 192 | Android, `site.webmanifest` |
| `icon-512.png` | 512 | `site.webmanifest`, the Site Icon source |
| `favicon.ico` | 16, 32, 48 | legacy `/favicon.ico` requests |

```bash
for s in 16 32 192 512; do magick "<image>[0]" -background none -resize ${s}x${s} "<dir>/icon-$s.png"; done
mv "<dir>/icon-16.png" "<dir>/favicon-16x16.png"; mv "<dir>/icon-32.png" "<dir>/favicon-32x32.png"
magick "<image>[0]" -background none -resize 180x180 "<dir>/apple-touch-icon.png"
magick "<image>[0]" -background none -define icon:auto-resize=16,32,48 "<dir>/favicon.ico"
```

Then write `<dir>/site.webmanifest` with `name` and `short_name` from
`$WP option get blogname`, `icons` pointing at `icon-192.png` and `icon-512.png` (type
`image/png`), and `display: "browser"`. Do not invent `theme_color` or `background_color`:
those are colours, and a colour on a site is asked about, not guessed.

## Step 4: Set the Site Icon

```bash
$WP option get site_icon
```

- `0`: import and set it.
- Non-zero without `--force`: the client or a previous run already chose an icon. Report its
  attachment ID and stop before Step 4's write; the generated files stay on disk.
- Non-zero with `--force`: replace it.

```bash
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
ID=$($WP media import "<dir>/icon-512.png" --post_author=$AUTHOR --porcelain)
$WP option update site_icon "$ID"
```

An attachment with no `--post_author` belongs to user 0, which does not exist; an empty `$AUTHOR`
means the site has no administrator, so stop and say so.

WordPress prints the 32, 180, 192 and 270 px icon links from that attachment on its own, and
answers `/favicon.ico` with a redirect to it.

## Step 5: Verify and report

```bash
$WP eval 'echo has_site_icon() ? "site icon OK: " . get_site_icon_url(32) : "MISSING";'
```

`MISSING` is a failure: report it and do not say the icon is set. Then give the absolute path
of every file written, and print the one line `site.webmanifest` needs, because WordPress does
not link a manifest by itself:

```html
<link rel="manifest" href="<?php echo esc_url( get_theme_file_uri( 'assets/img/favicon/site.webmanifest' ) ); ?>">
```

Add it to the theme's `wp_head` hook only if the user asks.
