#!/usr/bin/env bash
# Under the suffix i18n strategy, /wp-page blog installs templates/blog-language/blog-language.php:
# a post_language select on posts, and the blog lists filtered to the visitor's language plus
# posts with no language. This runs the template against stubbed WordPress: a post with no
# language must stay listed (so an existing blog renders as before), singular views, feeds,
# admin and secondary queries must be left alone, and a Polylang project must never get it.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

ref=skills/wp-page-run/references/blog.md
tpl=templates/blog-language/blog-language.php
[ -f "$tpl" ] || fail "$tpl is missing"

need_token "$ref" '## Blog language (suffix strategy only)'
need_token "$ref" 'templates/blog-language/blog-language.php'
need_token "$ref" 'Under `polylang`, skip it'
need_token "$ref" 'or when the line is absent'
need_token "$ref" 'do not retype or "improve" it'
need_token "$ref" 'never load it twice'
need_token "$ref" 'stop and show the diff'
need_token "$tpl" "defined( 'ABSPATH' ) || exit;"
need_token "$tpl" "'compare' => 'NOT EXISTS'"
need_token BACKLOG.md 'tests/checks/blog-language-field.sh'

require_tool php

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -e 's/__prefix__/fx/g' -e 's/__PREFIX__/FX/g' -e 's/__textdomain__/fx-theme/g' "$tpl" > "$tmp/blog-language.php"
if grep -q '__prefix__\|__PREFIX__\|__textdomain__' "$tmp/blog-language.php"; then fail "$tpl has a token the reference does not substitute"; fi
php -l "$tmp/blog-language.php" >/dev/null || fail "$tpl does not parse"

cat > "$tmp/run.php" <<'PHP'
<?php
// argv: view (home|category|tag|author|date|search|single|page|feed|cpt-archive|admin|secondary),
//       langs (comma list, "-" = constant undefined), current lang, prior meta_query (0|1)
define( 'ABSPATH', __DIR__ . '/' );
if ( $argv[2] !== '-' ) { define( 'FX_SUPPORTED_LANGS', explode( ',', $argv[2] ) ); }
$GLOBALS['hooks'] = array();
$GLOBALS['admin'] = $argv[1] === 'admin';
$GLOBALS['group'] = null;
function add_action( $h, $f ) { $GLOBALS['hooks'][ $h ] = $f; }
function is_admin() { return $GLOBALS['admin']; }
function __( $s, $d ) { return $s; }
function acf_add_local_field_group( $g ) { $GLOBALS['group'] = $g; }
function fx_get_current_lang() { return $GLOBALS['argv'][3]; }
class WP_Query {
    public $vars = array(); public $view; public $main;
    function __construct( $view, $main ) { $this->view = $view; $this->main = $main; }
    function is_main_query() { return $this->main; }
    function is_singular() { return in_array( $this->view, array( 'single', 'page' ), true ); }
    function is_feed() { return $this->view === 'feed'; }
    function is_post_type_archive() { return $this->view === 'cpt-archive'; }
    function is_home() { return in_array( $this->view, array( 'home', 'admin', 'secondary', 'feed' ), true ); }
    function is_category() { return $this->view === 'category'; }
    function is_tag() { return $this->view === 'tag'; }
    function is_author() { return $this->view === 'author'; }
    function is_date() { return $this->view === 'date'; }
    function is_search() { return $this->view === 'search'; }
    function get( $k ) { return isset( $this->vars[ $k ] ) ? $this->vars[ $k ] : ''; }
    function set( $k, $v ) { $this->vars[ $k ] = $v; }
}
require __DIR__ . '/blog-language.php';
$GLOBALS['hooks']['acf/init']();
$q = new WP_Query( $argv[1], $argv[1] !== 'secondary' );
$prior = array( array( 'key' => 'featured', 'value' => '1' ) );
if ( $argv[4] === '1' ) { $q->set( 'meta_query', $prior ); }
$GLOBALS['hooks']['pre_get_posts']( $q );
$mq = $q->get( 'meta_query' );
$field = $GLOBALS['group'] ? implode( ',', array_keys( $GLOBALS['group']['fields'][0]['choices'] ) ) : 'nofield';
if ( $mq === '' || $mq === ( $argv[4] === '1' ? $prior : '' ) ) { echo "unfiltered|$field"; exit; }
// Find the language clause wherever it sits, and confirm a prior meta_query survived.
$clause = ( isset( $mq['relation'] ) && $mq['relation'] === 'AND' ) ? $mq[1] : $mq[0];
$kept = ( isset( $mq['relation'] ) && $mq[0] === $prior ) ? '+prior' : '';
$parts = array();
foreach ( $clause as $k => $c ) {
    if ( $k === 'relation' ) { $parts[] = $c; continue; }
    $parts[] = $c['compare'] === 'NOT EXISTS' ? 'none' : '=' . $c['value'];
}
echo implode( ' ', $parts ) . $kept . '|' . $field;
PHP

expect() { got=$(php "$tmp/run.php" "$1" "$2" "$3" "$4"); [ "$got" = "$5" ] || fail "view=$1 langs=$2 lang=$3 prior=$4: expected '$5', got '$got'"; }

expect home        en,es es 0 'OR =es = none|,en,es'
expect home        en,es en 0 'OR =en = none|,en,es'
expect category    en,es es 0 'OR =es = none|,en,es'
expect tag         en,es es 0 'OR =es = none|,en,es'
expect author      en,es es 0 'OR =es = none|,en,es'
expect date        en,es es 0 'OR =es = none|,en,es'
expect search      en,es es 0 'OR =es = none|,en,es'
expect home        en,es es 1 'OR =es = none+prior|,en,es'
expect single      en,es es 0 'unfiltered|,en,es'
expect page        en,es es 0 'unfiltered|,en,es'
expect feed        en,es es 0 'unfiltered|,en,es'
expect cpt-archive en,es es 0 'unfiltered|,en,es'
expect admin       en,es es 0 'unfiltered|,en,es'
expect secondary   en,es es 0 'unfiltered|,en,es'
expect home        -     es 0 'unfiltered|nofield'
echo "PASS: blog-language template filters blog lists by language and leaves the rest alone"
