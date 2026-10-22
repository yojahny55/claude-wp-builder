- **Starters: mobile menu init, menu semantics, skip link, reduced-motion video.** The
  Tailwind starter's mobile menu registered on `DOMContentLoaded` only, so a bundle loaded
  later by a cache or "delay JS" plugin left the button dead; it now runs on the same
  `readyState` guard as the rest of the file, closes on Escape (returning focus to the
  button) and sets `aria-controls`. `navigation.php` no longer puts `role="menubar"` on a
  plain list of links or `role="navigation"` on a `<nav>`, and both starter headers gain a
  skip link. In the cinematic starter, `prefers-reduced-motion` returned before touching
  `.scene__video-mobile`, so the autoplaying loop kept playing (WCAG 2.2.2); it is now
  paused, stripped of autoplay and loop, and reset to its poster.
