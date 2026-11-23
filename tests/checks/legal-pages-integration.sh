#!/usr/bin/env bash
# skills/wp-page-run/scripts/legal-pages.php against a real WordPress:
#   - a dry run writes nothing;
#   - core's own unfilled Privacy Policy draft is filled and stays a draft; the other pages
#     are created as drafts on page-legal.php, with the default-language fields and the
#     `_<lang>` copies, and the pending markers are counted;
#   - a second run creates nothing and changes nothing;
#   - a page someone wrote under one of the slugs is left byte for byte as it was;
#   - wp_page_for_privacy_policy is set only when it points at no page;
#   - a spec entry without default-language content fails the run.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi
require_tool python3

prov=tests/fixtures/wp/provision.sh
script=skills/wp-page-run/scripts/legal-pages.php
DIR=""
SCRATCH=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$SCRATCH"
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(bash "$prov") || fail "could not provision a WordPress fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
q() { $WP eval "$1" 2>/dev/null; }
run() { $WP eval-file "$script" "$@" 2>&1; }
spec="$SCRATCH/spec.json"

python3 - "$spec" <<'PY'
import json, sys
body = "<h2>Who we are</h2><p>Fixture Co. [[pending: registered address]]</p>" + "<p>Text.</p>" * 40
json.dump({"default_lang": "en", "updated": "2026-11-23", "pages": [
  {"role": "privacy", "slug": "privacy-policy",
   "title": {"en": "Privacy Policy", "es": "Politica de privacidad"},
   "content": {"en": body, "es": "<p>Texto. [[pending: domicilio]]</p>"}},
  {"role": "terms", "slug": "terms-and-conditions",
   "title": {"en": "Terms and Conditions"}, "content": {"en": "<p>Terms.</p>"}},
  {"role": "cookies", "slug": "cookie-policy",
   "title": {"en": "Cookie Policy"}, "content": {"en": "<p>Cookies.</p>"}}]}, open(sys.argv[1], "w"))
PY

core=$(q 'echo (int) get_option("wp_page_for_privacy_policy");')
[ "$core" -gt 0 ] || fail "the fixture has no core privacy draft to start from"
[ "$(q "echo get_post_status($core);")" = draft ] || fail "core privacy page is not a draft"
pages_before=$(q 'echo count(get_posts(array("post_type"=>"page","post_status"=>"any","numberposts"=>-1)));')

out=$(run "$spec" dry-run) || fail "dry run failed: $out"
[ "$(q 'echo count(get_posts(array("post_type"=>"page","post_status"=>"any","numberposts"=>-1)));')" = "$pages_before" ] || fail "dry run created a page"
[ -z "$(q "echo get_post_meta($core,'legal_content',true);")" ] || fail "dry run filled the core privacy draft"
printf '%s' "$out" | grep -c '"dry_run":true' >/dev/null || fail "dry run did not say so: $out"

