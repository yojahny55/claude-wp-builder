- **Docker environments get their nginx config.** `docker-compose.yml.tpl` mounted a
  `docker/nginx.conf` that nothing wrote, so Docker created a directory at the mount source and
  the `webserver` container never started. `/wp-create` Step 4.3 now renders
  `templates/docker/nginx.conf.tpl` there (PHP to the `wordpress:9000` FPM service, the native
  deny list including `woocommerce_uploads`, `client_max_body_size`), backs it up on overwrite
  like the other environment files, and a new check serves it from a real nginx.
