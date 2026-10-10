# /wp-finalize — Demo-parity gate — Layer 3 (measured visual parity, claude-in-chrome)

`commands/wp-finalize.md` sends the run here at Demo-parity gate — Layer 3. Follow it in order; nothing in it is optional background.

Layer 3 is the backstop that measures **computed styles**, not just screenshots, so divergence is caught at build time instead of weeks later.

1. **Detect claude-in-chrome availability.** Call the extension's tabs/context tool (e.g. `tabs_context_mcp`). If the claude-in-chrome MCP tools are unavailable, not connected, or the built site / demo URL is unreachable, **SKIP Layer 3 with a noted reason — this is NOT a failure.** Layers 1-2 still gate delivery on their own.

2. **Load demo + built page.** For each in-scope page, navigate to the demo URL and to the corresponding built (local WordPress) URL.

3. **Conversion parity — tailwind template only.** When `Template:` is `basic`, skip this
   item and change nothing else in Layer 3. When `Template:` is `tailwind`, `/wp-yolo`
   Step 2.6 has already converted each demo page **in place**, so the demo URL loaded in
   item 2 serves the *converted* page: an error the conversion introduced is present on
   both sides of that comparison and cancels out. So for each in-scope page also open the
   pristine pre-conversion copy at `demo/.original/<slug>.html` (Step 2.6 keeps it there;
   the old `demo/<slug>.original.html` no longer exists) and repeat the measurement and
   classification below between it and the converted `demo/<slug>.html`. Report a hard
   delta found here as a **conversion defect** — `/wp-tailwindify` changed the page — and
   not as a build defect, which is a hard delta between the converted demo and the built
   site. The two have different fixes, and only the original can tell them apart. If
   `demo/.original/<slug>.html` is absent the page was never converted: note that and skip
   this item for that page.

4. **Measure computed styles.** Via `javascript_tool`, run `getComputedStyle()` on matching selectors on both pages (hero, nav, section backgrounds, headings, buttons) and compare the results.

5. **Classify every delta:**
   - **Hard delta (BLOCK)** — critical:
     - A `background-image` present in the demo is missing in the build.
     - `color` / `background-color` resolves to a **different hex** between demo and build.
     - A fixed `height` / `width` differs by **more than 3% or 8px** (whichever is larger).
     - `font-family` resolves to a **system fallback stack** instead of the demo's actual font face.
   - **Soft delta (WARN, non-blocking):**
     - Sub-pixel geometry differences.
     - Antialiasing / font-smoothing rendering variance.
     - Any value within the 3%/8px threshold.

6. **Confirm logo + hero rendering.** Verify the logo renders as an actual image (not a text fallback) and that hero section background images are visible (not blank/broken).

**PASS** if no hard deltas found (soft deltas are reported but do not block). **FAIL** listing every hard delta (selector, property, demo value vs. built value), and on the tailwind path every divergence item 3 reported against the pristine original. **SKIP** (not a failure) if claude-in-chrome or either URL is unavailable — state the reason (e.g. "claude-in-chrome not connected", "demo URL unreachable", "built site not running").
