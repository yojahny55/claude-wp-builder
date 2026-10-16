---
description: Update WordPress core, plugins and themes safely — backup first, migrations, premium-license skips, verification and a rollback recipe
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
argument-hint: "[wp-root] [--plugins=a,b] [--exclude=a,b] [--core-only] [--yes]"
---

# WP Update — Backed-up, Verified Updates

Update core, plugins and themes of one WordPress root in a fixed order: **preflight, backup,
update, migrate, verify, report**. Nothing is updated before the backup exists and nothing is
reported as done before the verification ran. It works on a production root and on a local
clone; the clone gets extra checks (Step 6), production gets a confirmation gate (Step 0.3).

## Step 0: Parse Arguments and Resolve the Target

### 0.1 Arguments

| Argument | Description |
|---|---|
| `<wp-root>` | WordPress root (directory with `wp-config.php`). Default: the project root from `.wp-create.json`, else the working directory |
| `--plugins=a,b` | Update only these plugin slugs |
| `--exclude=a,b` | Update everything available except these slugs |
| `--core-only` | Update core only |
| `--yes` | Skip the "which updates" question (the backup and the production gate still run) |

### 0.2 Project context

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** exit `3` falls through to a bare `wp --path=<wp-root>` run
rather than stopping — this command also updates sites this plugin did not build.

Read the WP-CLI wrapper from `.wp-create.json` (`wp_cli.wrapper`), else use
`wp --path=<wp-root>`; call it `$WP` below.

### 0.3 Clone or production

Treat the root as a **local clone** when `.wp-create.json` has `project.source: "restore"` or
`wordpress.url_origin`, or `wordpress.url` is a non-public host (`localhost`, `*.local`,
`*.local.com`, `*.test`, private ranges) — the same rule `/wp-audit` uses. Otherwise it is
**production**: say so, recommend a maintenance window, and ask for explicit confirmation with
`AskUserQuestion` (`[A] Update now` / `[B] Stop`) before Step 2. `--yes` never skips this gate.

## Step 1: Preflight

1. WP-CLI must boot: `$WP core version`. If it fails with a drop-in error (object cache,
   advanced-cache), retry with `--skip-plugins --skip-themes` for the read-only listing and tell
   the user which drop-in is blocking; do not rename drop-ins without asking.
