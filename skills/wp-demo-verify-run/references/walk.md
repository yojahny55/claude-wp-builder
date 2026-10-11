# /wp-demo-verify — Step 2b

`commands/wp-demo-verify.md` sends the run here at Step 2b. Follow it in order; nothing in it is optional background.

Six positions per section at 1440x900 and 390x844, plus a reduced-motion pass at
desktop width, then full-page shots at 375, 576, 620, 768, 1024, 1100, 1152, 1280 and 1440
(this replaces `/wp-responsive-check`).

**Firefox pass.** When a Playwright Firefox build already exists on the machine (Playwright's
browser cache, or `WP_BROWSER_FIREFOX`), the same nine full-page shots are taken in Firefox
under `.verify/[<page>/]firefox/`, and at each walk width every layout element's box is
compared between Chromium and Firefox. A box that differs by more than 2px (position within
its parent, width or height) is an `engine-delta` finding, advisory, the 15 largest per
width. Nothing is ever downloaded: without a Firefox build the run prints a notice and stays
Chromium-only; `--no-firefox` skips it on purpose. Firefox on Linux does not reproduce every
Windows rendering defect (a 1px rounded border draws corner artifacts only on Windows), so
the static CSS lint in `/wp-finalize` stays the guard for those. The browser executable and
its revision are logged at startup (`browsers: firefox <path> (revision N, ...)`); the
revision pinned by the loaded playwright-core's `browsers.json` is preferred over a newer
cached one, and a mismatch is named in that line. `tests/checks/demo-verify-engines.sh` only
exercises this pass when it finds a playwright-core: run it with
`PLAYWRIGHT_CORE="$(npm root -g)/@playwright/test/node_modules/playwright-core"` to test the
cross-engine path for real.

**`--no-motion`.** For a URL of an existing site the plugin did not build (a page-builder site,
say) that never carried the motion engine. Without it every section blocks as `no-engine`, a
true fact that says nothing about the layout, and the round fails for a reason that does not
apply. With it the `no-engine` and `dead-scroll` judgments are not emitted; overflow, clipped
copy, container-noop, the full-page shots and the Firefox pass still run. It is opt-in and
never inferred: a converted plugin page that lost its engine must still fail, so do not pass it
for a page `/wp-demo` or `/wp-yolo` built. A URL page with zero `[data-motion]` elements and no
flag prints one line suggesting it.

A directory target walks every page. Output lands in
`<dir>/.verify/[<page>/]<width>/`, with `findings.json` and, per width, both
`sheet.png` (full resolution, for a human who opens it directly) and `sheet.jpg`
(downscaled to 1000px wide, quality 70 — the one to Read in Step 4).

**Fractional widths.** Page builders emit breakpoints as integer pairs: `max-width: 767px`
for mobile and `min-width: 768px` above it. At a fractional CSS width (browser zoom, or OS
display scaling other than 100%: a 766px window at 110% is 767.27px) neither query matches,
and the page falls back to its unqueried defaults. The integer shots above can never see it.
So, in Chromium, the walk reads the page's same-origin stylesheets for `max-width: N` /
`min-width: N+1` pairs (at most three), loads the page inside each (N, N+1) by launching with
`--force-device-scale-factor=1.1` and a window sized until the CSS width read back lands in the
gap (an edge it cannot land is skipped with a notice), and compares it with N and N+1. A page
with only `min-width` queries, like a Tailwind one, has no gap and reports nothing.
`--no-gaps` skips the pass.


**On exit code 2**, fall back in this order: the Chrome or Playwright MCP
screenshot tools if either is connected, then ask the user for screenshots at the
five viewports. Say which route you used. (A craft build never reaches this
branch: `/wp-demo` probes first and stops on 2.)
