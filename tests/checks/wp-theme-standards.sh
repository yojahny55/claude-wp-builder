#!/usr/bin/env bash
# wp-theme-standards is the code agents copy into functions.php and inc/*.php. It taught
# five things that were wrong, each in a way that still runs:
#
#   1. A `wp_check_filetype_and_ext` filter that returned the type from the FILE NAME for
#      every upload — switching off core's content-vs-extension check for all file types,
#      not only SVG. The starter never shipped it.
#   2. One fixed layout (`assets/css/styles.css`, `assets/js/main.js`) that matches neither
#      shipped starter. An agent following it adds a second stylesheet to a Tailwind theme,
#      which enqueues exactly one compiled file.
#   3. A remote Google Fonts <link> plus preconnects to fonts.googleapis.com /
#      fonts.gstatic.com — the pattern /wp-init Step 4.5 removes and PERF-022 reports.
#   4. An unconditional Organization JSON-LD block. Beside Rank Math's graph it reads as
#      two Organization nodes; inc/agentic.php owns identity JSON-LD and steps aside for
#      an SEO plugin.
#   5. Smaller wrong output: raw get_field() past the i18n seam, page assets keyed on a
#      slug (one language only under Polylang), an LCP preload of the full-size original
#      with no imagesrcset (two downloads on mobile), and $_GET sanitized without
#      wp_unslash().
# Each is asserted in both directions where a wrong form existed.
set -uo pipefail
# `q "$text" <grep flags> <pattern>`: a here-string, never `printf | grep -q`. Under
# pipefail an early-exiting `grep -q` hands printf a SIGPIPE and the pipeline returns 141,
# which silently flips an assertion either way.
q() { local s=$1; shift; grep -q "$@" <<<"$s"; }
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

dir=skills/wp-theme-standards
skill=$dir/SKILL.md
refs=$(ls "$dir"/references/*.md 2>/dev/null)
[ -f "$skill" ] && [ -n "$refs" ] || fail "$dir is missing SKILL.md or its references"
all=$(cat "$skill" $refs)
flat=$(printf '%s' "$all" | tr '\n' ' ' | sed 's/  */ /g')
# The code samples alone: every fenced block. Negative assertions read this, so a sentence
# that names a forbidden form in order to forbid it cannot trip them.
code=$(printf '%s\n' "$all" | awk '/^```/{f=!f; next} f')
[ -n "$code" ] || fail "no fenced code found in $dir — the negative assertions below would judge nothing"

# 1. No filetype override, anywhere in the skill or the starter; the rule against it is stated.
q "$all" -E "add_filter\( *'wp_check_filetype_and_ext'" \
  && fail "$dir still hooks wp_check_filetype_and_ext — that disables core's content check for every upload"
grep -rEq "add_filter\( *'wp_check_filetype_and_ext'" starter-theme/ \
  && fail "a starter hooks wp_check_filetype_and_ext"
grep -Fq 'Never filter `wp_check_filetype_and_ext`' "$skill" \
  || fail "$skill does not forbid the wp_check_filetype_and_ext override, so the next edit restores it"

# 2. The layout is read from the recorded template, and the wrong fixed layout is gone.
grep -Fq '`Template:`' "$skill" || fail "$skill never reads the recorded Template: line"
grep -Fq 'starter-theme/__tailwind__/functions.php' "$skill" || fail "$skill does not send the reader to the tailwind starter's functions.php"
grep -Fq 'starter-theme/__cinematic__' "$skill" || fail "$skill has no answer for a cinematic theme"
grep -Fq 'assets/css/dist/main.css' "$skill" || fail "$skill does not name the tailwind theme's one compiled stylesheet"
q "$flat" -Ei 'never a second stylesheet|exactly one (compiled )?stylesheet' \
  || fail "$skill does not say a tailwind theme enqueues exactly one stylesheet"
q "$all" -E "(get_template_directory_uri\(\)|_URI) \. '/assets/(css/styles\.css|js/main\.js)'" \
  && fail "$dir still enqueues assets/css/styles.css or assets/js/main.js — neither starter has them"
grep -Fq "assets/js/dist/index.asset.php" "$dir/references/setup-and-enqueue.md" \
  || fail "the enqueue reference does not version the bundle from index.asset.php like the starter"

# 3. Self-hosted fonts: no Google Fonts enqueue or preconnect, one woff2 preload.
q "$all" -E "wp_enqueue_style\([^)]*fonts\.googleapis\.com|https://fonts\.googleapis\.com/css|rel=\"preconnect\" href=\"https://fonts\.(googleapis|gstatic)\.com" \
  && fail "$dir still enqueues or preconnects Google Fonts — /wp-init Step 4.5 self-hosts every family and PERF-022 reports the remote link"
grep -Fq 'as="font" type="font/woff2"' "$dir/references/head-and-performance.md" \
  || fail "the head reference has no self-hosted woff2 preload"
grep -Fq 'Step 4.5' "$skill" || fail "$skill does not point at /wp-init Step 4.5 for the font carry"

# 4. Identity JSON-LD has one owner and steps aside for an SEO plugin.
q "$all" -E "'@type' *=> *'Organization'" \
  && fail "$dir prints its own Organization JSON-LD — beside an SEO plugin's graph that is two Organization nodes; inc/agentic.php owns it"
grep -Fq 'inc/agentic.php' "$skill" || fail "$skill does not name inc/agentic.php as the owner of identity JSON-LD"
grep -Fq 'seo_plugin_owns_schema()' "$skill" || fail "$skill does not name the SEO-plugin guard identity JSON-LD returns on"

# 5a. Field reads go through the seam: no raw get_field('…') call in the code samples.
q "$all" -E "(^|[^_A-Za-z])get_field\( *'" \
  && fail "$dir calls raw get_field() in a sample — options and templates read through prefix_get_field()"
grep -Fq "prefix_get_field( 'site_logo', \$post_id )" "$dir/references/setup-and-enqueue.md" \
  || fail "prefix_get_logo() does not read the logo through prefix_get_field() like the starter"

# 5b. Page assets are keyed on the template, never a slug.
q "$code" -E "is_page\( *'" \
  && fail "$dir keys code on is_page('<slug>') — under Polylang each language has its own slug"
q "$flat" -F 'Never key them on a slug' || fail "$skill does not forbid slug-keyed page assets"

# 5c. The LCP preload offers the same candidates as the <img>.
for a in imagesrcset imagesizes; do
  grep -Fq "$a=" "$dir/references/head-and-performance.md" \
    || fail "the LCP preload has no $a — it preloads the full-size original and the <img> downloads its own pick too"
done

# 5d. Superglobals are unslashed before they are sanitized.
q "$all" -E 'sanitize_[a-z_]+\( *\$_(GET|POST|COOKIE)' \
  && fail "$dir sanitizes a superglobal without wp_unslash()"
grep -Fq 'wp_unslash( $_GET' "$skill" || fail "$skill's sanitization example does not unslash"

echo PASS
