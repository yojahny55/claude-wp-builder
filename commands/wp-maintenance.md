---
description: Turn maintenance mode on or off — a 503 page for visitors while editors keep working, stores included
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "on [--retry-after <seconds>] | off | status [--force]"
---

# /wp-maintenance — close the site to visitors, keep it open to editors

A site that is being migrated, reworked or waiting for launch needs to tell visitors and
crawlers "come back later" without locking out the people working on it. WordPress core's
`.maintenance` file (what `wp maintenance-mode activate` writes) is not that: it locks out
administrators too and is meant for the minutes of an update. This command uses a theme-owned
switch instead: the theme answers `503` with a `Retry-After` header to every visitor who
cannot `edit_posts`, and editors see the real site.

## Step 1: Gate

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report". The path travels as a positional argument, never inside the `-c` string: write it in single quotes, and a path that holds a single quote gets each one written as `'\''`.

```bash
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Read the WP-CLI wrapper once and use it as `$WP` below:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" wp_cli.wrapper' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Read `.claude/CLAUDE.md` for the function prefix and the theme directory and slug. `<theme>`
is the theme that owns the `functions.php` this command edits — on a child theme, the child,
never its parent. If it is missing, tell the user to run `/wp-init` first and stop.

## Step 2: Arguments

`$ARGUMENTS` starts with the action: `on`, `off` or `status`. No action, or any other word:
print the usage line and stop. `--retry-after <seconds>` applies to `on` only (default
`3600`); the theme clamps it to between 60 seconds and 7 days. `--force` lets Step 4 replace
an `inc/maintenance.php` that no longer matches the template.

## Step 3: Stores use the same switch

A store gets the theme switch too. **Do not use WooCommerce's coming-soon mode for
maintenance.** It answers `200` with no `Retry-After`, so crawlers index the notice; it lets
through only `manage_woocommerce`, so an editor is locked out; and it leaves the REST and
Store APIs open. It is launch state, owned by `/wp-woo-setup`, and this command never writes it.
On a store, read it and report it beside the result:

```bash
$WP plugin is-active woocommerce && $WP option get woocommerce_coming_soon
```

The theme switch closes the Store API to anonymous requests along with the rest of REST, so
no cart or checkout runs while the site is closed; shop managers can `edit_posts` and work through it.

## Step 4: Install the theme switch (`on` only)

The PHP is not written by you. It is a fixed file,
`${CLAUDE_PLUGIN_ROOT}/templates/maintenance/maintenance.php`, held to the PHP 7.4 floor.
**Copy it and substitute the two tokens; do not retype or "improve" it.**

| Token | Replace with |
|---|---|
| `__prefix__` | the bare function prefix from `.claude/CLAUDE.md` (no trailing underscore) |
| `__textdomain__` | the theme slug (the theme's `Text Domain`) |

Render the substituted copy to a scratch file first and compare it with
`<theme>/inc/maintenance.php`:

- Absent: copy it in.
- Identical: leave it.
- Different without `--force`: stop and show the diff. Someone edited the theme's copy, and
  overwriting it would discard that work.
- Different with `--force`: replace it.

```bash
tmp=$(mktemp)
sed -e "s/__prefix__/<prefix>/g" -e "s/__textdomain__/<slug>/g" \
  "${CLAUDE_PLUGIN_ROOT}/templates/maintenance/maintenance.php" > "$tmp"
if grep -q '__prefix__\|__textdomain__' "$tmp"; then echo "UNSUBSTITUTED TOKENS"; exit 1; fi
php -l "$tmp"
cmp -s "$tmp" "<theme>/inc/maintenance.php" && echo identical
```

Then require it from `functions.php`. Read the file with the `Read` tool; if it does not
already load `inc/maintenance.php`, add this block before its final closing statement, so a
missing file never fatals the theme:

```php
$maintenance = __DIR__ . '/inc/maintenance.php';
if ( is_readable( $maintenance ) ) {
    require_once $maintenance;
}
```

`__DIR__`, not `get_template_directory()`: on a child theme that function returns the
parent, the file is never found, and `on` silently does nothing.
If the theme loops over `inc/*.php`, it already loads the file: never load it twice.
While the option is absent the file only registers two hooks that read one option and
return, so installing it changes nothing a visitor sees.

## Step 5: Switch

| Action | Command |
|---|---|
| `on` | `$WP option update <prefix>_maintenance <seconds>` |
| `off` | `$WP option delete <prefix>_maintenance` |
| `status` | `$WP option get <prefix>_maintenance` (absent means off) |

`off` leaves `inc/maintenance.php` in place: the switch is the option, not the file.

## Step 6: Verify and report

Ask the site as an anonymous visitor, with no cookies:

```bash
URL=$($WP option get home)
curl -sk -o /dev/null -D - "$URL/" | sed -n '1p;/^[Rr]etry-[Aa]fter/p'
```

- `on`: the status line must be `503` and `Retry-After` must be present. Anything else is a
  failure: report it and do not say the site is closed.
- `off`: the status must not be `503`. On a store whose `woocommerce_coming_soon` is `yes`,
  say the shop is still in coming-soon mode: launching it is `/wp-woo-setup`'s step.

Report the action, the status line
and, after `on`, that `/wp-audit` and `/wp-demo-verify` read a closed site as a `503` until it
is turned off again.
