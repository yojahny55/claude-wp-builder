# /wp-audit — Step 9

`commands/wp-audit.md` sends the run here at Step 9, when a fix lands in a web-server rule or adds a URL that WordPress serves from PHP.

## Contents

- Why this file exists
- Rules for using a snippet
- The rules: `block-sensitive-files`, `uploads-no-php`, `no-directory-index`, `compression`,
  `expires-static`, `security-headers`, `webp-negotiation`, `virtual-endpoint`,
  `virtual-endpoint-prefix`

Record such a fix with the rule's id as `server_rule` (`references/fix.md`, *The replay
log*). `bin/audit-runbook.mjs` reads this file to print each rule in the production
runbook: one `### \`<id>\`` section per rule, with a `Verify:` line, an `apache` block and
an `nginx` block. The generator parses those three parts, so keep that shape when you add a
rule. `<endpoint>` and `<prod-url>` are placeholders it fills in.

## Why this file exists

A local clone usually runs Apache, which reads `.htaccess`. Production often runs nginx,
which never reads it. A fix written to `.htaccess` on the clone (block the sensitive files,
gzip and Expires, the WebP rewrite) passes every local check and changes nothing in
production. On one adopted news site every one of those fixes was reported done; production
served none of them.

The second failure is the reverse. A route that WordPress serves from PHP (`/llms.txt`, a
dynamic `/robots.txt`, `/.well-known/*`) works on Apache, because the standard WordPress
rewrite sends every missing file to `index.php`. On nginx the same URLs returned 404 or 403:
a static-file `location` answered `.txt` before WordPress saw the request, and the
`location ~ /\.` deny rule caught `/.well-known/`. A physical `llms.txt` or `robots.txt` left
in the web root shadows the dynamic route on both servers. On that site it also carried the
local host.

## Rules for using a snippet

- **Nobody in this plugin applies these to production.** The server owner does. The
  runbook prints every snippet as `not applied`, and the replay entry keeps
  `applied_on.prod: false` until the owner confirms it and the `Verify:` command passes on
  the public URL.
- **Order matters in nginx.** Regex `location`s are tried in file order, and the first one
  that matches wins. Put the uploads PHP deny and the WebP rule **before** the generic
  `location ~ \.php$` and the static-assets block. An exact `location =` and a
  `location ^~` prefix win over every regex, which is why the endpoint rules use them.
- **`add_header` does not inherit.** In nginx, a `location` with an `add_header` of its own
  drops every `add_header` from the `server` block. Repeat the headers there, or keep them
  in one `include` file used by both.
- **The static-assets block never lists `txt` or `xml`.** Sitemaps from an SEO plugin,
  `robots.txt` and `llms.txt` are often served by PHP. A static `location` that matches them
  answers 404 before WordPress runs.
- A rule that has no section here has no vetted nginx equivalent. The runbook says so, and
  the server owner translates it. Do not improvise one in the report.

### `block-sensitive-files`

Applies to: readme, license and sample config files, dumps, logs and backups left in the web
root, and hidden files and directories other than `/.well-known/`.
Verify: `curl -s -o /dev/null -w '%{http_code}\n' <prod-url>/readme.html` prints `403` or `404`

```apache
<FilesMatch "^(readme\.html|license\.txt|wp-config-sample\.php)$">
    Require all denied
</FilesMatch>
<FilesMatch "\.(sql|log|bak|orig|swp)$">
    Require all denied
</FilesMatch>
RedirectMatch 404 /\.(?!well-known/)
```

```nginx
location ~* ^/(readme\.html|license\.txt|wp-config-sample\.php)$ { deny all; }
location ~* \.(sql|log|bak|orig|swp)$ { deny all; }
location ~ /\.(?!well-known/) { deny all; }
```

### `uploads-no-php`

Applies to: PHP execution under `wp-content/uploads/`.
Verify: `curl -s -o /dev/null -w '%{http_code}\n' <prod-url>/wp-content/uploads/probe.php` prints `403`

```apache
# wp-content/uploads/.htaccess
<FilesMatch "\.(?:php|phtml|php[3-7]|phps)$">
    Require all denied
</FilesMatch>
```

```nginx
# before the generic "location ~ \.php$"
location ~* ^/wp-content/uploads/.*\.(?:php|phtml|php[3-7]|phps)$ { deny all; }
```

### `no-directory-index`

Applies to: directory listings, `Options -Indexes`.
Verify: `curl -s <prod-url>/wp-content/uploads/ | grep -c 'Index of'` prints `0`

