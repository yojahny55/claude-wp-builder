---
description: Create a complete WordPress local development environment — download, configure, and set up database, web server, SSL, plugins
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "--path=/var/www/html/my-project"
---

# WP Create — Environment Setup Orchestrator

Create a full local WordPress development environment: detect available tools, download WordPress, create the database, configure the web server, install plugins, and generate the `.wp-create.json` manifest. Supports native (Nginx/Apache/Caddy), Docker, DDEV, Lando, and wp-env environments.

**`$WP` convention:** Throughout this command, `$WP` refers to the WP-CLI wrapper determined by the chosen environment. For native installs it is `wp --path=<path>`, for Docker it is `docker exec <container> wp --allow-root`, for DDEV it is `ddev wp`, for Lando it is `lando wp`, for wp-env it is `npx wp-env run cli wp`. Substitute the correct wrapper in every WP-CLI command below.

---

## Step 0: Parse Arguments

Extract the `--path=` value from `$ARGUMENTS`.

- If `$ARGUMENTS` contains `--path=<value>`, use `<value>` as the target project path.
- If `$ARGUMENTS` is a bare path (no flag), treat it as the target path.
- If no path is provided, ask the user:
  > "Where should the WordPress project be created? Provide an absolute path (e.g., /var/www/html/my-project):"
- Resolve the path to an absolute path.
- Store it as `PROJECT_PATH` for use in all subsequent steps.

---

## Step 1: Environment Detection

Run the detection script to discover what tools are available on the system.

```bash
bash -c "${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh detect"
```

Parse the JSON output. The structure is:

```json
{
  "os": "fedora",
  "package_manager": "dnf",
  "web_servers": {
    "nginx": { "installed": true, "version": "1.24.0", "running": true },
    "apache": { "installed": true, "version": "2.4.58", "running": false },
    "caddy": { "installed": false }
  },
  "php": {
    "versions": ["8.2", "8.3"],
    "active": "8.3",
    "extensions": ["mysql", "curl", "mbstring", "xml", "gd", "zip", "intl"]
  },
  "docker": {
    "installed": true,
    "version": "24.0.7",
    "compose": true
  },
  "tools": {
    "ddev": { "installed": false },
    "lando": { "installed": false },
    "wp-env": { "installed": false },
    "wp-cli": { "installed": true, "version": "2.9.0" }
  },
  "database": {
    "mariadb": { "installed": true, "version": "10.11", "running": true },
    "mysql": { "installed": false }
  }
}
```

Present the findings clearly:

```
=== Environment Detection ===
  OS:            Fedora (dnf)
  Web servers:   Nginx 1.24.0 (running), Apache 2.4.58 (stopped)
  PHP:           8.3 (active), 8.2 (available)
  Docker:        24.0.7 with Compose
  DDEV:          not installed
  Lando:         not installed
  wp-env:        not installed
  WP-CLI:        2.9.0
  Database:      MariaDB 10.11 (running)
```

Let the user choose their environment type, or auto-select the best option based on what is available. The environment types are:

| Type | Requires |
|------|----------|
| Native (Nginx) | Nginx + PHP-FPM + MariaDB/MySQL + WP-CLI |
| Native (Apache) | Apache + PHP + MariaDB/MySQL + WP-CLI |
| Native (Caddy) | Caddy + PHP-FPM + MariaDB/MySQL + WP-CLI |
| Docker (own templates) | Docker + Docker Compose |
| DDEV | Docker + DDEV |
| Lando | Docker + Lando |
| wp-env | Docker + Node.js + @wordpress/env |

Only offer environment types whose prerequisites are met. If only one viable option exists, auto-select it and inform the user.

---

## Step 2: Check for Existing Install & Manifest

### 2a: Check for existing `wp-config.php` (Adopt Mode)

```bash
bash -c "test -f '${PROJECT_PATH}/wp-config.php' && echo 'EXISTS' || echo 'NOT_FOUND'"
```

If `wp-config.php` exists at `PROJECT_PATH`, enter **Adopt Mode** (see the full Adopt Mode section below). This skips WordPress download, database creation, config creation, and core install.

