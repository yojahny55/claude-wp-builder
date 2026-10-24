- **Script inputs are validated before they reach sudo, sed, SQL and PHP.**
  `bin/wp-env-setup.sh` used `--domain=` as-is in `sudo rm -f /etc/ssl/certs/$domain.crt`
  (a `../` or `/` walked out of the cert directory) and as an unanchored regex in
  `/etc/hosts` (removing `foo.local` also deleted `foo.local.es` and `myfoo.local`, and an
  existing `foo.local.es` made `hosts-add` think `foo.local` was present). It now rejects
  anything outside `^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$` up front, matches hosts lines with an
  anchored pattern, and `ssl-generate` adds `subjectAltName` (browsers reject CN-only
  certificates) and no longer hides openssl's stderr. `bin/wp-cinematic-encode.sh` pasted
  `--scene=` into the PHP of `wp eval`, so a crafted value ran code; it must now be an
  integer, as must the attachment IDs from `wp media import`.
