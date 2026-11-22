# Rendered by /wp-create Step 4.3 to docker/nginx.conf and mounted by docker-compose.yml as the
# webserver container's default.conf. Without this file Docker creates a directory at the
# mount source and the webserver container does not start.
#
# Plain HTTP on port 80 inside the container: no certificate is mounted, so the compose file's
# 443 mapping has nothing listening behind it. The deny rules mirror the native nginx
# templates and templates/native/_deny.list (tests/checks/vhost-deny-list-parity.sh).
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.php index.html;

    # nginx defaults to 1m, which rejects plugin/theme zips and migration
    # archives with a 413 before PHP ever sees the request.
    client_max_body_size {{max_upload_size}};

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Deny before the PHP block: regex locations match in order, and a dotfile, a dump or a
    # backup under the docroot would otherwise be served by the generic try_files.
    location ~ /\.(?!well-known) { deny all; }
    location ~* \.(sql|sql\.gz|bak|log)$ { deny all; }
    # Archives are denied outside uploads only: a zip in the media library is legitimate.
    location ~* "^(?!/wp-content/uploads/).*\.(zip|tar\.gz|tgz)$" { deny all; }
    location ~* \.bak- { deny all; }
    # The PHP location below is \.php$ only, so evil.php.jpg is served as a static file here.
    location ~* "/uploads/.*\.(php[0-9]?|phar|pht(ml)?)(\.|/|$)" { deny all; }
    # PATH_INFO form (/xmlrpc.php/x) still runs the script, so match the prefix.
    location ~ "^/xmlrpc\.php(/|$)" { deny all; }

    location ~ \.php$ {
        try_files $uri =404;
        include fastcgi_params;
        # The wordpress service runs php-fpm on 9000 (image wordpress:php*-fpm).
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # WooCommerce keeps paid downloads here behind an .htaccess `deny from all`, which nginx
    # never reads (SEC-039). `^~` so the static-file regex below cannot serve them first.
    location ^~ /wp-content/uploads/woocommerce_uploads/ { deny all; }
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { allow all; log_not_found off; access_log off; }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
}