### 2b: Check for existing `.wp-create.json`

```bash
bash -c "test -f '${PROJECT_PATH}/.wp-create.json' && echo 'EXISTS' || echo 'NOT_FOUND'"
```

If `.wp-create.json` already exists, see the **Existing `.wp-create.json` Handling** section below.

---

## Step 3: Configuration Collection

Gather all configuration values from the user. For each field, provide a sensible default derived from the project path and detected environment.

### 3.1 Project Name

- Default: derived from the folder name at `PROJECT_PATH` (e.g., `/var/www/html/my-project` -> `My Project`)
- Let the user edit

### 3.2 Project Slug

- Auto-generated from project name: lowercase, hyphens for spaces, strip special characters
- Used for theme directory, container names, database name

### 3.3 Domain

- Default: `<slug>.local.com` (e.g., `my-project.local.com`)
- Let the user customize

### 3.4 Web Server

- From detected options in Step 1
- If Docker/DDEV/Lando/wp-env selected, offer Nginx or Apache as the container web server
- Recommend Nginx as default

### 3.5 PHP Version

- List available versions from detection
- Recommend the latest stable version (currently 8.3)
- For Docker environments: maps to the PHP image tag
- For native environments: must be installed on the system

### 3.6 Database Credentials

- **DB name:** default `wp_<slug_with_underscores>` (e.g., `wp_my_project`)
- **DB user:** default `root`
- **DB password:** default `root`
- **DB host:** default `localhost` for native, `db` for Docker

### 3.7 Plugin Profile

Discover available profiles:

1. **Built-in profiles:** Read JSON files from `${CLAUDE_PLUGIN_ROOT}/templates/profiles/`
2. **Project-local custom profiles:** Glob `.wp-profiles/*.json` in `PROJECT_PATH`
3. **Global custom profiles:** Glob `~/.wp-profiles/*.json`

Present all discovered profiles:

```
=== Plugin Profiles ===
  [1] starter — Minimal setup (SCF, Yoast SEO, WP Fastest Cache)
  [2] full — Production-ready stack (SCF, Yoast, WP Super Cache, Wordfence, CF7, WP Mail SMTP, Redirection, Site Kit)
  [3] agency (custom: ~/.wp-profiles/agency.json) — Agency starter pack
  [4] none — No plugins
```

Let the user select a profile. Read the chosen JSON file to get the list of plugin slugs.

Profile JSON format:

```json
{
  "name": "Starter",
  "description": "Minimal setup for custom theme development",
  "plugins": [
    { "slug": "secure-custom-fields", "required": true },
    { "slug": "wordpress-seo", "required": false },
    { "slug": "wp-fastest-cache", "required": false }
  ]
}
```

### 3.8 Languages

- **Primary language:** default `en`
- **Additional languages:** default `es` (comma-separated if multiple)

### 3.9 Admin Credentials

- **Admin user:** default `webmaster`
- **Admin password:** default `webmaster`
- **Admin email:** default `webmaster@local.com`

### 3.10 Summary & Confirmation

Present all collected values:

```
=== WordPress Project Configuration ===
  Project name:    My Project
  Slug:            my-project
  Domain:          my-project.local.com
  Path:            /var/www/html/my-project
  Environment:     Docker (docker-compose)
  Web server:      Nginx
  PHP version:     8.3
  Database:        wp_my_project (root/root @ db)
  Plugin profile:  starter (SCF, Yoast SEO, WP Fastest Cache)
  Languages:       en (primary), es
  Admin:           webmaster / webmaster

Proceed? (Y/n)
```

Wait for user confirmation before proceeding to execution.

---

## Step 4: Execution

Execute all 14 steps in order. Each step validates its result before proceeding. Set up the `$WP` wrapper variable based on the chosen environment:

| Environment | `$WP` value |
|-------------|-------------|
| Native | `wp --path=${PROJECT_PATH}` |
| Docker | `docker exec ${SLUG}-wp wp --allow-root` |
| DDEV | `ddev wp` |
| Lando | `lando wp` |
| wp-env | `npx wp-env run cli wp` |

