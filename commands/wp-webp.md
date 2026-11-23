---
description: Convert new PNG and JPEG uploads to WebP before WordPress makes their sizes — a must-use plugin with a PSNR quality floor
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "upload on | upload off | upload status [--force]"
---

# /wp-webp — every new upload born WebP

An optimizer plugin such as Robin writes a `.webp` sibling next to each PNG or JPEG and then has
to deliver it: `<picture>` wrapping, URL rewriting or a server rule, each with gaps (a CSS
`background-image` keeps the original). Converting the upload itself removes the delivery
problem for new images: the attachment *is* a WebP, so every size WordPress makes from it, and
every URL that names it, is WebP.

`upload on` installs a fixed must-use plugin that does that. It changes nothing already in the
library — existing images stay as they are — and nothing a visitor sees until an editor uploads
a new image. Robin, when installed, stays: it still serves the library that predates this.

## Step 1: Gate

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report". The path travels as a positional argument, never inside the `-c` string: write it in single quotes, and a path that holds a single quote gets each one written as `'\''`.

```bash
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Exit `3` policy:** `adopt-or-stop` — read `${CLAUDE_PLUGIN_ROOT}/skills/wp-manifest-gate/SKILL.md`.

Read the WP-CLI wrapper once and use it as `$WP` below:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" wp_cli.wrapper' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

## Step 2: Arguments

`$ARGUMENTS` is `upload` followed by `on`, `off` or `status`. Anything else: print the usage line
and stop. `--force` lets `on` replace, and `off` remove, a copy that no longer matches the
template.

## Step 3: Where the plugin goes

```bash
$WP eval 'echo WPMU_PLUGIN_DIR;'
```

The file is `<mu-dir>/webp-on-upload.php`. It is a must-use plugin, not a theme file: it works the
same whatever theme is active, and a theme switch cannot turn it off.

That path is the one PHP sees. With a container wrapper (docker compose, DDEV, Lando, wp-env) it
is a path inside the container, not on this machine. Every file step below runs on this
machine, so resolve `<mu-dir>` here first:

- the printed path exists here (`test -d "$(dirname '<mu-dir>')"`): use it;
- it does not, and it ends in `/wp-content/mu-plugins`: use the WordPress root on this machine
  (`wp_cli.path` from the manifest, or the project root that holds `wp-config.php`) followed
  by `/wp-content/mu-plugins`, and check that its parent `wp-content` exists;
- neither: stop and ask the operator where the site's `wp-content` is on this machine. Never
  create a directory you could not place.

Step 6 then proves that WordPress loads the file from where it was put.

## Step 4: `upload on`

The PHP is not written by you. It is a fixed file,
`${CLAUDE_PLUGIN_ROOT}/templates/webp/webp-on-upload.php`, held to the PHP 7.4 floor, with no
tokens. **Copy it; do not retype or "improve" it.**

```bash
php -l "${CLAUDE_PLUGIN_ROOT}/templates/webp/webp-on-upload.php"
cmp -s "${CLAUDE_PLUGIN_ROOT}/templates/webp/webp-on-upload.php" "<mu-dir>/webp-on-upload.php" && echo identical
```

- Absent: create `<mu-dir>` if needed and copy the file in.
- Identical: leave it.
- Different without `--force`: stop and show the diff. Someone edited the installed copy, and
  overwriting it would discard that work.
- Different with `--force`: replace it.

Then go to Step 6.

## Step 5: `upload off`

No `<mu-dir>/webp-on-upload.php`: say the plugin is not installed and stop. Otherwise remove it
when it is identical to the template, or when `--force` is given; a different copy without
`--force`: stop and show the diff. Images already converted stay
WebP: removing the plugin only stops new conversions. To pause it without removing the file,
`WEBP_ON_UPLOAD_DISABLE` can be defined as `true` in `wp-config.php` instead.

## Step 6: Verify and report (`on`, `off` and `status`)

Ask the plugin itself whether it would convert, rather than guessing from the server:

```bash
$WP eval 'if ( ! function_exists( "webp_on_upload_blocker" ) ) { echo "not loaded"; return; } $b = webp_on_upload_blocker(); echo "" === $b ? "ready (" . webp_on_upload_cwebp() . ")" : "inactive: " . $b;'
```

| Output | Meaning |
|---|---|
| `ready (<path>)` | new PNG and JPEG uploads are converted |
| `inactive: cwebp not found` | install the `webp` package (`cwebp`) on the server, or define `WEBP_ON_UPLOAD_CWEBP` with its path |
| `inactive: proc_open is disabled` | the host forbids running programs from PHP; the plugin cannot work there |
| `inactive: no image editor can write WebP sizes` | GD or Imagick lacks WebP; converting would leave the image with no sizes, so it does not |
| `inactive: disabled by WEBP_ON_UPLOAD_DISABLE` | paused in `wp-config.php` |
| `not loaded` | after `off`, the expected result. After `on` or on `status`, the file is not in the must-use directory WordPress reads: after `on` that is a failure |

Only after `on`, and only when the status line says `ready`, prove it on a real upload, then
remove the test attachment. On any `inactive:` line, report the reason and skip the probe:
the upload would stay a JPEG by design, and that is not a failure.

```bash
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
php -r '$i=imagecreatetruecolor(64,64); imagefilledrectangle($i,0,0,63,63,imagecolorallocate($i,30,120,200)); imagejpeg($i,$argv[1],95);' "$T/webp-on-upload-probe.jpg"
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
id=$($WP media import "$T/webp-on-upload-probe.jpg" --post_author="$AUTHOR" --porcelain)
$WP post get "$id" --field=post_mime_type
$WP post delete "$id" --force
```

`image/webp` is a pass. `image/jpeg` while the plugin said `ready` is a failure: report it. A
flat test image can also stay JPEG when no WebP candidate is smaller; the PSNR and size gate
in the plugin is deliberate.

Report the action, the plugin's status line and, on a site with Robin active, that Robin keeps
serving the images uploaded before this. On a site whose uploads live in S3 (`/wp-s3`), the
plugin converts through a local temporary copy; nothing else is needed. The file lives in
`wp-content/mu-plugins/`, which a deploy has to carry like any plugin.
