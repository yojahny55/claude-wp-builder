---
description: Diagnose WordPress issues — runs health checks, identifies problems, and offers WP-CLI fixes
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "[issue description]"
---

# WP Debug — Diagnostics & Debugging

Diagnose WordPress issues by running systematic health checks, identifying problems, and offering targeted WP-CLI fixes. Optionally accepts an issue description to run extra targeted diagnostics.

## Step 0: Read Project Context

Read `.wp-create.json` from the project root to extract the WP-CLI wrapper command.

```bash
bash -c "cat .wp-create.json"
```

Set `$WP` to the value of `wp_cli.wrapper` from the manifest (e.g., `docker exec my-project-wp wp --allow-root`, `ddev wp`, `lando wp`, `wp --path=/var/www/html/my-project`).

If `.wp-create.json` does not exist:
- Check if bare `wp` is available: `bash -c "which wp"`
- If available, set `$WP` to `wp` and continue (assume the current directory is the WordPress root).
- If not available, tell the user that WP-CLI is required and stop.

Also determine the **environment type** for log tailing later:
- If `wp_cli.wrapper` contains `docker exec` → **Docker**
- If `wp_cli.wrapper` starts with `ddev` → **DDEV**
- If `wp_cli.wrapper` starts with `lando` → **Lando**
- Otherwise → **Native**

Store any user-provided issue description from the command argument for use in Step 2.

## Step 1: Always-Run Diagnostics

Run ALL 8 check categories. Execute each command via Bash using `bash -c`. Collect all output for the report in Step 3.

---

### Check 1: WordPress Health

```bash
bash -c "$WP core version"
bash -c "$WP core verify-checksums"
bash -c "$WP eval \"echo PHP_VERSION;\""
bash -c "$WP eval \"echo ini_get('memory_limit');\""
```

Note the WordPress version, whether checksums pass, PHP version, and memory limit.

---

### Check 2: Debug Configuration

```bash
bash -c "$WP config get WP_DEBUG"
bash -c "$WP config get WP_DEBUG_LOG"
bash -c "$WP config get WP_DEBUG_DISPLAY"
```

Note whether debug mode is enabled, whether logging is active, and whether errors are displayed.

---

### Check 3: Database Health

```bash
bash -c "$WP db check"
bash -c "$WP option get siteurl"
bash -c "$WP option get home"
```

Note if all tables pass the check, and whether `siteurl` and `home` match (mismatches cause redirect loops).

---

### Check 4: Plugin Status

```bash
bash -c "$WP plugin list --format=table"
bash -c "$WP plugin list --update=available --format=table"
```

Note total plugin count, any inactive plugins, and any with available updates.

---

### Check 5: Theme Status

```bash
bash -c "$WP theme list --format=table"
```

Note the active theme and whether it is a parent or child theme.

---

### Check 6: Cron Health

```bash
bash -c "$WP cron event list --format=table"
bash -c "$WP eval \"echo defined('DISABLE_WP_CRON') ? 'DISABLED' : 'ENABLED';\""
```

Note if cron is disabled and if there are overdue events.

---

### Check 7: Filesystem

```bash
bash -c "$WP eval \"echo is_writable(ABSPATH . 'wp-content/uploads') ? 'OK' : 'NOT WRITABLE';\""
```

Note whether the uploads directory is writable.

---

### Check 8: Error Log

Tail the last 50 lines of the debug log. The approach depends on environment type:

**Native:**
```bash
bash -c "tail -50 $(bash -c \"$WP eval \\\"echo ABSPATH;\\\"\")/wp-content/debug.log 2>/dev/null || echo 'No debug.log found'"
```

**Docker:**
```bash
bash -c "$WP eval \"echo ABSPATH;\"" # get the path inside the container
# Then use the container name from the wrapper to read the log:
bash -c "docker exec <container> tail -50 /var/www/html/wp-content/debug.log 2>/dev/null || echo 'No debug.log found'"
```

Extract the container name from `$WP` (the word after `docker exec`).

**DDEV:**
```bash
bash -c "ddev exec tail -50 /var/www/html/wp-content/debug.log 2>/dev/null || echo 'No debug.log found'"
```

**Lando:**
```bash
bash -c "lando ssh -c 'tail -50 /app/wp-content/debug.log 2>/dev/null || echo No debug.log found'"
```

If no log file exists, note this as informational (not an error).

## Step 2: Issue-Specific Diagnostics

If the user provided an issue description (the command argument), scan it for keywords and run the corresponding extra checks. If no description was given, skip this step.

