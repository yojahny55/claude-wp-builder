#!/usr/bin/env bash
# templates/store/store-theme.php and store.css against a real WordPress with WooCommerce,
# served over HTTP, in a minimal theme shaped like the tailwind starter (its header opens
# <main id="primary">, its pages render an <article> in .site-main):
#   - before install, WooCommerce runs the theme in compatibility mode (no .store-page, no
#     product tabs, no gallery scripts) — the control;
#   - after install, shop and product pages use WooCommerce's templates inside one <main> and
#     one id="primary", with the gallery scripts and no sidebar fallback notice;
#   - the stylesheet is linked on shop, product, cart and my account, and on no other page.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks. It provisions its own store
# fixture (WP_FIXTURE_STORE=1).
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi
require_tool python3 curl php

prov=tests/fixtures/wp/provision.sh
DIR=""; SERVER_PID=""
cleanup() {
  status=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(WP_FIXTURE_STORE=1 bash "$prov") || fail "could not provision a store fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"

# A theme with the starter's shape: header opens the one <main>, pages are an article.
T="$DIR/wp-content/themes/fx-theme"
mkdir -p "$T/inc" "$T/assets/css"
printf '/*\nTheme Name: FX Theme\nText Domain: fx-theme\n*/\n' > "$T/style.css"
printf ':root { --color-primary: #0f766e; }\n' > "$T/assets/css/main.css"
cat > "$T/functions.php" <<'PHP'
<?php
add_action( 'wp_enqueue_scripts', function () {
	wp_enqueue_style( 'fx-theme-tailwind', get_theme_file_uri( 'assets/css/main.css' ), array(), '1' );
} );
if ( file_exists( __DIR__ . '/inc/store-theme.php' ) ) {
	require_once __DIR__ . '/inc/store-theme.php';
}
PHP
cat > "$T/header.php" <<'PHP'
<!doctype html><html <?php language_attributes(); ?>><head><meta charset="utf-8"><?php wp_head(); ?></head>
<body <?php body_class(); ?>><?php wp_body_open(); ?>
<main id="primary" class="site-main">
PHP
printf '</main>\n<?php wp_footer(); ?></body></html>\n' > "$T/footer.php"
cat > "$T/index.php" <<'PHP'
<?php get_header(); while ( have_posts() ) { the_post(); ?><article <?php post_class(); ?>><div class="entry-content"><?php the_content(); ?></div></article><?php } get_footer();
PHP
$WP theme activate fx-theme >/dev/null 2>&1 || fail "could not activate the test theme"
$WP rewrite structure '/%postname%/' --hard >/dev/null 2>&1 || fail "could not set pretty permalinks"
$WP eval-file tests/fixtures/wp/woo-product.php >/dev/null 2>&1 || fail "no fixture product"
SAMPLE=$($WP eval 'echo (int) wp_insert_post( array( "post_type" => "page", "post_status" => "publish", "post_title" => "Plain page", "post_content" => "Hello" ) );' 2>/dev/null)
[ "${SAMPLE:-0}" -gt 0 ] || fail "could not create a plain page"

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
$WP server --host=127.0.0.1 --port="$PORT" >"$DIR/store-theme-server.log" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)" = "200" ] && { up=1; break; }
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -10 "$DIR/store-theme-server.log"; fail "wp server exited before answering on port $PORT"; }
  sleep 1
done
[ -n "$up" ] || { tail -5 "$DIR/store-theme-server.log"; fail "the fixture site never answered on port $PORT"; }

get() { curl -s "http://127.0.0.1:$PORT/$1"; }
count() { grep -o -- "$1" <<<"$2" | wc -l | tr -d ' '; }
has() { grep -F -- "$1" >/dev/null <<<"$2"; }

# Control: compatibility mode.
html=$(get product/fixture-mug/)
has 'Fixture Mug' "$html" || fail "the product page did not render the product"
has 'class="store-page"' "$html" && fail "control: a .store-page wrapper before anything was installed"
has 'woocommerce-tabs' "$html" && fail "control: product tabs rendered, so the fixture is not in compatibility mode and proves nothing"

# Install, as Step 6.6 does.
sed -e 's/__prefix__/fx_theme/g' -e 's/__textdomain__/fx-theme/g' templates/store/store-theme.php > "$T/inc/store-theme.php"
php -l "$T/inc/store-theme.php" >/dev/null || fail "the substituted file does not parse"
/bin/cp -f templates/store/store.css "$T/assets/css/store.css"

for page in shop/ product/fixture-mug/; do
  html=$(get "$page")
  [ "$(count 'id="primary"' "$html")" = 1 ] || fail "$page: id=\"primary\" appears $(count 'id="primary"' "$html") times; WooCommerce's wrapper is still there"
  [ "$(count '<main' "$html")" = 1 ] || fail "$page: $(count '<main' "$html") <main> elements"
  has 'class="store-page"' "$html" || fail "$page: no .store-page wrapper"
  has 'fx-theme-store-css' "$html" || fail "$page: store.css is not linked"
  has 'theme-compat' "$html" && fail "$page: WordPress's theme-compat sidebar notice rendered"
done
has 'ul class="products' "$(get shop/)" || fail "the shop lists no products"
html=$(get product/fixture-mug/)
has 'woocommerce-tabs' "$html" || fail "the product page is still in compatibility mode (no tabs)"
for script in zoom flexslider photoswipe; do
  has "$script" "$html" || fail "the product page loads no $script script: gallery support was not declared"
done
for page in cart/ my-account/; do
  has 'fx-theme-store-css' "$(get "$page")" || fail "$page: store.css is not linked"
done
for page in "" plain-page/ "?s=mug"; do
  has 'fx-theme-store-css' "$(get "$page")" && fail "store.css is linked on a page that is not a store page: /$page"
done
if grep -E 'PHP (Fatal|Warning|Notice|Deprecated)' "$DIR/store-theme-server.log" >/dev/null; then
  grep -E 'PHP (Fatal|Warning|Notice|Deprecated)' "$DIR/store-theme-server.log" | sed -n 1,3p
  fail "PHP reported errors while serving the store pages"
fi

echo "PASS: store-theme puts shop and product pages on WooCommerce's templates in one <main>, and loads store.css on store pages only"
