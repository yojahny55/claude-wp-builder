# /wp-clone — Path C

`commands/wp-clone.md` sends the run here at Path C. Follow it in order; nothing in it is optional background.

Path C restores a site from what a hosting-panel backup (Plesk, cPanel and the like) hands over: an archive of the whole docroot (`.zip`, `.tar.gz`, `.tgz`, `.tar`) plus a database dump (`.sql`, `.sql.gz`, `.gz`, `.zip`). Path B takes only a dump and an uploads archive, so core, plugins and theme come from a fresh download; here they come from the backup, which is why the docroot has to be located, the table prefix read from the dump and `wp-config.php` reconciled with the local database.

## Contents

- C1 — Validate Provided Files
- C2 — Run /wp-create Locally (Fresh)
- C3 — Read the Archive and the Dump (nothing is written)
- C4 — Extract the Site
- C5 — Reconcile wp-config.php
- C6 — Import the Dump
- C7 — Search-Replace URLs
- C8 — Local Safety and Fix Up

### C1: Validate Provided Files

Both `--files=` and `--db=` must exist and be readable; ask for whichever is missing. Check the
tools the formats need (`unzip` for `.zip`, `gzip` for `.gz`).

A full-site archive of a store can be tens of gigabytes, most of it uploads. **Never unpack it
into `/tmp`**, which is often a RAM-backed tmpfs: read its index, then extract straight into
the destination (C4). Compare the archive size with the free space on the destination
filesystem and on the database's filesystem (an InnoDB database takes about 1.6 times the
dump), and warn when they do not fit. If `--uploads-target=` is given, uploads are measured
against that disk instead.

### C2: Run /wp-create Locally (Fresh)

Same as B2: `/wp-create` at the `--to=` path, or `/wp-adopt` when it already runs WordPress
without a manifest. It creates the database, the local credentials and the web server entry
that the restored files will use. Keep a copy of the `wp-config.php` it wrote beside the
manifest (`wp-config.php.local`); C5 may need it.

### C3: Read the Archive and the Dump (nothing is written)

**Docroot.** Find where WordPress starts inside the archive from its index, without
extracting. The docroot is the directory holding `wp-load.php`, and the number of path
components above it is the strip count.

```bash
bash -c "tar -tzf /path/site.tar.gz | head -400 | grep -m1 -E '(^|/)wp-load\.php$'"   # .tar.gz / .tgz (use -tf for .tar)
bash -c "unzip -Z1 /path/site.zip | grep -E '(^|/)wp-load\.php$' | awk -F/ '{print NF \"\t\" \$0}' | sort -n | cut -f2- | head -1"
```

Read a zip's whole index: some zips list `wp-admin/` and `wp-content/` before the files in the
root, so `wp-load.php` can appear after tens of thousands of entries, and the shallowest match
is the docroot. A tar is read in order, so only its first entries are scanned; if
`wp-load.php` is not among them, ask for the strip count rather than guessing. The strip count
is the number of `/` in the matched path before `wp-load.php` (`public_html/wp-load.php` is 1,
`wp-load.php` is 0). Honour `--strip=<n>` when the user gives it.

**Dump to a clean stream.** Drop the lines that would send the import to the source's
database. A panel dump carries `CREATE DATABASE` and ``USE `source_db` ``; left in, the tables
land in the source's name and the local database stays empty. The filtered stream goes straight
into the import (C6) and is never written to disk: a decompressed store dump can be several
times the size of the `.gz`, `/tmp` is often a RAM-backed tmpfs, and a scratch copy is a full
database export that would need removing on every outcome:

```bash
# C6 runs this; set -o pipefail so a truncated or corrupt dump fails the import instead of loading half
set -o pipefail; gzip -dc /path/dump.sql.gz | grep -avE '^(CREATE DATABASE|USE \`)'   # .sql: cat; .zip: unzip -p
```

The operator's file is never edited. Say in the summary that the original at `--db=` was left
in place (same rule as B3).

**Table prefix.** Read it from the dump, not from the archive's `wp-config.php`, because the
database is what has to match. The prefix is the part before `options` in the first
``CREATE TABLE `<prefix>options` `` whose `<prefix>users` table also exists. Fall back to the
archive's `$table_prefix` only when the dump has no such table, and stop if neither gives one.

**Source URLs.** `siteurl` and `home` can differ on a production site. Read both from the dump
(`'siteurl','https://…'` and `'home','https://…'` in the `options` INSERT), keep the distinct
values, and use `--url-old=` when the user gives it. If the dump does not show them, read them
with `$WP option get` after C6.

Print what was found (docroot, strip count, prefix, source URLs, sizes) and let the user
correct it before anything is written.

### C4: Extract the Site

**Now run Step 1.5 (The Destination Gate).** Extraction overwrites the destination's files,
so the gate runs before it, not at the import.

Extract over the destination, not through a temporary copy.

```bash
bash -c "tar -xzf /path/site.tar.gz -C /local/path --strip-components=<n>"
bash -c "unzip -oq /path/site.zip -d /local/path"
```

`-o` is required: `/wp-create` has already put WordPress core in the destination, and without it
`unzip` stops to ask whether to replace `wp-load.php`, reading the answer from the terminal, so a
non-interactive run hangs.

