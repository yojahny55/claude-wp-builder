---
description: Record what a WooCommerce store sells and how, then bring the store in line with it — tier, address, currency, pages, shipping, tax, Stripe in test mode, bot protection
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-path] [--force] [--store-theme]"
---

# /wp-woo-setup — set up a WooCommerce store from a recorded decision

Installing WooCommerce is not setting it up. A WooCommerce activated from WP-CLI never runs
its new-store defaults — they wait for the first wp-admin visit — so HPOS stays off and nothing
about shipping, tax or payments exists. This command records what the store is in the `store`
block of `.wp-create.json`, then runs one script that brings WooCommerce in line with that
block, prints every change, and can be re-run at any time without duplicating anything.

The practice behind each value is in `${CLAUDE_PLUGIN_ROOT}/skills/wp-woocommerce/SKILL.md`; the
plugins each tier installs, and the ones left out, in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-woocommerce/references/plugins.md`.

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

**`--store-theme` on a recorded store goes straight to Step 6.6.** When `.wp-create.json`
already has a `store` block and `--store-theme` was passed, the store is set up and the flag
asks only for the theme files: skip Steps 2 to 6.5, run Step 6.6, then report. Without a
`store` block the flag changes nothing here: the run sets up a new store, and Step 6.6 installs
on a new store anyway. `/wp-yolo` runs it this way once the theme exists, because the
`/wp-woo-setup` that `/wp-create` runs comes before any theme.

## Step 2: WooCommerce and store-kit

A store needs native WP-CLI, running on the host. store-kit is copied into the host's
`wp-content/plugins`, and `woo-setup.php` and `.wp-create.json` are host paths: Docker (our
templates) mounts only the theme, wp-env loads no plugin from the project, and DDEV and Lando run
WP-CLI in a container that mounts neither this plugin's scripts nor the host project path. Read
the recorded environment first:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" environment.engine' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Anything but `native`: stop here, before syncing anything, rather than failing later at
`plugin activate`, and say so in one line:

> store profiles need native WP-CLI: on `<engine>` WP-CLI cannot see the plugin's scripts or the project directory

```bash
bash -c "$WP plugin is-active woocommerce"
```

Not active: stop. Install a store profile with `/wp-create`, or `wp plugin install woocommerce
--activate`, first.

Copy the bundled `store-kit` in when the site has none or an older one — it never downgrades —
and activate it:

```bash
WP="$WP" bash -c 'bash "$1/bin/store-kit-sync.sh" "$2/wp-content/plugins" && $WP plugin activate store-kit' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
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
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

A store block adds a `Store tier` row to the generated block in `.claude/CLAUDE.md`, so on a
project that already has that block, `validate` now exits `1` saying the generated block no
longer matches the manifest. Then, and only when `.claude/CLAUDE.md` already contains the
`wp-create:begin` block, regenerate it — same `${PROJECT_PATH}` substitution as the gate — and
validate again:

```bash
bash -c 'node "$1/bin/wp-config.mjs" render-context "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

A project with no generated block is left alone: no `.claude/CLAUDE.md` is created before
`/wp-init`. Any other exit-`1` message is a problem in the block — fix it, never regenerate
around it.

The WhatsApp number and its message are not in this block: they belong in the theme's settings
page, where the client can change them. Step 6.5 installs those fields and what renders them.

## Step 4: Stripe test keys — never in the chat

Do not ask the operator to paste a key, and never read one with `wp-config.mjs get`: anything
in this conversation is in the transcript. Tell them to put the test keys in
`.wp-create.local.json` themselves (it is gitignored), as
`{"store":{"payments":{"test_secret_key":"sk_test_…","test_publishable_key":"pk_test_…"}}}`,
or to export `WP_CREATE_STRIPE_TEST_SECRET_KEY` and `WP_CREATE_STRIPE_TEST_PUBLISHABLE_KEY`.
The script reads them itself, writes them to `wp-config.php` as `STORE_KIT_STRIPE_*`
constants, and never prints them. Without keys the store is still set up, and payments stay off
with a `degraded` line that says where the keys go.

A webhook secret is optional, in the same two places — `store.payments.test_webhook_secret` in
`.wp-create.local.json`, or `WP_CREATE_STRIPE_TEST_WEBHOOK_SECRET` — starting `whsec_`. Without
it, Stripe's webhooks (async payment confirmations, refunds, disputes) are not verified. Stripe
may rotate it later; setup leaves a rotated value to reach the database, and store-kit shows a
notice naming the now-stale constant.

## Step 5: Dry run first

```bash
WP="$WP" bash -c '$WP eval-file "$1/skills/wp-woocommerce/scripts/woo-setup.php" "$2" dry-run' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

