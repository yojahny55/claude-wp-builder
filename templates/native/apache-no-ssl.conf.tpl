<VirtualHost *:80>
    ServerName {{domain}}
    DocumentRoot {{document_root}}

    <Directory {{document_root}}>
        AllowOverride All
        Require all granted
    </Directory>

    # Dotfiles (except .well-known), dumps and backups are never served; PHP never runs in uploads.
    <DirectoryMatch "/\.(?!well-known)">
        Require all denied
    </DirectoryMatch>
    <FilesMatch "(^\.(?!well-known)|\.(sql|bak|log)$|\.bak-)">
        Require all denied
    </FilesMatch>
    <DirectoryMatch "/uploads/">
        <FilesMatch "\.php$">
            Require all denied
        </FilesMatch>
    </DirectoryMatch>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:{{php_fpm_sock}}|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
