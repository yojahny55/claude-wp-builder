- **Starter language switcher and chrome strings follow the page language.** The
  cinematic switcher was a fixed `?lang=` link, which Polylang ignores, so on a
  Polylang scaffold it never changed language; it now reads
  `__starter___lang_switcher()`, which the Polylang variant answers from
  `pll_the_languages()` and links to the translated page. The tailwind starter's skip
  link, menu `aria-label`, 404 copy and footer went through gettext with no text
  domain loaded, so they followed the site locale instead of the page; they now read
  the starter's string table. New scaffolds only: an existing project needs the helper
  copied into its own `inc/i18n.php` before taking the new `nav.php`.
