{{domain}} {
    root * {{document_root}}
    php_fastcgi unix/{{php_fpm_sock}}
    file_server
    encode gzip

    @disallowed {
        path /xmlrpc.php
        path *.sql
        path /wp-content/uploads/*.php
    }
    respond @disallowed 404
}
