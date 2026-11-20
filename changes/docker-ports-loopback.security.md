- **The Docker template publishes its ports on loopback only.** The web server,
  phpMyAdmin and Mailpit were mapped as `{{port}}:80`, which Docker binds to every
  interface, so a project started on a shared network exposed them to that network.
  Each mapping is now `127.0.0.1:{{port}}:…`, and `tests/checks/wp-environments.sh`
  fails if a bare mapping comes back.