The flags are bare words — `dry-run`, `force` — because `wp eval-file` refuses a `--flag` it
does not know. Show the operator the plan: every `would-set`, `client` and `degraded` line, and
the `plan:` summary. Continue on their go-ahead.

## Step 6: Apply

```bash
WP="$WP" bash -c '$WP eval-file "$1/skills/wp-woocommerce/scripts/woo-setup.php" "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Append ` force` only when the operator passed `--force`. It takes back values the client
changed and applies to a store that already has orders, which otherwise runs report-only. The
one exception: on a store that has orders, launch state — coming soon, Stripe's
`enabled`/`testmode`, cash on delivery — is never changed by `force`; change it in WooCommerce
instead.

## Step 6.5: Enquiry channels in the theme (catalog with `whatsapp` or `form` only)

A catalog sells nothing online, so its product pages need another way to ask. Skip this step
unless the tier is `catalog` and `store.enquiry` lists `whatsapp` or `form` (`where-to-buy` is
WooCommerce's External product type and needs nothing here), and skip it on a theme this
plugin did not scaffold — no `.claude/CLAUDE.md`, or a third-party theme `/wp-adopt`
registered: say the channel needs the theme's own work.

The PHP is a fixed file, `${CLAUDE_PLUGIN_ROOT}/templates/store/store-enquiry.php`, held to the
PHP 7.4 floor. **Copy it and substitute the two tokens; do not retype or "improve" it.**

| Token | Replace with |
|---|---|
| `__prefix__` | the bare function prefix from `.claude/CLAUDE.md` (no trailing underscore) |
| `__textdomain__` | the theme slug (the theme's `Text Domain`) |

The installed file is always the substituted copy, never the raw template:

```bash
tmp=$(mktemp); dest="<theme>/inc/store-enquiry.php"
sed -e "s/__prefix__/<prefix>/g" -e "s/__textdomain__/<slug>/g" \
  "${CLAUDE_PLUGIN_ROOT}/templates/store/store-enquiry.php" > "$tmp"
if grep -q '__prefix__\|__textdomain__' "$tmp"; then echo "UNSUBSTITUTED TOKENS"; rm -f "$tmp"; exit 1; fi
php -l "$tmp" || { rm -f "$tmp"; exit 1; }
if [ ! -f "$dest" ]; then
  mkdir -p "$(dirname "$dest")" && cp "$tmp" "$dest" && echo INSTALLED || { echo FAILED; rm -f "$tmp"; exit 1; }
