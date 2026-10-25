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
        path /wp-content/uploads/woocommerce_uploads/*
    }
    respond @disallowed 404

    # PHP at any depth under uploads: Caddy's path glob never crosses "/", so a
    # glob would miss the dated subdirectories. A regexp is a separate matcher
    # because different matcher types inside one block are ANDed. The pattern ends in
    # (/|$), not $: php_fastcgi splits the path at ".php" into script and PATH_INFO, so
    # /uploads/x/evil.php/foo would run evil.php and escape a bare \.php$ anchor.
    @uploadsphp path_regexp ^/wp-content/uploads/.*\.php(/|$)
    respond @uploadsphp 404

    # Dotfiles and dot-directories (.git, .env, .wp-create*.json) except .well-known.
    @dotfiles {
        path */.*
        not path /.well-known/*
    }
    respond @dotfiles 404
}