### Step 4.1: Create Directory Structure

```bash
bash -c "mkdir -p '${PROJECT_PATH}/wp-content/themes' '${PROJECT_PATH}/wp-content/plugins' '${PROJECT_PATH}/wp-content/uploads'"
```

**Validation:** Verify the directories exist.

### Step 4.2: Download WordPress

```bash
bash -c "$WP core download --version=latest --path='${PROJECT_PATH}'"
```

For Docker environments where WP-CLI runs inside the container, download WordPress into the bind-mounted path or use the container's entrypoint to handle it.

**Validation:** Check that `${PROJECT_PATH}/wp-load.php` exists after download.

**On failure:** See Failure Handling table.

### Step 4.3: Generate Environment Config from Templates

Read the appropriate template from `${CLAUDE_PLUGIN_ROOT}/templates/` and replace all `{{placeholder}}` values.

| Environment | Template(s) |
|-------------|------------|
| Docker (own) | `templates/docker/docker-compose.yml.tpl` |
| DDEV | `templates/docker/.ddev/config.yaml.tpl` |
| Lando | `templates/docker/.lando.yml.tpl` |
| wp-env | `templates/docker/.wp-env.json.tpl` |
| Native (Nginx) | `templates/native/nginx.conf.tpl` or `nginx-no-ssl.conf.tpl` |
| Native (Apache) | `templates/native/apache.conf.tpl` or `apache-no-ssl.conf.tpl` |
| Native (Caddy) | `templates/native/Caddyfile.tpl` |

Common placeholders to replace:

| Placeholder | Value |
|-------------|-------|
| `{{domain}}` | The configured domain |
| `{{document_root}}` | `PROJECT_PATH` |
| `{{php_version}}` | The chosen PHP version |
| `{{db_name}}` | Database name |
| `{{db_user}}` | Database user |
| `{{db_password}}` | Database password |
| `{{db_host}}` | Database host |
| `{{project_name}}` | Project slug |
| `{{ssl_cert}}` | `/etc/ssl/certs/<domain>.crt` |
| `{{ssl_key}}` | `/etc/ssl/private/<domain>.key` |
| `{{php_fpm_sock}}` | `/var/run/php/php<version>-fpm.sock` |
| `{{web_user}}` | `nginx`, `www-data`, or `apache` (from detection) |
| `{{phpmyadmin_port}}` | Default 8080 (check availability) |
| `{{mailpit_port}}` | Default 8025 (check availability) |
| `{{container_prefix}}` | Project slug |

Write the generated config to the appropriate location:
- Docker: `${PROJECT_PATH}/docker-compose.yml`
- DDEV: `${PROJECT_PATH}/.ddev/config.yaml`
- Lando: `${PROJECT_PATH}/.lando.yml`
- wp-env: `${PROJECT_PATH}/.wp-env.json`
- Native: write to a temp file, then install via `bin/wp-env-setup.sh native-setup`

**Port management (Docker):** Before writing the config, check if default ports (80, 443, 3306, 8080, 8025) are in use:

```bash
bash -c "ss -tlnp 2>/dev/null | grep -E ':(80|443|3306|8080|8025) ' || echo 'all-clear'"
```

If ports are occupied, auto-assign alternatives (e.g., 8081, 8444, 33060) and update the template values accordingly. Store assigned ports in the manifest.

**Validation:** Verify the config file was written.

### Step 4.4: Create Database

**Native environments:**

```bash
bash -c "$WP db create"
```

**Docker environments:** The database is created automatically by the MariaDB/MySQL container. Skip this step but verify the DB container starts successfully in Step 4.8.

**DDEV/Lando/wp-env:** These tools handle database creation. Skip this step.

**On failure:** See Failure Handling table.

### Step 4.5: Configure WordPress

```bash
bash -c "$WP config create --dbname='${DB_NAME}' --dbuser='${DB_USER}' --dbpass='${DB_PASSWORD}' --dbhost='${DB_HOST}'"
```

