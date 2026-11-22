- **One definition of a local host, and it no longer trusts `*.local.com` by name.**
  `prod-gate.sh`, `audit-suite.sh` and `geo-scan.sh` each kept their own list, and all
  three treated any `*.local.com` as development although `local.com` is a public domain
  (a production host there skipped the gate, got 4 workers, and was refused by the GEO
  scan). They now share `bin/lib/local-host.sh`: reserved suffixes (`.test`, `.local`,
  `.internal`, `.lan`, `.home.arpa`, `.example`, `.invalid`, `localhost`) and private IP
  literals by octet are local by name; any other name is local only when every address it
  resolves to is loopback or private, and an unresolved name is not local. `geo-scan.sh`
  also lower-cases the host and no longer matches `10.example.com` with a prefix glob.
  `audit-suite.sh` empties `results/audit/*.json` at the start of a run, so a run over
  fewer pages no longer reports the pages of an earlier one. `prod-gate.sh` falls back to
  a symlink-to-pid lock where `flock` is missing (macOS) instead of exiting 1; a lock it
  cannot create (read-only state dir, name too long) exits 1 with `cannot create lock`
  instead of spinning, and its
  header documents that the wrapped command's own exit 4 or 5 is indistinguishable from
  the gate's.
