#!/usr/bin/env bash
# CF7 missing form: a contact section rendered the settings-page shortcode with a bare
# do_shortcode(). The form it named had been re-imported under a new id, and CF7 printed
# its "Not Found" notice inside the live page. The starter's prefix_contact_form() must
# return '' for a form that does not exist (by hash, id or title), so the section is
# skipped. Behaviour test: CF7 and WordPress are stubbed, the real helper is loaded.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v php >/dev/null || { echo "SKIP: php not installed"; exit 0; }

helper=starter-theme/__tailwind__/inc/cf7-helpers.php
grep -Fq 'function __starter___contact_form()' "$helper" || fail "$helper has no contact-form helper"
grep -Fq 'prefix_contact_form()' commands/wp-section.md || fail "/wp-section does not render the settings form through the helper"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/run.php" <<PHP
<?php
define('ABSPATH', '/');
function add_action() {}
function shortcode_parse_atts(\$t) { preg_match_all('/(\w+)="([^"]*)"/', \$t, \$m); return array_combine(\$m[1], \$m[2]); }
function do_shortcode(\$s) { return 'RENDERED'; }
\$GLOBALS['opt'] = '';
function __starter___get_field(\$n, \$p) { return \$GLOBALS['opt']; }
\$GLOBALS['forms'] = array('id' => array(12 => 1), 'hash' => array('a1b2c3d' => 1), 'title' => array('Contact' => 1));
function wpcf7_contact_form(\$id) { return isset(\$GLOBALS['forms']['id'][\$id]) ? new stdClass() : null; }
function wpcf7_get_contact_form_by_hash(\$h) { return isset(\$GLOBALS['forms']['hash'][\$h]) ? new stdClass() : null; }
function wpcf7_get_contact_form_by_title(\$t) { return isset(\$GLOBALS['forms']['title'][\$t]) ? new stdClass() : null; }
require '$PWD/$helper';
\$cases = array(
  array('', ''),
  array('[contact-form-7 id="12"]', 'RENDERED'),
  array('[contact-form-7 id="99"]', ''),
  array('[contact-form-7 id="a1b2c3d" title="Contact"]', 'RENDERED'),
  array('[contact-form-7 id="ffffff0"]', ''),
  array('[contact-form-7 title="Contact"]', 'RENDERED'),
  array('[contact-form-7 title="Gone"]', ''),
  array('[other-form id="3"]', 'RENDERED'),
);
foreach (\$cases as \$c) {
  \$GLOBALS['opt'] = \$c[0];
  \$got = __starter___contact_form();
  if (\$got !== \$c[1]) { echo "FAIL: '{\$c[0]}' gave '\$got', expected '{\$c[1]}'\n"; exit(1); }
}
echo "ok\n";
PHP
out=$(php "$tmp/run.php") || fail "$out"
[ "$out" = ok ] || fail "$out"

echo PASS
