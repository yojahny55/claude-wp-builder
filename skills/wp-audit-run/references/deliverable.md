# /wp-audit — Step 8.5

`commands/wp-audit.md` sends the run here at Step 8.5. Follow it in order; nothing in it is optional background.

## Contents

- Every finding says who applies it
- Render it
- The report goes out before anything is fixed

The console report from Step 8 is for whoever ran the audit. It is gone when the scrollback is,
and `.wp-audit-findings.json` is a working file — nobody hands a client a JSON array of
check ids. When `--report` is given, or the run is report-only (Step 1 defaults `--report`
to `both` there), this step writes the same run as documents.

### Every finding says who applies it

Before rendering, assign each finding one of four owners. This is not a label for the
report; it is the answer to "how much of this can you do, and how much is mine?", and it is
the one question the counts cannot answer.

| Owner | What it is | Where it ends up |
|---|---|---|
| `code` | a file in the theme — CSS, `functions.php`, a template | **travels with the commit** |
| `setting` | a WordPress option, a plugin's configuration, a server rule (HTTPS, redirects, `.htaccess`) | applied with WP-CLI on the local clone, and **does not travel with the commit** |
| `content` | a text somebody has to write or decide — a title, a description, an `alt` | a person writes it; you may propose the text |
| `manual` | human judgment or an external tool | never automated |

**`setting` is the one that gets lost, and it is why the four exist rather than two.** A
`$WP option update` run against a local clone changes that clone's database and nothing
else. The commit carries no trace of it, the staging panel has no WP-CLI, and the next
deploy looks identical to the audit that "fixed" it. Every `setting` row is therefore a
step to repeat wherever the site is deployed, and the report says so in those words.

An owner comes from what the fix touches, never from whether the audit can do it: a fix
this run applies automatically is still a `setting` if it wrote to the database.

**Every agent reports its own owner** — the dispatch prompt in Step 6 asks for it, so this
step reads the field rather than classifying ~250 check codes at report time. When a finding
arrives without one, derive it from what its fix touches, and the category tells you where
to look first:

| Category | Almost always | The exceptions worth checking |
|---|---|---|
| `SEC-*` | `setting` — wp-config constants, `.htaccess`, AIOS options, file permissions | escaping and `$wpdb->prepare` in a template are `code` |
| `SEO-*` | `setting` — Rank Math options, permalinks, sitemap | hardcoded `<title>`/meta in a template are `code`; a missing description or a title to rewrite is `content` |
| `A11Y-*` | `code` — templates, CSS, ARIA | `alt` text and link text somebody has to write are `content` |
| `PERF-*` | `code` — enqueues, image attributes, `inc/performance.php` | object cache, autoload options, revisions, OPcache are `setting` |
| `WP-*` | `code` — it is the theme's own source by definition | — |
| `GEO-*` | `code` — `inc/agentic.php` and the surfaces it generates | the robots AI policy and anything written to an option are `setting`; trust-anchor prose is `content` |
| `UX-*` | read it from `skills/wp-audit-ux-standards/SKILL.md`, which gives an owner per criterion | — |

The table is a starting point, not the answer. **Ask what the fix writes to**: a file in the
theme is `code`, a row in the database or a server rule is `setting`, a sentence a person
must compose is `content`, a judgement is `manual`.

### Render it

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-report.mjs --run <run.json> --out .wp-audit \
  --format <md|html|both> --lang <en|es>
```

Write `<run.json>` first, into the session's scratch directory rather than the project —
it is an argument, not an artifact:

```json
{
  "site": "<project name>",
  "date": "<YYYY-MM-DD>",
  "tier": "<the same label Step 3 printed>",
  "categories": ["security", "seo", "usability"],
  "findings": [
    {
      "check": "SEC-036",
      "resource": "wp_options.siteurl",
      "severity": "CRITICAL",
      "ownership": "setting",
      "category": "security",
      "page": null,
      "message": "Development host in siteurl",
      "fix": "$WP option update siteurl https://…",
      "evidence": "$WP option get siteurl"
    }
  ],
  "unmeasured": [
    { "check": "PERF-LCP", "reason": "no browser tool and no suite — Tier 3 never ran" }
  ]
}
```

`check`, `severity`, `ownership` and `message` are required on every finding: the renderer
**refuses a finding with no `ownership`** and exits `1` naming it, because a plan whose last
column is blank is the plan this step exists to replace. `severity` is `CRITICAL`, `WARNING`
or `INFO` and nothing else: a GEO finding graded `ERROR` is written `CRITICAL`. `page` is the page a page-level finding is about and
`null` otherwise. An `UNVERIFIED` finding from Step 6.9 is **not** a finding here: it was
never measured, so it goes in `unmeasured` with the command that would settle it.

**With `--suite`, do not hand-merge.** Step 6.5 wrote a run file of its own; pass it:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/audit-report.mjs --run <agents.json> \
  --merge .wp-audit/suite/results/run.json --out .wp-audit --format both --lang <en|es>
```

The renderer applies Step 7's second rule — same `check` **and** same `resource` keeps the
measured one, notes the superseded source in its evidence — which the dated sidecar keeps —
and prints how many collided.
Rendering the two separately instead would split one audit across two documents and two
baselines.

| Exit | Meaning |
|---|---|
| `0` | documents written — print the paths. A run with no findings is written too: the report says nothing was found, and its sidecar is the baseline the next audit diffs against |
| `1` | the run file is unusable, or a finding is incomplete — fix the run file and re-run |
| `3` | crash — report it and continue to Step 9 |

It writes `.wp-audit/informe-<AAAA-MM-DD>.md`, `.html`, and a machine sidecar `.json`.
The Markdown is for working and versioning; the HTML is a single self-contained file that
opens with a double click, forwards as an attachment and prints to PDF from the browser.
Hand over both and say which is which.

**The sidecar is what makes the next report comparable.** The renderer diffs this run
against the newest earlier sidecar and opens the document with resolved / new / still
failing, by finding identity rather than by count. It never parses its own Markdown back:
a report edited by hand would otherwise change what the next comparison claims happened.
A second run on the same day keeps the first: the renderer moves the earlier set to
`informe-<AAAA-MM-DD>-<HHMM>.*` before writing, and diffs against it.
The ledger and the sidecar are different records and both stay — the ledger is the
project's running history of every finding ever seen, a sidecar is one dated snapshot.

### The report goes out before anything is fixed

Run this step before Step 9, always, including when the user has already said to fix
everything. The dated report is the baseline the next audit measures against, so a run
that fixes first has no before to compare with, and the user cannot choose what gets
touched in their site without seeing the whole of it. Step 9 then works from the plan this
step wrote: tell the user how many rows are `code`, how many are `setting`, `content` and
`manual`, and that you can apply the first two and not the last two.
