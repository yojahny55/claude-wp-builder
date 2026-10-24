- **Cinematic starter: the ACF field-group scan ran on every request.** `functions.php`
  globbed `fields/*.php`, read each file and ran a regex over it on every `acf/init` to find
  groups with no Local JSON yet, even when every group already had one. It now stores a
  signature (file names, newest mtime, and the `acf-json/` directory mtime, which moves when
  a JSON is added or removed) in an option once a scan finds nothing left to bootstrap, and a
  matching signature skips the scan. The signature is never stored after a pass that
  bootstrapped or while `acf-json/` is unwritable, so a failed or partial persist is retried
  on the next request. Delete the `__starter___fields_scan` option to force a rescan.
