- **The rest of the starters' front-end strings follow the page language.** The
  tailwind search, single-post and archive templates (`search.php`, `single.php`,
  `template-parts/content*.php`, the post meta in `inc/template-tags.php`) and the
  cinematic skip link, menu `aria-label`s, 404, empty index and post navigation still
  went through gettext, so on a Spanish page they read "Posted on", "Previous:" or
  "Skip to content". They now read the tailwind string table (16 new keys, registered
  with Polylang like the rest) or the cinematic `__starter___b()` literal. Only the
  nav-menu location labels keep gettext: they show in wp-admin. New scaffolds only.
