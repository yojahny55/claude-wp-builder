#!/usr/bin/env bash
# skills/wp-woocommerce/scripts/product-seed.php against a real WordPress with WooCommerce and
# store-kit: the products /wp-seed --products creates from a demo or a client's products file.
#   - a dry run writes nothing; a run creates simple and External products with prices,
#     categories and an image imported from a copy (the demo's file stays), owned by an
#     administrator; a product with options is a draft and is reported for review;
#   - a second run changes nothing and imports no second attachment;
#   - a price the client edited is left alone while a changed source field is written, and
#     force takes the edited price back;
#   - a product with the same name but no seed marker is the client's: reported, untouched,
#     and no duplicate is created;
#   - an image that cannot be imported degrades the product, and the next run tries again;
#   - an invalid entry refuses the whole run with exit 1 before anything is written.
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
require_tool php

prov=tests/fixtures/wp/provision.sh
DIR=""
WORK=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$WORK"
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(WP_FIXTURE_STORE=1 bash "$prov") || fail "could not provision a store fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"
script=$PWD/skills/wp-woocommerce/scripts/product-seed.php

mkdir -p "$WORK/project/demo/img"
printf '{"project":{"prefix":"acme_"}}\n' >"$WORK/project/.wp-create.json"
# A 1x1 PNG.
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d >"$WORK/project/demo/img/mug.png"
products="$WORK/project/demo/products.json"
write_products() { # <mug price> <tote description>
  cat >"$products" <<JSON
{ "products": [
  { "name": "Stoneware Mug", "sku": "MUG-1", "regular_price": "$1", "categories": ["Kitchen", "Mugs", "Pots & Pans", "Chef's"],
    "image": "img/mug.png", "short_description": "Hand thrown.", "source": "shop.html" },
  { "name": "Canvas Tote", "regular_price": "30.00", "sale_price": "24.00", "description": "$2" },
  { "name": "Dealer Lamp", "regular_price": "80", "external_url": "https://dealer.example/lamp", "button_text": "Buy at the dealer" },
  { "name": "Linen Shirt", "regular_price": "45.00", "options": { "Size": ["S", "M", "L"] } }
] }
JSON
}

