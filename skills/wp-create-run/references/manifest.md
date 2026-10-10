# /wp-create — Step 5

`commands/wp-create.md` sends the run here at Step 5 (Generate `.wp-create.json` Manifest). Follow it in order; nothing in it is optional background.

## Contents

- The manifest shape
- Field rules
- Validation and exit codes

```json
{
  "manifest_version": 3,
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
    ],
    "resolved": [
      { "slug": "<plugin-slug-1>", "version": "<X.Y.Z>", "source": "wordpress.org", "active": true }
    ],
    "degraded": [
      { "slug": "<plugin-slug-2>", "reason": "not found in the WP.org repository" }
    ]
  },
  "theme": {
    "slug": "<SLUG>",
    "initialized": false
  },
  "wp_cli": {
    "wrapper": "<WP_CLI_WRAPPER>",
    "path_flag": "<PATH_FLAG_OR_EMPTY>"
  },
  "demo mode": "<craft|plain>",
  "i18n strategy": "<suffix|polylang>"
}
```

The database password is **not** in the manifest. Generate `DB_PASSWORD` and
`ADMIN_PASSWORD` as soon as Step 3 decides them, and **write them to
`${PROJECT_PATH}/.wp-create.local.json` immediately** — do not defer this to the
manifest step above, which is gated on all of Steps 4.1-4.9 succeeding. The
credentials are already in use before that gate closes (Step 4.3's
`{{db_password}}`, Step 4.9's `--admin_password`), and writing them early means a
retry after a later critical step fails re-reads the same values already baked
into the database and `wp-config.php`, instead of generating new ones that no
longer match:

```json
{ "database": { "password": "<DB_PASSWORD>" }, "wordpress": { "admin_password": "<ADMIN_PASSWORD>" } }
```

`${PROJECT_PATH}/.wp-create.local.json` — the project root, a sibling of
`.wp-create.json`, not a file inside the theme directory `/wp-init` scaffolds
later. `/wp-init` (Step 9.6) adds `.wp-create.local.json` to
`${PROJECT_PATH}/.gitignore` — the project root's own `.gitignore`, creating
that file if the root has none yet. That is a different repository from the
theme's own `.gitignore` (`/wp-init` Step 9.5, scoped to `<theme-dir>`), which
sits below the project root and cannot ignore a path that lives above it.

Read either value through the validator, which resolves environment → local file →
manifest and warns when it had to fall back to the manifest:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs get '${PROJECT_PATH}' db_password"
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

The gate below runs here, after the manifest exists, rather than before Step 1 — this
command's own job is to create the manifest it would otherwise be validating against.

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
