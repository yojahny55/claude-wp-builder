---
description: Record what a WooCommerce store sells and how, then bring the store in line with it — tier, address, currency, pages, shipping, tax, Stripe in test mode, bot protection
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-path] [--force]"
---

# /wp-woo-setup — set up a WooCommerce store from a recorded decision

Installing WooCommerce is not setting it up. A WooCommerce activated from WP-CLI never runs
its new-store defaults — they wait for the first wp-admin visit — so HPOS stays off and nothing
about shipping, tax or payments exists. This command records what the store is in the `store`
block of `.wp-create.json`, then runs one script that brings WooCommerce in line with that
block, prints every change, and can be re-run at any time without duplicating anything.

The practice behind each value is in `skills/wp-woocommerce/SKILL.md`; the plugins each tier
installs, and the ones left out, in `skills/wp-woocommerce/references/plugins.md`.

## Step 1: Gate

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

Read the WP-CLI wrapper once and use it as `$WP` below:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs get '${PROJECT_PATH}' wp_cli.wrapper"
```

## Step 2: WooCommerce and store-kit

```bash
bash -c "$WP plugin is-active woocommerce"
```

Not active: stop. Install a store profile with `/wp-create`, or `wp plugin install woocommerce
--activate`, first.

Copy the bundled `store-kit` in when the site has none or an older one — it never downgrades —
and activate it:

```bash
bash -c "bash '${CLAUDE_PLUGIN_ROOT}/bin/store-kit-sync.sh' '${PROJECT_PATH}/wp-content/plugins' && $WP plugin activate store-kit"
```

## Step 3: Record the store

If `.wp-create.json` already has a `store` block, show it and ask what changed. Otherwise ask,
one question at a time, taking defaults from `docs/.scope-manifest.json` when `/wp-context`
wrote one:

1. **Tier** — `catalog` (nothing purchasable), `store` or `full`. Default: what the profile's
   `"store"` key says.
2. **Store address** — street, city, postcode, and country as `US` or `US:FL`.
3. **Currency** (`USD`) and **units** — weight `kg`/`g`/`lbs`/`oz`, dimension `m`/`cm`/`mm`/`in`/`yd`.
4. Catalog only: **enquiry channels** — any of `form`, `where-to-buy`, `whatsapp`, at least one.
5. Store and full only:
   - **Checkout** — `block` (default). `shortcode` only with a one-line reason, for example an
     extension that does not support the checkout block.
   - **Shipping** — zones by name, their locations (`US`, `US:FL`, `postcode:33602`,
     `continent:NA`), and methods: `flat_rate` with a `cost`, `free_shipping` with an optional
     `min_amount`, `local_pickup`.
   - **Tax** — whether tax is on, whether prices include it, and the merchant's rates (`country`,
     optional `state`, `rate` like `"6.0000"`, `name`, `shipping` true or false).
   - Payments are always `{"gateway": "stripe", "mode": "test"}`. Going live is a launch step.

Write the answers into `.wp-create.json` under `store`, in exactly this shape:

```json
"store": {
  "tier": "store",
  "address": { "street": "100 Main St", "city": "Tampa", "postcode": "33602", "country": "US:FL" },
  "currency": "USD",
  "units": { "weight": "lbs", "dimension": "in" },
  "checkout": "block",
  "payments": { "gateway": "stripe", "mode": "test" },
  "shipping": [{ "zone": "United States", "locations": ["US"],
                 "methods": [{ "type": "flat_rate", "cost": "10.00" }, { "type": "free_shipping", "min_amount": "100" }] }],
  "tax": { "enabled": true, "prices_include_tax": false,
           "rates": [{ "country": "US", "state": "FL", "rate": "6.0000", "name": "FL Sales Tax", "shipping": true }] }
}
```

Then validate. An invalid block is fixed and validated again; the script never runs against a
block that does not validate:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

The WhatsApp number and its message are not in this block: they live in the theme's settings
page, where the client can change them.

## Step 4: Stripe test keys — never in the chat

Do not ask the operator to paste a key, and never read one with `wp-config.mjs get`: anything
in this conversation is in the transcript. Tell them to put the test keys in
`.wp-create.local.json` themselves (it is gitignored), as
`{"store":{"payments":{"test_secret_key":"sk_test_…","test_publishable_key":"pk_test_…"}}}`,
or to export `WP_CREATE_STRIPE_TEST_SECRET_KEY` and `WP_CREATE_STRIPE_TEST_PUBLISHABLE_KEY`.
The script reads them itself, writes them to `wp-config.php` as `STORE_KIT_STRIPE_*`
constants, and never prints them. Without keys the store is still set up, and payments stay off
with a `degraded` line that says where the keys go.

## Step 5: Dry run first

```bash
bash -c "$WP eval-file '${CLAUDE_PLUGIN_ROOT}/skills/wp-woocommerce/scripts/woo-setup.php' '${PROJECT_PATH}' dry-run"
```

The flags are bare words — `dry-run`, `force` — because `wp eval-file` refuses a `--flag` it
does not know. Show the operator the plan: every `would-set`, `client` and `degraded` line, and
the `plan:` summary. Continue on their go-ahead.

## Step 6: Apply

```bash
bash -c "$WP eval-file '${CLAUDE_PLUGIN_ROOT}/skills/wp-woocommerce/scripts/woo-setup.php' '${PROJECT_PATH}'"
```

Append ` force` only when the operator passed `--force`. It takes back values the client
changed and applies to a store that already has orders, which otherwise runs report-only.

## Step 7: Report

| Exit | Meaning | Do |
|---|---|---|
| `0` | the store matches the block (degraded lines allowed) | report the summary line, and every `client` and `degraded` line verbatim |
| `1` | refused — the `refused:` line says why; nothing was written | report it, fix the cause, run again |

| Line | Means |
|---|---|
| `set` / `would-set` | changed, or would be in a dry or report-only run |
| `ok` | already what the block says |
| `client` | differs, and setup did not write it: left alone; `--force` takes it back |
| `degraded` | could not be done here; the line says why and what to do |
| `note` | information only |

Next: build the theme and the store pages, then seed products. Every later store command reads
the `store` block instead of asking again.
