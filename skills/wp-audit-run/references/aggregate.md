# /wp-audit — Step 7

`commands/wp-audit.md` sends the run here at Step 7. Follow it in order; nothing in it is optional background.

Collect reports from all agents. For each agent's output, parse the findings into a unified list. The parser is `bin/audit-report.mjs --agents <out>/agents` (Step 8.5): it normalizes the aliases agents drift into (`code` for `check`, `owner` for `ownership`, `fix: auto` for `auto_fixable`), refuses a finding with no catalog id or one also reported as a pass, and builds the run file's findings, so `run.json` is never hand-assembled.

**Deduplication** runs on three different keys, because three different things collide here.

*Different ids, one defect.* Owner and duplicate in the "Same defect, one owner" table of `wp-audit-standards` share its `root_cause`, folded as below.

*Two agents reporting the same place.* If the same `file:line` appears in multiple reports:
- Keep the highest-severity finding and drop the lower-severity duplicates
- Category claims: Security claims vulnerability checks, Practices claims coding-standards
  checks. ("Claims" names the auditor the check belongs to, not the finding's **owner** —
  Step 8.5's `code`/`setting`/`content`/`manual`, who applies the fix.)

*The suite and an agent reporting the same defect.* With `--suite`, a contrast failure or
missing description arrives twice: measured on a page and inferred from source.
**A measurement beats an inference.** They are the same defect only when the check **and**
the resource match — a contrast failure measured on `/contact` and one in a stylesheet rule
no audited page uses are two findings, and the second is the one nobody would find again.

This one is not applied by hand. `bin/audit-report.mjs --merge` does it in Step 8.5, keeping
the measured finding and recording the loser's code in its evidence so the ledger still
shows the check ran. Do not also dedupe them here: doing it twice drops the second copy
without recording that it existed.

**The resource convention both sides must share.** The merge matches on `check` + `resource`,
so a resource written two ways never matches and the duplicate survives:

| What the finding is about | `resource` |
|---|---|
| a page | `page:/contact/` — the path, with its trailing slash as the site serves it |
| a record | `post:412`, `menu_item:88`, `wp_options.siteurl` |
| a place in the code | `template-parts/hero.php:34` |
| a site-level judgement | `site` |

**A page-level finding is one row per page, not one per occurrence.** Three broken links on
`/contact/` are one `UX-014 : page:/contact/` whose evidence lists all three. One row per
link would match nothing the suite emits, and would turn a page with a bad footer into
forty findings that are one fix.

**One defect is one finding.** A production `display_errors` leak surfaces as a notice before
the document in security, both SEO files, the GEO head and performance. Agents tag these with
the same `Root cause:` slug, and `bin/audit-report.mjs` folds findings that share one into the
most severe, which lists the others under `also_affects` ("same cause: SEC-0xx site, …"). The
totals count the defect once. When no agent tagged it, the aggregator does: two findings whose
evidence quotes the same output line (the same notice text, the same header) get a shared slug
here, before the report runs. Findings with no root cause pass through untouched.

Sort all issues: CRITICAL first, then WARNING, then INFO.

Count totals per category and overall.
