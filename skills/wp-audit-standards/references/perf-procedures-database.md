# Performance procedures — database bloat and attribution

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-performance.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before running PERF-061 to PERF-064 or PERF-071 to PERF-074.

## Contents

- Procedure — database bloat checks (PERF-061 to PERF-064)
- PERF-061 — Action Scheduler backlog not pruned
- PERF-062 — `woocommerce_sessions` oversized
- PERF-063 — expired-transient backlog exceeds prune budget
- PERF-064 — orphaned `postmeta`
- Procedure — database bloat attribution (PERF-071 to PERF-074)
- PERF-071 — Action Scheduler pending backlog with no live owner
- PERF-072 — one plugin floods `options`
- PERF-073 — Rank Math 404 monitor growth
- PERF-074 — orphan autoloaded options

### Procedure — database bloat checks (PERF-061 to PERF-064)

PERF-042 already reports every table's size, but as `INFO only` — it names no threshold, so a
table that has quietly grown to gigabytes reads exactly like one that hasn't. These four checks
give the patterns that actually cost request time or backup size a number to fail against.
None of them are clone artifacts: an Action Scheduler backlog, an oversized session table, an
old transient nobody ever reads again, and a dead `postmeta` row are just as real on production
as on a local copy, so they report `PASS`/`FAIL`/`INFO` normally — never suppressed the way
Step 2.3's local-clone table suppresses `DISABLE_WP_CRON` or a deactivated payment gateway.

Every SQL command below resolves the site's real table prefix at run time with
`$($WP db prefix)` rather than assuming `wp_` — the same non-`wp_` prefix
`.wp-create.json`/`.claude/CLAUDE.md` already record when the site has one. Do not hand-edit
these commands to hardcode `wp_<table>`: on a site whose prefix isn't `wp_`, that table simply
doesn't exist and the query errors out instead of reporting the finding. Prose below still
refers to each table by its generic `wp_<table>` name — that is shorthand for "the table this
check reports on", not a literal identifier to run.

**PERF-061 — Action Scheduler backlog not pruned.** WooCommerce, and several other plugins that
queue background work, ship the Action Scheduler library. Its own cleaner purges `complete`,
`failed` and `canceled` actions older than 30 days — but only while the cleanup event itself
keeps firing. A cron that stopped running, or a queue runner overwhelmed by its own backlog,
lets both `wp_actionscheduler_actions` and `wp_actionscheduler_logs` grow unbounded; every later
queue-claim query (`WHERE status = 'pending' ORDER BY scheduled_date ASC LIMIT …`) then scans a
bigger table on every request that touches the queue. Report `N/A` only when
`wp_actionscheduler_actions` does not exist — not when WooCommerce is inactive, since other
plugins load the same library. Fix: `$WP action-scheduler clean` (repeat, or pass
`--batch-size=<n>` for a backlog too large to clear in one pass) prunes both tables; it is safe
to run live, since it only ever removes actions already in a terminal state.

**PERF-062 — `woocommerce_sessions` oversized.** `WC_Session_Handler` writes one row per visitor
(logged in or not) and expires it after 48 hours by default; the twice-daily
`woocommerce_cleanup_sessions` cron event is what actually deletes expired rows; a broken or
disabled cron leaves them piling up, and every guest-cart request pays for a lookup against the
larger table. Report `N/A` only when `wp_woocommerce_sessions` does not exist (WooCommerce never
installed) — a site with WooCommerce present but no purchase traffic still has the table and
still accumulates crawler/bot sessions that must count. Fix:
`$WP eval "do_action('woocommerce_cleanup_sessions');"` runs the same cleanup the cron would,
immediately, instead of waiting for the next scheduled run.

