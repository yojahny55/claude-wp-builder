- **Browser suite: audited host, production gate, timeouts, lockfile, visible UNMEASURED.**
  `bin/audit-suite.sh` rewrote `baseURL` inside the persistent `audit.config.js`, so a stale
  or hand-edited value pointed the next run at the wrong host (in one case production, with
  90 s timeouts, outside the gate). The audited host now comes from `--url` through
  `BASE_URL`; the config is only read, and a mismatch is reported. The script re-runs itself
  through `bin/prod-gate.sh` for any production host (public, or role prod in the manifest's
  `environments` when present) instead of trusting the caller; the gate exports
  `WP_AUDIT_GATE_HELD` and accepts `--prod`. After 3 consecutive page timeouts
  (`--max-timeouts` / `WP_AUDIT_MAX_TIMEOUTS`) the run stops and exits 2 with the cause
  instead of hammering a silent host. Dependencies install with `npm ci` from a committed
  `package-lock.json` (no lockfile, no install; still no browser download). A run with Tier 3
  unmeasured now opens the report summary (`.md` and `.html`) with a bold notice.
