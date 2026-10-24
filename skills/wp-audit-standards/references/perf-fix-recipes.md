# Performance fix recipes — boilerplate and per-finding fixes

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-performance.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read at the start of the Fix Phase, once the report lists auto-fixable findings, and apply only the recipes those findings name.

## Contents

- Performance functions.php boilerplate
- .htaccess performance block
- WP-CLI fix commands
- Font display fix
- Font subsetting fix
- Image lazy loading fix
- Unminified theme JavaScript fix
- Hero fetchpriority fix
- Multi-currency cache-key fix

### Performance functions.php boilerplate

Add to `inc/performance.php` and require from `functions.php`:

```php
<?php
/**
 * Performance Optimizations
 * @package __STARTER_NAME__
 */
if (!defined('ABSPATH')) { exit; }

// Clean wp_head
remove_action('wp_head', 'rsd_link');
remove_action('wp_head', 'wlwmanifest_link');
remove_action('wp_head', 'wp_generator');
remove_action('wp_head', 'wp_shortlink_wp_head');
remove_action('wp_head', 'rest_output_link_wp_head', 10);
remove_action('wp_head', 'wp_oembed_add_discovery_links', 10);

// Disable emojis
add_action('init', function() {
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_styles', 'print_emoji_styles');
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji');
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
    add_filter('tiny_mce_plugins', fn($plugins) => array_diff($plugins, ['wpemoji']));
    add_filter('wp_resource_hints', function($urls, $relation_type) {
        if ($relation_type === 'dns-prefetch') {
            $urls = array_filter($urls, fn($url) => !str_contains($url, 's.w.org'));
        }
        return $urls;
    }, 10, 2);
});

// Disable XML-RPC + pingbacks
add_filter('xmlrpc_enabled', '__return_false');
add_filter('wp_headers', function($headers) {
    unset($headers['X-Pingback']);
    return $headers;
});

// Throttle heartbeat
add_action('wp_enqueue_scripts', function() {
    wp_deregister_script('heartbeat');
}, 1);
add_filter('heartbeat_settings', function($settings) {
    $settings['interval'] = 60;
    return $settings;
});

// Dequeue block CSS (if not using Gutenberg on frontend)
add_action('wp_enqueue_scripts', function() {
    wp_dequeue_style('wp-block-library');
    wp_dequeue_style('wp-block-library-theme');
    wp_dequeue_style('classic-theme-styles');
    wp_dequeue_style('global-styles');
}, 100);

// Preload the weight(s) the real LCP text actually renders in — never "the
// first N files glob() happens to return". `array_slice($fonts, 0, 2)` picks
// whatever alphabetical order the filesystem gives, which preloaded inter-400
// on a build whose above-the-fold heading was inter-600: the one file the
// first paint waited on was the one not preloaded. PERF-054/PERF-055 measure
// the LCP element's computed font-weight per template; name those files here.
add_action('wp_head', function() {
    $font_dir = get_template_directory_uri() . '/assets/fonts/';
    // Replace with the weight(s) PERF-054/PERF-055 measured across every
    // template's LCP element — usually one or two, never "preload everything".
    $lcp_weights = array( 400 );
    foreach ($lcp_weights as $weight) {
        $file = get_template_directory() . "/assets/fonts/inter-{$weight}.woff2";
        if (file_exists($file)) {
            echo '<link rel="preload" href="' . esc_url($font_dir . basename($file)) . '" as="font" type="font/woff2" crossorigin>' . "\n";
        }
    }
}, 1);

// Force WebP output
add_filter('image_editor_output_format', fn($f) => array_merge($f, [
    'image/jpeg' => 'image/webp',
    'image/png' => 'image/webp',
]));

// JPEG/WebP quality
add_filter('wp_editor_set_quality', function($quality, $mime_type = '') {
    if ($mime_type === 'image/webp') return 75;
    return 80;
}, 10, 2);
```

### .htaccess performance block

Append to `.htaccess`:

