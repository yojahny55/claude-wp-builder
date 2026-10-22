---
description: Clone a remote or staging WordPress site to a local development environment
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "--from=ssh://user@host/path --to=/var/www/html/local [--force]"
---

# WP Clone — Remote/Staging Site Cloning

Clone an existing WordPress site into a local development environment. Supports three paths: automated SSH-based cloning, manual import from a SQL dump + uploads archive, or a restore from a full-site files archive + database dump (hosting-panel backup).

## Step 0: Parse Arguments

Parse `$ARGUMENTS` for the following flags:

| Flag | Required | Description |
|------|----------|-------------|
| `--from=` | Path A only | SSH URL: `ssh://user@host/path/to/wordpress` |
| `--to=` | Yes | Local destination path (e.g., `/var/www/html/local-clone`) |
| `--sql=` | Path B only | Path to a SQL dump file (e.g., `/tmp/dump.sql`) |
| `--uploads=` | Path B only | Path to uploads zip/tar archive (e.g., `/tmp/uploads.zip`) |
| `--files=` | Path C only | Full-site archive of the docroot (`.zip`, `.tar.gz`, `.tgz`, `.tar`) |
| `--db=` | Path C only | Database dump (`.sql`, `.sql.gz`, `.gz`, `.zip`) |
| `--strip=`, `--url-old=`, `--exclude=`, `--uploads-target=`, `--keep-config`, `--keep-plugins`, `--admin-user=` | No (Path C) | Docroot depth, source URL, patterns not to extract (repeatable), a directory on another disk for uploads (symlinked), keep the archive's `wp-config.php`, skip plugin deactivation, administrator to create |
| `--force` | No | Proceed when the destination already holds a WordPress site. The backup in Step 1.5 is still taken — `--force` means "I know what is there", not "skip the safety net" |

**Parsing rules:**

- If `--from=` starts with `ssh://`, extract `user`, `host`, and `remote_path` from `ssh://user@host/path`.
- If `--to=` is missing, ask the user for a local destination path.
- If neither `--from=` nor `--sql=` is provided, ask the user which path they want:
  > "How would you like to clone?
  > A) SSH — automated pull from a remote server
  > B) Manual — import from a SQL dump file + uploads archive
  > C) Site archive — restore from a full-site files archive + database dump"

## Step 1: Determine Clone Path

| Condition | Path |
|-----------|------|
| `--from=ssh://...` is provided | **Path A — SSH Automated** |
| `--files=` is provided (with `--db=`) | **Path C — Site Archive Restore** |
| `--sql=` is provided | **Path B — Manual Import** |
| Neither provided | Ask user (see Step 0) |

---

## Step 1.5: The Destination Gate

**Run this immediately before any `wp db import` or uploads sync, on both paths.** It is
written once here because both paths perform the same destructive act and a second copy
would drift; it does not execute here, because the destination is not knowable until the
path is chosen — under Path A, `/wp-create` may create it during this very run.

A dump carries `DROP TABLE` / `CREATE TABLE`, so `wp db import` does not merge into the
destination database: it replaces it. `rsync` into `wp-content/uploads/` overwrites
matching paths. Neither asks first, and neither leaves a copy behind.

The destination is a local development site — which is exactly where unpushed work lives:
seeded content, ACF values, test orders, a demo built this afternoon. `/wp-seed` has an
entire ownership model to avoid overwriting a client's work inside a database. Replacing
that database wholesale was, until this gate, one command with no prompt.

**Never import into production.** When the destination's `.wp-create.json` has `environments`,
a `role: "prod"` entry whose host matches the destination's `wordpress.url` (scheme and `www.`
ignored) stops the clone here, whatever the flags: `--force` does not override it. The same
entries tell Path A which environment is the source (`role: "prod"` or `"staging"`).
Without `environments`, the checks below are all there is.

### 1.5.1: Is the destination occupied?

```bash
bash -c "$WP db tables --format=count 2>/dev/null || echo 0"
bash -c "find wp-content/uploads -type f 2>/dev/null | wc -l"
```

**An empty destination proceeds silently.** That is the ordinary case — a fresh
`/wp-create` environment — and a gate that announces itself on every ordinary run is a gate
people learn to skip past. It speaks only when there is something to lose.

