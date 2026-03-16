<VirtualHost *:80>
    ServerName {{domain}}
    Redirect permanent / https://{{domain}}/
</VirtualHost>

<VirtualHost *:443>
    ServerName {{domain}}
    DocumentRoot {{document_root}}

    SSLEngine on
    SSLCertificateFile {{ssl_cert}}
    SSLCertificateKeyFile {{ssl_key}}

    <Directory {{document_root}}>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:{{php_fpm_sock}}|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
