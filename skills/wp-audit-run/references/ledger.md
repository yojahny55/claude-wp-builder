# /wp-audit — Step 7.5

## Contents

- A finding's identity is its check and its resource
- Six statuses, and only one of them is a judgement
- Recording a decision or a fix without auditing
- The shape of the file
- Where the ledger lives, and why not in the manifest
- The ledger is working state: it is not versioned
- What the counts become

`commands/wp-audit.md` sends the run here at Step 7.5. Follow it in order; nothing in it is optional background.

`issues_found`, `issues_fixed` and `carried_over` are three integers, and three integers
cannot answer the question every follow-up audit asks: **is this the same problem as last
time?** Fix one issue and find a new one and the count is unchanged while the contents
changed completely — Step 2.5e can report "25 carried over" and never say which 25. A number
that stays the same for two different reasons is not a measurement anyone can act on.

### A finding's identity is its check and its resource

```
SEC-036 : wp_options.siteurl
WP-048  : post:412.related_posts
SEO-054 : menu_item:88
A11Y-012: template-parts/hero.php:34
```

The resource comes from the evidence Step 6.9 already requires — the `$WP` call, the
`file:line`, the URL. **No new evidence is collected for this**; a finding that could not
name its resource could not have named its evidence either, and Step 6.9 already drops it.

The resource must be the most stable thing the evidence names. A `file:line` moves when
someone adds an import above it, so a rule that identifies its finding by line alone reports
every finding as resolved-and-new after any edit to the file. Prefer the record, the option
or the element; fall back to `file:line` only where nothing more stable exists, and accept
that those findings churn.

### Six statuses, and only one of them is a judgement

| Status | Meaning |
|---|---|
| `new` | not in the ledger before this run |
| `still_failing` | in the ledger, failing, and failing again now |
| `resolved` | in the ledger as failing, and **this run measured the same check and did not find it** |
| `accepted` | a human decided it stays; the audit stops re-raising it |
| `fixed_unverified` | a fix was applied since the last run and no check has re-run on it yet |
| `unmeasured` | the check did not run this time (wrong tier, no network) — its ledger entry is untouched |

**`resolved` is the one that can lie, so it is the one with a precondition.** A finding is
only resolved when the check that produced it actually ran and came back clean. A check that
did not run produces `unmeasured`, never `resolved` — otherwise running an audit without
Tier 2 would mark every Tier 2 finding fixed, and a report would show a site cleaning itself
up by being audited with less access than before.

**`fixed_unverified` is the honest name for a fix nobody has measured.** It is set by
`--mark-fixed` (below) and never by an audit. It is not `resolved`: only a run that measures
the same check on the same resource and does not find it turns it into `resolved`, and a run
that measures it and still finds it returns it to `still_failing` (clear `fixed_at` and
`fix_evidence`). A run that did not measure the check leaves it `fixed_unverified`, exactly as
it leaves a `resolved` entry untouched. Reports list it apart from the open findings and never
count it as resolved.

`accepted` is set by a human and by nothing else. An audit never promotes its own finding to
accepted, and never demotes one: re-raising something a client has explicitly accepted, every
run, is how a report stops being read.

### Recording a decision or a fix without auditing

