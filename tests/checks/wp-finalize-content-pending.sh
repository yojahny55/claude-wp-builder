#!/usr/bin/env bash
# /wp-finalize Check 7 item 12 lists empty contact and social settings as content pending.
# The snippet is PHP that runs inside WordPress, so this check extracts it from the reference
# and runs it against stubbed acf_get_fields()/get_field(): a regex or fallback edit that
# stops reporting an empty field, or starts reporting a filled one, fails here.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

ref=skills/wp-finalize-run/references/wp-cli-runtime.md
cmd=commands/wp-finalize.md

need_token "$ref" '12. **Contact and social settings left empty (report only).**'
need_token "$ref" 'never turns Check 7'
need_token "$ref" '**Content pending**'
need_token "$cmd" 'Content pending (client to supply, never a FAIL)'

require_tool php

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The body between the "$WP eval '" line and the closing "}'" line of item 12.
awk '/^12\. \*\*Contact and social/ { on = 1 }
     on && /\$WP eval '\''$/ { grab = 1; next }
     grab && /^    }'\''$/ { print "}"; exit }
     grab { print }' "$ref" > "$tmp/snippet.php"
[ "$(grep -c 'PENDING' "$tmp/snippet.php")" -gt 0 ] || fail "could not extract the item 12 snippet from $ref"

cat > "$tmp/run.php" <<'PHP'
<?php
$GLOBALS['opts'] = array(
  'social_instagram'    => '',
  'social_facebook'     => 'https://example.com/fb',
  'social_whatsapp'     => null,
  'contact_email'       => 'hi@example.com',
  'contact_email_es'    => '',
  'contact_phone'       => false,
  'header_phone'        => '555',
  'business_address'    => array(),
  'business_address_es' => 'Calle 1',
  'social_vk'           => '',
  'copyright_text'      => '',
);
function acf_get_fields($g) {
  return $g === 'group_settings'
    ? array_map(function ($n) { return array('name' => $n); }, array_keys($GLOBALS['opts']))
    : false;
}
function get_field($n, $where) { return $where === 'option' ? $GLOBALS['opts'][$n] : null; }
PHP
cat "$tmp/snippet.php" >> "$tmp/run.php"

out=$(php "$tmp/run.php")
want=$(printf 'PENDING %s\n' social_instagram social_whatsapp contact_phone business_address social_vk)
[ "$out" = "$want" ] || fail "item 12 snippet printed:
$out
expected:
$want"

echo "PASS: /wp-finalize lists empty contact and social settings as content pending"
