---
name: wp-environments
description: Detects the local tooling with the bundled wp-env-setup.sh, reads the .wp-create.json manifest through wp-config.mjs (environment.type and environment.engine, the wp_cli.wrapper every WP-CLI call runs through, the database password kept in .wp-create.local.json), fills the placeholders in the native and Docker .tpl templates, and resolves port and PHP-version conflicts for a local WordPress site on native, docker-compose, DDEV, Lando or wp-env. Use when /wp-create or /wp-adopt sets up a local WordPress site, when choosing or reading the WP-CLI wrapper for one, when a WordPress docker compose or wp-env port is already taken, or when listing or installing PHP versions for a local WordPress site. Not for deploying to a server, or for containerizing an app that is not WordPress.
user-invocable: false
---

# WordPress Environment Detection & Configuration

How a local WordPress site's environment is detected, recorded in `.wp-create.json`, and
turned into config files — and how every later command reaches WP-CLI through it.

## 1. Environment Detection

Run the detection script — run it, do not reimplement it. It needs no sudo, prints JSON on
stdout and exits 0; an unknown subcommand prints the usage and exits 1:

```bash
bash -c "${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh detect"
```

The top-level keys are `os`, `package_manager`, `web_servers` (`nginx`, `apache`, `caddy`),
`php` (`versions`, `active`, `extensions`), `docker` (`installed`, `version`, `compose`),
`tools` (`ddev`, `lando`, `wp-env`, `wp-cli`) and `database` (`mariadb`, `mysql`). A tool that
is absent still carries every key, with an empty version — test `installed`, never the
presence of `version`:

```json
"caddy": { "installed": false, "version": "", "running": false }
```

`php.versions` lists the versions installed under `/etc/php/` (Debian, Ubuntu) or through
Homebrew; anywhere else it holds only the active one.

### The other subcommands

The script does the root-level writes too. Every subcommand except `detect` and `php-list`
needs sudo, and each one prints its usage line and exits `1` when a required flag is missing:

| Subcommand | Flags | Does |
|---|---|---|
| `detect` | | The JSON above |
| `php-list` | `[--json]` | Installed PHP versions (section 6) |
| `php-install` | `--version=8.3` | Installs a PHP version and its extensions (section 6) |
| `native-setup` | `--domain=`, `--document-root=`, `--web-server=nginx\|apache\|caddy`, `[--vhost-src=/tmp/x.conf]`, `[--no-ssl]` | Certificate, hosts entry, vhost, reload |
| `native-remove` | `--domain=`, `[--web-server=]` | Removes the certificate, hosts entry and vhost |
| `vhost-install` | `--src=`, `--dest=` | Installs a generated vhost with its mode, owner and SELinux context |
| `ssl-generate` | `--domain=` | A self-signed certificate |
| `hosts-add`, `hosts-remove` | `--domain=` | The `/etc/hosts` entry |
| `permissions` | `--path=`, `[--web-user=]` | WordPress file and directory permissions |
| `service-reload` | `--service=` | Reloads the web server |

**A generated vhost goes in through `native-setup --vhost-src` or `vhost-install`, never
`sudo mv` or `sudo cp`.** On an SELinux host a file moved out of `/tmp` keeps its `user_tmp_t`
label, nginx and Apache cannot read it, and the reload fails with `(13: Permission denied)`;
`vhost-install` runs `restorecon`. Caddy has no `--vhost-src`: its block is appended to the
Caddyfile by hand.

## 2. Project Manifest: `.wp-create.json`

`/wp-create` writes `.wp-create.json` at the project root (its Step 5 holds the full shape),
and `bin/wp-config.mjs` is the single definition of a valid one. The fields this skill reads:

```json
{
  "project":     { "slug": "my-project", "domain": "my-project.local.com", "path": "/var/www/html/my-project" },
  "environment": { "type": "docker", "engine": "docker-compose", "web_server": "nginx", "php_version": "8.3" },
  "database":    { "name": "wp_my_project", "user": "root", "host": "db" },
  "theme":       { "slug": "my-project" },
  "wp_cli":      { "wrapper": "docker exec my-project-wp wp --allow-root", "path_flag": "" }
}
```