For Docker environments, run this inside the container after it starts (move after Step 4.8 if needed), or pre-generate `wp-config.php` from a template.

**Validation:** Check that `${PROJECT_PATH}/wp-config.php` exists and contains the correct DB credentials.

**On failure:** See Failure Handling table.

### Step 4.6: SSL Certificate (Native Only)

```bash
bash -c "sudo ${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh ssl-generate --domain='${DOMAIN}'"
```

Skip for Docker environments (handle SSL in the container config or use HTTP only for local dev).

Skip for Caddy (handles SSL natively/automatically).

**Validation:** Check that the cert and key files exist at the expected paths.

### Step 4.7: Hosts Entry (Native Only)

```bash
bash -c "sudo ${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh hosts-add --domain='${DOMAIN}'"
```

Skip for Docker environments that use `localhost` or handle their own DNS (DDEV, Lando).

**Validation:** Verify `/etc/hosts` contains the domain entry.

### Step 4.8: Start Services

**Docker (own templates):**

```bash
bash -c "cd '${PROJECT_PATH}' && docker-compose up -d"
```

**DDEV:**

```bash
bash -c "cd '${PROJECT_PATH}' && ddev start"
```

**Lando:**

```bash
bash -c "cd '${PROJECT_PATH}' && lando start"
```

**wp-env:**

```bash
bash -c "cd '${PROJECT_PATH}' && npx wp-env start"
```

**Native:**

```bash
bash -c "sudo ${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh service-reload"
```

**Validation:** Verify services are running:
- Docker: `docker-compose ps` shows all containers as "Up"
- DDEV: `ddev describe` shows project running
- Lando: `lando info` shows app running
- Native: web server and PHP-FPM are running

**On failure (Docker port conflict):** See Failure Handling table.

### Step 4.9: Install WordPress

```bash
bash -c "$WP core install --url='${URL}' --title='${PROJECT_NAME}' --admin_user='${ADMIN_USER}' --admin_password='${ADMIN_PASSWORD}' --admin_email='${ADMIN_EMAIL}'"
```

Where `URL` is `https://${DOMAIN}` (or `http://${DOMAIN}` if no SSL).

**Validation:** Check exit code and verify: `$WP option get siteurl` returns the expected URL.

**On failure:** See Failure Handling table.

### Step 4.10: Install Plugin Profile

If a plugin profile was selected (not "none"):

```bash
bash -c "$WP plugin install secure-custom-fields wordpress-seo wp-fastest-cache --activate"
```

Use the actual plugin slugs from the selected profile JSON.

**Validation:** `$WP plugin list --status=active --format=json` includes all expected plugins.

**On failure (plugin not found):** Warn about the missing plugin, skip it, continue with the rest. Do NOT abort the entire process for a missing plugin.

### Step 4.11: Set Permalinks

```bash
bash -c "$WP rewrite structure '/%postname%/'"
```

**Validation:** `$WP option get permalink_structure` returns `/%postname%/`.

### Step 4.12: Clean Defaults

Remove default WordPress content:

```bash
bash -c "$WP post delete 1 --force"
bash -c "$WP post delete 2 --force"
bash -c "$WP comment delete 1 --force"
```

These may fail silently if the defaults were already removed — that is fine.

### Step 4.13: Set Options

```bash
bash -c "$WP option update default_comment_status closed"
```

### Step 4.14: Install Languages (if non-English)

For each additional language:

```bash
bash -c "$WP language core install es"
```

If the primary language is not English:

```bash
bash -c "$WP site switch-language ${PRIMARY_LANG}"
```

---

## Failure Handling

Each step validates before proceeding. On failure:

