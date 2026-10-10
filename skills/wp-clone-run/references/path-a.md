# /wp-clone — Path A

`commands/wp-clone.md` sends the run here at Path A. Follow it in order; nothing in it is optional background.

## Contents

- A1 — Check Prerequisites
- A2 — Verify SSH Connectivity
- A3 — Check Remote WP-CLI
- A3.5 — Inventory Remote Dependencies
- Split the list by what the operator can do about it
- Write it down, and say where
- A4 — Export Remote Database
- A5 — Download Database Dump
- A6 — Detect Remote Upload Size
- A7 — Rsync Uploads
- A8 — Extract Remote Domain
- A9 — Run /wp-create Locally
- A10 — Import Database
- A11 — Search-Replace URLs
- A12 — Fix Up
- A13 — Fix Permissions

### A1: Check Prerequisites

Verify that `ssh`, `scp`, and `rsync` are available locally:

```bash
bash -c "command -v ssh && command -v scp && command -v rsync"
```

If any tool is missing, abort with a clear message:
> "Missing required tool: `<tool>`. Install it before running SSH clone."

### A2: Verify SSH Connectivity

Test that the SSH connection works and that the remote path exists:

```bash
bash -c "ssh -o ConnectTimeout=10 -o BatchMode=yes user@host 'test -d /remote/path && echo OK'"
```

If this fails, inform the user:
> "Cannot connect via SSH. Check that:
> 1. SSH key is configured for user@host
> 2. The remote path exists
> 3. The user has read access to the WordPress directory"

### A3: Check Remote WP-CLI

Check if WP-CLI is available on the remote server:

```bash
bash -c "ssh user@host 'which wp || command -v wp'"
```

If WP-CLI is not available on the remote, warn the user and ask them to either install it remotely or switch to Path B (manual export via phpMyAdmin).

### A3.5: Inventory Remote Dependencies

**This clone transfers the database and `wp-content/uploads/`. It does not transfer plugins
or themes.** The imported database will name the source site's active plugins and its active
theme, and none of those files will be present unless `/wp-create`'s profile happened to
install the same ones. WordPress deactivates a plugin whose file is missing and falls back
off a missing theme, so the first page load is a site with most of its behaviour gone.

**Take the inventory now, while the SSH session is open.** After the clone the source is
unreachable, and the local database can only report plugin *names* — not their versions, and
not whether they can be obtained at all. This is the one moment the authoritative answer is
available:

```bash
bash -c "ssh user@host 'cd /remote/path && wp plugin list --fields=name,title,status,version --format=csv'"
bash -c "ssh user@host 'cd /remote/path && wp theme list --fields=name,status,version --format=csv'"
```

### Split the list by what the operator can do about it

**Bundled plugins first.** A plugin claude-wp-builder ships — `store-kit` — is not on
WordPress.org and is not the client's to supply: it comes back from this repository. Check the
plugin root before asking WordPress.org, and read the bundled file's header:

```bash
bash -c "sed -n 's/^ \* Plugin Name: *//p' '${CLAUDE_PLUGIN_ROOT}/plugins/<slug>/<slug>.php' 2>/dev/null"
```

The plugin is `bundled` only when `plugins/<slug>/<slug>.php` exists **and** its `Plugin Name:`
header prints exactly the `title` the source reported for that slug in the inventory above. A
missing file prints nothing; a different name is a same-slug plugin that is not ours, and goes
through the WordPress.org split below like any other.

A `bundled` answer is reported as "shipped by claude-wp-builder — reinstall with `/wp-woo-setup`",
which copies and activates it. Only the rest go through the WordPress.org split below.

For each plugin and theme the source has **active** and the destination does not have on
disk, decide which of three groups it belongs to:

```bash
bash -c "curl -s -o /dev/null -w '%{http_code}' 'https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request\[slug\]=<slug>'"
```

| Answer | Group | Report |
|---|---|---|
| `200` | on WP.org — **recoverable** | the exact command, pinned to the source's version |
| `404` | not on WP.org — custom, licensed or premium | the clone is **incomplete** until someone supplies the files |
| anything else, or no network | **unknown** | say it could not be classified |

