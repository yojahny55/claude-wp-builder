- **The audit suite no longer re-takes its own gate on an IPv6 host, and a browser launch
  timeout is no longer read as a silent host.** `bin/audit-suite.sh` cut `https://[2001:db8::1]/`
  to `[2001`, so the child of a gated run never matched `WP_AUDIT_GATE_HELD`, re-ran the gate
  and waited 300 s on its own lock. Both scripts now derive the key from one helper,
  `bin/lib/host-key.sh`. The timeout guard also ignores `browserType.launch` timeouts (four
  workers on little RAM), which wrote `unmeasured.json` with the wrong cause.