| Step | Failure | Action |
|------|---------|--------|
| Download WP (4.2) | Network error, disk full | Abort. Show the error message. Suggest: "Check your internet connection and disk space, then re-run `/wp-create`." |
| DB create (4.4) | Server not running, permissions | Abort. Suggest: "Start your database server (`sudo systemctl start mariadb`) or check credentials." |
| Config create (4.5) | File write permissions | Abort. Suggest: "Fix path permissions: `sudo chown -R $USER:$USER ${PROJECT_PATH}`" |
| Docker up (4.8) | Port conflict | Detect which ports are in use with `ss -tlnp`. Offer alternative ports. Update `docker-compose.yml` with new ports. Retry `docker-compose up -d`. Update manifest with actual ports. |
| Core install (4.9) | DB connection refused | Check if services are running. For Docker: `docker-compose ps`. For native: `systemctl status mariadb`. Suggest fix and offer retry. |
| Plugin install (4.10) | Plugin not found in WP.org repo | Warn: "Plugin '<slug>' not found — skipping." Continue with remaining plugins. Do not abort. |

**Critical vs non-critical:**
- Steps 4.1-4.9 are **critical** — failure aborts the process.
- Steps 4.10-4.14 are **non-critical** — failure warns but continues.

**Partial state on failure:** On any critical failure, leave partial state in place for debugging. The `.wp-create.json` manifest is NOT generated until all critical steps succeed. The user can re-run `/wp-create` on the same path to retry — idempotent steps detect existing state and skip (e.g., if WordPress is already downloaded, skip download; if DB already exists, skip create).

---

## Adopt Mode

When `wp-config.php` is detected at `PROJECT_PATH` in Step 2a, enter Adopt Mode.

### What to skip

- WordPress download (Step 4.2)
- Database creation (Step 4.4)
- WordPress config creation (Step 4.5)
- WordPress core install (Step 4.9)

### Extract config from existing install

Determine the correct `$WP` wrapper first. For an existing native install, use `wp --path=${PROJECT_PATH}`. For Docker, detect the running container.

Run these commands to extract the existing configuration:

```bash
bash -c "$WP config list --format=json"
```

Extract: DB credentials (dbname, dbuser, dbpass, dbhost), table prefix, debug settings.

```bash
bash -c "$WP core version"
```

Extract: WordPress version.

```bash
bash -c "$WP plugin list --format=json"
```

Extract: installed plugins and their statuses.

```bash
bash -c "$WP theme list --status=active --format=json"
```

Extract: active theme slug.

```bash
bash -c "$WP option get siteurl"
bash -c "$WP option get home"
```

Extract: current site URL.

```bash
bash -c "$WP eval 'echo PHP_VERSION;'"
```

Extract: PHP version.

### Populate manifest from extracted values

Use the extracted values to pre-fill the `.wp-create.json` manifest instead of collecting them from the user. Present the extracted config and let the user confirm or override values (especially domain, if they want to change it).

### Still execute these steps

- Environment config generation (vhost/Docker) — Step 4.3
- SSL certificate — Step 4.6 (native only)
- Hosts entry — Step 4.7 (native only)
- Start/reload services — Step 4.8
- Set permalinks — Step 4.11 (if not already set)
- Clean defaults — Step 4.12 (skip if content already exists)
- Set options — Step 4.13
- Install languages — Step 4.14

If the domain changes from the existing config, run search-replace:

```bash
bash -c "$WP search-replace '${OLD_DOMAIN}' '${NEW_DOMAIN}'"
```

### Edge case: Old WordPress version (< 5.0)

Check the extracted version. If it is below 5.0:

- Warn the user: "This WordPress installation is version X.Y, which is below 5.0. Some features may not work correctly."
- Offer to update: "Update to latest version? (Y/n)"
- If yes:

```bash
bash -c "$WP core update"
bash -c "$WP core update-db"
```

### Edge case: Multisite

Detect multisite:

```bash
bash -c "$WP config get MULTISITE 2>/dev/null || echo 'not-set'"
```

If MULTISITE is `true` or `1`:

- Abort with message: "Multisite installations are not supported by /wp-create. This tool is designed for single-site WordPress installs only."

---

## Existing `.wp-create.json` Handling

When `.wp-create.json` already exists at `PROJECT_PATH` (detected in Step 2b):

1. Read and display the existing manifest summary:

```
=== Existing .wp-create.json Found ===
  Project:      My Project
  Environment:  Docker (Nginx, PHP 8.3)
  Domain:       my-project.local.com
  Created:      2026-03-10
```

