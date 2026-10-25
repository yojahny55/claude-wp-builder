<VirtualHost *:80>
    ServerName {{domain}}
    DocumentRoot {{document_root}}

    <Directory {{document_root}}>
        AllowOverride All
        Require all granted
    </Directory>

    # Dotfiles (except .well-known), dumps and backups are never served; PHP never runs in uploads.
    # Match the URL, not the filesystem path: a docroot under a dot-directory
    # or below an ancestor named uploads must not trip these.
    <LocationMatch "/\.(?!well-known)">
        Require all denied
    </LocationMatch>
    <FilesMatch "(^\.(?!well-known)|\.(sql|bak|log)$|\.bak-)">
        Require all denied
    </FilesMatch>
    <LocationMatch "(?i)^/wp-content/uploads/.*\.(php[0-9]?|phar|pht(ml)?)(\.|/|$)">
        Require all denied
    </LocationMatch>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:{{php_fpm_sock}}|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
