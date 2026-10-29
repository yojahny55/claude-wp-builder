# Security procedures — deploy safety, update network gate, paid downloads

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-security.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before SEC-036, SEC-037, SEC-038 (and so before SEC-032, SEC-033, SEC-041, SEC-042, which wait on its gate) or SEC-039.

## Contents

- Procedure — SEC-036 and SEC-037 (deploy safety)
- SEC-036 — the development host, stored in the database
- SEC-037 — backup and editor files inside the theme
- Procedure — SEC-038 (update counts need a network)
- Procedure — SEC-039 (paid downloads reachable without a purchase)

### Procedure — SEC-036 and SEC-037 (deploy safety)

Both of these fire on the state of a project that is *about* to be pushed to production. They
exist because the theme can be entirely correct while the database and the file list carry
things that must never leave the development machine, and nothing that reads the theme can
see either one.

**SEC-036 — the development host, stored in the database.** Every row of the database is
copied verbatim by every sync tool. A dev URL sitting in a stored value is not a cosmetic
problem: a push writes it into production, where it becomes a logo that 404s, an Organization
`url` that points at a machine nobody outside the office can reach, a menu item that leaves
the site, or a schema graph that identifies the business by a hostname that does not resolve.

**On a local clone this check is a pre-deploy gate (`INFO`, listed as a push blocker, `siteurl`/`home` not counted); see `/wp-audit` Step 2.3, "Local clone — severity ceiling".**

**Search four tables, not one.** `wp_options` is where this check started and it is the table
that holds the least of it. A first pass that read only `wp_options` on a real site reported
7 occurrences; the same needle across all four tables reported 25. The three it skipped are
the ones that reach the page:

| Table | What holds the host there | Why it reaches production |
|-------|---------------------------|---------------------------|
| `options` | plugin option arrays, the SEO plugin's social and schema values | rendered into `<head>` on every request |
| `postmeta` | custom-field URLs, builder payloads, `_menu_item_url` of `custom` menu items | a menu item that points at the dev host is a link off the live site |
| `posts` | `post_content` only — an editor pasted an absolute URL. `guid` is never searched: WordPress does not rewrite it and nothing renders it | printed inside the article body |
| `termmeta` | term images and per-term link fields | printed on archive pages |

Derive the needle from `home` rather than hard-coding it, and query every table in one pass:

```bash
$WP eval "
global \$wpdb;
\$needle = preg_replace('#^https?://#', '', rtrim(home_url(), '/'));
\$like   = '%' . \$wpdb->esc_like(\$needle) . '%';

\$queries = array(
    'options'  => array(\"SELECT option_name AS id, option_name AS label FROM \$wpdb->options WHERE option_value LIKE %s AND option_name NOT IN ('home','siteurl')\"),
    'postmeta' => array(\"SELECT post_id AS id, meta_key AS label FROM \$wpdb->postmeta WHERE meta_value LIKE %s\"),
    'posts'    => array(\"SELECT ID AS id, post_type AS label FROM \$wpdb->posts WHERE post_content LIKE %s\"),
    'termmeta' => array(\"SELECT term_id AS id, meta_key AS label FROM \$wpdb->termmeta WHERE meta_value LIKE %s\"),
);

\$total = 0;
foreach (\$queries as \$table => \$q) {
    \$args = array_fill(0, substr_count(\$q[0], '%s'), \$like);
    \$rows = \$wpdb->get_results(\$wpdb->prepare(\$q[0], \$args));
    echo strtoupper(\$table) . ': ' . count(\$rows) . PHP_EOL;
    foreach (\$rows as \$r) { echo '  ' . \$r->id . ' — ' . \$r->label . PHP_EOL; }
    \$total += count(\$rows);
}
echo \$total . ' rows carry the development host' . PHP_EOL;
"
```

`home` and `siteurl` are expected to hold it and are **not** findings — they are what makes
the local site work. Every other row is. Report the count per table and then each row, so the
reader can tell an option array from a menu item from an editor's paste; the SEO plugin's own
options and `_menu_item_url` are the ones that reach production markup, so name those first.

A `guid` is a historical identifier WordPress never rewrites and does not resolve as a URL, so
it is not searched and not counted, on a clone or anywhere else.

`skills/wp-cli-patterns/scripts/check-dev-host.php` runs exactly this sweep, read-only, and
exits 1 when it finds anything, so the same measurement can gate a deploy without an agent.

This is CRITICAL rather than WARNING because the damage happens at push time, silently, and is
discovered from the outside — by a search engine reading a schema graph that names a host it
cannot resolve.

