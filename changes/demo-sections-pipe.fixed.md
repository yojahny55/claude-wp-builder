- **`demo-sections.mjs` no longer cuts a large listing short on a pipe.** It wrote its report
  and then called `process.exit()`, which drops whatever a pipe has not taken yet: a `--json`
  listing over 64 KiB reached its reader truncated and unparseable. Exit codes are now set
  through `process.exitCode`, and bad usage is thrown to the entry point, which sets 64.
