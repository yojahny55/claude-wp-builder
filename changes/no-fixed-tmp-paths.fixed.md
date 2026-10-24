- **Audit snippets and `wp-cinematic-encode.sh` no longer share fixed `/tmp` files.**
  Paths such as `/tmp/emitted`, `/tmp/site-text.txt`, `/tmp/rm-head.html`,
  `/tmp/geo-home.html` and `/tmp/wp-cine-*.log` were the same on every run, so two
  concurrent runs or sessions could read each other's output and compare one site against
  another. They now use a per-run `mktemp -d`, and `tests/checks/no-fixed-tmp-paths.sh`
  fails on a new literal `/tmp/` outside the documented exceptions.
