#!/usr/bin/env bash
set -euo pipefail

# SEC-039 — paid WooCommerce downloads reachable without a purchase.
#
# The defect the check exists for: a store's paid files live under
# wp-content/uploads/woocommerce_uploads/, guarded only by an .htaccess `deny from all`.
# Apache honours it; nginx ignores it. With the `force`/`xsendfile` download method the store
# looks correctly configured from the admin while every paid file is fetchable by URL on an
# nginx host. `redirect` serves them from a public URL with no gate at all.
#
# What must not rot:
#   1. It is commerce-gated — N/A (no WooCommerce) on a non-commerce site, so adding it does
#      not move a generic site's score.
#   2. The live probe targets PRODUCTION, never the local clone, or a local Apache returns a
#      false PASS for a site wide open behind nginx.
#   3. The fix names the server layer (nginx location block, not .htaccess) and the check
#      reads the status of a HEAD/path-only request without downloading the paid file.
#   4. A WAF/bot-challenge 403 is not read as protection: a control request to a public
#      upload calibrates the host first, and every response outside CRITICAL (200/206 non-HTML)
#      or PASS (the server's own 403/404) is UNMEASURED, never PASS.
#   5. The probe file comes from _downloadable_files on published products AND published
#      variations, under /woocommerce_uploads/, printed as a percent-encoded relative path (the
#      stored URL carries the clone host); a bare 404 is PASS only for a file known to exist.
#   6. No request can pull the paid body: HEAD with a timeout, and a ranged GET capped by
#      --max-filesize when HEAD is refused.
#
# Every gate below runs on the SEC-039 procedure section only, so a phrase elsewhere in the
# agent (the file mentions "production" in other checks) cannot satisfy it.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

sec=agents/wp-audit-security.md
[ -f "$sec" ] || fail "$sec is missing"
[ -r "$sec" ] || fail "$sec exists but cannot be read"

# The code exists in the table, at CRITICAL.
grep -Eq '^\| SEC-039 \|.*\| CRITICAL \|$' "$sec" \
  || fail "$sec lost the SEC-039 table row, or it is no longer CRITICAL"

# Extract the procedure section, up to the next heading of level 2 or 3.
proc=$(awk '/^### Procedure — SEC-039/{on=1; print; next} on && /^##/{exit} on{print}' "$sec")
[ -n "$proc" ] || fail "$sec has no '### Procedure — SEC-039' section"
[ "$(printf '%s\n' "$proc" | wc -l)" -gt 20 ] || fail "SEC-039 procedure section is truncated"

# Prose wraps at 96 columns; flatten it so a phrase split across a line break still matches.
flat=$(printf '%s\n' "$proc" | tr '\n' ' ' | tr -s ' ')
# Here-strings, not pipes: under pipefail an early-exiting `grep -q` can SIGPIPE the writer and
# turn a match into status 141.
has()  { grep -Fq -- "$1" <<<"$flat"; }
# Exact code lines are matched unflattened, as whole lines.
line() { grep -Fxq -- "$1" <<<"$proc"; }

# The snippet block prints one labelled line each, so its output parses line by line.
has 'echo "METHOD ",get_option("woocommerce_file_download_method") ?: "force","\n";' \
  || fail "SEC-039 does not print the download method on its own labelled line"
has 'echo "UPLOADS-PATH ",rtrim((string) wp_parse_url(wp_upload_dir()["baseurl"],PHP_URL_PATH),"/"),"\n";' \
  || fail "SEC-039 does not print the uploads URL path"
has '**Build both URLs from `UPLOADS-PATH`, never from a hardcoded `/wp-content/uploads`.**' \
  || fail "SEC-039 hardcodes /wp-content/uploads (multisite and custom UPLOADS never measured)"
has '`/wp-content/uploads/sites/<N>` on a multisite subsite (run the snippets with `--url=<subsite>`)' \
  || fail "SEC-039 lost the multisite uploads path"
