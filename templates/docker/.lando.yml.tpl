name: {{project_name}}
recipe: wordpress
config:
  php: '{{php_version}}'
  via: {{web_server}}
  database: mariadb:10.11
  xdebug: false
tooling:
  wp:
    service: appserver
    cmd: wp