**SEC-037 — backup and editor files inside the theme.** A sync tool ships the directory it is
given. A `seo.php.bak-20260913` next to `seo.php` is inside `wp-content/`, so it is inside the
push, and once on the server it is a publicly fetchable file containing source that may hold
credentials or logic the live file no longer has.

```bash
find <theme> -type f \( -name '*.bak*' -o -name '*.orig' -o -name '*.save' -o -name '*~' \
  -o -name '*.php.[0-9]*' -o -name '*.sql' -o -name '*.zip' \) -print
```

Report each path. The fix is to delete it or move it outside `wp-content/` — never to add it
to a deny rule, which protects one server's configuration and travels with nothing.

Run both before any deployment step, and print their findings even when every other check
passes: a clean audit followed by a push that ships a dev URL is the failure this pair exists
to prevent.

### Procedure — SEC-038 (update counts need a network)

`$WP core check-update` and `$WP plugin list --update=available` do not query `api.wordpress.org`
themselves. They read the transients `update_core` and `update_plugins`, which a background
request filled in at some earlier point. When the machine has no route to `api.wordpress.org`
the refresh fails silently, the stale transient stays, and both commands answer from it. A
count of `0` then means "the last successful check found nothing", which can be months old —
and it is reported as "no updates pending", which is the opposite of the truth.

This is not hypothetical. On an audited site the cached count said one plugin needed updating;
once the machine had a route again the real count was twelve, and core was a full minor version
behind. The audit had already been written and had to be corrected.

Measure the route before reading either count:

```bash
if ! curl -sS --max-time 10 -o /dev/null https://api.wordpress.org/core/version-check/1.7/; then
  echo "SEC-038 FAIL: no route to api.wordpress.org"
fi
```

Then, **only when the dispatch context says `Report-only: no`**, force the transients to be
rebuilt rather than trusting whatever is cached. Deleting a transient is a database write, and
a report-only run writes nothing (see "Report-only writes nothing" below):

```bash
$WP transient delete update_core
$WP transient delete update_plugins
$WP transient delete update_themes
$WP core check-update
$WP plugin list --update=available --format=count
```

Rules that follow from this:

- When the request fails, SEC-032, SEC-033 and SEC-034's update column are `UNMEASURED`, with
  the curl command as the evidence line. They are **never** reported as passing, and never as
  "0 updates pending".
- When the request succeeds and `Report-only: no`, delete the three transients first. A count
  read without deleting them is a measurement of the cache, not of the site.
- **Report-only writes nothing.** With `Report-only: yes` do not delete, set or update any
  transient or option. Read the transient and report its age (`last_checked`); when it is
  older than 12 hours, ask the API directly instead
  (`curl -sS https://api.wordpress.org/core/version-check/1.7/`,
  `https://api.wordpress.org/plugins/update-check/1.1/`) or report the count `UNMEASURED —
  cached data from <date>`. A stale count stated as current is the defect; a read-only run
  that says how old its data is has none.
- Report the age of the data either way: `$WP transient get update_plugins --format=json` carries
  a `last_checked` timestamp, and a reader who sees it is a week old can judge the count.

The same note applies to WP-043 and WP-044 in `agents/wp-audit-practices.md`, which read the
same two transients.

### Procedure — SEC-039 (paid downloads reachable without a purchase)

WooCommerce only. When `site.commerce` is `none` (see `/wp-audit` Step 2.3), this check is
`N/A (no WooCommerce)` and is not counted. When a store is present, it is one of the most
damaging findings the audit can make: the paid files a customer pays to download are sitting
in the web root, and anyone with the URL takes them for free.

**Why the built-in protection can be inert.** WooCommerce stores paid files in
`woocommerce_uploads/` inside the uploads directory (`wp-content/uploads/` by default) and
ships an `.htaccess` there with `deny from all`.
It also has a download method, `woocommerce_file_download_method`, with three values:

- `redirect` — the file is served straight from its public URL with no gate at all. This is
  an exposure **by configuration**, independent of the web server — but only when the store
  keeps its paid files in `woocommerce_uploads`. Run the probe-file snippet below first; no
  HTTP probe is needed. **The redirect method is CRITICAL on `FOUND`**, and on
  `NO-LOCAL-UPLOADS`, where the paid files were never restored and the stored path is the best
  evidence there is. On `MISSING-LOCALLY` (the files are here, the stored one is not) it is
  `UNMEASURED`. With `NO-DOWNLOADS` or `EXTERNAL-ONLY` it is `N/A`, exactly as for the other
  methods.