- `environment.type` is `native` or `docker` — `docker` for every container engine.
- `environment.engine` names the engine: `native`, `docker-compose`, `ddev`, `lando` or
  `wp-env`. Commands branch on this one, not on `type`: store profiles (`/wp-create` with a
  `woo-*` profile, `/wp-woo-setup`, `bin/store-kit-sync.sh`) need `native`, and stop on
  anything else.

Read a value through the validator, not with `jq`:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs get '${PROJECT_PATH}' wp_cli.wrapper"
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` is: it is
the directory holding `.wp-create.json`, and you substitute the real path yourself, because
inside the double quotes an unset one expands to nothing. `get` exits `0` with the value, `1`
for an unknown key or a missing value, and `3` when there is no manifest.

If `.wp-create.json` does not exist, the commands' gate (`wp-config.mjs validate`) exits `3`:
the project was not created by `/wp-create`. Most commands stop there; a site that already
runs and only needs registering goes through `/wp-adopt`, which writes the manifest.

## 3. The WP-CLI Wrapper

`wp_cli.wrapper` is how WP-CLI runs against this site: `wp --path=…` on a native install,
`docker exec <slug>-wp wp --allow-root`, `ddev wp`, `lando wp` or `npx wp-env run cli wp` in
a container. `/wp-create` chooses it and writes it; everything else reads it with `get`
above and prefixes every `wp` command with it (`$WP` throughout this plugin):

```bash
$WP core version
$WP option update blogname "My Site"
```

Never hardcode the execution method. Always read it from the manifest.

## 4. Template Placeholder Replacement

All template files (`.tpl` extension) use `{{placeholder}}` syntax, replaced by plain string
substitution:

1. Read the `.tpl` file.
2. Replace every `{{placeholder}}` with its value from the table below.
3. Write the result to the final config path, without the `.tpl` extension.

The templates live in `${CLAUDE_PLUGIN_ROOT}/templates/native/` and
`${CLAUDE_PLUGIN_ROOT}/templates/docker/` (including the dot-files `.wp-env.json.tpl`,
`.lando.yml.tpl` and `.ddev/`). A file written with a `{{…}}` token still in it is broken —
docker compose and wp-env refuse it — so every token below is replaced, and these are all the
tokens the templates use:

| Placeholder | Source | Example |
|-------------|--------|---------|
| `{{domain}}` | `project.domain` | `my-project.local.com` |
| `{{document_root}}` | `project.path` | `/var/www/html/my-project` |
| `{{project_name}}` | `project.slug` | `my-project` |
| `{{theme_slug}}` | `theme.slug` | `my-project` |
| `{{php_version}}` | `environment.php_version` | `8.3` |
| `{{web_server}}` | `environment.web_server` | `nginx` |
| `{{db_name}}` | `database.name` | `wp_my_project` |
| `{{db_user}}` | `database.user` | `root` |
| `{{db_password}}` | **Not a manifest field.** `bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs get '${PROJECT_PATH}' db_password"` | generated per project, never a fixed default |
| `{{ssl_cert}}` | Derived: `/etc/ssl/certs/<domain>.crt` | |
| `{{ssl_key}}` | Derived: `/etc/ssl/private/<domain>.key` | |
| `{{php_fpm_sock}}` | Derived: `/var/run/php/php<php_version>-fpm.sock` | |
| `{{web_user}}` | Derived from the OS: `nginx` (Fedora/RHEL with nginx), `apache` (Fedora/RHEL with Apache), `www-data` (Debian/Ubuntu) | |
| `{{max_upload_size}}` | `1024M` unless the user asks otherwise; nginx templates only | `1024M` |
| `{{http_port}}` | Host port for HTTP: docker compose and wp-env (see section 5) | `80`, wp-env `8888` |
| `{{https_port}}` | Host port for HTTPS, docker compose | `443` |
| `{{tests_port}}` | wp-env's tests site | `8889` |
| `{{phpmyadmin_port}}` | docker compose | `8080` |
| `{{mailpit_port}}` | Mailpit's web UI, docker compose | `8025` |
| `{{mailpit_smtp_port}}` | Mailpit's SMTP, docker compose | `1025` |