has 'It has no trailing slash and is empty when uploads sit at the web root, so `<uploads-path>/<path>` always joins with exactly one slash.' \
  || fail "SEC-039 does not say how UPLOADS-PATH joins (double slash at the web root)"
has 'when the uploads base URL sits on another host (media offloaded to a CDN or bucket), the control on the production host fails and the check is `UNMEASURED`' \
  || fail "SEC-039 does not say what happens when uploads are offloaded to another host"

# Commerce gating (relies on Step 2.3's site.commerce, does not re-detect).
has 'N/A (no WooCommerce)' || fail "SEC-039 is not gated N/A on a non-commerce site"

# redirect is CRITICAL by configuration, but only when the store keeps paid files in
# woocommerce_uploads: FOUND, or NO-LOCAL-UPLOADS (paid files not restored); UNMEASURED when the
# directory is here and the stored file is not.
has '**The redirect method is CRITICAL on `FOUND`**, and on `NO-LOCAL-UPLOADS`' \
  || fail "SEC-039 lost the redirect-method CRITICAL rule"
has 'On `MISSING-LOCALLY` (the files are here, the stored one is not) it is `UNMEASURED`' \
  || fail "SEC-039 flags redirect CRITICAL on a stored file that no longer exists"
has 'With `NO-DOWNLOADS` or `EXTERNAL-ONLY` it is `N/A`, exactly as for the other methods' \
  || fail "SEC-039 flags redirect CRITICAL even with no woocommerce_uploads download"

# The nginx-vs-Apache reason is the crux; if it goes, the check looks like a config lookup.
has 'nginx does not' || fail "SEC-039 lost the reason the .htaccess is inert on nginx"
# The fix must name the server layer, not propose editing the (inert) .htaccess.
has 'on nginx, a `location` block that denies direct access to `woocommerce_uploads`' \
  || fail "SEC-039 fix does not name an nginx location block"
has 'purge that path from any edge cache' || fail "SEC-039 fix lost the edge-cache purge"

# Live probe targets production, never the clone (false PASS on local Apache).
has 'returns a false PASS' || fail "SEC-039 does not warn that a local probe is a false PASS"
has '**production**, never the local clone' \
  || fail "SEC-039 does not require probing the production host"
has 'fire nothing until it is confirmed' \
  || fail "SEC-039 may fire the probe before the production host is confirmed"
has 'with no public URL the check is `UNMEASURED`, not `PASS`' \
  || fail "SEC-039 does not report a missing public URL as UNMEASURED"

# Probe-file selection: published stored downloads, variations included, relative + encoded.
has '_downloadable_files' || fail "SEC-039 does not read _downloadable_files"
has 'p.post_type=\"product_variation\"' || fail "SEC-039 misses downloads attached to variations"
has 'AND p.post_status=\"publish\"' || fail "SEC-039 probes trashed or draft products"
has 'par.post_status=\"publish\"' || fail "SEC-039 probes variations of unpublished products"
has 'which must never be probed' || fail "SEC-039 does not forbid probing the stored (clone) host"
has '$seg="/woocommerce_uploads/"' \
  || fail "SEC-039 does not cut the stored URL at /woocommerce_uploads/"
has 'file_exists($dir.$p)' || fail "SEC-039 does not prefer a probe file that exists locally"
has '$local=is_dir($dir)&&count(array_diff(scandir($dir),[".","..","index.html",".htaccess"]))>0;' \
  || fail "SEC-039 reads WooCommerce's recreated stub directory as restored paid files"
has 'the clone has no `woocommerce_uploads` directory, or only the `index.html` and `.htaccess` WooCommerce recreates there on its own' \
  || fail "SEC-039 lost the stub-directory case of NO-LOCAL-UPLOADS"
has 'echo $local?"MISSING-LOCALLY":"NO-LOCAL-UPLOADS"," $first\n";' \
  || fail "SEC-039 snippet does not tell a missing file from uploads that were never restored"
