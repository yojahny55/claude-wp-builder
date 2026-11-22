[{{project_name}}]
user = {{web_user}}
group = {{web_user}}
listen = {{php_fpm_sock}}
listen.owner = {{web_user}}
listen.group = {{web_user}}
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

; PHP defaults (2M upload / 8M post) reject plugin and theme zips even when the web server
; allows them, so the pool carries the same limit as the vhost.
php_admin_value[upload_max_filesize] = {{max_upload_size}}
php_admin_value[post_max_size] = {{max_upload_size}}
