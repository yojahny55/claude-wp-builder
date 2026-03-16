<VirtualHost *:80>
    ServerName {{domain}}
    DocumentRoot {{document_root}}

    <Directory {{document_root}}>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:{{php_fpm_sock}}|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
