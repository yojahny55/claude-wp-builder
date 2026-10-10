# /wp-clone — Path B

`commands/wp-clone.md` sends the run here at Path B. Follow it in order; nothing in it is optional background.

## Contents

- B1 — Validate Provided Files
- B2 — Run /wp-create Locally (Fresh)
- B3 — Import Database
- B3.5 — Inventory Dependencies (from the database)
- B4 — Extract Uploads
- B5 — Detect Original Domain
- B6 — Search-Replace URLs
- B7 — Fix Up

### B1: Validate Provided Files

Check that the SQL dump file exists and is readable:

```bash
bash -c "test -f /path/to/dump.sql && echo 'SQL dump found' || echo 'SQL dump not found'"
```

If `--sql=` was not provided, ask the user:
> "Please provide the path to your SQL dump file (exported from phpMyAdmin, hosting panel, or `wp db export`):"

If `--uploads=` was provided, validate the archive exists:

```bash
bash -c "test -f /path/to/uploads.zip && echo 'Uploads archive found' || echo 'Uploads archive not found'"
```

If `--uploads=` was not provided, ask:
> "Do you have an uploads archive (zip/tar.gz) to import? If so, provide the path. Otherwise, press Enter to skip."

### B2: Run /wp-create Locally (Fresh)

Run the `/wp-create` command to set up a fresh local WordPress environment at the `--to=` path. This creates the full environment from scratch — WordPress download, database, web server, the works.

If the `--to=` path already runs WordPress with no `.wp-create.json`, offer the same choice
as A9 before creating anything: register it with `/wp-adopt` and import into it, or run
`/wp-create`.

### B3: Import Database

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** Exit `3` here means the step before this one neither
created nor adopted the destination. Run `${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md`
Steps 2 to 5 against it if it runs WordPress, then run the validator again. If it does not
run WordPress, or adoption fails, stop and say so, as the row says. Never import a database
into a destination this command has no manifest for.

This runs after B2, not before Step 0 — the manifest does not exist until `/wp-create`
has finished creating it.

**Now run Step 1.5 (The Destination Gate).** This is the last moment before the import
replaces the destination database. Do not run `wp db import` until it has passed.

Read `.wp-create.json` for the `$WP` wrapper:

**Now run Step 5.4 (Isolate the Clone — before the import).** The mail guard and
the cron constant are files; they must be in place before anything boots WordPress
against the source site's database, and the import does not remove them.

```bash
bash -c "$WP db import /path/to/dump.sql"
```

**Do not delete this file.** Unlike Path A's dump, the operator created it and passed it in
with `--sql=`; it may be their only copy, and removing someone's input because the command
happened to consume it is not cleanup.

Say what it is instead, once, in the final summary: the file at `--sql=` is a full database
export, it is still on disk with whatever permissions it was created with, and it is worth
removing or protecting once the clone is verified. Naming it is the right action here —
deleting it is not the command's to take, and staying silent leaves a production database
on the machine with nobody having mentioned it.

### B3.5: Inventory Dependencies (from the database)

Path B has no source to ask, so the inventory is derived from the database that was just
imported:

```bash
bash -c "$WP plugin list --fields=name,status,version --format=csv"
bash -c "$WP theme list --fields=name,status,version --format=csv"
```

Apply the same split as A3.5 — **bundled first**, then recoverable, not on WordPress.org,
unclassified — and write the same file beside the backup. A plugin this repository ships is
never sent to the client as "not on WordPress.org". There is no source header to compare here,
so a slug with a `plugins/<slug>/<slug>.php` in this repository is `bundled` on the slug alone,
and its line says so: "bundled — matched by slug only, no source header to compare".

**Say that this list is weaker, and why.** `wp plugin list` reports what is on disk joined
with what the options table activates, so a plugin the source had active whose directory
never existed here appears as a missing file rather than as a named dependency with a known
version. Path A asks the source directly and gets both. Reporting the two as equivalent
would tell an operator their inventory is complete when it is the best guess available from
a database alone.

### B4: Extract Uploads

If an uploads archive was provided, extract it:

**For .zip files:**
```bash
bash -c "unzip -o /path/to/uploads.zip -d /local/path/wp-content/uploads/"
```

**For .tar.gz files:**
```bash
bash -c "tar -xzf /path/to/uploads.tar.gz -C /local/path/wp-content/uploads/"
```

**Large uploads warning:** Before extracting, check the archive size:

```bash
bash -c "ls -lh /path/to/uploads.zip"
```

**If the archive is larger than 1 GB**, warn the user:
> "The uploads archive is `<size>`. Extraction may take several minutes and require significant disk space. Continue? (Y/n)"

### B5: Detect Original Domain

After importing the database, read the original site URL:

```bash
bash -c "$WP option get siteurl"
```

This will return the original domain from the imported database. Store it for search-replace.

### B6: Search-Replace URLs

Replace the original domain with the local domain from `.wp-create.json`:

```bash
bash -c "$WP search-replace 'old-domain.com' 'local-clone.local.com' --all-tables --precise"
```

Handle protocol changes as well:

```bash
bash -c "$WP search-replace 'https://old-domain.com' 'https://local-clone.local.com' --all-tables --precise"
```

### B7: Fix Up

```bash
bash -c "$WP cache flush"
bash -c "$WP rewrite flush"
```

Skip to **Step 5.5: Isolate the Clone — after the import**.