out=$(run "$spec") || fail "run failed: $out"
action() { printf '%s\n' "$out" | python3 -c "import json,sys
for l in sys.stdin:
  l=l.strip()
  if l.startswith('{'):
    d=json.loads(l)
    if d['role']=='$1': print(d['action'], d['id'], d['pending'])"; }
read -r a id p <<<"$(action privacy)"
[ "$a $id $p" = "filled $core 2" ] || fail "privacy: expected 'filled $core 2', got '$a $id $p'"
read -r a terms p <<<"$(action terms)"; [ "$a $p" = "created 0" ] || fail "terms: expected created, got '$a $p'"
read -r a cookies p <<<"$(action cookies)"; [ "$a" = created ] || fail "cookies: expected created, got '$a'"
for i in "$core" "$terms" "$cookies"; do
  [ "$(q "echo get_post_status($i);")" = draft ] || fail "page $i is not a draft"
  [ "$(q "echo get_post_meta($i,'_wp_page_template',true);")" = page-legal.php ] || fail "page $i is not on page-legal.php"
  [ "$(q "echo get_post_meta($i,'legal_last_updated',true);")" = 20261123 ] || fail "page $i has no Ymd last-updated date"
done
q "echo get_post_meta($core,'legal_content',true);" | grep -c 'Who we are' >/dev/null || fail "privacy legal_content not written"
q "echo get_post_meta($core,'legal_content_es',true);" | grep -c 'Texto' >/dev/null || fail "privacy legal_content_es not written"
[ "$(q "echo get_post_meta($core,'legal_title_es',true);")" = "Politica de privacidad" ] || fail "privacy legal_title_es not written"
[ "$(q "echo get_post_field('post_name',$terms);")" = terms-and-conditions ] || fail "terms slug wrong"

# Second run: nothing new, nothing changed.
pages_after=$(q 'echo count(get_posts(array("post_type"=>"page","post_status"=>"any","numberposts"=>-1)));')
out=$(run "$spec") || fail "second run failed: $out"
[ "$(printf '%s\n' "$out" | grep -c '"action":"kept"')" = 3 ] || fail "second run did not keep all three: $out"
[ "$(q 'echo count(get_posts(array("post_type"=>"page","post_status"=>"any","numberposts"=>-1)));')" = "$pages_after" ] || fail "second run created a page"

# Core's privacy draft, once someone has edited it, is theirs: kept byte for byte.
fp() { q "\$p=get_post($1); echo md5(\$p->post_content.\$p->post_title.\$p->post_status.json_encode(get_post_meta($1)));"; }
$WP post create --post_type=page --post_status=draft --post_name=edited-privacy --post_title="Our privacy" --porcelain > "$SCRATCH/ep"
edited=$(cat "$SCRATCH/ep")
q "update_option('wp_page_for_privacy_policy', $edited);"
sleep 1
$WP post update "$edited" --post_content="Written by the client." --quiet
python3 - "$spec" "$SCRATCH/spec-edited.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["pages"][0]["slug"] = "edited-privacy"
json.dump(s, open(sys.argv[2], "w"))
PY
before=$(fp "$edited")
out=$(run "$SCRATCH/spec-edited.json") || fail "run over an edited privacy draft failed: $out"
read -r a id p <<<"$(action privacy)"; [ "$a $id" = "kept $edited" ] || fail "edited privacy draft: expected 'kept $edited', got '$a $id'"
[ "$before" = "$(fp "$edited")" ] || fail "the client's edited privacy draft changed"
# A terms entry under the privacy page's slug must never fill it either.
python3 - "$spec" "$SCRATCH/spec-role.json" "$edited" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["pages"] = [dict(s["pages"][1], slug="edited-privacy")]
json.dump(s, open(sys.argv[2], "w"))
PY
q "global \$wpdb; \$p=get_post($edited); \$wpdb->update(\$wpdb->posts, array('post_modified_gmt'=>\$p->post_date_gmt), array('ID'=>$edited)); clean_post_cache($edited);"
before=$(fp "$edited")
out=$(run "$SCRATCH/spec-role.json") || fail "run with a terms entry on the privacy slug failed: $out"
read -r a id p <<<"$(action terms)"; [ "$a" = kept ] || fail "terms entry on the privacy page's slug: expected kept, got '$a'"
[ "$before" = "$(fp "$edited")" ] || fail "a terms entry filled the privacy page"
q "update_option('wp_page_for_privacy_policy', $core);"

# A page someone wrote is never touched.
$WP post delete "$cookies" --force --quiet
mine=$($WP post create --post_type=page --post_status=publish --post_name=cookie-policy --post_title="Our cookies" --post_content="Written by the client." --porcelain)
before=$(q "\$p=get_post($mine); echo md5(\$p->post_content.\$p->post_title.\$p->post_status.json_encode(get_post_meta($mine)));")
out=$(run "$spec") || fail "run with a client page failed: $out"
read -r a id p <<<"$(action cookies)"; [ "$a $id" = "kept $mine" ] || fail "client cookie page: expected 'kept $mine', got '$a $id'"
after=$(q "\$p=get_post($mine); echo md5(\$p->post_content.\$p->post_title.\$p->post_status.json_encode(get_post_meta($mine)));")
[ "$before" = "$after" ] || fail "the client's cookie page changed"

# The privacy option: set when it points at nothing, left alone when it points at a page.
q 'update_option("wp_page_for_privacy_policy", 0);'
run "$spec" >/dev/null || fail "run with no privacy page set failed"
[ "$(q 'echo (int) get_option("wp_page_for_privacy_policy");')" = "$core" ] || fail "privacy option not set when it pointed at no page"
q "update_option('wp_page_for_privacy_policy', $mine);"
run "$spec" >/dev/null || fail "run with another privacy page set failed"
[ "$(q 'echo (int) get_option("wp_page_for_privacy_policy");')" = "$mine" ] || fail "privacy option overwritten while it pointed at a page"

# A broken entry fails the run.
python3 - "$spec" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["pages"][1]["content"] = {"es": "<p>x</p>"}
json.dump(s, open(sys.argv[1], "w"))
PY
if run "$spec" >/dev/null; then fail "an entry without default-language content did not fail the run"; fi

echo "PASS: legal pages are created as drafts, filled once, and never written over a client's page"
