- **Suffix-model language no longer leaks through page caches, and Accept-Language reads
  q-values.** Both starters' `inc/i18n.php` (Tailwind and cinematic) send
  `Vary: Accept-Language, Cookie` on front-end responses, and keep a response out of
  WordPress page caches (`DONOTCACHEPAGE` plus `nocache_headers()`) when it is not the
  default language or carries `?lang`; before, the first visitor's language could be cached
  and served to everyone. `fr,es;q=0.9` now resolves to Spanish instead of the default; an
  unsupported `?lang` falls through to the cookie in both starters (the cinematic one reset
  it to English); and the `<html lang>` rewrite no longer reaches wp-admin or the login
  screen. Check `theme-i18n-request-lang.sh` runs both resolvers under stubbed WordPress.
