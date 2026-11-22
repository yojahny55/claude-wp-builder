# /wp-create — Step 4.15

`commands/wp-create.md` sends the run here at Step 4.15 (Filesystem Permissions, native only). Follow it in order; nothing in it is optional background.

WordPress must be able to write to `wp-content` as the PHP process user, or media uploads and plugin installs fail. Determine that user:

```bash
bash -c "grep -hE '^user =' /etc/php-fpm.d/*.conf 2>/dev/null || grep -hE '^(user|User)' /etc/apache2/envvars /etc/httpd/conf/httpd.conf 2>/dev/null"
```

Grant it write access via an inherited default ACL:

```bash
bash -c 'setfacl -R -m "g:$1:rwX" -m "d:g:$1:rwX" "$2/wp-content"' _ '${WEB_USER}' '${PROJECT_PATH}'
```

A plain `chmod -R g+w` is not sufficient: WordPress creates `uploads/<year>/<month>` at runtime under umask 022, so each new month's directory is created mode 755 and uploads break again. The `d:` (default) entry makes every directory created later inherit group write. Capital `X` sets execute on directories only, so uploaded files never become executable.

**Validation:** create a directory under `uploads/` and confirm it is group-writable, then remove it.

**On failure (`setfacl: Operation not permitted`):** the path is owned by another user — ACLs require ownership. If a restore or migration created directories owned by the web user, rename the parent rather than chasing ownership, or re-run with `sudo`.

**Note on the ACL mask:** if a directory already exists with mode 750, its ACL mask clamps `group:<user>:rwx` down to an effective `r-x`. `getfacl` shows this as `#effective:r-x`. The recursive `setfacl` above recalculates the mask, but directories created afterward by a *different* owner may reintroduce it.