### 1.5.2: Back up what is about to be replaced

Whenever the destination is occupied, back it up **before** asking anything:

```bash
bash -c "mkdir -p ~/.wp-clone-backups"
bash -c "$WP db export ~/.wp-clone-backups/<project-slug>-$(date -u +%Y%m%dT%H%M%SZ).sql"
```

**The backup goes outside the project directory on purpose.** A backup inside
`wp-content/` shares the fate of the thing it protects: the next clone's `rsync` reaches it,
and so does an `rm -rf` of a project someone has given up on. `~/.wp-clone-backups/` is the
one place that survives both.

**Path C** also archives the code it will overwrite (`path-c.md` C4); the export is database-only.

Print the full path on its own line. A backup whose location the operator has to reconstruct
is not one they will find at the moment they need it.

### 1.5.3: Say what is there, then refuse

Do not ask "overwrite?" — nobody can answer that. Say what would be lost:

```bash
bash -c "$WP option get blogname"
bash -c "$WP post list --post_type=any --post_status=any --format=count"
bash -c "$WP post list --post_type=any --post_status=any --orderby=modified --order=desc --format=csv --fields=post_title,post_modified | sed -n 2p"
```

```
Error: the destination already holds a WordPress site.

  Site:          Client Demo
  Content:       47 posts and pages
  Last modified: "Services" — 2026-09-19 14:02 (2 hours ago)
  Uploads:       312 files

Importing replaces this database. A backup was written first:
  ~/.wp-clone-backups/client-demo-20260919T161145Z.sql
(Path C also replaces code: it was archived beside it as `*-code-*.tar.gz`; uploads were not.)

Re-run with --force to proceed, or clone into a different path.
```

"47 posts, last modified two hours ago" is a question an operator can answer. "Overwrite?"
is one they can only guess at, and a guess at this prompt costs a day of work.

### 1.5.4: `--force` proceeds, and still backs up

`--force` means "I know what is there", never "skip the safety net". The export costs seconds
and is the only thing that makes the decision reversible; tying it to the flag would remove
the backup from precisely the runs most likely to need it. Report the backup path under
`--force` too.

### 1.5.5: Carry the path into the summary

The backup path appears in the Step 6 summary, not only in this step's output — by the time
the clone finishes, this step has scrolled away.

---

## Path A — SSH Automated Clone

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-clone-run/references/path-a.md` now and follow
it — it is this path, not background. It covers A1 to A13: prerequisites, SSH and remote WP-CLI checks, the remote dependency inventory, the database export and download, the uploads rsync, the local /wp-create, the import, the URL search-replace and the fix-up.

---

## Path B — Manual Import Clone

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-clone-run/references/path-b.md` now and follow
it — it is this path, not background. It covers B1 to B7: validating the provided files, the local /wp-create, the import, the dependency inventory from the database, the uploads extraction, the original domain, the URL search-replace and the fix-up.

---

## Path C — Site Archive Restore

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-clone-run/references/path-c.md` now and follow
it — it is this path, not background. It covers C1 to C8: validating the files, the local /wp-create, reading the docroot depth, table prefix and source URLs, extracting the site (optionally with uploads on another disk), reconciling wp-config.php, the import, the URL search-replace and the local safety steps.

---

## Step 5.4: Isolate the Clone — before the import

**Both paths arrive here before `wp db import`, and nothing may boot WordPress until it
has run.**

This used to live inside Step 5.5, after the import and after the fix-up commands. That
ordering was wrong, and the isolation test could not see it because it only asserted that
5.5 came before Step 6. Between the import and Step 5.5 both paths run `wp search-replace`
and `wp rewrite flush`; `rewrite flush` fires `init` with the *source site's* plugins
active, and Path B additionally runs `wp plugin list` and `wp option list` to build its
dependency inventory. Every one of those loads production code against a production
database on a machine that is not production — before the mail guard existed. A
subscription plugin that mails on `init`, or a webhook that fires when a rewrite rule is
rebuilt, had already acted by the time isolation was applied.

Both measures below are **file** operations — a must-use plugin and a `wp-config.php`
constant. Neither needs the database, so neither has to wait for the import, and both
survive it: `wp db import` replaces tables, not files. That is what makes moving them
earlier possible rather than merely desirable.

What stays in Step 5.5 is the part that genuinely cannot run yet: `blog_public` is a row in
`wp_options`, so setting it before the import writes a value the import then overwrites.

### 5.4.1: Stop outbound mail

Write `wp-content/mu-plugins/00-clone-isolation.php` in the clone (create `mu-plugins/`
if absent):

```php
<?php
/**
 * CLONE ISOLATION — delete this file if this site ever becomes real.
 *
 * Written by /wp-clone. This site is a copy of another one and must not act
 * on its behalf. Mail is captured to wp-content/clone-mail.log instead of sent.
 */
