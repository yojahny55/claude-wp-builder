---
description: Check that a WooCommerce store works from the outside — setup has nothing left to change, the store pages answer, the shop lists products, a cart takes a product; with --order, a real test order on a local store, deleted afterwards
allowed-tools: Read, Bash, Grep, Glob
argument-hint: "[project-path] [--url <base-url>] [--order]"
---

# /wp-woo-verify — prove a store works

`/wp-woo-setup` says what it set. This command checks what a shopper gets: it runs setup's own
dry run, visits the store pages, reads the shop, and puts a product in a cart through the Store
API, the way the checkout blocks do. It changes nothing on the store: the cart session it opens
is deleted afterwards.

With `--order` it also places one cash-on-delivery order, checks that WooCommerce sent the
new-order email, then cancels the order (WooCommerce puts the stock and sales count back) and
deletes it for good. Only on a local site: a store that keeps an order is one `/wp-woo-setup`
treats as a merchant's, and on any other site the new-order email reaches a real inbox.

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

No `store` block: stop, and say `/wp-woo-setup` records one first. Then read the recorded
environment:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" environment.engine' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Anything but `native`: stop, for the reason `/wp-woo-setup` stops — WP-CLI in a container sees
neither this plugin's scripts nor the project directory.

## Step 2: Verify

```bash
bash -c 'node "$1/bin/woo-verify.mjs" "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Append ` --order` only when the operator passed `--order`, and ` --url <base-url>` when they
passed one: the site's home URL is used otherwise, and a local site's certificate is not
verified.

Before a run with `--order`, tell the operator in one line that WooCommerce sends the order's
emails for real — the new-order email to the store's recipient, which the `email` line names —
and that the order is deleted afterwards.

| Check | Passes when |
|---|---|
| `setup` | `woo-setup.php dry-run` plans nothing: the store still matches its block. Its `client` and `degraded` lines are shown as `note` |
| `page:shop`, `page:cart`, `page:checkout`, `page:myaccount` | the page answers 200 after same-site redirects; on a catalog, cart and checkout end at the shop |
| `shop` | a product is published and the shop page lists one |
| `cart` | a product goes into a cart and comes out again through the Store API; a catalog refuses it |
| `order`, `email`, `cleanup` | `--order` only: the order is processing, its notes say the new-order email was sent, and it is gone with the product's stock and sales count back |

A coming-soon store skips the page and shop checks: visitors see the coming-soon page.

`--order` is refused, before anything runs and with nothing written, unless the site is
local, the tier sells, cash on delivery is on, and the store has no other order — and with
`--url`, only when it names the home URL's host or loopback; and no order is placed unless the
cart check's session turns up in the database WP-CLI reads, the site that cleans the order up. An order a
stopped run left behind (billed to `woo-verify@example.test`, placed through the Store API) is
removed by the next `--order` run.

## Step 3: Report

| Exit | Meaning | Do |
|---|---|---|
| `0` | every check passed | report the summary line and every `note` |
| `1` | a check failed, or `--order` was refused | report each `fail` or the `refused:` line verbatim, with what fixes it: drift is `/wp-woo-setup`, missing products are `/wp-seed --products`, a failed email is the site's mail transport |
| `2` | could not measure: WP-CLI or the site did not answer | report the line; pass `--url` when the home URL does not resolve from here |
| `64` | usage | fix the arguments |

A `fail cleanup` line names an order the run could not delete: say so first, because until it
is deleted `/wp-woo-setup` reads the store as one with orders.