**PERF-063 — expired-transient backlog exceeds prune budget.** PERF-039 already flags *any*
expired transient as `INFO` — that check exists because `get_transient()` only deletes a
transient's rows lazily, on the next read, so one left over from a plugin's old cache key that
nothing reads anymore never gets cleared on its own. PERF-063 does not duplicate that check; it
escalates the same underlying data once it has piled up enough to matter for the `wp_options`
table's physical size (`mysqldump`/migration weight, `ANALYZE TABLE` cost) rather than merely
existing. Report the row count and byte sum together — a handful of large serialized values can
cross the byte budget well before the row count does. The `LIKE` pattern escapes its leading
underscores (`\_transient\_timeout\_%`) rather than leaving them bare: MySQL treats an
unescaped `_` as a single-character wildcard, which blocks the range scan on the `option_name`
index and forces a full table scan of `wp_options` on every run — escaped, the same query reads
the index instead. The join to the value row is a `LEFT JOIN`, not an inner one, and its
byte sum is wrapped in `COALESCE(…, 0)`: an inner join would silently drop a timeout marker
whose `_transient_<key>` value row was already deleted out from under it — undercounting
against PERF-039's own plain `COUNT(*)` of the same expired markers, which has no such join to
lose rows through. The join condition itself is written as
`CONCAT('_transient_', SUBSTRING(t.option_name, LENGTH('_transient_timeout_') + 1))`, never
`REPLACE(...)`: WP-CLI's `db query` scans the query text for `UPDATE`/`DELETE`/`INSERT`/
`REPLACE`/`LOAD DATA` (case-insensitively, as a whole word) and treats a match as a
row-modifying statement, printing only `Rows affected: -1` instead of the result set — a
`REPLACE()` string function trips the same detection as the `REPLACE INTO` statement it exists
to catch. None of PERF-061/062/064's cells may pick up one of those words either, for the same
reason. Fix: `$WP transient delete --expired`.

**PERF-064 — orphaned `postmeta`.** A `wp_postmeta` row whose `post_id` no longer resolves to a
row in `wp_posts` is left behind when a plugin (or a direct `$wpdb` delete) removes a post
without calling `wp_delete_post()`, which is what actually cascades the meta delete. This is
`postmeta` rows with no owning post — a different defect from WP-048 in `wp-audit-practices`,
which is about a *live* post's ACF/relationship field still pointing at another post's ID after
that post was deleted; here the post owning the meta itself is gone. Report the count.
**Never auto-fix this finding.** The cleanup is a bulk delete, which is irreversible the
moment it runs, so require an export first: `$WP db export`. On a small backlog, the single
statement from the row above works: `$WP eval 'global $wpdb; $wpdb->query("DELETE pm FROM {$wpdb->prefix}postmeta pm LEFT JOIN {$wpdb->prefix}posts p ON p.ID = pm.post_id WHERE p.ID IS NULL");'`.
A `DELETE … LEFT JOIN …` cannot take a `LIMIT` — MySQL rejects `LIMIT` on a multi-table
delete — so on a backlog in the hundreds of thousands, batch it instead with a subquery that
can be limited, materialized in a derived table (`x`) so MySQL will not refuse "you can't
specify target table for update in FROM clause": run this repeatedly, in a loop, until it
reports 0 rows affected, so no single statement holds a long table lock on a live site:

```
$WP db query "DELETE FROM $($WP db prefix)postmeta WHERE meta_id IN (SELECT meta_id FROM (SELECT pm.meta_id FROM $($WP db prefix)postmeta pm LEFT JOIN $($WP db prefix)posts p ON p.ID = pm.post_id WHERE p.ID IS NULL LIMIT 5000) x);"
```

### Procedure — database bloat attribution (PERF-071 to PERF-074)

PERF-061 to PERF-064 count rows; these four say *whose* rows they are, because the fix is
different: pruning a table that a live plugin refills in an hour fixes nothing, while a
backlog written by a plugin that is off, deleted or never connected is dead weight to remove at
the source. Like PERF-061 to PERF-064 they are real on production, so they report normally. The
one clone-aware input is "is the plugin active": on a local clone read `Clone-suppressed
plugins` from the dispatch (the names the security agent uses) and treat those as **active**,
never as inactive — they were switched off by the copy, not by the owner. Never infer that list
from which plugins are inactive. Every command resolves the real prefix with `$($WP db prefix)`
(or `$wpdb->prefix` inside `$WP eval`), never `wp_`, and every query below is a read-only
`SELECT`. **No fix here is auto-applied**: each deletes data, so each requires explicit approval
and a prior `$WP db export`.