**Never guess the third row into one of the first two.** A network failure that silently
reports a licensed plugin as "available on WP.org" sends the operator to run a command that
installs a *different* plugin which happens to share a slug, and a failure that reports an
ordinary plugin as licensed sends them to ask a client for a file they could have downloaded.
Unknown is a real answer and the only honest one when the check did not complete.

Already present locally — `/wp-create`'s profile installed some of these — is silent. A list
that repeats what is already there buries the part that needs action.

### Write it down, and say where

```
=== Dependency inventory ===
Recoverable — install these (versions from the source):
  wp plugin install contact-form-7 --version=6.0.1 --activate
  wp plugin install wordpress-seo --version=23.4 --activate

Bundled with claude-wp-builder — reinstall with /wp-woo-setup:
  store-kit                  1.0.0

Not on WordPress.org — this clone is incomplete without them:
  woocommerce-subscriptions  6.4.1   (active on the source)
  acf-pro                    6.3.6   (active on the source)
  → These need the client's own copies. Nothing local can obtain them.

Could not classify (no network):
  some-plugin-slug           1.2.0

Already installed locally — nothing to do:
  akismet, woocommerce
```

Write the same content to `~/.wp-clone-backups/<project-slug>-<timestamp>-dependencies.md`,
beside the destination backup from Step 1.5, and print the path.

An inventory that exists only in the terminal is one the operator cannot act on tomorrow —
and this is the list they work through *after* the clone, once the site is up and obviously
missing things. It goes next to the backup rather than into the project because it is an
artifact of this clone, not part of the site, and nothing generated here should end up
committed to the project's repository.

### A4: Export Remote Database

**The dump is the whole production database** — customer records, order rows, password
hashes, and whatever API keys and tokens the site keeps in `wp_options`. It exists, briefly,
as a plain file on two machines. Both copies get a unique name and owner-only permissions,
and both are deleted.

Pick the remote path first, and keep it for A5:

```bash
bash -c "REMOTE_DUMP=\$(ssh user@host 'mktemp -t wp-clone-XXXXXXXX.sql') && echo \$REMOTE_DUMP"
```

`mktemp`, never a fixed name under `/tmp`, for two independent reasons. A predictable
path in a world-writable directory on a **production** server is a name an unprivileged local
user can wait for. And two clones running at once against the same machine would otherwise
share one filename — the second export overwrites the first, and the first clone imports the
second site's database into its own destination, with nothing to say so.

Export with a restrictive umask so the file is never briefly world-readable:

```bash
bash -c "ssh user@host \"cd /remote/path && umask 077 && (wp db export '\$REMOTE_DUMP' --allow-root 2>/dev/null || wp db export '\$REMOTE_DUMP')\""
```

`umask 077` applies to files the command creates, so it has to be set in the same shell as
the export — `chmod` afterwards leaves a window in which the dump already exists with the
default mode.

### A5: Download Database Dump

```bash
bash -c "LOCAL_DUMP=\$(mktemp -t wp-clone-XXXXXXXX.sql) && chmod 600 \"\$LOCAL_DUMP\" && scp user@host:\"\$REMOTE_DUMP\" \"\$LOCAL_DUMP\" && echo \$LOCAL_DUMP"
```

**Delete the remote copy whether or not the transfer worked:**

```bash
bash -c "ssh user@host \"rm -f '\$REMOTE_DUMP'\""
```

Run this even when the `scp` above failed, and say so if it cannot be reached. A failed
clone is exactly the run that leaves a production database sitting on a production server:
the transfer is the step most likely to break, and a cleanup that only runs on success is
absent from every case that needed it.

`$LOCAL_DUMP` carries to A10, which imports it, and to A10's cleanup, which deletes it.
**The local copy is not self-cleaning.** `/tmp` survives until a reboot or a distribution's
tmpfiles timer, which is days — long enough that the dump outlives every memory of the
clone that made it.

### A6: Detect Remote Upload Size

