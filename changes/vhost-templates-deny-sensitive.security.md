- **Native vhost templates deny sensitive files.** The nginx, Apache and Caddy templates
  denied only `/.ht` (nginx) and served everything else under the project root, so
  `.wp-create*.json` (which can hold test payment keys) and its `.bak` copies, `.git/`,
  `.env` and `*.sql` dumps were downloadable, and PHP ran inside `uploads/`. They now deny
  dotfiles (except `.well-known`), `.sql`/`.bak`/`.log`/`.bak-*` files and PHP in uploads, and
  nginx runs `try_files $uri =404` before `fastcgi_pass`.
  The Apache rules match the URL (`LocationMatch`, uploads anchored to `/wp-content/uploads/`),
  not the filesystem path, so a docroot under a dot-directory or below a directory named
  `uploads` is not denied wholesale.
