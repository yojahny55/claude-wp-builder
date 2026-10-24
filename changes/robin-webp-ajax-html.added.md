- **WebP delivery now covers HTML returned by admin-ajax, and the audit checks it.** The
  Robin reference listed the delivery modes as if `picture` covered the whole site, but Robin
  only processes `template_redirect`, so infinite scroll, tabs and "load more" kept serving
  the PNG or JPEG next to an existing `.webp` (354 KB against 39 KB on a real build).
  `webp-delivery.md` gains the symptom, the measurement and the recipe (a theme helper that
  reuses Robin's API, availability checked before the buffer starts, with the warning about
  coupling to internal classes) and a rule not to serve or preload a `.webp` that weighs as
  much as the original. `wp-audit-performance` adds PERF-078 (UNMEASURED when the action
  cannot be launched) and `/wp-robin` verifies that the hero image has a `.webp`.
