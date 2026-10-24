{{domain}} {
    root * {{document_root}}
    php_fastcgi unix/{{php_fpm_sock}}
    file_server
    encode gzip

    @disallowed {
        path /xmlrpc.php
        path *.sql
        path *.bak
        path *.log
        path *.bak-*
        path /wp-content/uploads/*.php
        path /wp-content/uploads/woocommerce_uploads/*
    }
    respond @disallowed 404

    # Dotfiles and dot-directories (.git, .env, .wp-create*.json) except .well-known.
    @dotfiles {
        path */.*
        not path /.well-known/*
    }
    respond @dotfiles 404
}
