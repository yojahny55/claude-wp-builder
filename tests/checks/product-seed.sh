#!/usr/bin/env bash
# A store's products (N01 piece 4a): wp-normalize extracts them into products[], /wp-seed
# --products creates them through skills/wp-woocommerce/scripts/product-seed.php, and /wp-yolo
# passes the flag on a store. This pins the contract and runs product-lib.php's decisions under
# bare PHP; tests/checks/product-seed-integration.sh runs the script on a real store.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

script=skills/wp-woocommerce/scripts/product-seed.php
lib=skills/wp-woocommerce/scripts/product-lib.php
for f in "$script" "$lib" skills/wp-seed-run/references/products.md; do
  [ -f "$f" ] || fail "$f is missing"
done

need_token commands/wp-seed.md '[--products <file>]'
need_token commands/wp-seed.md '## Phase 2.5: Products (`--products` only)'
need_token commands/wp-seed.md 'skills/wp-seed-run/references/products.md'
need_token skills/wp-seed-run/references/parse-demo.md '**`--products <file>`**'
need_token skills/wp-seed-run/references/products.md 'product-seed.php" "$2" "$3" dry-run'
need_token skills/wp-seed-run/references/products.md 'append `force` to the second call'
need_token skills/wp-seed-run/references/products.md 'has no `store`
block'
need_token agents/wp-normalize.md '### `products[]` — the store'"'"'s products'
need_token agents/wp-normalize.md 'never write copy, prices or categories the demo does not'
need_token agents/wp-normalize.md 'products without a name or a plain regular_price'
need_token commands/wp-yolo.md 'On a store, also pass `--products`: `demo/products.json`'
need_token docs/known-ceilings.md '**Seeded products are simple or External, in one language.**'
need_token BACKLOG.md 'tests/checks/product-seed.sh'
need_token BACKLOG.md 'tests/checks/product-seed-integration.sh'
need_token .github/workflows/ci.yml 'bash tests/checks/product-seed-integration.sh'

# The script: marker, identity and digests saved with the product; the client's product left alone.
need_token "$script" "\$prodseed_product->update_meta_data( \$prodseed_marker, 1 );"
need_token "$script" "exists without the seed marker"
need_token "$script" "copy( \$ref, \$tmp )"
need_token "$script" "\$GLOBALS['prodseed_meta'] = array("

require_tool php
for f in "$script" "$lib"; do
  php -l "$f" >/dev/null || fail "$f does not parse"
done

