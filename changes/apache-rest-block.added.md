- **Blocking the REST API in Apache, written down and replayed.** `wp-environments` gains a
  reference with a server-context `<If>` rule that refuses `/wp-json` and every key form PHP
  reads as `rest_route` (percent-encoded letters, `.`, `+`, `[`, NUL, `index.php/` path info),
  naming the site by its document root so an alias, the IP or a missing `Host` cannot route
  around it, and leaving `admin-ajax.php` and Contact Form 7 open. It also
  ships the PHP half the rule cannot replace, a `rest_pre_dispatch` mu-plugin, because
  WordPress reads `rest_route` from a POST body Apache never sees. A new check loads the rule
  exactly as printed into a throwaway Apache and replays the whole table.
