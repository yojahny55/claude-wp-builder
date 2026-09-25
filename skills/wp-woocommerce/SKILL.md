---
name: wp-woocommerce
description: WooCommerce store practice for sites this plugin builds — the three store tiers and the plugins each installs (and the ones deliberately avoided, with reasons), the setup facts a WP-CLI install gets wrong, and the scripts /wp-woo-setup runs to bring a store in line with the `store` block in .wp-create.json
user-invocable: false
---

# WooCommerce stores

A store is a recorded decision, like the i18n strategy and the demo mode. The `store` block in
`.wp-create.json` says what the store sells and how, `/wp-woo-setup` brings WooCommerce in line
with it, and every other command reads the block instead of guessing. This skill is the
knowledge behind those values. It acts on nothing: the command runs the scripts.

## The three tiers

| Tier | What it is | Profile |
|---|---|---|
| `catalog` | Products and prices, nothing purchasable. Each product offers an enquiry form, a "where to buy" link (WooCommerce's External product type) or a WhatsApp button. Runs on WooCommerce with buying switched off by `store-kit`, so moving up a tier keeps every product, with no migration. | `templates/profiles/woo-catalog.json` |
| `store` | Cart, block checkout, Stripe (test mode until launch), shipping, tax, SMTP, Turnstile, and cookie consent where the market needs it. | `templates/profiles/woo-store.json` |
| `full` | `store` plus abandoned-cart email, email marketing, reviews, search and filters, swatches, wishlist, and Google and Meta feeds. | `templates/profiles/woo-full.json` |

Why each plugin is there, why the popular alternatives are not, and the add-ons (digital
downloads, print-on-demand, wholesale, multilingual): `references/plugins.md`.

When a client will never sell online, a product custom post type from `/wp-cpt` is lighter
than any tier: no sessions, no Action Scheduler, no Store API. The catalog tier is for the
client who may sell later.

## What a WP-CLI install gets wrong

Measured on WooCommerce 11.1.2 unless marked (source).

- **New-store defaults never run.** They are hooked to `admin_init` (source), so HPOS, "coming
  soon" and the onboarding defaults wait for the first wp-admin visit. Setup sets every value
  itself.
- **HPOS must be on before the first order.** On a store with no orders `wp wc hpos enable`
  creates the tables and switches; after an order exists WooCommerce will not switch on its own.
- **Pages.** Activation creates Shop, Cart, Checkout (block markup) and My account, and a draft
  Refund policy — no Terms page.
- **Polylang gives WooCommerce's pages no language** when it was configured after they were
  created, and `product` is not a translated post type by default. Setup assigns the default
  language to the store pages; products are the Polylang bridge's job.
- **Card testing.** The Store API rate limit is off by default, and card-testing scripts post to
  `/wc/store/v1/checkout` directly even on a classic-checkout store. Setup turns on the checkout
  limit: 3 attempts a minute per IP, refused as HTTP 400 `rate_limit_exceeded`. It never turns on
  the general Store API limiter — both share one per-IP row, so ordinary traffic dilutes the
  checkout limit to the general one.
- **Turnstile loads its WooCommerce integration only once `cfturnstile_tested` is `yes`** (source),
  normally set by testing the keys in wp-admin. Setup sets it together with Cloudflare's
  always-pass test keys on a local site; real keys are a launch step.
- **Background jobs.** With `DISABLE_WP_CRON`, Action Scheduler runs only on wp-admin requests
  (source); setup runs the queue once and reports the missing cron (PERF-061, PERF-062).
- **Emails.** Every send attempt leaves an order note (`Email "New order" sent.`), which is how a
  test proves email without an inbox.

## Practices every store gets

- **API keys never at rest; a rotated webhook secret is the one exception.** Stripe's API keys
  are `STORE_KIT_STRIPE_*` constants in `wp-config.php`; `store-kit` supplies them when the
  gateway reads its settings and strips them when it saves, so a database dump or clone carries
  none of those, and SEC-040 (which reads the raw row) agrees. A webhook-secret constant only
  ever seeds an *empty* field, because Stripe rotates that secret on its own when Stripe
  reconfigures webhooks (connect, re-key, the settings button, or after a plugin update) — a
  rotated value is left to reach the database, with an admin notice naming the now-stale
  constant. Configure Stripe with API keys, not "Connect with Stripe", which saves keys to the
  database.
- **Paid downloads stay closed.** Download method `force`; the native nginx and Caddy templates
  deny `woocommerce_uploads`, because nginx never reads WooCommerce's `.htaccess` (SEC-039).
- **Guest checkout on, account creation offered after purchase, coupons on.** A forced account is
  among the top reasons US shoppers abandon a checkout (Baymard, 2025).
- **Block checkout by default.** It is WooCommerce's default and where new features land; classic
  PHP checkout hooks do not fire on it. `shortcode` only with a written reason — an extension that
  does not support blocks.
- **Test mode until launch.** Cash on delivery only in a `local` environment, for the automated
  test order; "coming soon" everywhere else.
- **Abandoned-cart email depends on the market.** The US is opt-out (CAN-SPAM); the UK allows a
  soft opt-in only for an address typed at checkout; in the EU — Germany above all — treat it as
  advertising that needs prior consent.

## The scripts

`scripts/woo-setup.php`, run through `wp eval-file` by `/wp-woo-setup`, brings the store in line
with the block. `scripts/woo-lib.php` holds its decisions with no WordPress calls, so
`tests/checks/woo-lib.sh` runs them under bare PHP. Setup records a hash of every value it
writes in `store_kit_setup_state`; a value that no longer matches that hash is the client's and
is left alone unless `force` is passed. The one exception is launch state — "coming soon",
Stripe's `enabled`/`testmode`, cash on delivery — which a store with orders never has written
for it, absent or not, force or not: change it in WooCommerce instead. PHP 7.4 floor.