out=$(
LIB="$PWD/$lib" php -d error_reporting=E_ALL -d display_errors=1 <<'PHP' 2>&1
<?php
ob_start();
require getenv( 'LIB' );
if ( '' !== ob_get_clean() ) { echo "MISMATCH [require] the library printed output\n"; exit( 1 ); }
$fail = 0;
function check( $label, $got, $want ) {
	global $fail;
	if ( $got !== $want ) {
		echo "MISMATCH [$label] got: " . var_export( $got, true ) . ' want: ' . var_export( $want, true ) . "\n";
		$fail = 1;
	}
}
function err( $raw ) {
	$got = prodseed_normalize( $raw, '/demo' );
	return isset( $got['error'] ) ? $got['error'] : 'ok';
}
function entry( $raw ) {
	$got = prodseed_normalize( $raw, '/demo' );
	return isset( $got['entry'] ) ? $got['entry'] : array();
}

// Prices are plain decimals: no currency sign, no comma, no negative.
check( 'a plain price', prodseed_price( '24.00' ), '24.00' );
check( 'an integer price', prodseed_price( 24 ), '24' );
check( 'a padded price is trimmed', prodseed_price( ' 24.5 ' ), '24.5' );
check( 'a currency sign is refused', prodseed_price( '$24' ), null );
check( 'a thousands comma is refused', prodseed_price( '1,299.00' ), null );
check( 'a decimal comma is refused', prodseed_price( '24,00' ), null );
check( 'a negative price is refused', prodseed_price( '-1' ), null );
check( 'a missing price is refused', prodseed_price( null ), null );
check( 'no name', err( array( 'regular_price' => '1' ) ), 'no name' );
check( 'sale not lower', err( array( 'name' => 'A', 'regular_price' => '10', 'sale_price' => '10' ) ), 'sale_price 10 is not lower than regular_price 10' );
check( 'an external url must be http', err( array( 'name' => 'A', 'regular_price' => '1', 'external_url' => 'javascript:alert(1)' ) ), 'external_url is not an http(s) URL' );
check( 'categories must be names', err( array( 'name' => 'A', 'regular_price' => '1', 'categories' => array( '' ) ) ), 'categories holds an empty or non-string name' );

// Identity: the sku, else the key, else the name.
check( 'sku is the identity', entry( array( 'name' => 'Mug', 'sku' => 'M-1', 'regular_price' => '1' ) )['key'], 'sku:M-1' );
check( 'key without a sku', entry( array( 'name' => 'Mug', 'key' => 'The Mug', 'regular_price' => '1' ) )['key'], 'the-mug' );
check( 'the name slugified', entry( array( 'name' => 'Big Mug!', 'regular_price' => '1' ) )['key'], 'big-mug' );
setlocale( LC_ALL, 'C' );
check( 'accents fold the same under any locale', entry( array( 'name' => 'Café Ñandú Øl', 'regular_price' => '1' ) )['key'], 'cafe-nandu-ol' );
$two = prodseed_normalize_all( array( array( 'name' => 'Mug', 'regular_price' => '1' ), array( 'name' => 'mug', 'regular_price' => '2' ) ), '/demo' );
check( 'one identity twice is an error on the second', array( count( $two['entries'] ), $two['errors'] ), array( 1, array( 'mug: same identity (mug) as Mug; give one of them a sku or a key' ) ) );

// Shape: type, images, categories, options.
$e = entry( array( 'name' => 'Lamp', 'regular_price' => '80', 'external_url' => 'https://d.example/l', 'button_text' => 'Buy', 'image' => 'img/l.png', 'gallery' => array( 'https://cdn.example/a.png', '/abs/b.png' ), 'categories' => array( 'b', 'a', 'b' ), 'options' => array( 'Size' => array( 'S' ) ) ) );
check( 'external_url makes an External product', $e['type'], 'external' );
check( 'a relative image resolves against the file directory', $e['image'], '/demo/img/l.png' );
check( 'URLs and absolute paths are kept', $e['gallery'], array( 'https://cdn.example/a.png', '/abs/b.png' ) );
check( 'categories are unique and sorted', $e['categories'], array( 'a', 'b' ) );
check( 'options are flagged', array( $e['has_options'], $e['options'] ), array( true, array( 'Size' ) ) );
check( 'button text only on External', entry( array( 'name' => 'M', 'regular_price' => '1', 'button_text' => 'Go' ) )['button_text'], '' );

// Whose value is a field?
$d = prodseed_digest( '12.00' );
check( 'already the source value', prodseed_decide( '13.00', $d, '13.00', false ), 'skip' );
check( 'ours, and the source changed', prodseed_decide( '12.00', $d, '13.00', false ), 'update' );
check( 'the client edited it', prodseed_decide( '15.00', $d, '13.00', false ), 'conflict' );
check( 'no record is not ours', prodseed_decide( '12.00', null, '13.00', false ), 'conflict' );
check( 'force takes it back', prodseed_decide( '15.00', $d, '13.00', true ), 'update' );
check( 'lists compare by content', prodseed_decide( array( 'a', 'b' ), prodseed_digest( array( 'a', 'b' ) ), array( 'a', 'c' ), false ), 'update' );
exit( $fail );
PHP
) || fail "product-lib.php decisions:
$out"
[ -z "$out" ] || fail "product-lib.php printed: $out"

echo "PASS: /wp-seed --products creates a store's products from the demo, owned field by field, and reports what it leaves"
