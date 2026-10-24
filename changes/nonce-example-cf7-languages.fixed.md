- **The AJAX nonce example is complete, and `wp-cf7` writes a form per language.** The
  `wp-theme-standards` enqueue reference showed `wp_create_nonce()` with nothing that
  verified it; it now pairs the localized nonce with a handler using `check_ajax_referer()`,
  a capability check and input sanitizing, and notes the page-cache and `wp_localize_script()`
  string-casting pitfalls. The `wp-cf7` agent only created the English form post; it now
  creates one per language on the project's language list (primary plus every secondary),
  with the same fields, messages translated key for key, and one form ID per language.
