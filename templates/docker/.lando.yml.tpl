name: {{project_name}}
recipe: wordpress
config:
  php: '{{php_version}}'
  via: {{web_server}}
  database: mariadb:10.11
  xdebug: false
  config:
    php: .lando/php.ini
tooling:
  wp:
    service: appserver
    cmd: wp
