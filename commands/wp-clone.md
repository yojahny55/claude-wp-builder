---
description: Clone a remote or staging WordPress site to a local development environment
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "--from=ssh://user@host/path --to=/var/www/html/local [--force]"
---

# WP Clone — Remote/Staging Site Cloning

Clone an existing WordPress site into a local development environment. Supports two paths: automated SSH-based cloning or manual import from SQL dump + uploads archive.

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for the following flags:

| Flag | Required | Description |
|------|----------|-------------|
| `--from=` | Path A only | SSH URL: `ssh://user@host/path/to/wordpress` |
| `--to=` | Yes | Local destination path (e.g., `/var/www/html/local-clone`) |
| `--sql=` | Path B only | Path to a SQL dump file (e.g., `/tmp/dump.sql`) |
| `--uploads=` | Path B only | Path to uploads zip/tar archive (e.g., `/tmp/uploads.zip`) |
| `--force` | No | Proceed when the destination already holds a WordPress site. The backup in Step 1.5 is still taken — `--force` means "I know what is there", not "skip the safety net" |

**Parsing rules:**

- If `--from=` starts with `ssh://`, extract `user`, `host`, and `remote_path` from `ssh://user@host/path`.
- If `--to=` is missing, ask the user for a local destination path.
- If neither `--from=` nor `--sql=` is provided, ask the user which path they want:
  > "How would you like to clone?
  > A) SSH — automated pull from a remote server
  > B) Manual — import from a SQL dump file + uploads archive"

## Step 1: Determine Clone Path

| Condition | Path |
|-----------|------|
| `--from=ssh://...` is provided | **Path A — SSH Automated** |
| `--sql=` is provided | **Path B — Manual Import** |
| Neither provided | Ask user (see Step 0) |

---

## Step 1.5: The Destination Gate

**Run this immediately before any `wp db import` or uploads sync, on both paths.** It is
written once here because both paths perform the same destructive act and a second copy
would drift; it does not execute here, because the destination is not knowable until the
path is chosen — under Path A, `/wp-create` may create it during this very run.

A dump carries `DROP TABLE` / `CREATE TABLE`, so `wp db import` does not merge into the
destination database: it replaces it. `rsync` into `wp-content/uploads/` overwrites
matching paths. Neither asks first, and neither leaves a copy behind.

The destination is a local development site — which is exactly where unpushed work lives:
seeded content, ACF values, test orders, a demo built this afternoon. `/wp-seed` has an
entire ownership model to avoid overwriting a client's work inside a database. Replacing
that database wholesale was, until this gate, one command with no prompt.

### 1.5.1: Is the destination occupied?

```bash
bash -c "$WP db tables --format=count 2>/dev/null || echo 0"
bash -c "find wp-content/uploads -type f 2>/dev/null | wc -l"
```

**An empty destination proceeds silently.** That is the ordinary case — a fresh
`/wp-create` environment — and a gate that announces itself on every ordinary run is a gate
people learn to skip past. It speaks only when there is something to lose.

### 1.5.2: Back up what is about to be replaced

Whenever the destination is occupied, back it up **before** asking anything:

```bash
bash -c "mkdir -p ~/.wp-clone-backups"
bash -c "$WP db export ~/.wp-clone-backups/<project-slug>-$(date -u +%Y%m%dT%H%M%SZ).sql"
```

**The backup goes outside the project directory on purpose.** A backup inside
`wp-content/` shares the fate of the thing it protects: the next clone's `rsync` reaches it,
and so does an `rm -rf` of a project someone has given up on. `~/.wp-clone-backups/` is the
one place that survives both.

Print the full path on its own line. A backup whose location the operator has to reconstruct
is not one they will find at the moment they need it.

### 1.5.3: Say what is there, then refuse

Do not ask "overwrite?" — nobody can answer that. Say what would be lost:

```bash
bash -c "$WP option get blogname"
bash -c "$WP post list --post_type=any --post_status=any --format=count"
bash -c "$WP post list --post_type=any --post_status=any --orderby=modified --order=desc --format=csv --fields=post_title,post_modified | sed -n 2p"
```

```
Error: the destination already holds a WordPress site.

  Site:          Client Demo
  Content:       47 posts and pages
  Last modified: "Services" — 2026-09-19 14:02 (2 hours ago)
  Uploads:       312 files

Importing replaces this database. A backup was written first:
  ~/.wp-clone-backups/client-demo-20260919T161145Z.sql

Re-run with --force to proceed, or clone into a different path.
```

"47 posts, last modified two hours ago" is a question an operator can answer. "Overwrite?"
is one they can only guess at, and a guess at this prompt costs a day of work.

