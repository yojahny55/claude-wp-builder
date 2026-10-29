# /wp-audit — Step 6.5

`commands/wp-audit.md` sends the run here at Step 6.5. Follow it in order; nothing in it is optional background.

## Contents

- Running the suite, the gate and the audited host
- Run settings are flags, not config edits
- Exit codes
- The suite's findings and the agents' findings can be the same defect
- The shopper-flow regression suite is not an audit pass
- Tier 3 UNMEASURED must be visible in the report

The seven agents read code, the database and a rendered `<head>`. None of them loads the page
the way a visitor does, so the criteria that only exist in a rendered page — contrast as
measured, line width at each breakpoint, a form's validation, a broken link followed, a
Lighthouse score — were either unmeasured or asserted from the source. This runs them.

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh --url <public-url> --dir .wp-audit/suite \
  --site "<project name>" [--pages "/,/services/,/contact/"]
```

**Start it only after every Step 6 agent has returned.** The gate holds a per-host lock for the whole
wrapped command, and a suite run against a slow production host lasts many minutes. Any agent that calls
the gate meanwhile waits `--wait` (300 s), exits 5 and, after three 5s, reports its check
`UNMEASURED: production gate busy`. The agents' production checks go first; the suite runs alone after them.

Against a public URL, run it through the gate from Step 6:
`WP_AUDIT_GATE_DIR=<scratch>/prod-gate ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh <public-url> -- ${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh …`.
The script does not depend on the caller remembering: for a production host (a public host, or
one the manifest's `environments` marks role prod) it re-runs itself through `prod-gate.sh`
when it is not already under it, and a blocked or busy host ends the run with exit `4` or `5`
before anything is sent. The suite then runs with one Playwright worker.

**The audited host is `--url`, never the config.** `audit.config.js` is persistent, so
`audit-suite.sh` does not write `baseURL` into it: it passes `BASE_URL` in the environment on
every run, compares the file's `baseURL` with `--url`, says so on stderr when they differ and
audits `--url`. A hand-edited or stale `baseURL` therefore cannot send a run to another host.

**A host that stops answering ends the run.** After `--max-timeouts` page timeouts in a row
(default 3, or `WP_AUDIT_MAX_TIMEOUTS`) the guard reporter writes `results/unmeasured.json`, the
remaining passes are skipped and the script exits `2` with an `UNMEASURED:` line naming the cause.
Do not re-run it against the same host to "try again"; check the host first. The tests, pages and metrics are the
same; only the four parallel browsers are gone.

**A slow page is not a silent host.** After each timeout the guard sends one GET to `--url`.
Only a host that does not answer it, refuses the connection, or answers `403`/`429`/`503`
counts toward `--max-timeouts`. A host that answers resets the count: the page is recorded in
`results/unmeasured-pages.json` as a slow page with the timing, and the run goes on. So does a
check that ran on a page a timeout had already closed. `scripts/to-run.js` turns each entry
into an `UNMEASURED` row (`SUITE-PAGE-*`) with that reason; quote it, never report it as the
criterion's finding.

### Run settings are flags, not config edits

Never edit the generated `playwright.config.js` to tune a run. Pass the flag instead:

| Flag | Default | Use it when |
|---|---|---|
| `--workers <n>` | 4 locally, 1 on production (more is refused there) | a machine short of RAM starts browsers that hang at launch |
| `--timeout <s>` | the template's 90 | a heavy page needs longer per test |
| `--engines chromium[,firefox][,webkit]` | all three, each one that exists | the other engines are not needed this run; `chromium` is required |
| `--settle <s>` | 5 | pages load to `domcontentloaded`, then get this long to go network-idle; a video embed or a polling widget never does |
| `--block-third-party` / `--no-block-third-party` | ON against a local host, OFF against production | a clone must not send real hits to production analytics, embeds or widget APIs; against production, pass it to measure the site's own payload |
| `--allow-hosts <h1,.cdn.example>` | — | the site serves its own assets from another host (`.domain` allows its subdomains) |

There is no `--project`; engines are `--engines`. The block allows the audited host, its
www/non-www twin and loopback (`bin/lib/third-party.cjs`, the list `bin/ux-probe.mjs` uses
too), and the run prints the allowlist. With the block on, Lighthouse scores describe the site
without its third parties: say so beside them. The broken-link check is an HTTP request, not a
page load, and still verifies external links.

A generated config somebody did edit is kept: `.scaffold-sums` records each config as
scaffolded, a re-run that finds it changed keeps it and says so, and deleting it takes the
template's again. The flags remain the way to tune a run, because a kept file misses every
later template fix.

**The suite directory holds only the suite.** A non-empty `--dir` that no earlier run
scaffolded is refused, and the message lists what is in it. Write run logs elsewhere
(`.wp-audit/suite.log`, not `.wp-audit/suite/run.log`).

**Before reporting "no browser", look for one.** `node ${CLAUDE_PLUGIN_ROOT}/bin/lib/browsers.mjs chromium`
prints an existing Chromium (Playwright's caches, then the system one such as `/usr/bin/chromium`).
The suite uses whatever it finds and never downloads one; exit `2` from that lookup is the only
"no browser".

**Lighthouse results and the serving layer.** With `local_clone` true the suite never targets the clone (below), so its LCP, FCP, TBT, performance score and byte totals are those of the confirmed public URL; without one they are `UNMEASURED`. Should a run be pointed at a local host anyway, those numbers inherit the clone's serving layer (compression, HTTP version): label them `clone measurement — serving layer differs (…)` as *Clone-safe versus production-only measurement* in `site-context.md` says, and never use them as a baseline or a finding by themselves.

**Which URL is production.** When the manifest has `environments`, the entry with `role: "prod"`
is the production gate: its `url` is the confirmed production URL, and a target whose host
matches a `role: "local"` entry is a clone. Without `environments`, the URL comparison below
is the fallback.

`<public-url>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` —
**unless `local_clone` is true (Step 2.3): the suite must not probe the clone's own host**,
so Step 2.3's live-check rule applies instead of that fallback — the confirmed production
URL (asked for, defaulting to `production_url`), or Tier 3 stays `UNMEASURED — needs the
public URL` and this run is skipped.
**Pass `--pages` with the list Step 2.7 fixed.** Without it the suite keeps whatever its
config already holds, which on a first run is the template's placeholder — so a run that
looks successful measures pages that are not this site's.
The first run scaffolds `.wp-audit/suite/` from `templates/audit-suite/` and installs the
suite's dependencies **once per machine** with `npm ci` against the template's `package-lock.json`
(no lockfile means no install, with a message; no browser is ever downloaded), into a shared cache keyed by the template's
`package.json`. Later runs and later projects reuse it.

| Exit | Meaning | What to report |
|---|---|---|
| `0` | the suite ran; `.wp-audit/suite/results/run.json` holds its findings | fold them in |
| `1` | it could not run, or produced nothing to convert | report the error; Tier 3 findings stay `UNMEASURED` |
| `2` | no Node, no npm, no existing browser, or the host stopped answering | Tier 3 `UNMEASURED` — a skip, not a failure; quote the `UNMEASURED:` cause |
| `4` / `5` | the production gate refused: host marked blocked / busy | Tier 3 `UNMEASURED: production gate …`; nothing was sent |
| `3` | crash | report it and continue |

**`audit.config.js` is written once and then left alone.** It carries the selectors
somebody inspected the real DOM to find, and a scaffold that overwrote it every run would
re-measure a different site each time without saying so. When a run reports selectors that
match nothing, edit that file — do not delete it.

### The suite's findings and the agents' findings can be the same defect

The suite measures accessibility with axe and reads the same `<head>` `wp-audit-seo` reads,
so a contrast failure or a missing description can arrive twice, once as `A11Y-AXE-*` or
`UX-*` and once as `A11Y-*` or `SEO-*`. Reporting **the same defect twice under two codes**
inflates every count and makes the ledger's identity useless, so Step 7's deduplication
owns it, with one rule:

- **A measurement beats an inference.** Where both describe the same resource, keep the
  suite's finding and drop the agent's — the agent reasoned about the code, the suite
  loaded the page. The kept finding's evidence notes that it superseded another source, and
  the sidecar keeps that evidence.
- **Contrast findings end in a proposal, not a patch.** Group the failing `A11Y-AXE-*` colour
  pairs and run `bin/contrast-propose.mjs --axe <axe.json>`: nearest compliant shade per pair,
  ratio before and after, affected texts and pages, for the client to approve. No colour is
  changed without that approval, and text over images (axe `incomplete`) is listed as not measured.
- Where they describe *different* resources, they are different findings. A contrast
  failure the suite measured on `/contact` and one the agent found in a stylesheet rule
  that no audited page uses are both real, and the second is the one nobody would find
  again.

### The shopper-flow regression suite is not an audit pass

`.wp-audit/suite/` also holds `npm run test:regression` (projects `regression-desktop` and
`regression-mobile`, tests tagged `@regression`). It answers "does the store still work", not
"is it good", so it produces no findings and `scripts/to-run.js` ignores it: its output is
`results/regression/<REGRESSION_LABEL>.md` and `.json`. Run it with `REGRESSION_LABEL=before` ahead
of performance or update work and `after` once done, then `npm run regression:compare -- before after`.
It runs against the local clone only: it never places an order, and the flows that write (contact,
newsletter) are skipped off a clone unless `regression.allowWrites` is set. The first admin request
after an update can time out; the admin flow retries once before it reports `FAIL`.

### Tier 3 UNMEASURED must be visible in the report

When the suite did not run (exit `2`, `4` or `5`), put `"tier3": "unmeasured"` in the run file (and an
`unmeasured` entry whose check id starts with `tier3`, with the cause). `bin/audit-report.mjs` then
opens the summary of the `.md` and the header of the `.html` with a bold line saying Tier 3 was not
measured, so a report with no browser findings is not read as a pass.
