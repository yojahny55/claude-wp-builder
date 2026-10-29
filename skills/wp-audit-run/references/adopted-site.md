# /wp-audit — Step 2.2

`commands/wp-audit.md` sends the run here at Step 2.2. Follow it in order; nothing in it is optional background.

The site was registered by `/wp-adopt`. This plugin built none of it,
so three assumptions made everywhere else are false here:

1. **The code is not one theme directory.** `code_scope.editable` lists the site's own code:
   the child theme, the site's own plugins, mu-plugins. `code_scope.read_only` lists vendor
   code: a commercial parent theme and third-party plugins. **Both lists are audited.**
   - Findings in editable code follow the normal rules.
   - Read-only code produces findings only from checks that affect the running site: a known
     vulnerability (SEC-041 and the vendor feeds), an available update, an abandoned plugin
     (SEC-042). Those are reported with `Fix: manual` and `Owner: manual`; their `Method` names
     the way around the vendor file, never an edit to it: an override in the child theme, a
     filter from the site's own plugin, or a report to the vendor.
   - Pattern hits in `code_scope.read_only` (a deprecated function, a missing `ABSPATH` guard,
     `eval()`, `unserialize`, raw `$wpdb->query` counts, `posts_per_page => -1`, `RAND()`, a
     coding-standard code of any category) are not findings. Each plugin gets **one** `INFO`
     line, `vendor notes: <slug> — <n> pattern hits (<codes>)`, with no fix and no weight in the
     headline or the totals. The same root cause reported under several codes is one hit.

   An update overwrites every file under a read-only path. A fix written there is lost at
   the next update and hides the defect until then.
2. **The plugin stack was not chosen by this plugin.** `stack.seo`, `stack.security`,
   `stack.fields`, `stack.multilingual`, `stack.builder` and `stack.cache` name what the site
   already runs. `none` means nothing was detected.
   - Never offer to install a second plugin for a concern the site's stack already owns.
     Rank Math beside Yoast, or AIOS beside Wordfence, is a new defect, not a fix.
   - Checks that read one plugin's options are `N/A (stack: <name>)` when that plugin is
     not the one in the stack. This covers Rank Math option checks on a Yoast site and AIOS
     configuration checks on a Wordfence site.
   - Checks that read the rendered output apply whatever plugin produced it: the head, the
     schema graph, response headers, the DOM.
3. **The i18n strategy was detected, not decided.** `polylang` when Polylang is active,
   otherwise `none`. `none` means the site is monolingual, or `stack.multilingual` names a
   plugin this one does not build for. `none` never falls back to `suffix`: an adopted site
   has no ACF `_<lang>` fields to check.

**A finding carries a catalog code.** The code must exist in the category's catalog (Step
2.5d). A pattern with no code is a note in the agent's report, never a finding: no
shard-local labels (`PERF-0xx` invented for one run, `SEC-ACCT`), and no code is reused with a
different meaning. Same-root-cause hits are grouped into one finding before they are counted,
so merging shards never raises the total.

Print it before the tier detection, so the scope of the run is visible up front:

```
=== Adopted site ===
  Editable code   <path>, <path>, …
  Read-only code  <path>, <path>, …   (audited, reported, never edited)
  Stack           seo=<…> security=<…> fields=<…> multilingual=<…> builder=<…> cache=<…>
```