defined( 'ABSPATH' ) || exit;

add_filter( 'pre_wp_mail', function ( $null, $atts ) {
    $to = is_array( $atts['to'] ) ? implode( ', ', $atts['to'] ) : (string) $atts['to'];
    error_log(
        sprintf( "[%s] BLOCKED to=%s subject=%s\n", gmdate( 'c' ), $to, (string) $atts['subject'] ),
        3,
        WP_CONTENT_DIR . '/clone-mail.log'
    );
    return true; // reported to the caller as sent; nothing leaves the machine
}, 0, 2 );
```

**`pre_wp_mail` is the right seam, and a mail plugin is not.** Every sender — core password
resets and new-user notices, WooCommerce order and subscription mail, Contact Form 7 —
goes through `wp_mail()`, and this filter short-circuits all of them at once. Disabling an
SMTP plugin instead does not stop sending: core falls back to PHP `mail()`, so the site
keeps mailing and merely stops logging it where anyone would look.

Returning `true` matters as much as intercepting. `wp_mail()` reports success to its caller,
so WooCommerce marks the order email sent and does not retry, and no plugin enters a failure
path that a real send would never have triggered. The clone behaves like the original
everywhere except at the wire.

**What this does not stop:** code that drives PHPMailer directly never calls `wp_mail()`, and
a plugin that replaces `wp_mail()` wholesale (SMTP plugins do) skips the filter. Redefining
`wp_mail()` in the mu-plugin is stronger: must-use plugins load before regular ones, so a
definition guarded by `function_exists` wins.

A **must-use** plugin, because it cannot be deactivated from wp-admin, survives any plugin
being reactivated, and cannot be undone by an option write. Its filename sorts first and its
header says what it is, so nobody mistakes it for part of the site.

### 5.4.2: Stop scheduled jobs

```bash
bash -c "$WP config set DISABLE_WP_CRON true --raw --type=constant"
```

WordPress spawns cron on page loads. On a store clone the due queue is the source site's:
subscription renewals, abandoned-cart mail, scheduled publishes — all of them wanting to run
against whatever integrations the database still points at. `/wp-debug` already reports this
constant, so the state is visible afterwards.

### 5.4.3: Park the cache drop-ins

```bash
for d in object-cache.php advanced-cache.php; do
  if [ -f "wp-content/$d" ]; then mv -n "wp-content/$d" "wp-content/$d.bak"; fi
done
bash -c "$WP config get WP_CACHE --type=constant" >/dev/null 2>&1 \
  && bash -c "$WP config set WP_CACHE false --raw --type=constant"
