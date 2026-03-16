---
description: Clone a remote or staging WordPress site to a local development environment
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "--from=ssh://user@host/path --to=/var/www/html/local"
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

```bash
bash -c "ssh user@host 'cd /remote/path && wp db export /tmp/wp-clone-dump.sql --allow-root 2>/dev/null || wp db export /tmp/wp-clone-dump.sql'"
```

### A5: Download Database Dump

```bash
bash -c "scp user@host:/tmp/wp-clone-dump.sql /tmp/wp-clone-dump.sql"
```

Clean up the remote temp file:

```bash
bash -c "ssh user@host 'rm -f /tmp/wp-clone-dump.sql'"
```

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

Read `.wp-create.json` from the local project to get the `$WP` wrapper:

```bash
bash -c "$WP db import /tmp/wp-clone-dump.sql"
```

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

Skip to **Step 6: Post-Clone Verification**.

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

Read `.wp-create.json` for the `$WP` wrapper:

```bash
bash -c "$WP db import /path/to/dump.sql"
```

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

Skip to **Step 6: Post-Clone Verification**.

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

Next steps:
  - Visit <local-url> to verify the site
  - Visit <local-url>/wp-admin/ to log in
  - Run /wp-debug if you encounter any issues
```
