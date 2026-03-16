{
  "core": "WordPress/WordPress",
  "phpVersion": "{{php_version}}",
  "plugins": [],
  "themes": ["./wp-content/themes/{{theme_slug}}"],
  "port": {{http_port}},
  "testsPort": {{tests_port}},
  "config": {
    "WP_DEBUG": true,
    "WP_DEBUG_LOG": true,
    "WP_DEBUG_DISPLAY": false
  }
}