has 'array_map("rawurlencode",explode("/",$p))' \
  || fail "SEC-039 does not percent-encode the probe path"
has '`NO-DOWNLOADS` — no published product or variation stores a download: `N/A (no downloadable products)`' \
  || fail "SEC-039 lost the NO-DOWNLOADS marker"
has 'EXTERNAL-ONLY' && has 'N/A (downloads served from outside woocommerce_uploads)' \
  || fail "SEC-039 does not report external-only downloads as N/A with a reason"
has '`NO-CONTROL` — no public upload to calibrate against: `UNMEASURED`' \
  || fail "SEC-039 lost the NO-CONTROL marker"
has 'Never `PASS` without a probe file and a control file' \
  || fail "SEC-039 may PASS without a probe file"

# Control request calibrates the host before the paid file is judged.
has '**Control request first.**' || fail "SEC-039 lost the control request"
has '"meta_query"=>[["key"=>"_wp_attached_file","value"=>"woocommerce_uploads/","compare"=>"NOT LIKE"]]' \
  || fail "SEC-039 control file can be a paid file under woocommerce_uploads"
has 'repeat the control against that host and use it for the probe too' \
  || fail "SEC-039 lost the canonical-host repeat of the control request"
has 'a challenge page, a `403` from the edge, a redirect elsewhere' \
  || fail "SEC-039 lost the list of failed-control answers"
has 'the check is `UNMEASURED`, with the control status line as evidence' \
  || fail "SEC-039 does not report a failed control as UNMEASURED"
line 'curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"' \
  || fail "SEC-039 control request is not a timed HEAD on a public upload"
line 'curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"' \
  || fail "SEC-039 control has no capped ranged-GET fallback for a host that refuses HEAD"
has 'It must come back `200` or `206` with a non-HTML `content-type` (an `image/*`); a host that refuses HEAD (`405`/`501`) gets the same one-byte ranged GET as the paid file' \
  || fail "SEC-039 lost the control's 200/206 non-HTML criterion or its HEAD fallback"
has '?"CONTROL ".implode(' || fail "SEC-039 control snippet does not label its output line"
has 'redirects are not followed (no `-L`)' \
  || fail "SEC-039 does not say which response the verdict is read from"

# The paid-file probe itself, header-only and timed, plus the capped ranged fallback.
line 'curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"' \
  || fail "SEC-039 lost the header-only probe of the paid file"
line 'curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"' \
  || fail "SEC-039 ranged fallback is missing or uncapped (could download the paid file)"
has 'Exit `63` from either fallback means the server ignored the range and announced a larger file; curl stopped before the body and the status line is still in its output — read it.' \
  || fail "SEC-039 does not explain reading the status after a capped fallback (exit 63)"
has 'Any other non-zero exit, or no status line at all, is `UNMEASURED`, quoting the curl exit code' \
  || fail "SEC-039 does not report a curl error as UNMEASURED"

# Every code block in the procedure, compared whole: a changed, removed OR added line fails
# (an added `curl -sL -o paid.bin …` would otherwise slip past per-line presence checks). The
# fragment gates above say why each piece matters; this catches everything else.
code=$(awk '/^```bash$/{on=1; next} on && /^```$/{on=0; next} on' <<<"$proc")
expected_code=$(cat <<'EOF_SNIPPETS'
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
curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"
# HEAD not allowed (405/501)? The same capped one-byte ranged GET:
curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/<control-path>"
curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"
# HEAD not allowed (405/501)? Fall back to a one-byte ranged GET, body discarded and capped
# in case the server ignores the range:
curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host><uploads-path>/woocommerce_uploads/<path>"
EOF_SNIPPETS
)
if [ "$code" != "$expected_code" ]; then
  diff <(printf '%s\n' "$expected_code") <(printf '%s\n' "$code") | head -20 || true
  fail "SEC-039 code blocks differ from the pinned copy (a line changed, removed or added)"
fi

