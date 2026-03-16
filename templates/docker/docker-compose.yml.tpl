# Docker Compose v2+ (no version field needed)

services:
  wordpress:
    image: wordpress:php{{php_version}}-fpm
    container_name: {{project_name}}-wp
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: {{db_name}}
      WORDPRESS_DB_USER: {{db_user}}
      WORDPRESS_DB_PASSWORD: {{db_password}}
    volumes:
      - wordpress_data:/var/www/html
      - ./wp-content/themes/{{theme_slug}}:/var/www/html/wp-content/themes/{{theme_slug}}
    networks:
      - {{project_name}}_network
    depends_on:
      - db

  webserver:
    image: nginx:alpine
    container_name: {{project_name}}-web
    restart: unless-stopped
    ports:
      - "{{http_port}}:80"
      - "{{https_port}}:443"
    volumes:
      - wordpress_data:/var/www/html
      - ./wp-content/themes/{{theme_slug}}:/var/www/html/wp-content/themes/{{theme_slug}}
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf
    networks:
      - {{project_name}}_network
    depends_on:
      - wordpress

  db:
    image: mariadb:10.11
    container_name: {{project_name}}-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: {{db_name}}
      MYSQL_USER: {{db_user}}
      MYSQL_PASSWORD: {{db_password}}
      MYSQL_ROOT_PASSWORD: {{db_password}}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - {{project_name}}_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: {{project_name}}-pma
    restart: unless-stopped
    ports:
      - "{{phpmyadmin_port}}:80"
    environment:
      PMA_HOST: db
      PMA_USER: {{db_user}}
      PMA_PASSWORD: {{db_password}}
    networks:
      - {{project_name}}_network
    depends_on:
      - db

  mailpit:
    image: axllent/mailpit:latest
    container_name: {{project_name}}-mail
    restart: unless-stopped
    ports:
      - "{{mailpit_port}}:8025"
      - "{{mailpit_smtp_port}}:1025"
    networks:
      - {{project_name}}_network

volumes:
  wordpress_data:
  db_data:

networks:
  {{project_name}}_network:
    driver: bridge