### 1.5.4: `--force` proceeds, and still backs up

`--force` means "I know what is there", never "skip the safety net". The export costs seconds
and is the only thing that makes the decision reversible; tying it to the flag would remove
the backup from precisely the runs most likely to need it. Report the backup path under
`--force` too.

### 1.5.5: Carry the path into the summary

The backup path appears in the Step 6 summary, not only in this step's output — by the time
the clone finishes, this step has scrolled away.

---

## Path A — SSH Automated Clone

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

This runs after A9, not before Step 0 — the manifest does not exist until `/wp-create`
has finished creating it.

**Now run Step 1.5 (The Destination Gate).** This is the last moment before the import
replaces the destination database, and the first at which the destination is known — which
is why the gate executes here rather than where it is written. Do not run `wp db import`
until it has passed.

Read `.wp-create.json` from the local project to get the `$WP` wrapper:

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

Skip to **Step 5.5: Isolate the Clone**.

---

## Path B — Manual Import Clone

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

This runs after B2, not before Step 0 — the manifest does not exist until `/wp-create`
has finished creating it.

**Now run Step 1.5 (The Destination Gate).** This is the last moment before the import
replaces the destination database. Do not run `wp db import` until it has passed.

Read `.wp-create.json` for the `$WP` wrapper:

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

Skip to **Step 5.5: Isolate the Clone**.

---

## Step 5.5: Isolate the Clone

**Both paths arrive here, and nothing may load the site before this step runs.** Step 6
below loads WordPress and then tells the operator to go visit it — that page load is the
moment an uncontained clone acts, and by then every send is already out.

A clone carries the source site's whole configuration: its mail settings, its payment
credentials, its webhook URLs, its scheduled jobs. None of that knows it has been copied.
Everything up to this point has faithfully reproduced a production site on a machine that
is not production, and reproducing it faithfully is exactly the problem.

### 5.5.1: Stop outbound mail

Write `wp-content/mu-plugins/00-clone-isolation.php` in the clone (create `mu-plugins/`
if absent):

```php
<?php
/**
 * CLONE ISOLATION — delete this file if this site ever becomes real.
 *
 * Written by /wp-clone. This site is a copy of another one and must not act
 * on its behalf. Mail is captured to wp-content/clone-mail.log instead of sent.
 */
defined( 'ABSPATH' ) || exit;

add_filter( 'pre_wp_mail', function ( $null, $atts ) {
    $to = is_array( $atts['to'] ) ? implode( ', ', $atts['to'] ) : (string) $atts['to'];
    error_log(
        sprintf( "[%s] BLOCKED to=%s subject=%s\n", gmdate( 'c' ), $to, (string) $atts['subject'] ),
        3,
        WP_CONTENT_DIR . '/clone-mail.log'
    );
    return true; // reported to the caller as sent; nothing leaves the machine
}, 0, 2 );
```

**`pre_wp_mail` is the right seam, and a mail plugin is not.** Every sender — core password
resets and new-user notices, WooCommerce order and subscription mail, Contact Form 7 —
goes through `wp_mail()`, and this filter short-circuits all of them at once. Disabling an
SMTP plugin instead does not stop sending: core falls back to PHP `mail()`, so the site
keeps mailing and merely stops logging it where anyone would look.

Returning `true` matters as much as intercepting. `wp_mail()` reports success to its caller,
so WooCommerce marks the order email sent and does not retry, and no plugin enters a failure
path that a real send would never have triggered. The clone behaves like the original
everywhere except at the wire.

A **must-use** plugin, because it cannot be deactivated from wp-admin, survives any plugin
being reactivated, and cannot be undone by an option write. Its filename sorts first and its
header says what it is, so nobody mistakes it for part of the site.

### 5.5.2: Stop scheduled jobs

```bash
bash -c "$WP config set DISABLE_WP_CRON true --raw --type=constant"
```

WordPress spawns cron on page loads. On a store clone the due queue is the source site's:
subscription renewals, abandoned-cart mail, scheduled publishes — all of them wanting to run
against whatever integrations the database still points at. `/wp-debug` already reports this
constant, so the state is visible afterwards.

### 5.5.3: Keep it out of search results

```bash
bash -c "$WP option update blog_public 0"
```

### 5.5.4: Report live integrations — do not silently change them

Search the clone for credentials and endpoints that still address production, and **report
what is found without editing it**:

```bash
bash -c "$WP option list --search='*_webhook*' --format=table"
bash -c "$WP option list --search='*_live_*' --format=table"
bash -c "$WP plugin list --status=active --field=name | grep -iE 'stripe|paypal|woocommerce|mailchimp|zapier'"
```

