---
description: Take a WooCommerce store live on purpose — production only, live keys checked never written, a verified backup first, a typed confirmation, a fixed order with coming soon off last, and --revert back to coming soon
allowed-tools: Read, Bash, Grep, Glob
argument-hint: "[project-path] [--url <base-url>] [--backup-out <dir>] [--revert]"
---

# /wp-woo-launch — take a store live

`/wp-woo-setup` leaves every store in test mode: Stripe's test keys, cash on delivery only on a
local site, Cloudflare's always-pass Turnstile keys, and "coming soon" everywhere but local. This
command is the one step that changes that, on a production site, once, in a fixed order:

1. Stripe live: test mode off, the gateway on
2. cash on delivery off
3. Turnstile on the checkout, with the real keys
4. coming soon off — last, so a step that does not land leaves a store no visitor reaches

Then it verifies the live store from outside, and records `store.launch` in `.wp-create.json`.
From then on `/wp-woo-setup` never writes launch state on that store, `force` or not.

**Never run from `/wp-yolo`, nor from any other command.** The operator runs it, and types the
site's host to confirm.

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

No `store` block: stop — only a store `/wp-woo-setup` set up is launched here. Anything but
`native` in `environment.engine`: stop, for the reason `/wp-woo-setup` stops.

With `--revert`, go to Step 5.

## Step 2: Keys — never in the chat

Do not ask the operator for a key, and never print one. They put these in the site's
`wp-config.php` themselves; the command checks them and never writes them:

| Constant | Holds |
|---|---|
| `STORE_KIT_STRIPE_SECRET_KEY` | the live secret key, `sk_live_` or a restricted `rk_live_` |
| `STORE_KIT_STRIPE_PUBLISHABLE_KEY` | the live publishable key, `pk_live_` |
| `STORE_KIT_STRIPE_WEBHOOK_SECRET` | the live webhook's signing secret, `whsec_` — required: without it Stripe's live webhooks are not verified |
| `CF_TURNSTILE_SITE_KEY`, `CF_TURNSTILE_SECRET_KEY` | the site's real Cloudflare Turnstile keys, never the `1x0000…` test keys |

A catalog sells nothing: it needs none of them, and its launch is coming soon off alone.

## Step 3: Check

```bash
bash -c 'node "$1/bin/woo-launch.mjs" "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Append ` --url <base-url>` when the operator passed one (the home URL otherwise). This run writes
nothing; the cart check opens a Store API session and deletes it, as `/wp-woo-verify` does.

| Line | Passes when |
|---|---|
| `environment` | `wp_get_environment_type()` is `production` — a local or staging site is never launched |
| `stripe:plugin`, `stripe:secret_key`, `stripe:publishable_key`, `stripe:webhook_secret` | selling tiers: the gateway is active, and each constant above is set with its live prefix |
| `turnstile:plugin`, `turnstile:cfturnstile_key`, `turnstile:cfturnstile_secret` | selling tiers: the plugin is active and reads the real keys from the constants |
| `verify` | `/wp-woo-verify` passes: setup has nothing left to change, a cart works |
| `audit` | the store audit (`--read-only`) has no `CRITICAL` finding but `STORE-014`, which is the launch itself, and neither `STORE-005` (terms) nor `STORE-007` (refund and returns) fails: a store takes money under them |

The last line is `launch: ready` or `launch: blocked, N failed`. Blocked: report every `fail`
line with its fix — keys in `wp-config.php`, `/wp-woo-setup` for drift, the policy pages written
and published by the client — and stop.

## Step 4: Confirm, then launch

Tell the operator, in full sentences, that the store will take real card payments and be visible
to everyone, and that a verified backup is taken first. Then ask them to **type the site's host
exactly** (the host of its home URL, port included when it has one). Never fill it in for them,
and never take "yes" instead.

```bash
bash -c 'node "$1/bin/woo-launch.mjs" "$2" --confirm "$3"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}' '<typed host>'
```

Same ` --url` as Step 3; append ` --backup-out <dir>` when the operator named where backups go
(`bin/wp-backup.sh`'s default otherwise, always outside the WordPress root).

It runs the checks again, takes the backup (`bin/wp-backup.sh --label pre-launch`), launches in
the order above, and verifies the live store:

| Exit | Meaning | Do |
|---|---|---|
| `0` | `launch: live, backup <folder>` — recorded in `store.launch` | report it with the backup folder |
| `1` | `refused:` — the line says why | report it verbatim, with what it means below |
| `2` | could not measure: WP-CLI or the site did not answer | report it; pass `--url` when the home URL does not resolve from here |
| `64` | usage | fix the arguments |

What a `refused:` line means:

- **a check fails, the host does not match, or there is no verified backup** — nothing was written.
- **`the launch stopped before coming soon went off`** — a write did not land; the store is still
  hidden. Fix the cause and run it again: the steps already done are skipped.
- **`the live store failed verify`** — the store went back to coming soon and nothing was
  recorded; the payment settings stay live behind it. Fix what verify names, then launch again.
- **`going back to coming soon failed`** — say this first: the store is visible and failing.
  The operator switches it on in WooCommerce > Settings > Site visibility.
- **`was launched at`** — already live; `--revert` comes first.

## Step 5: `--revert`

```bash
bash -c 'node "$1/bin/woo-launch.mjs" "$2" --revert' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Puts the store back to coming soon, nothing else — the live keys, Stripe and Turnstile stay as
they are — and adds `store.launch.reverted_at`. `/wp-woo-setup` still leaves launch state alone.
A later launch runs every step again and replaces the record. A restore of the database is
`/wp-restore <backup folder>`, the folder `store.launch.backup` names.

## Step 6: Report

The launched store, its backup folder, and the next step: `/wp-audit --store` on the live site.
A real card payment is never made by this command; the merchant places the first one.
