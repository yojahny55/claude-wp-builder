# /wp-create — Step 4.2

`commands/wp-create.md` sends the run here at Step 4.2 (Download WordPress) when the user chose **Overwrite** on an existing manifest. Follow it in order; nothing in it is optional background.

Overwrite is a full install, never Adopt Mode, even though `wp-config.php` is still on disk. Read the environment, the database settings (`database.*`), the wrapper (`wp_cli.wrapper`, the `$WP` of this run), the slug (`project.slug`) and the database name (`database.name`) from the existing `.wp-create.json`: this branch runs from Step 2b, before Steps 3 and 4 have produced them. Step 3 then reuses the manifest's `database.*` and environment without asking and without generating a new password, so `db reset` (4.4, which reads the old `wp-config.php`) and `config create` (4.5) hit the same database.

1. **Services.** For a container environment (`environment.engine` is `docker-compose`, `ddev`, `lando` or `wp-env`) whose services are stopped, start them with that environment's Step 4.8 command; if that fails, stop and tell the user the backup could not be taken.
2. **Export, to the host.** Write the dump outside the WordPress root, with the file on the host and not inside a container:
   ```bash
   mkdir -p ~/wp-create-backups
   WP='<wrapper>' bash -c '$WP db export - > "$1"' _ ~/wp-create-backups/<slug>-$(date -u +%Y%m%dT%H%M%SZ).sql
   ```
   Do not wrap it in `bin/wp-quiet.sh`: that filter rewrites stdout, which here is the dump itself. Require exit 0 and a last non-empty line containing `-- Dump completed`; otherwise delete the file and stop. If WP-CLI reports `Unknown database`, there is nothing to lose: ask whether to continue without a copy. Any other failure: stop.
3. **Confirm.** Ask the user to confirm, naming only what this environment will really replace: the WordPress core files in `${PROJECT_PATH}` (`wp-admin`, `wp-includes` and the root files; `wp-content` is kept), `wp-config.php` (recreated with `config create --force`) and the contents of database `<database.name>` (emptied, not the container or server), plus the regenerated environment config (Step 4.3) and the backup path. Without an explicit yes, stop: no 4.2, no 4.4.
4. **Replace.** Step 4.2 runs with `core download --force --skip-content` (the flag is what keeps `wp-content`). Step 4.4 does not run `db create`, which fails on a database that exists: run `$WP db reset --yes` instead (it drops and recreates the database), in every environment. If the database was missing (`Unknown database`), 4.4 runs as written.
5. Step 4.5 runs `config create --force`: without it the run aborts on the existing `wp-config.php` after core and database are already replaced.
6. Back up the old manifest to `.wp-create.json.bak` and continue as if it did not exist.
