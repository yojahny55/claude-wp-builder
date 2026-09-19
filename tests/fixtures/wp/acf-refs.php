<?php
/**
 * Exercise the ACF reference re-pointing pass inside a real WordPress with real Polylang.
 *
 * The text walk and the reference pass are two traversals of the same structure, and they
 * disagreed: the walk recursed and this did not, so a nested link came out with a
 * translated title on a URL still pointing at the source language. That is worse than the
 * untranslated link it replaced, because it reads as correct.
 *
 * Nothing pure can prove this one. Re-pointing needs pll_get_post() to resolve a real
 * translation group, and the ownership check needs meta that survives a round trip.
 */

require_once dirname( __DIR__, 3 ) . '/skills/wp-polylang/scripts/pll-lib.php';

$GLOBALS['pllx_fixture_failed'] = 0;

function t( $label, $got, $want ) {
	if ( $got !== $want ) {
		echo "FAIL [$label]\n  got:  " . var_export( $got, true ) . "\n  want: " . var_export( $want, true ) . "\n";
		$GLOBALS['pllx_fixture_failed'] = 1;
		return false;
	}
	echo "ok   [$label]\n";
	return true;
}

// ---- languages -----------------------------------------------------------------------
if ( ! function_exists( 'PLL' ) || ! class_exists( 'PLL_Settings' ) ) {
	echo "FAIL [setup] Polylang is not loaded\n";
	exit( 1 );
}

// Created through pllx_add_language(), the function pll-setup.php ships, so this fixture
// exercises the real path rather than a copy of it that could agree with a bug. It found
// one on its first run: the helper called PLL()->model->add_language(), which is defined
// only on PLL_Admin_Model, which Polylang instantiates only when is_admin() is true --
// never under `wp eval-file`, which is how every script here is documented to run.
$have = (array) pll_languages_list();
foreach ( array( 'en' => 'en_US', 'es' => 'es_ES' ) as $code => $locale ) {
	if ( ! in_array( $code, $have, true ) ) {
		pllx_add_language( $code, array( $code => $locale ) );
	}
}

// ---- a field group with a link nested inside a repeater row's group -------------------
acf_add_local_field_group( array(
	'key'      => 'group_refs',
	'title'    => 'Refs',
	'location' => array( array( array( 'param' => 'post_type', 'operator' => '==', 'value' => 'post' ) ) ),
	'fields'   => array(
		array(
			'key'        => 'field_rows',
			'name'       => 'rows',
			'label'      => 'Rows',
			'type'       => 'repeater',
			'sub_fields' => array(
				array(
					'key'        => 'field_card',
					'name'       => 'card',
					'label'      => 'Card',
					'type'       => 'group',
					'sub_fields' => array(
						array( 'key' => 'field_more', 'name' => 'more', 'label' => 'More', 'type' => 'link' ),
						array( 'key' => 'field_rel', 'name' => 'rel', 'label' => 'Rel', 'type' => 'post_object' ),
					),
				),
			),
		),
	),
) );

function mkpost( $title, $lang ) {
	$id = wp_insert_post( array( 'post_title' => $title, 'post_status' => 'publish', 'post_type' => 'post' ) );
	pll_set_post_language( $id, $lang );
	return $id;
}

// The page being linked TO, in both languages, joined as one translation group.
$dest_en = mkpost( 'Destination', 'en' );
$dest_es = mkpost( 'Destino', 'es' );
pll_save_post_translations( array( 'en' => $dest_en, 'es' => $dest_es ) );

// The page carrying the nested reference, in both languages.
$src = mkpost( 'Source', 'en' );
$tgt = mkpost( 'Fuente', 'es' );
pll_save_post_translations( array( 'en' => $src, 'es' => $tgt ) );

update_field( 'rows', array(
	array( 'card' => array(
		'more' => array( 'title' => 'Read more', 'url' => get_permalink( $dest_en ), 'target' => '' ),
		'rel'  => $dest_en,
	) ),
), $src );

// Mirror the import's real order, which matters here and is easy to get wrong -- the first
// version of this fixture did. pllx_acf_copy_untranslated() copies every non-text value to
// the counterpart BEFORE any translated text is written, so by the time the text pass runs,
// the target's link already holds the source's url and target and only its title changes.
//
// Writing just the title into a link that does not exist yet produces an array with no url,
// which ACF cannot round-trip: get_field() hands back an empty value and the title is gone.
// That is a property of the link field, not a defect in the writer, and reproducing the
// wrong order here would have tested a state the pipeline never creates.
$seed = get_field( 'rows', $src );
pllx_acf_write( $tgt, 'rows.0.card.more', $seed[0]['card']['more'], $src );
pllx_acf_write( $tgt, 'rows.0.card.rel', $seed[0]['card']['rel'], $src );

// Now the counterpart holds the translated TITLE on the source-language URL: the exact
// state the old top-level-only re-pointing left behind, and the one that reads as
// translated while going to the wrong language.
pllx_acf_write( $tgt, 'rows.0.card.more.title', 'Leer mas', $src );

$before = pllx_acf_get( $tgt, 'rows.0.card.more', $src );
t( 'title was translated first', isset( $before['title'] ) ? $before['title'] : null, 'Leer mas' );

// ---- the pass under test ---------------------------------------------------------------
$n = pllx_repoint_acf_refs( $src, $tgt, 'es' );

$after = pllx_acf_get( $tgt, 'rows.0.card.more', $src );
t( 'nested link url re-pointed to the es counterpart',
	isset( $after['url'] ) ? $after['url'] : null, get_permalink( $dest_es ) );

// The re-point must not undo the translation that was already there. The old top-level
// code preserved the title by read-modify-write; the path version has to keep doing that.
t( 'translated title survives the re-point',
	isset( $after['title'] ) ? $after['title'] : null, 'Leer mas' );

$rel = pllx_acf_get( $tgt, 'rows.0.card.rel', $src );
$rel_id = is_object( $rel ) ? (int) $rel->ID : (int) $rel;
t( 'nested post_object re-pointed', $rel_id, $dest_es );

t( 'the pass reported what it changed', $n > 0, true );

// ---- ownership is per path, not per field name ------------------------------------------
// An editor changes the link on the counterpart. A second run must leave it alone, and
// must say so rather than quietly restoring its own earlier value.
$edited = $after;
$edited['url'] = 'https://example.invalid/editor-chose-this';
pllx_acf_write( $tgt, 'rows.0.card.more', $edited, $src );

pllx_repoint_acf_refs( $src, $tgt, 'es' );
$final = pllx_acf_get( $tgt, 'rows.0.card.more', $src );
t( "an editor's nested edit is not overwritten",
	isset( $final['url'] ) ? $final['url'] : null, 'https://example.invalid/editor-chose-this' );

$failed = $GLOBALS['pllx_fixture_failed'];
echo $failed ? "INTEGRATION FAILED\n" : "INTEGRATION OK\n";
exit( $failed );