Hand-editing the Markdown or HTML report, or keeping a decision in session memory, leaves the
ledger stale: a finding the client declined is proposed again next session, and fixes applied
between audits stay `new` for days. Use `bin/audit-report.mjs` instead. These commands run no
check and take no measurement; they only write the ledger (`--ledger <file>`, default the
manifest's `audit.findings_ledger.path`, else `.wp-audit-findings.json`).

```bash
R=${CLAUDE_PLUGIN_ROOT}/bin/audit-report.mjs
node $R --accept A11Y-028 --reason "client declined: targets under 24px" # every resource of the check
node $R --accept 'SEC-036:wp_options.siteurl' --reason "intentional on this host"
node $R --unaccept A11Y-028                                                 # back to its previous status
node $R --mark-fixed SEO-054:menu_item:88,SEO-055 --evidence "alt text added in the theme, commit abc123"
node $R --rerender                    # rebuild the newest .md/.html from its sidecar + the ledger
node $R --summary                     # counts by status and severity; add --json for scripts
```

An id is `check:resource` exactly as the ledger spells it, or a bare `check` for all of its
resources; several ids go comma-separated or by repeating the flag. An id the ledger and the
newest report both lack is refused, and nothing is written. `--accept` needs `--reason` and
`--mark-fixed` needs `--evidence`; both store the text and the date on the entry
(`accepted_reason`, `accepted_at`, `fix_evidence`, `fixed_at`). `--mark-fixed` skips an
`accepted` entry (unaccept it first) and a `resolved` one.

`--rerender` reflects the decisions in the report without a new audit: accepted entries leave
the headline counts, the plan and the next steps and get their own section, `fixed_unverified`
ones get theirs, and a note says no check was run again. It overwrites the documents and
sidecar of the newest report in place.

`--summary` is where counts come from. Quote the numbers it prints, never a total remembered
from earlier in the session; `open` there means `new` + `still_failing` + `unmeasured`.

Every step that lists pending or open work (the reuse offer in `re-audit.md`, the fix offer in
`fix.md`, a "what is left" summary) skips `accepted` entries, and shows `fixed_unverified`
ones as "awaiting verification", not as open and not as done.

### The shape of the file

```json
{"ledger_version":1,"findings":[{"check":"SEC-036","resource":"wp_options.siteurl","status":"still_failing","severity":"CRITICAL","first_seen":"<ISO>","last_seen":"<ISO>","evidence":"<command>"}]}
```

`findings` is an **array of entries**, not an object keyed by identity; read it with
`ledger["findings"]` and each entry's `check` and `resource`. Decision fields are added only
when set: `accepted_reason`, `accepted_at`, `previous_status`, `fix_evidence`, `fixed_at`.

### Where the ledger lives, and why not in the manifest

`.wp-create.json` is a **configuration** record. Every command parses it on every run to find
a WP-CLI wrapper and a theme slug, and `bin/wp-config.mjs` validates the whole of it. A
findings ledger is **audit history**: one command reads it, and it grows without bound — a
single check found 70 orphan ACF ids on one real site, which is 70 entries from one rule.
Putting that in the manifest makes `/wp-section` parse an audit's history to learn a theme
slug.

So the ledger is its own file, beside the manifest:

```
.wp-audit-findings.json
```

`audit.findings_ledger` in the manifest records only its path and the run that last wrote it
— a pointer, fixed in size.

### The ledger is working state: it is not versioned

`.wp-audit-findings.json` and the `.wp-audit/` report directory are **working state**, not
source. They are regenerable, they differ between a clone and the live site, and a committed
ledger turns every audit into a diff on a file nobody reviews. They are not versioned.

When the ledger is written (and before the first write on a project), run:

```bash
node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs gitignore-check <site-root>
```

Exit `0` means nothing to do (or the root is not a git work tree). Exit `4` lists the
entries git would commit, one `missing:` line each, from `TOOL_STATE_PATHS` in
`bin/wp-config.mjs`. Then warn in one line ("the audit ledger and reports are not ignored by
git") and ask with AskUserQuestion, default **yes**, whether to append the missing entries
to the root `.gitignore`. Append only those lines and touch nothing else in the file. On no,
do not ask again in this run.

This is the one exception to `/wp-adopt`'s "never edit `.gitignore`" rule: it covers only
entries this plugin owns, and only after the operator answers yes.

**A missing ledger means "no history", never "nothing ever failed".** It can be deleted,
gitignored, or simply never written by an older plugin version, and the audit cannot tell
those apart. Report it as absent and start one; do not report a first run as a project with
everything resolved.

### What the counts become

`issues_found` counts the open entries (`new`, `still_failing`, `unmeasured`); `accepted` and
`fixed_unverified` entries are in neither `issues_found` nor `issues_fixed`.

`issues_found` and `issues_fixed` stay in the manifest and are now **derived** from the
ledger rather than authoritative — kept because older reports and Step 2.5e read them, and
because a number is still the right thing to print in a summary. When the two disagree, the
ledger wins and the disagreement is worth reporting: it means a run wrote one and not the
other.