| Keywords | Extra Checks |
|----------|-------------|
| "white screen", "WSOD", "blank" | Read the last 100 lines of `debug.log`. Test with default theme: `bash -c "$WP theme activate twentytwentyfour"` (ask user first). Try disabling all plugins: `bash -c "$WP plugin deactivate --all"` (ask user first). |
| "slow", "performance", "timeout" | Count transients: `bash -c "$WP transient list --format=count"`. Check autoloaded options size: `bash -c "$WP db query \"SELECT SUM(LENGTH(option_value)) as size FROM $(bash -c \"$WP db prefix\")options WHERE autoload='yes';\" --skip-column-names"`. Count active plugins: `bash -c "$WP plugin list --status=active --format=count"`. |
| "login", "redirect", "cookies" | Check URL mismatch: compare `siteurl` vs `home` from Step 1. Check cookie path: `bash -c "$WP config get COOKIE_DOMAIN 2>/dev/null || echo 'not set'"`. Check for `.htaccess` redirect rules: `bash -c "grep -i redirect .htaccess 2>/dev/null || echo 'No .htaccess redirects'"`. |
| "media", "upload", "image" | Check upload dir permissions: `bash -c "ls -la $(bash -c \"$WP eval \\\"echo wp_upload_dir()['basedir'];\\\"\")"`. Check max upload size: `bash -c "$WP eval \"echo ini_get('upload_max_filesize');\""`. Check GD/Imagick: `bash -c "$WP eval \"echo extension_loaded('gd') ? 'GD: yes' : 'GD: no'; echo extension_loaded('imagick') ? ' Imagick: yes' : ' Imagick: no';\""`. |
| "404", "permalink", "not found" | Flush rewrite rules: `bash -c "$WP rewrite flush"`. Check permalink structure: `bash -c "$WP option get permalink_structure"`. Check server config for rewrite support (Nginx: check for `try_files`; Apache: check `mod_rewrite` and `.htaccess`). |
| "email", "mail", "smtp" | Test email sending: `bash -c "$WP eval \"var_dump(wp_mail('test@example.com', 'WP Debug Test', 'Testing mail from wp-debug'));\""`. Check if Mailpit is running (Docker): `bash -c "curl -s http://localhost:8025/api/v1/messages 2>/dev/null | head -1 || echo 'Mailpit not reachable'"`. Check for mail plugins: `bash -c "$WP plugin list --format=table" | grep -i mail`. |
| "SSL", "https", "mixed content", "certificate" | Check URL options for http vs https: compare `siteurl` and `home` from Step 1. Suggest search-replace if needed: `bash -c "$WP search-replace 'http://' 'https://' --dry-run --report-changed-only"`. Check certificate validity (native): `bash -c "openssl s_client -connect <domain>:443 -servername <domain> </dev/null 2>/dev/null | openssl x509 -noout -dates"`. |

Multiple keyword matches are allowed — run all matching extra checks.

## Step 3: Analyze & Report

Present all findings in a structured report:

```
=== WP Debug Report ===

WordPress: 6.7.1 | PHP: 8.3.6 | Memory: 256M
Environment: Docker (docker exec my-project-wp wp --allow-root)

--- Core Health ---
[PASS] Core version: 6.7.1
[PASS] Checksum verification passed
[PASS] PHP version: 8.3.6
[WARN] Memory limit: 128M (recommended: 256M)

--- Debug Config ---
[INFO] WP_DEBUG: false
[INFO] WP_DEBUG_LOG: false
[INFO] WP_DEBUG_DISPLAY: false

--- Database ---
[PASS] All tables OK
[PASS] siteurl: https://my-project.local.com
[PASS] home: https://my-project.local.com
[PASS] URLs match

--- Plugins ---
[INFO] 5 active, 1 inactive, 0 must-use
[WARN] 2 plugins have updates available

--- Theme ---
[INFO] Active: my-project (parent)

--- Cron ---
[PASS] WP-Cron enabled
[WARN] 3 overdue cron events

--- Filesystem ---
[PASS] wp-content/uploads is writable

--- Error Log ---
[INFO] No debug.log found (WP_DEBUG_LOG is disabled)

--- Issue-Specific: "slow page loads" ---
[INFO] Transients: 142
[WARN] Autoloaded options: 2.4 MB (high — over 1 MB)
[INFO] Active plugins: 5

=== Summary ===
2 warnings found. Suggested actions below.
```

Use `[PASS]` for healthy items, `[WARN]` for potential issues, `[FAIL]` for definite problems, and `[INFO]` for informational items.

## Step 4: Fix Actions

For each warning or failure found, propose a specific fix. **Ask the user to confirm before running each fix.** Use AskUserQuestion to get confirmation.

Present fixes one at a time. After each fix, re-run the relevant check to verify it worked.

### Available Fixes

**Enable debug mode** (when WP_DEBUG is off and issues are reported):
```bash
bash -c "$WP config set WP_DEBUG true --raw"
bash -c "$WP config set WP_DEBUG_LOG true --raw"
bash -c "$WP config set WP_DEBUG_DISPLAY false --raw"
```

**Fix URL mismatch** (when siteurl and home differ or are wrong):
```bash
bash -c "$WP option update siteurl 'https://<correct-domain>'"
bash -c "$WP option update home 'https://<correct-domain>'"
```

**Increase memory limit** (when below 256M):
```bash
bash -c "$WP config set WP_MEMORY_LIMIT '256M'"
```

**Disable a problem plugin** (when a specific plugin is causing issues):
```bash
bash -c "$WP plugin deactivate <slug>"
```

**Reset permalinks** (when 404 errors on pages/posts):
```bash
bash -c "$WP rewrite flush"
```

**Fix file permissions** (when uploads directory is not writable):
```bash
bash -c "bin/wp-env-setup.sh permissions --path=<project-path> --web-user=<web-user>"
```
Where `<web-user>` is `nginx`, `www-data`, or `apache` depending on the environment.

**Clear cache and transients** (when stale data or performance issues):
```bash
bash -c "$WP cache flush"
bash -c "$WP transient delete --all"
```

**Fix mixed content / SSL** (when http:// URLs found in https:// site):
```bash
bash -c "$WP search-replace 'http://<domain>' 'https://<domain>' --all-tables --report-changed-only"
```

After all confirmed fixes are applied, print a final summary of what was changed.
