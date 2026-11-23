# /wp-create — Step 4.5

`commands/wp-create.md` sends the run here at Step 4.5 (Configure WordPress). Follow it in order; nothing in it is optional background.

```bash
bash -c "$WP config create --dbname='${DB_NAME}' --dbuser='${DB_USER}' --dbpass='${DB_PASSWORD}' --dbhost='${DB_HOST}'"
```

**Overwrite:** add `--force` (`wp-config.php` exists).

For Docker environments, run this inside the container after it starts (move after Step 4.8 if needed), or pre-generate `wp-config.php` from a template.

Then set the filesystem method so WordPress writes updates directly instead of prompting for FTP credentials:

```bash
bash -c "$WP config set FS_METHOD direct --type=constant"
```

`FS_METHOD direct` is correct for local development, where PHP runs as a user that owns (or has group write on) `wp-content`. Without it, WordPress falls back to asking for FTP credentials on every plugin/theme install. It depends on the permissions set in Step 4.15 — `direct` without write access turns the FTP prompt into a "could not create directory" error instead of fixing anything. Do not carry this constant to shared hosting where PHP runs as a different user than the file owner.

**Validation:** Check that `${PROJECT_PATH}/wp-config.php` exists and contains the correct DB credentials, and that `$WP config get FS_METHOD` returns `direct`.

Mark the site as local. WordPress reads an unset `WP_ENVIRONMENT_TYPE` as `production`, and
store setup keys its test-only behaviour — cash on delivery for the automated test order, a
visible storefront — on this value:

```bash
bash -c "$WP config set WP_ENVIRONMENT_TYPE local --type=constant"
```

**Validation:** `$WP config get WP_ENVIRONMENT_TYPE` returns `local`.

**On failure:** See Failure Handling table.