2. Offer three options:

```
What would you like to do?
  [1] Overwrite — Delete existing config and recreate from scratch
  [2] Update — Keep existing environment, update configuration only
  [3] Abort — Cancel and keep everything as-is
```

- **Overwrite:** Proceed with full setup as if `.wp-create.json` did not exist. The old manifest is backed up to `.wp-create.json.bak`.
- **Update:** Skip environment setup steps (4.1-4.8). Only re-run configuration steps: update plugins (4.10), update permalinks (4.11), update options (4.13), install new languages (4.14). Regenerate the manifest with updated values.
- **Abort:** Exit the command immediately.

---

## Step 5: Generate `.wp-create.json` Manifest

Only generate after all critical steps (4.1-4.9) succeed. Write the manifest to `${PROJECT_PATH}/.wp-create.json`.

```json
{
  "project": {
    "name": "<PROJECT_NAME>",
    "slug": "<SLUG>",
    "domain": "<DOMAIN>",
    "path": "<PROJECT_PATH>",
    "created": "<YYYY-MM-DD>"
  },
  "environment": {
    "type": "<docker|native>",
    "engine": "<docker-compose|ddev|lando|wp-env|native>",
    "web_server": "<nginx|apache|caddy>",
    "php_version": "<8.3>",
    "container_prefix": "<SLUG>"
  },
  "database": {
    "name": "<DB_NAME>",
    "user": "<DB_USER>",
    "password": "<DB_PASSWORD>",
    "host": "<DB_HOST>"
  },
  "wordpress": {
    "version": "latest",
    "admin_user": "<ADMIN_USER>",
    "admin_email": "<ADMIN_EMAIL>",
    "url": "<URL>",
    "permalink_structure": "/%postname%/"
  },
  "languages": {
    "primary": "<PRIMARY_LANG>",
    "additional": ["<ADDITIONAL_LANGS>"],
    "default": "<PRIMARY_LANG>"
  },
  "plugins": {
    "profile": "<PROFILE_NAME>",
    "installed": [
      "<plugin-slug-1>",
      "<plugin-slug-2>"
    ]
  },
  "theme": {
    "slug": "<SLUG>",
    "initialized": false
  },
  "wp_cli": {
    "wrapper": "<WP_CLI_WRAPPER>",
    "path_flag": "<PATH_FLAG_OR_EMPTY>"
  }
}
```

The `wp_cli.wrapper` value depends on the environment:

| Environment | `wp_cli.wrapper` |
|-------------|-----------------|
| Native | `wp --path=${PROJECT_PATH}` |
| Docker | `docker exec ${SLUG}-wp wp --allow-root` |
| DDEV | `ddev wp` |
| Lando | `lando wp` |
| wp-env | `npx wp-env run cli wp` |

The `wp_cli.path_flag` is set to `--path=${PROJECT_PATH}` for native installs and empty string for all containerized environments (the container already knows its path).

**Validation:** Read back the file and verify it is valid JSON.

---

## Step 6: Chain to `/wp-init`

After the manifest is written and validated, prompt the user:

> "WordPress environment is ready at ${URL}. Run /wp-init to scaffold your theme now? (Y/n)"

- If yes: invoke `/wp-init` — it will read `.wp-create.json` and skip redundant questions (project name, languages, domain are already known).
- If no: print a final summary and exit.

### Final Summary

```
=== WordPress Project Created ===
  Project:      <PROJECT_NAME>
  URL:          <URL>
  Admin:        <URL>/wp-admin (webmaster / webmaster)
  Path:         <PROJECT_PATH>
  Environment:  <ENV_TYPE> (<WEB_SERVER>, PHP <PHP_VERSION>)
  Database:     <DB_NAME>
  Plugins:      <PROFILE_NAME> (<count> plugins)
  Languages:    <PRIMARY> + <ADDITIONAL>
  Manifest:     <PROJECT_PATH>/.wp-create.json

Next steps:
  1. Run /wp-init to scaffold your theme
  2. Run /wp-demo to create a demo mockup
  3. Visit <URL>/wp-admin to verify the install
```
