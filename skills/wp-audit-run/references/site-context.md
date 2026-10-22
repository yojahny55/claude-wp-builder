# /wp-audit — Step 2.3

`commands/wp-audit.md` sends the run here at Step 2.3. Follow it in order; nothing in it is optional background.

## Contents

- Site type — is this a store?
- Store tier — what the store sells
- Local clone — audit production's posture, not the copy's
- Live checks need a public URL, and you ask for it
- Clone-safe versus production-only measurement
- A clone with a live mail transport is a finding, before any form is submitted

Two facts decide how many later checks should even run, and both are read once, here, before
any category dispatches.

### Site type — is this a store?

A store fails in ways an informational site cannot, and an informational site must never be
scored against checks it could not satisfy. Detect commerce once and record it:

```bash
$WP plugin is-active woocommerce && echo "site type: commerce (WooCommerce)" \
  || echo "site type: non-commerce"
```

Set `site.commerce` to `woocommerce` or `none`. This is the contract every commerce-only
check — present or still to be added — must follow: **read `site.commerce`, and report
`N/A` when it is `none`**, said with the reason "no WooCommerce", and excluded from the
denominator. A check whose object is the store (a cart, a checkout, a priced-per-currency
listing, a protected paid file) is commerce-only by definition, whichever category dispatches
it. For example, the gateway-credential check, the download-protection check, and the
multi-currency check are commerce-only, as are the SEO checks that a commerce-specific
section of `skills/wp-audit-seo-standards` adds — each reads `site.commerce` and is `N/A` on
a non-commerce site rather than being skipped or, worse, scoring a blog for a cart it never
had. This is how commerce depth is added without regressing a generic site: a blog audited
after a new commerce check ships scores exactly as it did before, because that check reads
`N/A` on it.

`is-active`, not `is-installed`: a store with WooCommerce deactivated is not currently a
store, and its commerce surfaces are not live to audit.

### Store tier — what the store sells

A store set up by `/wp-woo-setup` records what it sells in `.wp-create.json`, and a catalog
sells nothing: its products carry prices, and no cart or checkout is live. Read the tier once:

```bash
bash -c 'node "$1/bin/wp-config.mjs" get "$2" store.tier 2>/dev/null || echo unknown' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Set `site.store_tier` to `catalog`, `store` or `full`, or `unknown` when there is no `store`
block (a store set up by hand, or before `/wp-woo-setup` existed). A check whose object is the
cart, the checkout or a payment is **`N/A ("catalog: nothing purchasable")`** when
`site.store_tier` is `catalog` — the rule `site.commerce` applies, one level down, for the same
reason: a catalog must not be scored for a checkout it deliberately does not have. `unknown` is
not `catalog`: it audits as a store.

### Local clone — audit production's posture, not the copy's

When `.wp-create.json` carries `project.source: "restore"` (the field lives under
`project`, not at the manifest's root — `restore` itself holds only
`files_archive`, `db_archive` and `url_rewritten`, none of which name production), or a
`wordpress.url_origin` (the pre-restore URL, written beside `wordpress.url`), or its
`wordpress.url` is a non-public host, the project is a **local clone of a site that lives
somewhere else**. "Non-public host" is not this check's own list to keep in sync by hand:
it is exactly what `bin/geo-scan.sh` already refuses to scan — `localhost`, `*.localhost`,
`*.local`, `*.local.com` (this plugin's own default domain shape: `/wp-create` Step 3.3
offers `<slug>.local.com`, and `/wp-clone`'s placeholder follows the same shape), `*.test`,
any of those with a port, the private ranges `127.`, `10.`, `192.168.`,
`172.16.`–`172.31.`, `[::1]`, and a dotless hostname. Set `local_clone = true` and read
`production_url` from `wordpress.url_origin` when present.

A clone is deliberately altered to run in isolation, and those alterations are not defects of
the site being audited — they are the cost of having a local copy at all. Reporting them
audits the clone instead of the site. When `local_clone` is true, the following are
**`N/A (local clone)`**, out of the denominator, and are *not* printed as findings — the
reader wants production's posture, not a list of what localization changed:

| Condition normally a finding | Why it is a clone artifact here |
|---|---|
| Dev host stored in the database (SEC-036) | the clone's own URL is *supposed* to be the local host |
| Known-local plugins deactivated (payment gateways, a CDN/page-cache plugin, an object-cache/Redis plugin, a mail plugin, a security/scanner plugin) | turned off so the copy does not reach live payment, cache or mail endpoints |
| `DISABLE_WP_CRON` true, `WP_CACHE` false | set so an isolated copy does not fire scheduled or cached work |
| `object-cache.php` / `advanced-cache.php` absent or left as `*.bak` | the backing service (Redis, a CDN cache) does not exist locally |
| `advanced-cache.php` still in place, with `WP_CACHE` true, while the page-cache plugin that wrote it is clone-suppressed (PERF-070) | the drop-in and the constant came with the copy from production, where that plugin is active |
| A must-use plugin that neutralizes mail or external calls (e.g. a local `wp_mail()` override) | added by the clone to keep the copy from contacting the outside world |
| `WP_DEBUG` / `WP_DEBUG_LOG` on (SEC-008/009) | a development copy logs; production is what those checks are about |
| An attachment whose file is missing on disk **when the file archive predates the database** | the media was uploaded after the file backup was taken; it exists in production |

Do not widen this list to excuse a real defect: a plugin deactivated on the clone that has no
local reason to be off is still a finding, and media missing with no archive/database date gap
is still a finding (see WP-060/061/062 in `agents/wp-audit-practices.md`). The test is
"would this be true on production too?" — if yes, report it; if it exists only because this is
a copy, suppress it.

**Record what was actually suppressed, not just that the rule applied.** While walking the
"known-local plugins deactivated" and the `*.bak` drop-in rows above, keep the two lists that
came out of them:

- `clone_suppressed_plugins` — the slugs of the plugins that row found inactive (payment
  gateways, a CDN/page-cache plugin, an object-cache/Redis plugin, a mail plugin, a
  security/scanner plugin). Empty, never absent, when the clone deactivated none of them.
- `clone_parked_dropins` — the drop-in files found parked as `*.bak` (e.g.
  `object-cache.php.bak`, `advanced-cache.php.bak`). Empty, never absent, when none were
  parked.

These two lists are what Step 6 passes to the security agent so it knows which plugins and
drop-ins Step 2.3 already looked at, without re-deriving the clone rule itself. The
suppression they record reaches exactly one finding per item — "this plugin is deactivated",
"this drop-in is missing" — and nothing else: a plugin in `clone_suppressed_plugins` with a
known vulnerability, an outdated version, or a hardcoded credential is still a finding: the
clone rule silences "it is off", never "it is off *and* it is broken."

### Live checks need a public URL, and you ask for it

Some checks can only be answered against the running production site: response headers, and
whether a paid file is reachable without a purchase. The **local clone must never be probed
for these** — a local Apache reads `.htaccess` and would pass a rule a production nginx
ignores, turning a real exposure into a false PASS.

So when a live check needs a URL and `local_clone` is true:

1. Use `--host` when it was given.
2. Otherwise, **ask the user for the production URL**, proposing `production_url`
   (`wordpress.url_origin`) as the default when the manifest has one. Do not fire an
   external request at a host the user has not confirmed this run.
3. If no production URL is available, the live check is `UNMEASURED` with "needs the public
   URL", never `PASS`.

### Clone-safe versus production-only measurement

"Never probe the clone for live checks" does not mean "send everything to production". A
check that depends only on the markup and CSS the theme and plugins emit gives the same answer
on the clone, so it is measured there, with a browser when Tier 3 is available. Only what the
server, the network or real traffic shapes needs production.

| Clone-safe — measure on the clone | Production-only — needs the confirmed public URL, else `UNMEASURED` |
|---|---|
| contrast, target size, focus visibility, hover/active feedback, text-spacing | response headers (CSP, HSTS, cache-control, `X-Powered-By`) |
| keyboard menu behaviour, form validation, layout shift (CLS) | `robots.txt`, `sitemap.xml` and `llms.txt` as served |
| rendered head, schema graph, heading order, alt text, DOM structure | server rules (`.htaccess` vs nginx), redirects, TLS, HTTP version |
| theme source, `$WP` options, postmeta, plugin list, file permissions | CDN and page-cache behaviour, compression |
| link targets resolved through `resolve-link-targets.php` | real analytics, Search Console, field data (CrUX) |

**Timing and transfer-size metrics measured on the clone inherit the clone's serving layer.** A
clone's web server (say Apache, no compression, HTTP/1.1) is not production's (say nginx, h2,
brotli), so LCP, FCP, TBT, the Lighthouse performance score and total bytes describe the clone's
server as much as the site. One run's mobile baseline was meaningless: a 468 KB uncompressed
stylesheet that production serves as 69 KB of brotli over h2. When `local_clone` is true:

1. Probe the clone once, with a GET on the home page and again on its main stylesheet:
   `curl -s --compressed -o /dev/null -w '%{http_version} %header{content-encoding}\n' <url>`
   (`%header{}` needs curl 7.83 or later). A HEAD request can answer differently from a GET.
2. When the public URL is confirmed, probe the same two paths there the same way and compare.
3. When they differ (or production was not probed), label every clone timing and size metric
   `clone measurement — serving layer differs (<clone: encoding, HTTP version> vs <production: …>)`.
   Such a number is never a baseline and never a finding by itself; the production figure, or
   `UNMEASURED`, stands in its place.

The layer can be made to resemble production's: enable compression on the vhost and front the
clone with `bin/h2-proxy.mjs` (HTTP/2, brotli, a page-cache-like HTML cache) for the Lighthouse
run, mobile, 5 runs, median. Say which layer a number came from; the recipe is in
`wp-audit-standards/references/performance-lessons.md`, *A local lab that resembles
production*. A score measured that way is still `clone measurement`, only a better one.

Render-path facts do not depend on the serving layer and stay clone-safe: request counts,
render-blocking handles, image intrinsic versus rendered size, CLS.

Pass this split to every agent in Step 6. An agent that reports a clone-safe check `UNMEASURED`
because "this is a clone" has misread the rule, and Step 6.8 sends it back.

**A browser pointed at a clone must not reach third parties.** Route-block analytics,
tag-manager, reCAPTCHA and pixel hosts (everything that is not the clone's own origin or its
CDN-served assets) for the whole run: a headless browser on the clone host otherwise sends
real hits to the production analytics property.

### A clone with a live mail transport is a finding, before any form is submitted

A restored database carries the SMTP plugin's credentials and forced From address. A form
submitted on the clone then sends real mail, and a newsletter plugin subscribes real addresses.
Step 2.3's isolation table treats "mail plugin deactivated" as a clone artifact; the opposite
state, a mail plugin **active and configured**, is not an artifact, it is a hazard.

When `local_clone` is true and Tier 2 is available, measure it before dispatch:

```bash
$WP plugin list --status=active --field=name | grep -Ei 'smtp|mail|sendgrid|mailgun|postmark|ses|brevo|sendinblue'
$WP eval 'echo has_filter("pre_wp_mail") ? "guarded" : "open";'
ls wp-content/mu-plugins 2>/dev/null
```

An active mail-transport plugin with no `pre_wp_mail` filter (`open`) is a **WARNING** finding
(`Owner: setting`, resource `mail-transport`), reported at the top of the run and in the
blocking-warnings block. Then: **do not submit any form, subscribe, or trigger any mail-sending
action** (contact forms, newsletter, checkout, password reset) until it is guarded. Offer the
block recipe in `skills/wp-cli-patterns/SKILL.md` ("Guard a clone against outbound mail and
calls") as a temporary mu-plugin and tell the user to remove it, and delete the test rows it
protected, when the audit ends. Without Tier 2 the state is `UNMEASURED`, and the same
no-submit rule applies.

Print the two facts before tier detection, next to the adopted-site block when there is one:

```
=== Site ===
  Type          <commerce (WooCommerce) | non-commerce>
  Store tier    <catalog | store | full | unknown>
  Local clone   <yes — production: https://… | no>
```