2. Record the start marks used by Step 5: the byte size of `wp-content/debug.log`
   (`stat -c %s`, 0 if absent) and the time. On a clone also record the enabled WooCommerce
   gateways and the active plugin list, for Step 6.
   When the site had performance work (see Step 5.3), also count the render-blocking scripts in
   the home page `<head>` now, for the same comparison afterwards:

   ```bash
   curl -s --max-time 30 <home-url> | sed -n '/<head/,/<\/head>/p' | grep -oE '<script\b[^>]*\bsrc=[^>]*>' | grep -vEc '\b(defer|async)\b|type="module"'
   ```

   If the repo has the shopper-flow regression suite (`.wp-audit/suite/`, see
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/browser-suite.md`), take its baseline
   now on a clone: `REGRESSION_LABEL=before npm run test:regression`.
   **Live gateway keys stop a clone here, before anything is updated.** On a clone, check
   `$WP option list --search='woocommerce_*_settings' --field=option_value | grep -E '(sk|rk|pk)_live_'`;
   a hit means the update would run against a payment account that can charge real customers.
   Report it and ask (`AskUserQuestion`) whether to disable the gateway first; do not go on
   without an answer.
3. List what is available:

```bash
$WP core check-update
$WP plugin list --update=available --fields=name,title,version,update_version --format=table
$WP theme list --update=available --fields=name,version,update_version,status --format=table
```

4. Show the three tables. Mark each theme that is the **parent of an active child theme**
   (`$WP theme list --fields=name,parent --format=csv`) as *held*: a commercial or customized
   parent is never updated without a separate question, because the child's overrides can break
   on a new parent. Ask which to update (`AskUserQuestion`: all / all except a list / only a
   list / core only), honouring the flags. If nothing is available, report that and stop.

## Step 2: Backup

Back up **before** any update, into a dated folder **outside the docroot** (default
`~/wp-update-backups/<site-slug>-<UTC timestamp>/`). Never write it under the WordPress root.

```bash
B=~/wp-update-backups/<site-slug>-$(date -u +%Y%m%dT%H%M%SZ); mkdir -p "$B"
$WP db export "$B/db.sql"
tar -czf "$B/plugins.tar.gz" -C <wp-root>/wp-content plugins
tar -czf "$B/core.tar.gz" --exclude=wp-config.php -C <wp-root> wp-admin wp-includes $(cd <wp-root> && ls *.php | grep -v '^wp-config\.php$')
```

`tar --exclude` must come **before** the operands (the file and directory names) or it has no
effect; the second pattern above also leaves `wp-config.php` out of the operand list so a
credentials file is not copied into the backup. Add `themes.tar.gz` when themes will be updated.
Verify each artifact is non-empty (`test -s`) and `gzip -t` / `tar -tzf` reads it; if any check
fails, stop. Uploads are not backed up here (updates do not touch them); say so in the report.

## Step 3: Update

Core, then plugins, then themes, each only if approved. Capture CSV so each item has a status.

```bash
$WP core update && $WP core update-db
$WP plugin update <slug> [<slug>...] --format=csv > "$B/plugin-update.csv"
$WP theme update <slug> [<slug>...] --format=csv > "$B/theme-update.csv"
```

Use `--all --exclude=<csv>` when the answer was "all except". Read the status column per plugin
(`Updated` / `Error`). One failing plugin does not stop the rest; record it.

**Premium plugins that answer `Download failed. "Unauthorized"`** (or a licence/401 error) have
a licence bound to the production domain. Report each as **skipped**, with the reason and the
options: update it in production, or upload the vendor zip manually. Never try to work around
licensing (no cracked zips, no licence-server spoofing, no editing the licence option). Record
**version skew** when a plugin and its companion moved apart — for example Elementor updated but
Elementor Pro not, or WooCommerce updated but one of its paid extensions not — and carry it to
Step 5 and the report as a regression-run flag.

## Step 4: Post-update Migrations

Run only those whose plugin is active (`$WP plugin is-active <slug>`), and record each result:

| Plugin | Command |
|---|---|
| WooCommerce | `$WP wc update` (database updates; skip when it reports none pending) |
| Elementor | `$WP elementor update db`, then `$WP elementor flush-css` |
| Elementor Pro | `$WP elementor update db --pro` — skip if Pro was skipped in Step 3 |

Then `$WP rewrite flush` if permalinks are in use and a plugin that registers post types or
endpoints changed, and `$WP cache flush`. A command that does not exist for the installed
version is reported, not retried with guessed flags.

## Step 5: Verify

1. **Key pages**: home, shop or blog index, one product or post, cart, checkout, `wp-login.php`
   (those that exist). For each, HTTP status and total time:
   `curl -s -o /dev/null -w '%{http_code} %{time_total}\n' -L --max-time 30 <url>`. Expect 200
   (login 200, cart/checkout 200). Paced requests only; on a public host do not burst.
2. **debug.log**: read only the bytes after the Step 1 mark; list new `Fatal error`,
   `Uncaught` and `Parse error` lines. A new fatal is a failure, not a note.
3. **Head scripts**: when the site had performance work (deferred or delayed scripts, or a
   page-cache/optimizer plugin), compare the render-blocking `<script src>` in the home page
   `<head>` with and without `defer`/`async`/`type=module` against the pre-update count taken
   in Step 1.2 (same command); a new blocking script is a regression to report.
4. **Regression suite**: if `.wp-audit/suite/` exists (the shopper-flow suite installed by
   `/wp-audit`), run `REGRESSION_LABEL=after npm run test:regression` there and
   `npm run regression:compare -- before after`, and quote the pass/fail counts. It is meant for
   a local clone and never places an order; it is not an audit pass, so do not point
   `bin/audit-suite.sh` at the site for this. On production do not run it unless
   the user asks, and then through `bin/prod-gate.sh` as `browser-suite.md` describes. A flow
   that went PASS to SKIP is a regression, not a note. If there is no baseline or no suite, say
   "regression suite not available" and list the manual flows to click (add to cart, checkout,
   login, search); do not invent a substitute. The first admin-side load after an update can
   time out while caches rebuild: retry that one section once before reporting it FAIL.
5. Extra attention to anything flagged as version skew in Step 3.

## Step 6: Clone-aware Checks

On a local clone, after Step 5, re-check that updates did not undo the
isolation. Read the state, change nothing without asking:

- Outgoing mail is still disabled (`wp-content/mu-plugins/00-clone-isolation.php` is still
  present; it captures mail at `pre_wp_mail`, so do not look for an overridden `wp_mail`).
- Payment gateways that are enabled now were already enabled in Step 1's list (`$WP eval`
  listing enabled WooCommerce gateways, compared with that list); a newly enabled one is a
  regression.
- `DISABLE_WP_CRON` and the disabled-plugin set are unchanged; no plugin that was inactive is
  now active.

Anything re-enabled is reported as a regression with the command that turns it off again;
offer it, do not run it silently. The live-gateway-key gate is in Step 1.2, before the update.

## Step 7: Report

Print one block, then the rollback:

- Versions before and after for core, each plugin and theme.
- Skipped items with reason (licence, held parent theme, excluded) and the next option.
- Migrations run and their outcome; version skew flagged.
- Verification: page table, new fatals (count), head-script result, suite result.
- Backup path and its contents.
- **Rollback**: `$WP db import "$B/db.sql"`; then restore files by extracting the matching tar
  over the root (`tar -xzf "$B/plugins.tar.gz" -C <wp-root>/wp-content` after removing the
  updated plugin directories; `tar -xzf "$B/core.tar.gz" -C <wp-root>` for core), then
  `$WP cache flush`. Database migrations in Step 4 are only undone by the db import, so restore
  both together.
