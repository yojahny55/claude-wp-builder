- **Media imports no longer fail on `--post_author`.** `wp media import` has no
  `--post_author` option and refuses it (`unknown --post_author parameter`), so every import
  `/wp-seed`, `/wp-favicon`, `/wp-cinematic-seed`, `/wp-cinematic-encode` and the `wp-acf`
  agent ran with it failed outright. They now pass the global `--user=<admin ID>`, which makes
  that user the attachment's author; `wp post create` keeps `--post_author`.
  `tests/checks/seed-post-author.sh` requires `--user` on every import and refuses
  `--post_author` there.
