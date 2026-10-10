# /wp-audit — Step 7.5

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

### Five statuses, and only one of them is a judgement

| Status | Meaning |
|---|---|
| `new` | not in the ledger before this run |
| `still_failing` | in the ledger, failing, and failing again now |
| `resolved` | in the ledger as failing, and **this run measured the same check and did not find it** |
| `accepted` | a human decided it stays; the audit stops re-raising it |
| `unmeasured` | the check did not run this time (wrong tier, no network) — its ledger entry is untouched |

**`resolved` is the one that can lie, so it is the one with a precondition.** A finding is
only resolved when the check that produced it actually ran and came back clean. A check that
did not run produces `unmeasured`, never `resolved` — otherwise running an audit without
Tier 2 would mark every Tier 2 finding fixed, and a report would show a site cleaning itself
up by being audited with less access than before.

`accepted` is set by a human and by nothing else. An audit never promotes its own finding to
accepted, and never demotes one: re-raising something a client has explicitly accepted, every
run, is how a report stops being read.

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

**A missing ledger means "no history", never "nothing ever failed".** It can be deleted,
gitignored, or simply never written by an older plugin version, and the audit cannot tell
those apart. Report it as absent and start one; do not report a first run as a project with
everything resolved.

### What the counts become

`issues_found` and `issues_fixed` stay in the manifest and are now **derived** from the
ledger rather than authoritative — kept because older reports and Step 2.5e read them, and
because a number is still the right thing to print in a summary. When the two disagree, the
ledger wins and the disagreement is worth reporting: it means a run wrote one and not the
other.