```

A production `wp-content/object-cache.php` (Redis or Memcached) or `advanced-cache.php`
(page cache) is loaded by WordPress even under `--skip-plugins`. Without that backend on the
local machine, every WP-CLI call fails ("Error establishing a Redis connection"), including
the import fix-up, and a page-cache drop-in would serve pages with production URLs. Park them
as `<name>.bak`, never delete, so the operator can restore them, and set `WP_CACHE` to
`false` when `wp-config.php` defines it as true. Do this before the first command that boots
WordPress. Record each parked file and the `WP_CACHE` change in the clone report and in the
manifest, so nobody ships the `.bak` state back to production.

## Step 5.5: Isolate the Clone — after the import

**Both paths arrive here, and nothing may load the site in a browser before this step
runs.** Step 6 below loads WordPress and then tells the operator to go visit it — that page
load is the moment an uncontained clone acts in front of a human, and by then every send is
already out.

Step 5.4 has already stopped mail and cron, before anything booted WordPress. What is left
here needs the imported database to exist first, and the confirmation that re-checks all of
it in one place.

A clone carries the source site's whole configuration: its mail settings, its payment
credentials, its webhook URLs, its scheduled jobs. None of that knows it has been copied.
Everything up to this point has faithfully reproduced a production site on a machine that
is not production, and reproducing it faithfully is exactly the problem.

### 5.5.1: Keep it out of search results

```bash
bash -c "$WP option update blog_public 0"
```

### 5.5.2: Disable payment gateways, report the other live integrations

**Payment gateways are disabled, not only reported.** A clone must never be able to charge or
refund a real customer, and a gateway that stays enabled with live keys can. Before
deactivating anything, list the gateways that are on and the plugin that owns each (WooCommerce
only; skip when it is not active):

```bash
$WP eval 'if ( function_exists( "WC" ) ) { foreach ( WC()->payment_gateways()->payment_gateways() as $id => $g ) { if ( "yes" === $g->enabled ) { echo $id, "\t", ( new ReflectionClass( $g ) )->getFileName(), "\n"; } } }'
```

Turn off **every** enabled gateway except an allow-list of the core gateways that hold no remote
credentials: `bacs`, `cheque`, `cod`. A rule naming "the dangerous ones" misses core's PayPal
Standard (API credentials for refunds) and gateways defined in a theme or mu-plugin. For each
other gateway:

- set `enabled` to `no` in `woocommerce_<gateway>_settings`
  (`$WP option patch update woocommerce_<id>_settings enabled no`), so reactivating its plugin
  does not bring it back on;
- when its class file is under `wp-content/plugins/<slug>/` and `<slug>` is not `woocommerce`,
  also deactivate that plugin (`$WP plugin deactivate <slug>`);
- when it lives in a theme or mu-plugin there is no plugin to deactivate: the `enabled` setting
  is the only switch, and the report names the file.

List every gateway touched in the report: id, plugin or file, action.

**Warn that the keys are still there.** The API keys stay in `woocommerce_<gateway>_settings`,
and reactivating a gateway on the clone points at the real API. A bug that needs the payment
flow reproduced is a decision the operator takes on purpose, with test credentials.

The rest is **reported, not changed**: search the clone for credentials and endpoints that
still address production, and say what each is, where it lives and what it points at.

```bash
bash -c "$WP option list --search='*_webhook*' --format=table"
bash -c "$WP option list --search='*_live_*' --fields=option_name --format=table"
bash -c "$WP plugin list --status=active --field=name | grep -iE 'stripe|paypal|mailchimp|zapier'"
```

The one thing not to leave to a decision is **real customer data**, which is already on the
disk by the time this step runs. Say so plainly in the report, and name the remedy:
`/wp-anonymize` replaces the records in a named catalog and reports every table it did not
examine. It is a separate operation and stays one — it is irreversible, it is not always
wanted (a bug in checkout may need the real order that triggered it), and inferring it from
a clone would make an unasked-for destructive write the default.

Naming it *here* is the point. This report is the one moment an operator is looking at the
sentence "this database holds real customer records", and a remedy documented anywhere else
is one they read for the first time after they have already handed the database on.

### 5.5.3: Confirm the isolation took

```bash
bash -c "test -f wp-content/mu-plugins/00-clone-isolation.php && echo 'mail: captured' || echo 'mail: NOT ISOLATED'"
bash -c "$WP eval \"echo defined('DISABLE_WP_CRON') && DISABLE_WP_CRON ? 'cron: disabled' : 'cron: STILL RUNNING';\""
bash -c "$WP option get blog_public"
```

**Any line reporting a failure stops the clone here.** Do not continue to Step 6, which loads
the site. A clone that cannot be isolated is not a clone that should be opened, and the
honest report is that it is unsafe to visit — not a summary with a warning buried in it.

---

## Step 6: Post-Clone Verification

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-clone-run/references/verify.md` now and follow
it — it is this step, not background. It covers 6.1 to 6.7: WordPress loads, URLs, admin access, theme, plugins, the HTTP check and the clone summary.