Report each finding as: what it is, where it lives, and what it still points at.

**Reporting is the action here.** Flipping a gateway into test mode would change the
behaviour under test, and a clone of a store usually exists *because* something about
payment needs reproducing — a silent switch makes that bug disappear and wastes the session
that was meant to find it. Silent edits also hide the far more serious fact the operator
needs to hold: a database on this machine contains live credentials. What to do about that
is a decision, not a default. Say what is live, and let the operator choose.

The one thing not to leave to a decision is **real customer data**, which is already on the
disk by the time this step runs. Say so plainly in the report; opt-in anonymisation is a
separate operation, not something to infer.

### 5.5.5: Confirm the isolation took

```bash
bash -c "test -f wp-content/mu-plugins/00-clone-isolation.php && echo 'mail: captured' || echo 'mail: NOT ISOLATED'"
bash -c "$WP eval \"echo defined('DISABLE_WP_CRON') && DISABLE_WP_CRON ? 'cron: disabled' : 'cron: STILL RUNNING';\""
bash -c "$WP option get blog_public"
```

**Any line reporting a failure stops the clone here.** Do not continue to Step 6, which loads
the site. A clone that cannot be isolated is not a clone that should be opened, and the
honest report is that it is unsafe to visit — not a summary with a warning buried in it.

---

## Step 6: Post-Clone Verification

Run a series of checks to verify the cloned site is working correctly.

### 6.1: Check WordPress Loads

```bash
bash -c "$WP eval 'echo \"WordPress loaded: \" . get_bloginfo(\"version\");'"
```

### 6.2: Verify URLs Are Correct

```bash
bash -c "$WP option get siteurl"
bash -c "$WP option get home"
```

Both should return the local domain (e.g., `https://local-clone.local.com`). If they still show the old domain, the search-replace may have missed serialized data — re-run with `--precise` flag.

### 6.3: Check Admin Accessibility

```bash
bash -c "$WP user list --role=administrator --format=table"
```

Verify at least one admin user exists. If admin passwords are unknown, offer to reset:

> "The cloned site has these admin users: `<list>`. Would you like to reset any admin password for local development?"

If yes:

```bash
bash -c "$WP user update <user_id> --user_pass=admin"
```

### 6.4: Check Active Theme

```bash
bash -c "$WP theme list --status=active --format=table"
```

If the active theme is missing files (not found in `wp-content/themes/`), warn the user.

### 6.5: Check Plugins

```bash
bash -c "$WP plugin list --format=table"
```

Note any plugins that are "active" but have missing files — these will cause errors.

### 6.6: HTTP Response Check

```bash
bash -c "curl -sI -o /dev/null -w '%{http_code}' https://local-clone.local.com/ 2>/dev/null || echo 'Could not reach site'"
```

Expect a `200` or `301/302` response. If unreachable, check that the web server is running and DNS/hosts entry is configured.

### 6.7: Print Summary

```
=== Clone Complete ===
Source:       <remote-url or "manual import">
Destination:  <local-path>
Local URL:    <local-url>
Admin URL:    <local-url>/wp-admin/
DB replaced:  <old-domain> → <new-domain>
Uploads:      <synced | extracted | skipped>
Admin users:  <list of admin usernames>

Replaced:     a WordPress site was already here — "Client Demo", 47 posts
  Backup      ~/.wp-clone-backups/client-demo-20260919T161145Z.sql
              (omit this block entirely when the destination was empty)

Database dump:
  Path A        exported, transferred, imported and deleted from both machines
  Path B        /tmp/dump.sql is yours and was left in place — it is a full database
                export; remove or protect it once this clone is verified

Isolation:
  Mail          captured to wp-content/clone-mail.log (mu-plugins/00-clone-isolation.php)
  Cron          disabled (DISABLE_WP_CRON)
  Indexing      discouraged (blog_public = 0)

Still live — reported, not changed:
  - woocommerce_stripe_settings holds a live secret key (option: woocommerce_stripe_settings)
  - 2 webhooks still point at <old-domain> (options: *_webhook_url)
  - This database holds real customer records: 1,284 orders, 903 customer accounts.
  → These are decisions, not defaults. Nothing above was edited.

Next steps:
  - Visit <local-url> to verify the site
  - Visit <local-url>/wp-admin/ to log in
  - Run /wp-debug if you encounter any issues
  - Delete wp-content/mu-plugins/00-clone-isolation.php if this site ever becomes real
```

The isolation block is **not** optional and **not** collapsed to one line when everything
succeeded. An operator who cannot see that mail is captured has no reason to believe it is,
and the one time it silently failed is the run where that line mattered.
