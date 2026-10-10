# /wp-init — Step 4.5

`commands/wp-init.md` sends the run here at Step 4.5 (Font carry). Follow it in order; nothing in it is optional background.

## Contents

- A demo that self-hosts
- A demo that links Google Fonts, and the empty-extraction guard
- `unicode-range`, `font-display: swap` and the requested weights
- Placement
- Preload exactly one file
- No network, or a font that will not download
- The final token check

Take the font sources recorded in Step D2 and carry each family into
`<theme-dir>/assets/fonts/`, by where the demo got it from:

**A demo that self-hosts (`@font-face` with a local `src`).** Copy the woff2 out of the demo
folder and re-emit the rule with `src` rewritten to `assets/fonts/<file>.woff2`. This is
`/wp-yolo` Step 4.5's font carry, including its missing-file branch and its per-template
placement rule — read it there and follow it verbatim rather than inventing a second answer.

**A demo that links Google Fonts** (`<link href="https://fonts.googleapis.com/css2?family=…">`).
Self-host it; the theme emits no `fonts.googleapis.com` request at runtime. Fetch the
stylesheet, take the woff2 URLs out of it, and store them next to the self-hosted case:

```bash
mkdir -p <theme-dir>/assets/fonts
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
curl -fsS -A "$UA" "<the demo's exact css2 URL>" -o /tmp/gf.css
urls=$(grep -oE 'https://fonts\.gstatic\.com/[^)]+\.woff2' /tmp/gf.css | sort -u)
[ -n "$urls" ] || { echo "no woff2 URLs in the Google Fonts response — carry failed" >&2; exit 1; }
printf '%s\n' "$urls" \
  | xargs -r -n1 sh -c 'curl -fsS -o "<theme-dir>/assets/fonts/$(basename "$1")" "$1"' _
```

**An empty extraction is a failure, not a quiet no-op.** Without the guard, a response that
carries no woff2 URLs — the TTF stylesheet from a wrong user agent, an error page, a format
change at Google — runs the loop zero times and the step reports success with no fonts
carried, which is the silent fallback this whole step exists to end. The URL is passed to
`sh -c` as a positional argument rather than interpolated into the command string, so a
filename with a shell metacharacter cannot alter what runs.

The `-A` is not decoration. Google serves a *different* stylesheet per user agent, and the
default `curl` UA gets the legacy TTF build — you download fonts that work, in a format two
generations old, and never notice. Send a modern browser UA and the response is woff2.

Then write `/tmp/gf.css` into the theme's font-face location with each `src: url()` rewritten
to `assets/fonts/<basename>`, keeping every `@font-face` block the response contains:

- Keep the `unicode-range` descriptors exactly as Google emitted them. They are what makes the
  many blocks cheap — the browser fetches a subset's file only when the page renders a
  character in that range — so carrying all of them costs one HTTP request in practice and
  removes the judgment call about which subsets this site will ever need.
- **Every carried block ends up with `font-display: swap`.** Google emits it only when the
  URL asked for `&display=swap`, and a demo whose link omits it hands you blocks with no
  `font-display` at all — which is FOIT: the browser hides the text for up to three seconds
  rather than showing it in the fallback. Keep the descriptor where the response has it and
  add it where it does not. `wp-audit-performance` PERF-020 flags the absence.
- Carry only the weights and styles the demo's `css2` URL asked for. It already names them;
  do not widen the request.

Placement follows `/wp-yolo` Step 4.5 — on `Template: tailwind` that is
`assets/css/src/tailwindcss/base/fonts.css` plus its `@import` in `main.css`, and **no second
enqueue**: the Tailwind theme enqueues exactly one compiled stylesheet.

**Preload exactly one file.** A self-hosted face is discovered only after the stylesheet
parses, so the first paint costs an extra round trip. Preload the file that fixes it — the
**primary family's regular (400) latin subset**, and **never every subset**: the
`unicode-range` blocks are cheap precisely because the browser skips the ones it will not
render, and preloading them all downloads Cyrillic and Greek faces to a site that shows
neither. One family, one weight, one subset; the rest load on demand.

Add it where the deleted Google preconnect used to sit in `functions.php`, guarded on the
file actually existing so a skipped carry cannot emit a hint pointing at nothing:

```php
add_action( 'wp_head', function() {
    $font = get_template_directory() . '/assets/fonts/<primary-regular-latin>.woff2';
    if ( file_exists( $font ) ) {
        printf(
            '<link rel="preload" as="font" type="font/woff2" href="%s" crossorigin>' . "\n",
            esc_url( get_template_directory_uri() . '/assets/fonts/<primary-regular-latin>.woff2' )
        );
    }
}, 1 );
```

`crossorigin` is mandatory even same-origin — fonts are fetched in CORS mode, and a preload
without it downloads the file twice.

**No network, or a font that will not download.** Do not emit a `@font-face` pointing at a
file the theme does not have — `/wp-yolo` Step 4.5 states why. Then **drop that family from
the head of its `--font-*` token** and let the rest of the demo's stack stand (the starter's
system stack, if the demo declared no fallback), and report it in the Step 10 summary as
`font <family>: not carried — token falls back to <next family>`.

Dropping it changes nothing at render time — a family with no `@font-face` and no local
install was never going to render, and the browser was already falling through to the next
entry. What it changes is that the theme stops *naming* a font it does not have, which is the
whole defect this step removes, and it is the difference between a stack `/wp-finalize`'s
font-parity check passes (an intentional fallback) and one it fails (a family with no face).

Finally, confirm every `--font-*` token either leads with a family this step carried or is a
plain fallback stack. Those are the only two states; a token leading with an uncarried family
is the one `/wp-finalize` fails on.
