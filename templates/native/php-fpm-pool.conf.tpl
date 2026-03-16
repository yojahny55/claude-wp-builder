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
