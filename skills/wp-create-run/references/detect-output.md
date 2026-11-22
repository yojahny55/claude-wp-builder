# /wp-create — Step 1

`commands/wp-create.md` sends the run here at Step 1 (Environment Detection) to read the JSON `detect` prints. Follow it in order; nothing in it is optional background.

Parse the JSON output. The structure is:

```json
{
  "os": "fedora",
  "package_manager": "dnf",
  "web_servers": {
    "nginx": { "installed": true, "version": "1.24.0", "running": true },
    "apache": { "installed": true, "version": "2.4.58", "running": false },
    "caddy": { "installed": false }
  },
  "php": {
    "versions": ["8.2", "8.3"],
    "active": "8.3",
    "extensions": ["mysql", "curl", "mbstring", "xml", "gd", "zip", "intl"]
  },
  "docker": {
    "installed": true,
    "version": "24.0.7",
    "compose": true
  },
  "tools": {
    "ddev": { "installed": false },
    "lando": { "installed": false },
    "wp-env": { "installed": false },
    "wp-cli": { "installed": true, "version": "2.9.0" }
  },
  "database": {
    "mariadb": { "installed": true, "version": "10.11", "running": true },
    "mysql": { "installed": false }
  }
}
```
