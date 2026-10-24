- **Tailwind starter: the CF7 HTML mail filter only touches the theme's own forms.**
  `wpcf7_mail_components` forced `text/html` on every Contact Form 7 form on the site, so on
  a plain-text form of the client's own, a visitor's `[your-message]` was parsed as HTML in
  the owner's inbox (injected links, remote images). It now acts only when the mail template
  has `use_html` set, which is what the wp-cf7 agent writes. Substituted settings values are
  escaped for where they land: `esc_html()`/`esc_url()` in the body, plain text in the
  subject. The `wp-cf7` agent also passes the template directory to `wp eval-file` as an
  argument instead of splicing `$(pwd)` into a quoted PHP string, which broke on a path
  containing a quote.