```apache
# === PERFORMANCE OPTIMIZATIONS ===

# Gzip Compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css
    AddOutputFilterByType DEFLATE text/javascript application/javascript application/json
    AddOutputFilterByType DEFLATE application/xml image/svg+xml
</IfModule>

# Browser Caching
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/avif "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresDefault "access plus 1 month"
</IfModule>

# Cache-Control
<IfModule mod_headers.c>
    <FilesMatch "\.(css|js|woff2|svg|png|jpg|jpeg|gif|webp|avif|ico)$">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </FilesMatch>
</IfModule>

# Disable ETags
<IfModule mod_headers.c>
    Header unset ETag
</IfModule>
FileETag None
```

### WP-CLI fix commands

Run these to clean up runtime issues:

```bash
# Delete expired transients
$WP transient delete --expired

# Limit post revisions
$WP config set WP_POST_REVISIONS 5 --raw --type=constant

# Increase autosave interval
$WP config set AUTOSAVE_INTERVAL 120 --raw --type=constant
```

On a local clone, purge only local caches (`$WP cache flush`, `$WP cfcache purge_fallback_cache`). Never run a CDN or page-cache purge command such as `$WP cfcache purge_cache`: it can call the real CDN API with the production credentials restored from the database. See *Purging caches on a clone* in `wp-cli-patterns`.

### Font display fix

Edit CSS `@font-face` blocks to add `font-display: swap;` if missing.

### Font subsetting fix

A family downloaded as one file per weight carries every script its designer shipped. A site
written in one Latin language pays for Cyrillic, Greek and Vietnamese on every first paint and
renders none of it. On a real build eight faces were 442KB on disk and 263KB after subsetting,
which was 141KB off the home page.

Subset with `pyftsubset` (`pip install fonttools brotli` — brotli is what writes woff2):

```bash
# Latin + Latin-1 supplement + the punctuation and symbols a Western European site uses.
RANGES='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD'
pyftsubset Family-Regular.woff2 \
  --flavor=woff2 --unicodes="$RANGES" --layout-features='*' \
  --output-file=Family-Regular.subset.woff2
```

`--layout-features='*'` keeps kerning and ligatures; dropping them is how a subset starts
rendering visibly worse than the original at the same glyph coverage.

**Verify coverage before replacing the file, and verify it against the site's real text, not
against the range list.** A missing glyph does not error — the browser silently falls back to
the next family in the stack for that one character, so a single absent `ñ`, `€` or `—` reads
as a font that is "slightly off" on one page and nobody can say why:

```bash
# Every character the site actually renders, from the database and the templates.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
wp post list --post_type=any --post_status=publish --field=ID \
  | xargs -n1 -I{} wp post get {} --field=post_content > $T/site-text.txt
wp post list --post_type=any --post_status=publish --field=post_title >> $T/site-text.txt
cat wp-content/themes/<slug>/**/*.php >> $T/site-text.txt   # hardcoded UI strings

python3 - "$T/site-text.txt" <<'PY'
import sys
from fontTools.ttLib import TTFont
cmap = set(TTFont('Family-Regular.subset.woff2').getBestCmap())
text = set(open(sys.argv[1], encoding='utf-8', errors='replace').read())
missing = {c for c in text if ord(c) not in cmap and c.isprintable() and not c.isspace()}
print('MISSING:', sorted(missing) if missing else 'none')
PY
```

A non-empty `MISSING` list is a refusal, not a warning: widen the ranges and subset again.
Field values in ACF/SCF and term names live outside `post_content`, so a site whose copy sits
in fields needs those in the sample too — `wp postmeta list` per post, or an `$wpdb` dump of
`wp_postmeta` and `wp_terms`.

