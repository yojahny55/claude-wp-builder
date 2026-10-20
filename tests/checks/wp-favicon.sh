#!/usr/bin/env bash
# /wp-favicon is prose, so the contract is its wording. Each token below is a decision that
# once had a cheaper wrong answer: cropping a non-square logo, upscaling a small raster,
# overwriting an icon the client chose, installing ImageMagick, or inventing manifest colours.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-favicon.md
[ -f "$f" ] || fail "$f is missing"

grep -Fq 'mkdir -p' "$f" || fail "$f does not create the favicon directory before writing"
grep -Fq -- '-density 1024' "$f" || fail "$f rasterizes an SVG at 72 dpi and scales it up"
grep -Fq 'absent counts as `0`' "$f" || fail "$f does not treat a missing site_icon option as unset"
for sz in favicon-16x16.png favicon-32x32.png apple-touch-icon.png icon-192.png icon-512.png favicon.ico site.webmanifest; do
  grep -Fq "$sz" "$f" || fail "$f no longer produces $sz"
done
grep -Fq 'option update site_icon' "$f" || fail "$f does not set the site_icon option"
grep -Fq 'has_site_icon()' "$f" || fail "$f does not verify the Site Icon after setting it"
grep -Fq 'Not square' "$f" || fail "$f no longer refuses a non-square source"
grep -Fq 'Raster under 512 px' "$f" || fail "$f no longer refuses a raster under 512 px"
grep -Fq 'and never install one' "$f" || fail "$f no longer forbids installing ImageMagick"
grep -Fq -- '--force' "$f" || fail "$f lost --force for replacing an existing icon"
grep -Fq 'Do not invent `theme_color`' "$f" || fail "$f may guess manifest colours"

# The gate block is checked byte-for-byte by wp-config-gate.sh; here only that it is present.
grep -Fq 'wp-config.mjs validate' "$f" || fail "$f reads the manifest but never calls the validator"

# Both starters link the manifest the command writes, and only when the file exists, so a
# theme that never ran the command prints nothing.
for t in __tailwind__ __cinematic__; do
  g=starter-theme/$t/functions.php
  grep -Fq 'assets/img/favicon/site.webmanifest' "$g" || fail "$g no longer links the web manifest"
  grep -Eq "file_exists\( *get_theme_file_path\( *'assets/img/favicon/site\.webmanifest'" "$g" || fail "$g links the manifest without checking that it exists"
done

# Documented in both tables and the backlog row points at this check.
grep -Fq '/wp-favicon' README.md || fail "README.md does not list /wp-favicon"
grep -Fq '(#wp-favicon)' docs/commands.md || fail "docs/commands.md does not list /wp-favicon"
grep -Fq 'tests/checks/wp-favicon.sh' BACKLOG.md || fail "BACKLOG.md does not link this check"
echo PASS