**PERF-071 — Action Scheduler pending backlog with no live owner.** PERF-061 counts finished
rows; this one counts `pending` ones, which nothing prunes, because Action Scheduler assumes a
pending action will run. A plugin that schedules work for an integration that was never
connected (or whose plugin was removed, leaving its recurring schedules) never completes
them. One real case: 1,885,748 pending actions, plus a log row each, from two ad-platform
plugins for WooCommerce that had never been connected; `actionscheduler_actions` and
`actionscheduler_logs` weighed about 2 GB and every queue-claim query scanned them. Run the
query in the row, then map each group slug and hook prefix to a plugin: the group is usually the
plugin's slug or name, otherwise match the hook prefix against `$WP plugin list` slugs
(underscores and hyphens interchangeable) and against the source with
`grep -rl '<hook>' wp-content/plugins`. Report `WARNING` when a group/hook prefix exceeds
10,000 pending rows, or exceeds 1,000 and its plugin is inactive, not installed, or active but
has no connection or credentials configured. Name plugin, hook prefix, count and the
oldest `scheduled_date`. Report `N/A` only when the table does not exist, not when WooCommerce
is off. Fix, with approval and a backup: deactivate and remove the plugin if it is unused,
then delete its rows in batches of about 50,000 (actions and their logs, so no
orphan log rows are left), repeating until 0 rows are affected so no statement holds a long
lock: `$WP db query "DELETE FROM $($WP db prefix)actionscheduler_actions WHERE status='pending' AND hook LIKE '<prefix>%' LIMIT 50000;"`,
then `DELETE` the matching `actionscheduler_logs` rows whose `action_id` no longer exists
(same batching) and `OPTIMIZE TABLE` both. Do not use `$WP action-scheduler clean` for this:
it only ever touches terminal states.

**PERF-072 — one plugin floods `options`.** PERF-063 sizes the expired-transient backlog as a
whole; this one groups every `options` row by the plugin-looking prefix of its name, after
stripping `_transient_timeout_`, `_transient_`, `_site_transient_timeout_` and
`_site_transient_` (a transient and its timeout row then land in the same group). The prefix is
the first two `_`-separated segments, a heuristic: confirm the owner by searching the plugin
sources for the full prefix before naming it. Flag any single prefix with more than 10,000
rows, with its row count and byte sum. One real case: about 739,000 temporary options written
by one cart-recovery plugin took `options` from 36 MB to 200 MB, and only showed up in
PERF-042's table list as a big table with no owner. Core prefixes (`widget_`, `theme_mods_`,
`wc_`/`woocommerce_` session and note data) can legitimately be large; read the group before
calling it a finding. Fix, with approval and a backup: fix or remove the plugin first (otherwise
it refills), then delete in batches by prefix,
`$WP db query "DELETE FROM $($WP db prefix)options WHERE option_name LIKE '\_transient\_<prefix>%' OR option_name LIKE '\_transient\_timeout\_<prefix>%' LIMIT 50000;"`,
repeated until 0 rows are affected. Never delete non-transient options by prefix without
reading what they hold.

**PERF-073 — Rank Math 404 monitor growth.** PERF-060 (and `wp-audit-rankmath`) only check that
`rank_math_404_logs` exists; neither looks at how big it has become. In advanced mode with
no limit the monitor logs every distinct 404 request with its referrer and user agent, and
bot probing makes it grow without bound. One real case: 289,340 rows (78 MB) after months of
scanner traffic; simple mode with a limit of 30,000 and a compaction brought it to 16,292 rows
(9 MB). Read the three values once; do not hardcode the option keys, print every key that
mentions `404` since Rank Math has renamed them across versions:

```bash
$WP eval 'global $wpdb; $t=$wpdb->prefix."rank_math_404_logs"; if($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s",$t))!==$t){echo "N/A: no table".PHP_EOL;return;} echo "rows=".$wpdb->get_var("SELECT COUNT(*) FROM `$t`").PHP_EOL; echo "mb=".$wpdb->get_var($wpdb->prepare("SELECT ROUND((data_length+index_length)/1048576,1) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=%s",$t)).PHP_EOL; foreach((array)get_option("rank-math-options-general",[]) as $k=>$v){ if(false!==strpos($k,"404")){ echo $k."=".(is_scalar($v)?$v:wp_json_encode($v)).PHP_EOL; } }'
```

`WARNING` when the table is over 30,000 rows or 20 MB, or the mode is advanced and no limit
is set (a limit of 0 or empty). `N/A` when the 404 Monitor module is off
(`rank_math_modules` has no `404-monitor`) or the table is missing (that is PERF-060's
finding). Fix, with approval and a backup: in Rank Math > General Settings > 404 Monitor, use
simple mode or set a log limit (30,000 was workable), then trim the table, keeping the newest
rows, in batches. The Rank Math UI's "Clear Log" empties it entirely, which is acceptable only
when the log history is not wanted.