Keep the originals in the repository (or in the project's `docs/`), because a subset cannot be
widened back into a full family — the discarded glyphs are gone, and a second language added
to the site later has no source to subset from.

### Image lazy loading fix

Do not apply `loading="lazy"` by a blanket "below the hero" rule — PERF-054 exists because
that rule is wrong on any template whose LCP is a grid card rather than the hero (a directory
archive, a team/news strip: the first row is above the fold on every viewport the grid
renders at). Use what PERF-054 measured: eager-load the images in the LCP element's own row
(with `fetchpriority="high"` on the LCP element itself, never on more than one), `loading="lazy"`
everything after it. A four-across grid at desktop that drops to two-across on mobile needs
the wider count eager, e.g.:

```php
'loading'       => $card_index <= 4 ? 'eager' : 'lazy',
'fetchpriority' => 1 === $card_index ? 'high' : 'auto',
```

Everywhere else — a true below-the-fold image with no grid ambiguity — `loading="lazy"` as
before.

### Unminified theme JavaScript fix

A hand-written theme (the common case in an audit: no bundler, files enqueued one by one)
ships `assets/js/*.js` exactly as they were written. Rewriting every `wp_enqueue_script()`
call to point at a `.min.js` is the obvious fix and the wrong one: it is a change in as many
places as there are handles, it breaks the moment someone adds a handle and forgets, and it
leaves the theme unusable until the build has been run at least once.

Build the minified copies into a sibling directory and swap the URL in one filter, so no
`wp_enqueue_script()` call has to know the build exists:

```php
/**
 * Serve the minified twin of a theme script when one has been built.
 *
 * The filter swaps the URL only when the twin exists on disk, so a checkout where
 * the build has not been run — or one file that failed to minify — serves the
 * original unchanged instead of 404ing.
 */
add_filter( 'script_loader_src', 'prefix_use_minified_scripts', 10, 2 );
function prefix_use_minified_scripts( $src, $handle ) {
	if ( is_admin() || false === strpos( $src, '/assets/js/' ) ) {
		return $src;
	}

	$theme_uri = get_template_directory_uri();
	if ( 0 !== strpos( $src, $theme_uri . '/assets/js/' ) ) {
		return $src;
	}

	$file = basename( wp_parse_url( $src, PHP_URL_PATH ) );
	if ( ! file_exists( get_template_directory() . '/assets/js/min/' . $file ) ) {
		return $src;
	}

	return str_replace( '/assets/js/' . $file, '/assets/js/min/' . $file, $src );
}
```

The build is one script and one dev dependency (`terser`), writing every
`assets/js/*.js` into `assets/js/min/` and printing the before/after bytes per file so the
saving is a number rather than a claim. Commit both the sources and the output: the filter
reads the disk, not a manifest.

**State this in the project's `.claude/CLAUDE.md` as part of the fix, because it is a trap
that wastes a whole debugging session:** once the twin exists, editing a file under
`assets/js/` changes nothing that the site serves. The page still loads, the console stays
clean, the old behaviour persists, and reading the source confirms a change that is not
live — so the next edit has to run the build in the same pass, and bump the theme's version
constant so the new file is not served from the browser cache either.

Two things this fix does not cover, and both belong in the report rather than in a silent
decision: a file under `vendors/` is third-party and usually minified already, so it is left
alone; and `assets/js/min/` must be excluded from the theme bundle's own exclude list only if
that list names `min` — check `bundle`/`zip` scripts before assuming the twins ship.

### Hero fetchpriority fix

Edit the hero template to add `fetchpriority="high"` to the main hero image.

### Multi-currency cache-key fix

PERF-065/PERF-067 are never auto-applied — the fix is a setting on a plugin or an edge
service this agent does not own, the same rule the "Cache plugin" note in *Adopted sites*
already states for every other caching finding. Report `Fix: manual`, `Owner: setting`, and
name the concrete control:

- **A caching plugin** (WP Rocket, LiteSpeed Cache, W3 Total Cache, …) — add the
  multi-currency plugin's currency cookie to that plugin's own cookie-exclusion / "never
  cache" list (WP Rocket: *Cache Settings → Never Cache Cookies*; LiteSpeed Cache: the vary
  group for that cookie). This makes the cache treat each currency as its own cache entry
  instead of one shared entry.
- **An edge CDN** (Cloudflare, or another CDN/proxy cache PERF-066 detected) — no WP-CLI command reaches this: it is a Cache Rule at the
  edge, configured to bypass or vary the cache key on the currency cookie/query parameter.
  Point the report at the dashboard control, never at a `.htaccess` or `performance.php`
  workaround that the edge never sees in the first place.

Never propose disabling the page cache site-wide as the fix — that trades a wrong price for
a slow site. The fix is scoping the cache key, not removing the cache.
