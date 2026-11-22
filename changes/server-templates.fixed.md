- **Native server templates agree on what they refuse, and stop breaking local setups.** The
  PHP-FPM pool now sets `upload_max_filesize` and `post_max_size` from `{{max_upload_size}}`
  (PHP's 2M/8M defaults rejected plugin zips even when nginx allowed 1024M, and the doc claimed
  otherwise). The nginx template no longer sends a two-year HSTS header over a 365-day
  self-signed certificate, which locked the browser out of `example.test` once it expired. The
  Apache vhosts add `Options -Indexes`, and the Caddyfile adds `tls internal` so a local domain
  stops asking a public ACME CA. nginx, Apache and Caddy now share one deny list
  (`templates/native/_deny.list`): `/xmlrpc.php` (including `/xmlrpc.php/x`), `.sql.gz` and
  `phar`/`pht(ml)` under uploads are refused by all three, and `.zip`, `.tar.gz` and `.tgz` are
  refused everywhere except `/wp-content/uploads/`, so media-library zips still load, and
  `tests/checks/vhost-deny-list-parity.sh` fails when an engine stops denying an entry.