# Every curl the procedure names, in code or prose: header-only or capped, never following
# redirects, never writing a body anywhere but /dev/null.
curls=$(grep -oE 'curl +-[^`]*' <<<"$proc" || true)
[ "$(printf '%s\n' "$curls" | grep -c .)" -ge 4 ] || fail "SEC-039 lost its curl commands"
while IFS= read -r c; do
  case "$c" in
    *" -sI "*|*" --max-filesize "*) ;;
    *) fail "SEC-039 curl can download a body (neither -sI nor --max-filesize): $c" ;;
  esac
  if grep -Eq -- '(^| )(-[A-Za-z]*L[A-Za-z]*|--location(-trusted)?)( |$)' <<<"$c"; then
    fail "SEC-039 curl follows redirects: $c"
  fi
  rest=${c// -o \/dev\/null/}
  if grep -Eq -- '(^| )(-[A-Za-z]*[oO][A-Za-z]*|--output|--remote-name(-all)?|--output-dir)( |$)' <<<"$rest"; then
    fail "SEC-039 curl writes output somewhere other than /dev/null: $c"
  fi
done <<<"$curls"

# Verdict table compared whole: header, delimiter and exactly these seven consecutive rows. A
# paragraph between rows ends the table in GFM; an extra row (a second PASS) must fail too.
table=$(awk '/^\| Response \| Verdict \|$/{on=1} on && !/^\|/{exit} on' <<<"$proc")
expected_table=$(cat <<'EOF_TABLE'
| Response | Verdict |
|---|---|
| `200` or `206` with any `content-type` other than `text/html` | the file is served without a purchase → **CRITICAL** |
| `403` from the site's own server — no challenge headers (below) and the control returned `200`/`206` | protected → PASS |
| `404` from the site's own server, same conditions, and the probe file was `FOUND` | protected → PASS |
| `404` on a `NO-LOCAL-UPLOADS` or `MISSING-LOCALLY` probe file | the file may simply be gone → `UNMEASURED` |
| `403` carrying a challenge header: `cf-mitigated: challenge`, a `cf-chl-*` / `__cf_chl` cookie, `x-sucuri-block`, or any header naming a WAF or bot check | **a 403 from a WAF is not protection** — the challenge would clear for a browser and the file may still be open → `UNMEASURED` |
| `3xx` (login redirect or otherwise), `405` after the ranged fallback, `401`, `429`, `5xx`, or `200` with `text/html` (a soft 404 or a challenge page) | `UNMEASURED`, with the status line and headers as evidence |
| curl error (exit other than `0`/`63`) or empty response | `UNMEASURED`, quoting the curl exit code |
EOF_TABLE
)
if [ "$table" != "$expected_table" ]; then
  diff <(printf '%s\n' "$expected_table") <(printf '%s\n' "$table") | head -20 || true
  fail "SEC-039 verdict table is not the 7 pinned rows, consecutive after the delimiter"
fi
# GFM keeps a non-blank line straight after the last row inside the table: require a blank.
after_table=$(awk '/^\| Response \| Verdict \|$/{on=1} on && !/^\|/{print; exit}' <<<"$proc")
[ -z "$after_table" ] || fail "SEC-039 verdict table is not closed by a blank line: $after_table"
[ "$(grep -c '^|' <<<"$proc" || true)" -eq 9 ] \
  || fail "SEC-039 has table rows outside the verdict table (split table or stray row)"
has '`server: cloudflare`, `cf-ray` or `x-sucuri-id` on their own do not make it a WAF answer; only a challenge or block header does.' \
  || fail "SEC-039 may read any 403 on a proxied site as a WAF answer"
has 'Only the table'"'"'s first three rows produce a verdict; everything else is `UNMEASURED`, never `PASS`' \
  || fail "SEC-039 lets unclassified responses fall through to PASS"

# One 200 is enough.
has 'do not enumerate or download more files' \
  || fail "SEC-039 lost the 'one 200 is enough, do not download' bound"

echo PASS