# Every output line and the exit code: "<lines> | <code>".
seed() { local out code=0; out=$($WP eval-file "$script" "$WORK/project" "$products" "$@" 2>&1) || code=$?; printf '%s | %s' "$out" "$code"; }
last() { printf '%s\n' "$1" | sed -n '$p'; }
has() { printf '%s\n' "$1" | grep -F -- "$2" >/dev/null || fail "no line \"$2\" in:
$1"; }
pid() { $WP eval "echo (int) wc_get_product_id_by_sku( '$1' );" 2>/dev/null; }
by_name() { $WP post list --post_type=product --post_status=any --title="$1" --format=ids 2>/dev/null; }
count() { $WP post list --post_type="$1" --post_status=any --format=count 2>/dev/null; }

write_products 12.00 "Heavy canvas."

got=$(seed dry-run)
has "$got" 'would-create sku:MUG-1'
has "$got" 'would-create linen-shirt: draft, has options Size'
[ "$(last "$got")" = "products: 4 to create, 0 to update, 0 unchanged, 0 conflict, 0 degraded | 0" ] || fail "dry run: $got"
[ "$(count product)" = 0 ] || fail "a dry run created products"

got=$(seed)
[ "$(last "$got")" = "products: 4 created, 0 updated, 0 unchanged, 0 conflict, 0 degraded | 0" ] || fail "first run: $got"
has "$got" 'review linen-shirt: options Size are not built as variations'
MUG=$(pid MUG-1)
[ "${MUG:-0}" -gt 0 ] || fail "no product with sku MUG-1"
facts=$($WP eval "\$p = wc_get_product( $MUG ); \$c = wp_get_post_terms( $MUG, 'product_cat', array( 'fields' => 'names' ) ); sort( \$c ); echo implode( '|', array( \$p->get_type(), \$p->get_status(), \$p->get_regular_price(), implode( ',', \$c ), get_post_meta( \$p->get_image_id(), '_acme_seeded_source', true ), user_can( (int) get_post_field( 'post_author', $MUG ), 'administrator' ) ? 'admin' : 'nobody' ) );" 2>/dev/null)
[ "$facts" = "simple|publish|12.00|Chef's,Kitchen,Mugs,Pots &amp; Pans|$WORK/project/demo/img/mug.png|admin" ] || fail "the mug is not what the source says: $facts"
[ -f "$WORK/project/demo/img/mug.png" ] || fail "importing the image moved the demo's own file"
TOTE=$(by_name "Canvas Tote")
[ "$($WP eval "\$p = wc_get_product( $TOTE ); echo \$p->get_regular_price() . '/' . \$p->get_sale_price();" 2>/dev/null)" = "30.00/24.00" ] || fail "the tote's sale price is wrong"
LAMP=$(by_name "Dealer Lamp")
[ "$($WP eval "\$p = wc_get_product( $LAMP ); echo \$p->get_type() . ' ' . \$p->get_product_url() . ' ' . \$p->get_button_text();" 2>/dev/null)" = "external https://dealer.example/lamp Buy at the dealer" ] || fail "the lamp is not an External product"
[ "$($WP post get "$(by_name "Linen Shirt")" --field=post_status 2>/dev/null)" = draft ] || fail "a product with options was published"
attachments=$(count attachment)

got=$(seed)
[ "$(last "$got")" = "products: 0 created, 0 updated, 4 unchanged, 0 conflict, 0 degraded | 0" ] || fail "an unchanged re-run: $got"
[ "$(count attachment)" = "$attachments" ] || fail "a re-run imported the image again"

$WP eval "\$p = wc_get_product( $MUG ); \$p->set_regular_price( '15.00' ); \$p->save();" >/dev/null 2>&1 || fail "could not edit the mug's price"
write_products 13.00 "Heavier canvas."
got=$(seed)
has "$got" 'conflict sku:MUG-1: regular_price edited in WooCommerce; left alone (force overwrites)'
has "$got" 'update canvas-tote: description'
[ "$(last "$got")" = "products: 0 created, 1 updated, 2 unchanged, 1 conflict, 0 degraded | 0" ] || fail "a run over a client's edit: $got"
[ "$($WP eval "echo wc_get_product( $MUG )->get_regular_price();" 2>/dev/null)" = "15.00" ] || fail "the client's price was overwritten"
got=$(seed force)
has "$got" 'update sku:MUG-1: regular_price'
[ "$($WP eval "echo wc_get_product( $MUG )->get_regular_price();" 2>/dev/null)" = "13.00" ] || fail "force did not take the price back"

CLIENT=$($WP wc product create --name="Copper Kettle" --regular_price=60 --user=1 --porcelain 2>/dev/null) || fail "could not create the client's product"
cat >"$products" <<JSON
{ "products": [
  { "name": "Copper Kettle", "regular_price": "55.00" },
  { "name": "Oak Board", "regular_price": "20.00", "image": "img/missing.png" }
] }
JSON
got=$(seed)
has "$got" "conflict copper-kettle: exists without the seed marker (product $CLIENT); left alone"
has "$got" 'degraded oak-board: image '
[ "$(by_name "Copper Kettle" | wc -w | tr -d ' ')" = 1 ] || fail "a second Copper Kettle was created beside the client's"
[ "$($WP eval "echo wc_get_product( $CLIENT )->get_regular_price();" 2>/dev/null)" = "60" ] || fail "the client's product was changed"
got=$(seed)
has "$got" 'degraded oak-board: image '

printf '{"products":[{"name":"Bad Price","regular_price":"$24"},{"name":"Fine","regular_price":"5"}]}\n' >"$products"
before=$(count product)
got=$(seed)
has "$got" 'invalid Bad Price: regular_price is missing or not a plain decimal'
case "$(last "$got")" in "refused: 1 invalid product(s) in "*" | 1") ;; *) fail "an invalid entry: $got" ;; esac
[ "$(count product)" = "$before" ] || fail "a refused run wrote products"

echo "PASS: product-seed creates a store's products once, keeps the client's edits and products, and says what it could not do"
