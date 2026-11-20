- **The cinematic starter's mobile menu and motion toggle now work.** `nav.php` emitted a
  hamburger, a `#mobile-menu` dialog and a motion toggle that `cinematic.css` and
  `cinematic-engine.js` never styled or wired: on mobile the button did nothing, and the dialog
  rendered unstyled in normal flow on every viewport. The menu is now hidden on desktop and a
  focus-trapped overlay at 780px and below (Escape and link clicks close it, `inert` while
  closed). A pause/play toggle, also added to the desktop nav, pauses every video and stops the
  engine from playing one while paused, defaulting to paused under `prefers-reduced-motion`
  (WCAG 2.2.2).
