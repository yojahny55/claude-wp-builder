# Store plugins: why each one, and what we avoid

Checked 2026-09-24 against WordPress.org (installs, last update, declared HPOS and block
checkout compatibility) and the vulnerability records at wpvulnerability.net, which aggregates
Wordfence, Patchstack and WPScan. This file goes stale by design: `/wp-audit` re-checks every
installed plugin live (SEC-041 known vulnerabilities, SEC-042 abandoned or closed). Every
plugin a store profile installs has a row under **Picks**; `tests/checks/wp-profiles.sh`
fails a profile that installs one without a reason, or installs anything under **Avoid**.

## Picks

| Plugin | Tiers | Why |
|---|---|---|
| `secure-custom-fields` | all, required | The field engine every generated theme calls through `prefix_get_field()`. |
| `woocommerce` | all, required | The store. 11.1.2 needs WordPress 7.0 and PHP 7.4. A WP-CLI install never runs its new-store defaults; `/wp-woo-setup` sets every one. |
| `store-kit` | all, required, bundled | Ours: catalog mode, and Stripe keys read from `wp-config.php` instead of the database. Copied from this repository by `bin/store-kit-sync.sh`, never fetched from WordPress.org. |
| `seo-by-rank-math` | all, optional | Product schema and noindex for hidden products, in the SEO plugin the rest of claude-wp-builder already configures. Brand, GTIN and per-variation schema are Pro. |
| `wp-super-cache` | all, optional | Honours WooCommerce's `DONOTCACHEPAGE` on cart, checkout and account; no vulnerability records since 2025. W3 Total Cache and Breeze had 2026 criticals. |
| `contact-form-7` | all, optional | The enquiry form a catalog offers and the contact page every site has, built by the existing `wp-cf7` agent. |
| `wp-mail-smtp` | catalog optional; store and full required | Order mail has to arrive. No records since 2025. Conflicts with `fluent-smtp`: two mailers fight over `wp_mail()`. |
| `woocommerce-gateway-stripe` | store, full | Cards and wallets on the block checkout, with Radar. Configured with API keys through `store-kit`, not the Connect button, which stores keys in the database. |
| `simple-cloudflare-turnstile` | store, full | A bot check that validates the Store API checkout itself, where card-testing scripts post directly. Preferred to reCAPTCHA, whose free tier is capped at 10,000 assessments a month. |
| `woocommerce-google-analytics-integration` | store, full, optional | GA4 purchase events that respect the WP Consent API; no records since 2025. Use it or Site Kit's WooCommerce tracking, never both. |
| `google-listings-and-ads` | store, full, optional | The Merchant Center product feed through Google's own API; no records since 2025. |
| `complianz-gdpr` | store, full, optional | Cookie consent where the market needs it, run locally and wired to the WP Consent API. 7.5.5 is past both of its 2026 records. |
| `mailpoet` | full, required | Email marketing and list-based abandoned-cart email, free to 500 subscribers. |
| `woo-cart-abandonment-recovery` | full, required | Abandoned-cart email from the address a shopper types at checkout, including the block checkout; 2.1.3 is past its 2026 record. Conflicts with FunnelKit Automations. Whether you may email that guest depends on the market: see `SKILL.md`. |
| `customer-reviews-woocommerce` | full, optional | Review reminders and photo reviews. Many past records, all fixed: keep it current. |
| `ajax-search-for-woocommerce` | full, optional | Live product search, SKU included. |
| `filter-everything` | full, optional | AJAX filters for a classic theme: core's Product Filters blocks sit beside a Product Collection block and cannot drop into a PHP archive loop. No records since 2025. |
| `woo-variation-swatches` | full, optional | Colour and size swatches in a classic theme; core's swatches are block-theme only. No records since 2025. |
| `woo-smart-wishlist` | full, optional | Wishlist; 6.1.0 is past its records. |
| `facebook-for-woocommerce` | full, optional | Meta catalog sync; 3.7.6 is past its 2026 record. |
| `pinterest-for-woocommerce` | full, optional | Pinterest catalog sync; no records since 2025. |

## Avoid

| Plugin | Why not, as of 2026-09-24 |
|---|---|
| `woocommerce-catalog-enquiry` | CatalogX: an unauthenticated privilege escalation affecting the latest release, flagged unfixed. Catalog mode is `store-kit`'s. |
| `judgeme-product-reviews-woocommerce` | Closed on WordPress.org on 2025-08-13: Judge.me left WooCommerce. |
| `wholesalex` | Closed on WordPress.org on 2026-09-16, pending review. |
| `wp-marketing-automations` | FunnelKit Automations: CVE-2025-1562 (CVSS 9.8, unauthenticated plugin install) and seven more records; no HPOS declaration. |
| `woocommerce-products-filter` | HUSKY: eleven records since 2025. |
| `woo-product-filter` | Two critical (9.3) records in 2026. |
| `flexible-checkout-fields` | Declares itself incompatible with the block checkout. |
| `subscriptions-for-woocommerce` | Ten records since 2025, one rated 8.8. Subscriptions will be our own (N01 piece 7). |
| `post-smtp` | Fourteen records since 2025. |
| `woo-poly-integration` | Abandoned since 2021. The Polylang bridge will be our own (N01 piece 6). |
| `retainful-next-order-coupon-for-woocommerce` | Its readme says it will be deprecated soon. |
| `w3-total-cache` | A critical (9.0) record in July 2026; not a default cache. |
| `breeze` | A critical (9.8) record in April 2026; not a default cache. |
| `ti-woocommerce-wishlist` | CVE-2025-47577, CVSS 10 (fixed in 2.10.0); `woo-smart-wishlist` has the cleaner record. |
| `translatepress-multilingual` | Two critical (9.8) records in August 2026, and stores stay on Polylang. |

## Add-ons, not in a profile

- **Digital downloads** — native; seeded and verified in the products piece (N01 piece 4),
  and must pass SEC-039.
- **Print-on-demand** — Printful's official plugin connects an account, so it is not headless;
  Printify's integration needs a paid plan.
- **Wholesale** — `woocommerce-wholesale-prices`; its premium Lead Capture add-on must be
  2.0.3.2 or later (earlier versions were actively exploited in 2026).
- **Multilingual** — Polylang plus our own bridge (N01 piece 6). Never SCF suffix fields for a
  store: one URL per product cannot rank in two languages.