```apache
Options -Indexes
```

```nginx
# nginx lists nothing unless told to: make sure no server or location block says "autoindex on"
autoindex off;
```

### `compression`

Applies to: gzip of text responses (`mod_deflate`).
Verify: `curl -s -o /dev/null -D - -H 'Accept-Encoding: gzip' <prod-url>/ | grep -i '^content-encoding'` prints `gzip` or `br`

```apache
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/css text/xml application/javascript application/json application/xml application/rss+xml image/svg+xml font/ttf
</IfModule>
```

```nginx
# http or server block; text/html is always compressed once gzip is on
gzip on;
gzip_vary on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_types text/plain text/css text/xml application/javascript application/json application/xml application/rss+xml image/svg+xml font/ttf;
```

### `expires-static`

Applies to: browser caching of static assets (`mod_expires`, `Cache-Control`).
Verify: `curl -sI <prod-url>/wp-includes/js/jquery/jquery.min.js | grep -i '^cache-control'` prints a `max-age`

```apache
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
</IfModule>
```

```nginx
# never add txt or xml here: robots.txt, llms.txt and sitemaps may be served by PHP
location ~* \.(?:css|js|mjs|jpe?g|png|gif|webp|avif|svg|ico|woff2?|ttf)$ {
    expires 1y;
    access_log off;
    try_files $uri =404;
}
```

### `security-headers`

Applies to: response headers set in `.htaccess` (`nosniff`, frame options, referrer and
permissions policy). Headers that a PHP must-use plugin already sends need no server rule for
HTML pages. They still miss the static files, which never pass through PHP.
Verify: `curl -sI <prod-url>/ | grep -i '^x-content-type-options'` prints `nosniff`

```apache
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"
</IfModule>
```

```nginx
# server block; repeat in any location that has an add_header of its own
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

### `webp-negotiation`

Applies to: serving Robin's `<original>.webp` sibling by `Accept` header. The reasoning, and
when not to use it, is in `skills/wp-robin/references/webp-delivery.md`.
Verify: `curl -sI -H 'Accept: image/webp' <prod-url>/wp-content/uploads/<image>.jpg | grep -i '^content-type\|^vary'` prints `image/webp` and `Vary: Accept`

```apache
# wp-content/uploads/.htaccess
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteCond %{HTTP_ACCEPT} image/webp
RewriteCond %{REQUEST_FILENAME}.webp -f
RewriteRule ^(.+)\.(png|jpe?g)$ $1.$2.webp [T=image/webp,L]
</IfModule>
<IfModule mod_headers.c>
<FilesMatch "\.(png|jpe?g)$">Header append Vary Accept</FilesMatch>
</IfModule>
```

```nginx
# http block
map $http_accept $webp_suffix { default ""; "~*image/webp" ".webp"; }
# server block, before the static-assets location
location ~* ^/wp-content/uploads/.+\.(png|jpe?g)$ {
    add_header Vary Accept;
    expires 1y;
    try_files $uri$webp_suffix $uri =404;
}
```

### `virtual-endpoint`

Applies to: one URL that WordPress serves from PHP, such as `/llms.txt` or a dynamic
`/robots.txt`. A physical file of the same name in the web root wins on both servers.
Delete it, or the route never runs.
Verify: `curl -s -o /dev/null -w '%{http_code} %{content_type}\n' <prod-url><endpoint>` prints `200` and the type the route sends

```apache
# Nothing to add: the standard WordPress block already routes a missing file to index.php.
# Confirm it is present and that no physical <endpoint> exists in the web root.
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
```

```nginx
# server block; an exact match wins over the static-file and dotfile regex locations
location = <endpoint> {
    try_files $uri /index.php?$args;
}
```

### `virtual-endpoint-prefix`

Applies to: a family of URLs that WordPress serves from PHP under one prefix, such as
`/.well-known/`. The generic `location ~ /\.` deny rule catches it on nginx and answers 403.
Verify: `curl -s -o /dev/null -w '%{http_code} %{content_type}\n' <prod-url><endpoint>` prints `200` for a path the route serves

```apache
# Nothing to add beyond the standard WordPress block, as long as no rule denies dot paths
# without excepting /.well-known/ (see block-sensitive-files).
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
```

```nginx
# server block; ^~ stops the regex locations (the dotfile deny included) from matching
location ^~ <endpoint> {
    try_files $uri $uri/ /index.php?$args;
}
```
