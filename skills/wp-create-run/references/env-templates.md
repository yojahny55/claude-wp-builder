# /wp-create — Step 4.3

`commands/wp-create.md` sends the run here at Step 4.3 (Generate Environment Config from Templates). Follow it in order; nothing in it is optional background.

## Contents

- The template per environment
- Placeholders and port assignment
- Validation

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
| `{{max_upload_size}}` | Default `1024M`. Nginx only — see note below |
| `{{phpmyadmin_port}}` | Default 8080 (check availability) |
| `{{mailpit_port}}` | Default 8025 (check availability) |
| `{{container_prefix}}` | Project slug |

**Upload size (`{{max_upload_size}}`):** nginx's `client_max_body_size` defaults to `1m`, which rejects plugin/theme zips and migration archives with a bare `413 Request Entity Too Large` — nginx returns it before PHP runs, so WordPress shows no error of its own and PHP's `upload_max_filesize` is irrelevant. Set it to `1024M` unless the user asks otherwise. Only the nginx templates need this: Apache's `LimitRequestBody` and Caddy's request body limit both default to unlimited.

Write the generated config to the appropriate location:
- Docker: `${PROJECT_PATH}/docker-compose.yml`
- DDEV: `${PROJECT_PATH}/.ddev/config.yaml`
- Lando: `${PROJECT_PATH}/.lando.yml`
- wp-env: `${PROJECT_PATH}/.wp-env.json`
- Native: write the generated config to a temp file (e.g., `/tmp/<domain>.conf`), then install via:
  ```bash
  sudo bin/wp-env-setup.sh native-setup \
       --domain=<domain> \
       --document-root=<path> \
       --web-server=nginx \
       --vhost-src=/tmp/<domain>.conf
  ```
  Passing `--vhost-src` triggers `vhost-install` internally, which atomically copies the file with correct mode/owner AND runs `restorecon` to apply the proper SELinux context. **Do NOT use `sudo mv` from `/tmp` to `/etc/nginx/conf.d/` directly** — on Fedora/RHEL/CentOS with SELinux enforcing, the file inherits `user_tmp_t` and nginx will fail to read it with `(13: Permission denied)` on reload.

  If `--vhost-src` is omitted, you can install the file later with:
  ```bash
  sudo bin/wp-env-setup.sh vhost-install --src=/tmp/<domain>.conf --dest=/etc/nginx/conf.d/<domain>.conf
  ```

**Port management (Docker):** Before writing the config, check if default ports (80, 443, 3306, 8080, 8025) are in use:

```bash
bash -c "ss -tlnp 2>/dev/null | grep -E ':(80|443|3306|8080|8025) ' || echo 'all-clear'"
```

If ports are occupied, auto-assign alternatives (e.g., 8081, 8444, 33060) and update the template values accordingly. Store assigned ports in the manifest.

**Validation:** Verify the config file was written.