**PERF-074 — orphan autoloaded options.** PERF-036/037 report how much autoloaded data there is
and which ten are heaviest; they do not say whose it is. Options left by a plugin or theme that is
no longer installed (an installer library of a removed multilingual plugin, a deleted slider, an
inactive coming-soon plugin) are loaded by `wp_load_alloptions()` on every request for nothing. One
real case: 23 such options turned to autoload off took the autoloaded payload from 420 KB to
232 KB. List the autoloaded options (same `IN ('yes','on','auto-on','auto')` filter as PERF-036: WP
6.6+ writes `on`/`auto`, not only `yes`) whose first name segment does not match any installed
plugin or theme:

```bash
$WP eval 'global $wpdb; $slugs=[]; foreach(array_keys(get_plugins()) as $f){ $slugs[]=strtolower(preg_replace("/[^a-z0-9]/i","",dirname($f)==="."?basename($f,".php"):dirname($f))); } foreach(wp_get_themes() as $s=>$th){ $slugs[]=strtolower(preg_replace("/[^a-z0-9]/i","",$s)); } $core="/^(siteurl|home|blog|admin_email|users_can|default_|comment|ping|posts_per|date_format|time_format|start_of_week|permalink|rewrite|active_plugins|template|stylesheet|current_theme|theme_mods|widget|sidebars|cron|recently_|user_roles|wp_|fresh_site|db_|initial_|show_|upload|use_|thumbnail|medium|large|image|site_|page_|category|tag_|link_|mailserver|moderation|gmt_offset|timezone|WPLANG|auto_|finished_|can_compress|embed|wp_user_roles|nav_menu|sticky|blogname|blogdescription|admin_|woocommerce|action_scheduler|_)/i"; $rows=$wpdb->get_results("SELECT option_name, LENGTH(option_value) AS b FROM {$wpdb->options} WHERE autoload IN (\x27yes\x27,\x27on\x27,\x27auto-on\x27,\x27auto\x27)"); $tot=0; foreach($rows as $r){ if(preg_match($core,$r->option_name)){continue;} $p=strtolower(preg_replace("/[^a-z0-9]/i","",strtok(ltrim($r->option_name,"_"),"_-"))); if(strlen($p)<3){continue;} $hit=false; foreach($slugs as $sl){ if(0===strpos($sl,$p)||0===strpos($p,$sl)){$hit=true;break;} } if(!$hit){ $tot+=$r->b; echo $r->b."\t".$r->option_name.PHP_EOL; } } echo "orphan_bytes=".$tot.PHP_EOL;' | sort -rn | head -40
```

The match is a name heuristic, because options carry no owner column: a vendor-prefixed option
(an options library, an SDK shared by several plugins) can match nothing and still be live, and a
plugin whose option prefix differs from its slug will be listed. That is why the result is
`INFO`, a list to review, never a delete list; promote it to `WARNING` only when the orphan
total passes 100KB after you have confirmed the owners by searching the source of every large
entry. Installed plugins count whether active or not, and on a local clone the
`Clone-suppressed plugins` count too, so the result is the same on production and on a clone.
Fix, with approval and a backup: set the confirmed orphans to autoload off rather than deleting
them (`$WP option autoload set <name> off`, WP-CLI 2.10+, otherwise `UPDATE` the `autoload`
column to `off` through `$wpdb`), which is reversible and removes the per-request cost. Delete
them only after the owner is confirmed gone for good.

**Autoload budget — already covered, not duplicated here.** PERF-036 already reports the summed
autoloaded-options size against an ≤800KB threshold at `WARNING`, and PERF-037 already lists the
heaviest ten. Autoloaded options are the one bloat pattern in this group that loads on *every*
request (`wp_load_alloptions()`), which is why that pair was already a real threshold rather than
`INFO only` — there is nothing missing to add a new code for. Both queries filter
`autoload IN ('yes','on','auto-on','auto')`, not `autoload='yes'` alone: WP 6.6 added the
per-option autoloading heuristic (`wp_autoload_values_to_autoload()`), so a 6.6+ install can
write `on`, `off`, `auto-on`, `auto-off` or `auto` and never write `yes` at all — a query that
only matches `'yes'` silently under-reports, or on a site with no `'yes'` rows at all, reports
nothing.
