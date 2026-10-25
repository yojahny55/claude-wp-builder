- **Native vhost templates deny sensitive files.** The nginx, Apache and Caddy templates
  denied only `/.ht` (nginx) and served everything else under the project root, so
  `.wp-create*.json` (which can hold test payment keys) and its `.bak` copies, `.git/`,
  `.env` and `*.sql` dumps were downloadable, and PHP ran inside `uploads/`. They now deny
  dotfiles (except `.well-known`), `.sql`/`.bak`/`.log`/`.bak-*` files and PHP in uploads, and
  nginx runs `try_files $uri =404` before `fastcgi_pass`.
  The Apache rules match the URL (`LocationMatch`, uploads anchored to `/wp-content/uploads/`),
  not the filesystem path, so a docroot under a dot-directory or below a directory named
  `uploads` is not denied wholesale.
  The uploads PHP rule in Apache and Caddy is `(?i)^/wp-content/uploads/.*\.(php[0-9]?|phar|pht(ml)?)(\.|/|$)`,
  not `\.php$`: it also covers `.phar`, `.phtml` and `.pht`, which the Debian/Ubuntu and RHEL global PHP handlers execute. `mod_mime` applies `AddHandler .php` to the extension in any position of the name
  and ignores case, and PATH_INFO maps `evil.php/foo` to `evil.php`. Measured on Apache 2.4 with
  `mod_php`: `evil.php`, `evil.php/foo`, `evil.php/x.jpg`, `evil.php.jpg`, `evil.PHP`, `evil.php5/x`, `evil.phtml`, `evil.phar` and `evil.pht` answer 403,
  while `x.php_.jpg` (the name WordPress gives a renamed upload), `my.phpunit.pdf`, `a.jpg` and `/index.php/foo` are
  untouched. The Caddy pattern is the same regexp, checked by reading only (no Caddy binary).
  nginx needs no change: its PHP location is `\.php$` with no PATH_INFO split, so neither
  `evil.php/foo` nor `evil.php.jpg` reaches fastcgi.
