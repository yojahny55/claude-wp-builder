server {
    listen 80;
    server_name {{domain}};
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name {{domain}};

    root {{document_root}};
    index index.php index.html;

    ssl_certificate {{ssl_cert}};
    ssl_certificate_key {{ssl_key}};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:{{php_fpm_sock}};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.ht { deny all; }
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { allow all; log_not_found off; access_log off; }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
}
