# /wp-audit — Step 6.5

`commands/wp-audit.md` sends the run here at Step 6.5. Follow it in order; nothing in it is optional background.

The seven agents read code, the database and a rendered `<head>`. None of them loads the page
the way a visitor does, so the criteria that only exist in a rendered page — contrast as
measured, line width at each breakpoint, a form's validation, a broken link followed, a
Lighthouse score — were either unmeasured or asserted from the source. This runs them.

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh --url <public-url> --dir .wp-audit/suite \
  --site "<project name>" [--pages "/,/services/,/contact/"]
```

Against a public URL, run it through the gate from Step 6:
`WP_AUDIT_GATE_DIR=<scratch>/prod-gate ${CLAUDE_PLUGIN_ROOT}/bin/prod-gate.sh <public-url> -- ${CLAUDE_PLUGIN_ROOT}/bin/audit-suite.sh …`.
The suite then runs with one Playwright worker. The tests, pages and metrics are the
same; only the four parallel browsers are gone.

`<public-url>` is `--host` when given, otherwise `wordpress.url` from `.wp-create.json` —
**unless `local_clone` is true (Step 2.3): the suite must not probe the clone's own host**,
so Step 2.3's live-check rule applies instead of that fallback — the confirmed production
URL (asked for, defaulting to `production_url`), or Tier 3 stays `UNMEASURED — needs the
public URL` and this run is skipped.
**Pass `--pages` with the list Step 2.7 fixed.** Without it the suite keeps whatever its
config already holds, which on a first run is the template's placeholder — so a run that
looks successful measures pages that are not this site's.
The first run scaffolds `.wp-audit/suite/` from `templates/audit-suite/` and installs the
suite's dependencies **once per machine**, into a shared cache keyed by the template's
`package.json`. Later runs and later projects reuse it.

| Exit | Meaning | What to report |
|---|---|---|
| `0` | the suite ran; `.wp-audit/suite/results/run.json` holds its findings | fold them in |
| `1` | it could not run, or produced nothing to convert | report the error; Tier 3 findings stay `UNMEASURED` |
| `2` | no Node, no npm, or the browser would not install | Tier 3 `UNMEASURED` — a skip, not a failure |
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
- Where they describe *different* resources, they are different findings. A contrast
  failure the suite measured on `/contact` and one the agent found in a stylesheet rule
  that no audited page uses are both real, and the second is the one nobody would find
  again.