Before syncing uploads, check the size to warn about large transfers:

```bash
bash -c "ssh user@host 'du -sh /remote/path/wp-content/uploads/ 2>/dev/null'"
```

**If uploads are larger than 1 GB**, warn the user:
> "The remote uploads directory is `<size>`. This may take a while to sync. Options:
> 1. Continue with full sync
> 2. Skip uploads for now (you can rsync later)
> 3. Use `--exclude='*.mp4' --exclude='*.zip'` to skip large files"

Ask the user which option they prefer before proceeding.

### A7: Rsync Uploads

**Run Step 1.5 (The Destination Gate) first if it has not run yet in this clone.** `rsync`
overwrites matching paths under `wp-content/uploads/`, and an occupied destination has files
there that this clone did not put there.

```bash
bash -c "rsync -avz --progress user@host:/remote/path/wp-content/uploads/ /local/path/wp-content/uploads/"
```

### A8: Extract Remote Domain

Get the remote site URL for search-replace later:

```bash
bash -c "ssh user@host 'cd /remote/path && wp option get siteurl 2>/dev/null'"
```

Store the remote domain (e.g., `staging.example.com`) for the search-replace step.

### A9: Run /wp-create Locally

Run the `/wp-create` command to set up the local WordPress environment at the `--to=` path. This handles WordPress download, database creation, web server configuration, and all environment setup.

If WordPress files already exist at the destination (e.g., from a previous clone attempt), use adopt mode.

**When the destination is already a working local site** — its vhost, database and WP-CLI
already serve it, but it has no `.wp-create.json` — ask with `AskUserQuestion` before running
`/wp-create`:

```
The destination already runs WordPress and was not created by /wp-create.
  [A] Register it with /wp-adopt and import into it — nothing about its environment changes (recommended)
  [B] Run /wp-create in Adopt Mode — reconfigures vhost, SSL, hosts entry and options for it
```

On A, run `${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md` Steps 2 to 5 against the
destination instead of `/wp-create`, then continue with A10. The Destination Gate (Step 1.5)
still runs at A10 and still backs up the database it is about to replace. Adoption registers
the destination; it does not make it disposable.

### A10: Import Database

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

This runs after A9, not before Step 0 — the manifest does not exist until `/wp-create`
has finished creating it.

**Now run Step 1.5 (The Destination Gate).** This is the last moment before the import
replaces the destination database, and the first at which the destination is known — which
is why the gate executes here rather than where it is written. Do not run `wp db import`
until it has passed.

Read `.wp-create.json` from the local project to get the `$WP` wrapper:

**Now run Step 5.4 (Isolate the Clone — before the import).** The mail guard and
the cron constant are files; they must be in place before anything boots WordPress
against the source site's database, and the import does not remove them.

```bash
bash -c "$WP db import \"\$LOCAL_DUMP\""
```

**Then delete the local dump, and delete it whether the import succeeded or not:**

```bash
bash -c "rm -f \"\$LOCAL_DUMP\""
```

A failed import is the case that matters. It is the run the operator retries, investigates,
or abandons — and the one where a full production database is most likely to be left in
`/tmp` and forgotten, because nobody tidies up after a command that did not finish. The
dump has served its only purpose the moment the import returns, either way.

Report the deletion in the final summary. A dump that was written and then removed is
something the operator should be able to confirm rather than assume.

### A11: Search-Replace URLs

Replace the remote domain with the local domain from `.wp-create.json`:

```bash
bash -c "$WP search-replace 'staging.example.com' 'local-clone.local.com' --all-tables --precise"
```

Also handle protocol changes if needed (https to http or vice versa):

```bash
bash -c "$WP search-replace 'https://staging.example.com' 'https://local-clone.local.com' --all-tables --precise"
```

### A12: Fix Up

```bash
bash -c "$WP cache flush"
bash -c "$WP rewrite flush"
```

### A13: Fix Permissions

```bash
bash -c "bash ${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh permissions --path=/local/path"
```

Skip to **Step 5.5: Isolate the Clone — after the import**.