- `force` / `xsendfile` — downloads are meant to stream through PHP with a capability check,
  and the directory `.htaccess` is the only thing stopping a direct hit. **Apache reads that
  `.htaccess`; nginx does not.** On an nginx host the `deny from all` is dead text and every
  file under `woocommerce_uploads` is fetchable by URL, while the store looks correctly
  configured from the admin.

**So configuration alone cannot answer this — a live request must.** And it must go to
**production**, never the local clone: a local Apache honours the `.htaccess` and returns a
false PASS for a site that is wide open behind nginx. Follow Step 2.3's rule for a live check
— use `--host`, otherwise ask for the production URL (default `wordpress.url_origin`) and fire
nothing until it is confirmed; with no public URL the check is `UNMEASURED`, not `PASS`.

**Pick the probe file from the stored downloads, not from the product API.** The first
downloadable product may serve from an external URL, and downloads attached to a variation
never show up in `wc_get_products(["downloadable"=>true])`. Read `_downloadable_files` on
published products **and** on published variations of published products — a trashed or draft
product can point at a file that was deleted long ago. Take the URLs that sit under
`/woocommerce_uploads/`, keep only what follows that segment (the stored URL carries whatever
host was saved — the clone's, after a search-replace — which must never be probed), and prefer
the first one whose file exists in the local copy of the uploads. The path is printed
percent-encoded per segment, so a file name with spaces or accents reaches `curl` intact:

```bash
# One line per snippet, each starting with its label, so the output parses line by line.
$WP eval 'echo "METHOD ",get_option("woocommerce_file_download_method") ?: "force","\n";'
# Where uploads are served from (multisite: uploads/sites/N; custom UPLOADS or upload_path).
$WP eval 'echo "UPLOADS-PATH ",rtrim((string) wp_parse_url(wp_upload_dir()["baseurl"],PHP_URL_PATH),"/"),"\n";'
# Probe file: FOUND|NO-LOCAL-UPLOADS|MISSING-LOCALLY <path relative to woocommerce_uploads/>,
# or a marker when there is no path to probe.
$WP eval 'global $wpdb; $seg="/woocommerce_uploads/";
$rows=$wpdb->get_col("SELECT pm.meta_value FROM {$wpdb->postmeta} pm JOIN {$wpdb->posts} p ON p.ID=pm.post_id LEFT JOIN {$wpdb->posts} par ON par.ID=p.post_parent WHERE pm.meta_key=\"_downloadable_files\" AND pm.meta_value<>\"\" AND p.post_status=\"publish\" AND (p.post_type=\"product\" OR (p.post_type=\"product_variation\" AND par.post_status=\"publish\")) ORDER BY p.post_date DESC");
if(!$rows){echo "NO-DOWNLOADS\n";return;}
$dir=wp_upload_dir()["basedir"].$seg; $local=is_dir($dir)&&count(array_diff(scandir($dir),[".","..","index.html",".htaccess"]))>0; $first=null;
foreach($rows as $r){foreach((array)maybe_unserialize($r) as $f){$u=is_array($f)?($f["file"]??""):"";$i=strpos($u,$seg);if($i===false){continue;}
$p=rawurldecode(preg_replace("/[?#].*$/","",substr($u,$i+strlen($seg))));
$enc=implode("/",array_map("rawurlencode",explode("/",$p)));
if($local&&file_exists($dir.$p)){echo "FOUND $enc\n";return;} $first=$first??$enc;}}
if($first===null){echo "EXTERNAL-ONLY\n";return;} echo $local?"MISSING-LOCALLY":"NO-LOCAL-UPLOADS"," $first\n";'
# Control file: a public upload outside woocommerce_uploads, relative to the uploads path.
$WP eval '$a=get_posts(["post_type"=>"attachment","post_mime_type"=>"image","post_status"=>"inherit","numberposts"=>1,"fields"=>"ids","meta_query"=>[["key"=>"_wp_attached_file","value"=>"woocommerce_uploads/","compare"=>"NOT LIKE"]]]); echo $a?"CONTROL ".implode("/",array_map("rawurlencode",explode("/",get_post_meta($a[0],"_wp_attached_file",true)))):"NO-CONTROL","\n";'
```

- `FOUND <path>` — the file exists in the local uploads, so it is known to exist on the site:
  a `404` from the server is evidence of protection.
- `NO-LOCAL-UPLOADS <path>` — the clone has no `woocommerce_uploads` directory, or only the
  `index.html` and `.htaccess` WooCommerce recreates there on its own (the paid files were not
  restored): the path is real store data, but whether the file still exists
  on the site is unknown, so a `404` is `UNMEASURED`.
- `MISSING-LOCALLY <path>` — the directory is here but none of the stored files are: they may
  be gone from the site too, so a `404` is `UNMEASURED`.
- `NO-DOWNLOADS` — no published product or variation stores a download:
  `N/A (no downloadable products)`, whatever the download method.
- `EXTERNAL-ONLY` — every download points outside `woocommerce_uploads` (a CDN, S3, another
  host): `N/A (downloads served from outside woocommerce_uploads)`, whatever the download
  method, with the reason in the evidence line. This check does not judge those hosts.
- `NO-CONTROL` — no public upload to calibrate against: `UNMEASURED`. Images added through a
  product's downloadable-file field are attachments too, stored under `woocommerce_uploads/`;
  the control query excludes them, so the control is never a paid file. `NO-CONTROL` matters
  only to the HTTP probe; the `redirect` method's verdict needs no control.

Never `PASS` without a probe file and a control file.

**Build both URLs from `UPLOADS-PATH`, never from a hardcoded `/wp-content/uploads`.** It is
`/wp-content/uploads` on a default single site, `/wp-content/uploads/sites/<N>` on a multisite
subsite (run the snippets with `--url=<subsite>`), and whatever a custom `UPLOADS` constant or
`upload_path` option sets otherwise; the probe and control paths are relative to it. It has
no trailing slash and is empty when uploads sit at the web root, so `<uploads-path>/<path>`
always joins with exactly one slash. Only
the path is kept: when the uploads base URL sits on another host (media offloaded to a CDN or
bucket), the control on the production host fails and the check is `UNMEASURED`, never a
verdict read off a host that is not the site.

**Control request first.** Request the public control file over the confirmed production
host. It must come back `200` or `206` with a non-HTML `content-type` (an `image/*`); a host
that refuses HEAD (`405`/`501`) gets the same one-byte ranged GET as the paid file. Requests
read the first response only — redirects are not followed (no `-L`). If the control answers
`3xx` with a `Location` on the same site under its canonical host (`www` or not, `https`),
repeat the control against that host and use it for the probe too. Anything else — a
challenge page, a `403` from the edge, a redirect elsewhere — means the host is not answering
this client the way it answers a visitor, and any verdict on the paid file would be read off
the WAF, not the server: the check is `UNMEASURED`, with the control status line as evidence.

```bash
curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"
# HEAD not allowed (405/501)? The same capped one-byte ranged GET:
curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"
```

**Then probe the paid file** with the **path only**, over the same host, and read the status
— never save the body, which would copy the paid file:

```bash
curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"
# HEAD not allowed (405/501)? Fall back to a one-byte ranged GET, body discarded and capped
# in case the server ignores the range:
curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"
```

Exit `63` from either fallback means the server ignored the range and announced a larger file;
curl stopped before the body and the status line is still in its output — read it. Any other
non-zero exit, or no status line at all, is `UNMEASURED`, quoting the curl exit code.

Read the verdict off that first response:

| Response | Verdict |
|---|---|
| `200` or `206` with any `content-type` other than `text/html` | the file is served without a purchase → **CRITICAL** |
| `403` from the site's own server — no challenge headers (below) and the control returned `200`/`206` | protected → PASS |
| `404` from the site's own server, same conditions, and the probe file was `FOUND` | protected → PASS |
| `404` on a `NO-LOCAL-UPLOADS` or `MISSING-LOCALLY` probe file | the file may simply be gone → `UNMEASURED` |
| `403` carrying a challenge header: `cf-mitigated: challenge`, a `cf-chl-*` / `__cf_chl` cookie, `x-sucuri-block`, or any header naming a WAF or bot check | **a 403 from a WAF is not protection** — the challenge would clear for a browser and the file may still be open → `UNMEASURED` |
| `3xx` (login redirect or otherwise), `405` after the ranged fallback, `401`, `429`, `5xx`, or `200` with `text/html` (a soft 404 or a challenge page) | `UNMEASURED`, with the status line and headers as evidence |
| curl error (exit other than `0`/`63`) or empty response | `UNMEASURED`, quoting the curl exit code |

On a site behind Cloudflare or Sucuri every response carries the proxy's headers, the site's
own `403` included: `server: cloudflare`, `cf-ray` or `x-sucuri-id` on their own do not make it
a WAF answer; only a challenge or block header does.

Only the table's first three rows produce a verdict; everything else is `UNMEASURED`, never
`PASS`. The fix names the server: on nginx, a `location` block that denies direct access to
`woocommerce_uploads` (an `.htaccess` never runs there); and purge that path from any edge
cache (a CDN may already hold a public copy). One `200` proves the hole; do not enumerate or
download more files.