`unzip` has no strip option: extract whole, then **merge** the docroot's contents up one level
(`cp -a <container>/. . && rm -rf <container>`; a `mv` fails on `wp-admin/`, `wp-includes/` and
`wp-content/`, which already exist, and leaves the site's own `wp-content` inside the container).
Check that `wp-load.php` exists in the destination afterwards and that the active theme's
directory from the archive is there too, and stop if not.

`--exclude=<pattern>` (repeatable, for example the folder of paid downloads or a cache
directory) is passed through to `tar --exclude` or `unzip -x`. Say what was skipped in the
summary: skipped files are missing from the clone.

**Production leftovers.** Rename, never delete, whatever would expose credentials or confuse
a local run: `.env`, `php_errorlog`, `error_log`, `wp-config.php.bak`, `.htaccess.bk`
(append `.bak`).

**Uploads on another disk (`--uploads-target=<dir>`).** For a large media library, keep the
files on a bigger disk and link them in.

1. Exclude `<docroot>wp-content/uploads/*` from the extraction above.
2. Extract only that subtree into `<dir>` (tar: `--strip-components=<n+2>` with the
   `<docroot>wp-content/uploads/` pattern; zip: extract the pattern to a scratch directory on
   the same filesystem as `<dir>` and move its contents).
3. Replace the empty `wp-content/uploads` with a symlink to `<dir>`.

Point the link at the path the web server will really traverse. Apache runs as its own user,
so **every directory on the way to the target needs search permission for it**: a target under
a home directory with mode `700` fails with 403 or missing images however the files are
owned. Use a mount point outside the home directory (for example under `/mnt`), not a
convenience symlink into `~`.

On an NTFS mount (`ntfs3`) ownership and mode are set by mount options and by each file:
mount with `gid=<web group>,umask=002` so the web server can write, and if something still
answers "Permission denied", `chgrp` it to the web group and `chmod g+w`. Identify the disk in
`/etc/fstab` by `PARTUUID` rather than `UUID`, which changes when the filesystem is repaired,
and if the target looks empty check that the disk is actually mounted before suspecting the
archive. The vhost needs a `<Directory>` for the target so `.htaccess` rules inside it apply
(a protected downloads folder must keep answering 403). Do not move or rename those files from
another operating system: their paths are stored in the database.

### C5: Reconcile wp-config.php

Read the local credentials from `.wp-create.json` and apply them to the restored config; all
with `$WP config set`, which does not boot WordPress:

- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` to the local values, and `table_prefix`
  (`--type=variable`) to the prefix found in C3.
- `WP_HOME` and `WP_SITEURL`, **only if the file defines them**, to the local URL: a config
  that pins them wins over the database and would redirect every request to the source domain.
- `FORCE_SSL_ADMIN` and `FORCE_SSL_LOGIN` to `false` when defined: a local `http` vhost cannot
  answer the `https` redirect and wp-admin becomes unreachable.
- `WP_CACHE` to `false` when defined, and `DISABLE_WP_CRON` is left to Step 5.4.
- `FS_METHOD` to `direct`, and the debug constants (`WP_DEBUG`, `WP_DEBUG_LOG` true,
  `WP_DEBUG_DISPLAY` false) so errors go to `wp-content/debug.log`.

If the archive had no `wp-config.php`, restore the one saved in C2 and set `table_prefix` on it.
`--keep-config` skips every edit above: say that the clone then keeps the source credentials.

**Cache drop-ins.** WordPress loads `wp-content/object-cache.php` and `advanced-cache.php`
even when WP-CLI runs with `--skip-plugins`. An object cache drop-in for a Redis that does not
exist locally makes every `wp` command fail with a connection error, and a page-cache drop-in
serves pages carrying source URLs. Rename both to `*.bak` now, before the first command that
boots WordPress, and list them in the summary.

**Permissions.** Owner the user, group the web server's, directories `755`, files `644`,
`wp-content` `2775` / `664` (WP-CLI and Apache both write there), `uploads` writable by the
web group, `wp-config.php` `640`.

### C6: Import the Dump

**Now run Step 5.4 (Isolate the Clone — before the import).** The extraction brought the
source's plugins and mu-plugins with it, and the first command that loads WordPress runs them
against the source's data.

```bash
bash -c "set -o pipefail; gzip -dc /path/dump.sql.gz | grep -avE '^(CREATE DATABASE|USE \`)' | $WP db import -"   # filter from C3; .sql: cat; .zip: unzip -p
```

Count the tables afterwards and stop if there are none.

### C7: Search-Replace URLs

Run the replacement for every distinct source URL from C3, `--all-tables --precise` (serialized
arrays), then the same host without the scheme (`//host`, protocol-relative links and CDN
settings), and the `www.` / non-`www.` counterpart:

```bash
bash -c "$WP search-replace 'https://old.example.com' 'http://local.example' --all-tables --precise --report-changed-only --skip-tables='*_actionscheduler_actions,*_actionscheduler_logs,*_woocommerce_sessions,*_wsal_*,*_*_404_logs,*_email_logs,*_wc_admin_note*'"
bash -c "$WP option update home 'http://local.example'"
bash -c "$WP option update siteurl 'http://local.example'"
```

Skip the tables that are logs, queues and sessions: on a store they weigh gigabytes, `--precise`
over them takes hours, and a URL in them does not change how the site looks. **Say in the
summary that the old domain can remain in those tables** (and in anything else skipped with
`--skip-tables=`, which the user may override). Keep this a decision about weight, never
about content: do not skip a table that holds posts, options or plugin settings.

### C8: Local Safety and Fix Up

Deactivate what only works, or only does harm, against production: page-cache and
object-cache plugins, firewalls and security scanners that bind to the source host, and
services that call external APIs with the source's credentials (catalog and ads connectors,
analytics, social feeds). Only those that are active, by slug, with
`$WP plugin deactivate <slugs>`; list them, and honour `--keep-plugins`. **Payment gateways are
handled in Step 5.5.2**, for every path, not here.

Then `$WP cache flush` and `$WP rewrite flush --hard`. If `--admin-user=` was given, create or
update that administrator with a local-only password and print it once.

Skip to **Step 5.5: Isolate the Clone — after the import**.