The database password is the one value not read from `.wp-create.json`: it lives in the
gitignored `.wp-create.local.json`, and the only supported way to read it is
`wp-config.mjs get '${PROJECT_PATH}' db_password`, which resolves environment → local file →
manifest and warns when the last rung wins. Read straight out of the manifest it comes back
empty, or as a stale legacy value on a project that kept one there.

## 5. Docker Port Conflict Detection

Before starting containers, check only the host ports the templates publish. The database
is not one of them — `docker-compose.yml.tpl` publishes no port for `db` — so a native
MariaDB on 3306 is not a conflict.

| Port | Placeholder | Template |
|---|---|---|
| 80 | `{{http_port}}` | `docker-compose.yml.tpl` |
| 443 | `{{https_port}}` | `docker-compose.yml.tpl` |
| 8080 | `{{phpmyadmin_port}}` | `docker-compose.yml.tpl` |
| 8025 | `{{mailpit_port}}` | `docker-compose.yml.tpl` |
| 1025 | `{{mailpit_smtp_port}}` | `docker-compose.yml.tpl` |
| 8888 | `{{http_port}}` | `.wp-env.json.tpl` |
| 8889 | `{{tests_port}}` | `.wp-env.json.tpl` |

```bash
# Linux (docker compose; for wp-env check 8888 and 8889 instead)
ss -tlnp | grep -E ':(80|443|8080|8025|1025) '
# macOS or fallback
lsof -i :80 -i :443 -i :8080 -i :8025 -i :1025
```

A port in use gets the next free alternative (8081 for 8080, 8444 for 443), substituted into
its placeholder; stop the service holding it only when the user asks. No manifest field holds
a port: the generated `docker-compose.yml` or `.wp-env.json` is the record, so read the port
back from there.

## 6. PHP Version Management

### Native

Run the script; do not type the package names yourself — they differ per OS and the script
already carries them, with the extensions WordPress needs (`cli fpm mysql curl mbstring xml
gd zip intl`):

```bash
bash -c "${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh php-list"                  # installed versions, no sudo
bash -c "${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh php-install --version=8.3" # needs sudo
```

`php-list` lists the versions already **installed** (`/etc/php/*/` on Debian and Ubuntu,
Homebrew on macOS); anywhere else, Fedora included, it prints only the active one. It shows
nothing that is merely available to install. `php-install` exits `1` without `--version` and
on an unsupported OS. On Debian and Ubuntu it adds the `ondrej/php` PPA first; on Fedora it
installs `php83` and its `php83-*` packages, falling back to the Remi naming. Switching the
CLI version is not scripted: on Debian and Ubuntu it is
`sudo update-alternatives --set php /usr/bin/php8.3`.

### Containers

No system PHP is involved. The version comes from `environment.php_version` through
`{{php_version}}`: the `wordpress:php{{php_version}}-fpm` image tag in
`docker-compose.yml.tpl`, `php_version` in `.ddev/config.yaml`, `php` in `.lando.yml`,
`phpVersion` in `.wp-env.json`. To change it, change the manifest value and regenerate the
file from its template.

## 7. Adopt Mode

Two different things share the word "adopt". `/wp-create`'s Adopt Mode **reconfigures** an
existing install into a `/wp-create` environment: vhost, SSL, hosts entry, options.
`/wp-adopt` (`bin/wp-config.mjs adopt`) only **registers** a site: it runs a read-only probe
and writes the manifest with `"origin": "adopted"`. Use it for a site that is already served
and only needs auditing, debugging or cloning into.

`/wp-create` enters Adopt Mode when the target path already holds a `wp-config.php`. The
procedure — what it skips, what it reads from the existing install, the multisite refusal —
is `commands/wp-create.md`'s "Adopt Mode" section; follow it there.
