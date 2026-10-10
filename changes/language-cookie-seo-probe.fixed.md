- **The language cookie is `SameSite=Lax` and `HttpOnly`, and `Secure` on HTTPS.** Both
  starters set it with the options array; no starter script reads it, so nothing needs
  JavaScript access. The SEO-plugin detection the starter, `wp-agentic-surfaces` and
  `wp-theme-standards` share calls `class_exists()` without the autoloader, so a Composer
  autoloader cannot load a same-named class from another package while probing.
