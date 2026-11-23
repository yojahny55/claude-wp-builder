- **`/wp-webp migrate` converts a PNG library already on disk.** The written PNG-to-WebP
  procedure had no script, so nothing ran it. `skills/wp-robin/scripts/webp-migrate.php` now
  does, in steps the command drives after a database and uploads backup: `convert` each PNG
  attachment to a WebP original with WebP sizes and an old-to-new map, `replace` every stored
  reference (serialized and JSON-escaped values included), `verify` files and database, and
  `move-aside` the old files to a folder outside uploads only once verify passes. Nothing is
  deleted.
