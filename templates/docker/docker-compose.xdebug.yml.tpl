# Docker Compose v2+ (no version field needed)

services:
  wordpress:
    build:
      context: ./docker
      dockerfile: Dockerfile.xdebug
      args:
        PHP_VERSION: {{php_version}}
    environment:
      XDEBUG_MODE: debug
      XDEBUG_CONFIG: "client_host=host.docker.internal client_port=9003"
