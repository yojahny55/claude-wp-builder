- **`/wp-clone` Path C restores a site from a full-site files archive plus a database dump.**
  Hosting-panel backups (Plesk, cPanel) hand over the whole docroot as one `.zip` or `.tar.gz`
  and a dump, which Path B (dump plus uploads only) could not use. `--files=` and `--db=` select
  the path. It reads the archive index to find the docroot depth (the shallowest `wp-load.php`;
  `--strip=` overrides), reads the table prefix and the `siteurl`/`home` values from the dump,
  strips `CREATE DATABASE`/`USE` lines so the import cannot land in the source's database,
  reconciles `wp-config.php` with the local credentials (pinned `WP_HOME`/`WP_SITEURL` and forced
  SSL undone), sets cache drop-ins aside, extracts without unpacking to a temporary directory,
  and skips log, session and queue tables in the URL search-replace with a note that the old
  domain can remain there. `--uploads-target=<dir>` keeps a large media library on another disk
  through a symlink, with the traps spelled out: the web server user must be able to traverse
  every directory of the target (a mode-700 home directory blocks it) and NTFS mounts need
  group and umask mount options. The step detail lives in
  `skills/wp-clone-run/references/path-c.md`; `commands/wp-clone.md` stays a map.
