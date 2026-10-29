# /wp-audit — Step 8

## Contents

- Status vocabulary
- Allowed UNMEASURED reasons
- The console report format

`commands/wp-audit.md` sends the run here at Step 8. Follow it in order; nothing in it is optional background.

### Status vocabulary

Every check resolves to one of five statuses, and the last three are not interchangeable:

| Status | Means |
|---|---|
| `PASS` | ran, and the site satisfies it |
| `FAIL` | ran, and the site does not |
| `N/A` | does not apply to this site type — say why (e.g. "no WooCommerce", or "local clone", see Step 2.3) |
| `UNMEASURED` | applies, but was never measured — say what stopped it (e.g. "needs the public URL") |
| `NEVER RUN` | the whole category has never run on this project (Step 2.5d) |

`N/A` and `UNMEASURED` were one status, and merging them hid the difference between "this
site has no API to check" and "this check applies and nothing ever ran it". A reader counting
failures cannot tell those apart, and the second one is the one that needs action. Count them
separately in every summary line, and never fold `UNMEASURED` into the passing total.

Findings in the ledger carry a separate set of statuses (`ledger.md`), and two of them must be
reported apart from the counts above, never folded into them: `accepted` (a human decided it
stays) is listed as accepted and left out of open and critical totals and of next steps;
`fixed_unverified` (a fix was applied, no check has re-run) is listed as awaiting verification
and is never called `resolved`. Only a measured re-run turns `fixed_unverified` into
`resolved`, and a re-run that still finds it returns it to `still_failing`. Quote counts from
`audit-report.mjs --summary`, not from memory.

### Allowed UNMEASURED reasons

An `UNMEASURED` check is accepted, and kept out of the "missing" list, only when its reason is
one of these four (Step 6.8, point 2; `bin/audit-coverage.mjs` applies them):

| Reason | Example wording |
|---|---|
| needs credentials | "needs a logged-in user", "needs the gateway API key" |
| needs the network or a third party | "third-party API unreachable", "rate limit" |
| needs production | "needs the public URL", "production gate busy", "host blocked" |
| needs a tier the run does not have | "needs Tier 3", "no WP-CLI", "no browser tool and no suite" |

Anything else is measurable with tools already present and counts as missing: "not measured in
this run", "not run", "no browser measurement" when a browser is available, "clone", or no
reason at all. An `N/A` needs a reason too (the site has no WooCommerce); one without is
missing.

The reconciliation block from Step 2.5 goes **first**, above the per-category counts. A
never-run category and a stale record change how every number below them should be read, so
they cannot sit underneath those numbers.

```
=== WP Audit Report ===
Tier: <tier description>
Categories: <comma-separated selected categories>

<the Step 2.5 reconciliation block, or its one-line clean form>

[SECURITY] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: <message> (<file>:<line>)
  ✗ WARNING: <message>
  ℹ INFO: <message>

[SEO] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[A11Y] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[PERFORMANCE] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[BEST PRACTICES] N issues (X critical, Y warnings, Z info)
  ✗ CRITICAL: ...
  ✗ WARNING: ...
  ℹ INFO: ...

[USABILITY] N issues (X critical, Y warnings, Z info) — M/A criteria passed of those that applied
  Pages: <the Step 2.7 scope, or "not measured — no page scope">
  ✗ CRITICAL: <message> (UX-014, /services/)
  ✗ WARNING: <message> (UX-006, desktop: 142 characters)
  ○ N/A: K — <the criteria this site genuinely lacks the feature for>
  ? UNMEASURED: J — <what stopped them: no page scope, no browser, no Tier 2>

[GEO] <site_type> — N issues (X errors, Y warnings, Z info, K N/A)
  Layer coverage: <Discovery ✓|✗> <Access ✓|✗> <Usability ✓|✗> <Payments ✓|N/A>
  ✗ ERROR: <message> (GEO-A13)
  ✗ WARNING: <message> (GEO-A06)
  ℹ INFO: <message>
  ○ N/A: <layer> — <rationale>
  Live scan: <score|<score> (stale: scanned <date>)|unavailable — challenged by a bot interstitial|unavailable — skipped: <reason>> (produced by Step 6.2's scan; Step 9 adds before → after)

---
Total: N issues (X critical, Y warnings, Z info)
Auto-fixable: M/N
```

If any agent failed:
```
[SECURITY] ⚠ Agent failed: <reason>. Skipped.
```

If all checks passed in a category:
```
[SECURITY] ✓ All checks passed
```