elif cmp -s "$tmp" "$dest"; then echo UNCHANGED
else diff -u "$dest" "$tmp"; echo EDITED; fi
rm -f "$tmp"
```

`INSTALLED` or `UNCHANGED`: go on. `EDITED`: someone changed the theme's copy; stop and show
the diff, unless `--force`, which re-runs the block with `cp "$tmp" "$dest"` in the `EDITED`
branch. Then require it from that theme's
`functions.php`, unless the theme already loops over `inc/*.php` (never load it twice):

```php
require_once __DIR__ . '/inc/store-enquiry.php';
```

It adds three fields to the theme's settings page — WhatsApp number, WhatsApp message (with
`{product}`), and the Contact Form 7 form ID — and renders the filled ones on each product
page after the price, only while store-kit's catalog mode is on. **Never fill the number or
the form ID yourself**: an invented number is one the client ships by mistake. With
`form` in the channels and Contact Form 7 active, create the enquiry form with the `wp-cf7`
agent and report its ID as the value the client confirms. Report the channels whose field is
still empty under "Content pending", like `/wp-finalize`.

## Step 6.6: Store pages in the theme (tailwind themes)

Without `add_theme_support( 'woocommerce' )` WooCommerce squeezes the shop and every product
into `page.php`, with no gallery zoom, lightbox or slider, in its own purple and olive. This
step installs two fixed files: `${CLAUDE_PLUGIN_ROOT}/templates/store/store-theme.php` to
`<theme>/inc/store-theme.php`, which declares support, replaces WooCommerce's wrapper and
sidebar (the theme's header already opens `<main id="primary">`) and loads the stylesheet on
store pages only; and `${CLAUDE_PLUGIN_ROOT}/templates/store/store.css` to
`<theme>/assets/css/store.css`, WooCommerce in the theme's tokens. **Copy them; do not retype
or "improve" them.** Every other page of the site renders as before.

Skip this step, saying the store pages need the theme's own work, unless `.claude/CLAUDE.md`
records `**Template:** tailwind` — no `.claude/CLAUDE.md`, a theme `/wp-adopt` registered, or a
cinematic theme (no `#primary` wrapper) all skip.

It changes how an existing store looks, so it **installs only on a new store** — Step 3 found
no `store` block and wrote it in this run — **or with `--store-theme`**. On a store that already
had its block and has no `inc/store-theme.php`, install nothing and report one line: "store
pages: theme support not installed; `/wp-woo-setup --store-theme` installs it and changes how
the shop, product, cart, checkout and account pages look".

Same tokens as Step 6.5 (`__prefix__`, `__textdomain__`). The stylesheet is compared without
its last section, `Section: Store demo`, which holds the demo's own store styling and is the
project's (the theme's copy keeps its own):

```bash
theme="<theme>"; tmp=$(mktemp -d)
sed -e "s/__prefix__/<prefix>/g" -e "s/__textdomain__/<slug>/g" \
  "${CLAUDE_PLUGIN_ROOT}/templates/store/store-theme.php" > "$tmp/store-theme.php"
head_of() { sed '/====== Section: Store demo ======/,$d' "$1"; }
st="INSTALLED"
if grep -q '__prefix__\|__textdomain__' "$tmp/store-theme.php"; then st="UNSUBSTITUTED TOKENS"
elif ! php -l "$tmp/store-theme.php" >/dev/null; then st="PHP LINT FAILED"; fi
for pair in "store-theme.php:inc/store-theme.php" "store.css:assets/css/store.css"; do
  [ "$st" = INSTALLED ] || break
  src="$tmp/${pair%%:*}"; [ -f "$src" ] || src="${CLAUDE_PLUGIN_ROOT}/templates/store/${pair%%:*}"
  dest="$theme/${pair#*:}"
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")" && /bin/cp -f "$src" "$dest" && cmp -s "$src" "$dest" \
      && echo "INSTALLED $dest" || { echo "FAILED $dest"; st=FAILED; }
  elif [ "${pair%%:*}" = store.css ] && cmp -s <(head_of "$src") <(head_of "$dest"); then echo "UNCHANGED $dest"
  elif cmp -s "$src" "$dest"; then echo "UNCHANGED $dest"
  else diff -u "$dest" "$src"; echo "EDITED $dest"; fi
done
[ "$st" = INSTALLED ] || echo "$st"
rm -rf "$tmp"
```

`INSTALLED` or `UNCHANGED` lines: go on. A last line `UNSUBSTITUTED TOKENS`, `PHP LINT FAILED`
or `FAILED`: stop and report it. `EDITED`: the theme's copy was changed; stop and show the
diff, unless `--force`, which copies that one file over — for `store.css` keep the theme's
`Section: Store demo` and replace only what comes before it. Then require the PHP from the
theme's `functions.php`, beside the other `inc/` requires (never load it twice):

```php
require_once __DIR__ . '/inc/store-theme.php';
```

The stylesheet reads the theme's Tailwind tokens (`--color-primary`, `--color-dark`,
`--color-light`, `--color-gray`, `--color-accent`, `--font-primary`, `--font-secondary`).
Tailwind emits only the variables something uses; `inc/store-theme.php` names them, and it is
in the build's `@source`, so rebuild once it is installed:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Then check the compiled `assets/css/dist/main.css` for each name and report the missing ones:
the theme's `@theme` does not declare them (a craft palette renames its tokens), so the store
falls back to neutral greys there until the `Section: Store demo` of `store.css` maps the
`--store-*` properties to the theme's own names.

## Step 7: Report

| Exit | Meaning | Do |
|---|---|---|
| `0` | the store matches the block (degraded lines allowed) | report the summary line, and every `client` and `degraded` line verbatim |
| `1` | refused — the `refused:` line says why; nothing was written | report it, fix the cause, run again |

| Line | Means |
|---|---|
| `set` / `would-set` | changed, or would be in a dry or report-only run |
| `ok` | already what the block says |
| `client` | differs, and setup did not write it: left alone; `force` takes it back — except launch state on a store with orders, which `force` never changes; change it in WooCommerce |
| `degraded` | could not be done here; the line says why and what to do |
| `note` | information only |

Next: build the theme and the store pages, then seed products. Every later store command reads
the `store` block instead of asking again.
