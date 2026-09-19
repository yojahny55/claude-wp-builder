<?php
/**
 * Exercise the ACF path walker and writer inside a real WordPress.
 *
 * tests/checks/wp-polylang-nesting.sh already runs both under bare PHP, which proves the
 * logic. What it cannot prove is that the logic agrees with SCF: that get_field_objects()
 * really shapes a nested repeater the way the walker expects, and that update_field()
 * really stores what the writer hands it. Every defect this file has caught so far was in
 * that seam rather than in the logic either side of it.
 *
 * Run by tests/checks/wp-polylang-integration.sh via `wp eval-file`. Exits non-zero with
 * a FAIL line on the first disagreement.
 */

require_once dirname( __DIR__, 3 ) . '/skills/wp-polylang/scripts/pll-lib.php';

// $GLOBALS, not a plain variable. `wp eval-file` evaluates this file inside a WP-CLI
// method's local scope, so a top-level `$failed` here and the `global $failed` inside t()
// are two different variables: the assertions wrote to one and the exit status read the
// other, and the first run of this file printed INTEGRATION OK with two failures above it.
// pll-lib.php's own header documents the same trap for $args -- which is how it was found.
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

if ( ! function_exists( 'acf_add_local_field_group' ) ) {
	echo "FAIL [setup] acf_add_local_field_group() is missing -- SCF did not load\n";
	exit( 1 );
}

// A repeater whose rows carry a group. This is the shape the walker used to stop before,
// and the shape the writer's old dot-count reading mis-resolved.
acf_add_local_field_group( array(
	'key'      => 'group_fixture',
	'title'    => 'Fixture',
	'location' => array( array( array( 'param' => 'post_type', 'operator' => '==', 'value' => 'post' ) ) ),
	'fields'   => array(
		array(
			'key'        => 'field_sections',
			'name'       => 'sections',
			'label'      => 'Sections',
			'type'       => 'repeater',
			'sub_fields' => array(
				array( 'key' => 'field_heading', 'name' => 'heading', 'label' => 'Heading', 'type' => 'text' ),
				array(
					'key'        => 'field_cta',
					'name'       => 'cta',
					'label'      => 'CTA',
					'type'       => 'group',
					'sub_fields' => array(
						array( 'key' => 'field_label', 'name' => 'label', 'label' => 'Label', 'type' => 'text' ),
					),
				),
			),
		),
		array(
			'key'        => 'field_box',
			'name'       => 'box',
			'label'      => 'Box',
			'type'       => 'group',
			'sub_fields' => array(
				array(
					'key'        => 'field_inner',
					'name'       => 'inner',
					'label'      => 'Inner',
					'type'       => 'group',
					'sub_fields' => array(
						array( 'key' => 'field_text', 'name' => 'text', 'label' => 'Text', 'type' => 'text' ),
					),
				),
			),
		),
	),
) );

$source = wp_insert_post( array( 'post_title' => 'Source', 'post_status' => 'publish', 'post_type' => 'post' ) );
$target = wp_insert_post( array( 'post_title' => 'Target', 'post_status' => 'publish', 'post_type' => 'post' ) );
if ( ! $source || ! $target ) {
	echo "FAIL [setup] could not create fixture posts\n";
	exit( 1 );
}

update_field( 'sections', array(
	array( 'heading' => 'Top', 'cta' => array( 'label' => 'Nested' ) ),
), $source );
update_field( 'box', array( 'inner' => array( 'text' => 'Deep' ) ), $source );

// ---- the read half, against SCF's own field objects ---------------------------------
$payload = pllx_acf_payload( $source );
ksort( $payload );
$keys = array_keys( $payload );

t( 'repeater>group reaches SCF', in_array( 'sections.0.cta.label', $keys, true ), true );
t( 'nested value is the real one', isset( $payload['sections.0.cta.label'] ) ? $payload['sections.0.cta.label'] : null, 'Nested' );
t( 'group>group reaches SCF', isset( $payload['box.inner.text'] ) ? $payload['box.inner.text'] : null, 'Deep' );
t( 'top-level row field still walked', isset( $payload['sections.0.heading'] ) ? $payload['sections.0.heading'] : null, 'Top' );

// ---- the write half, which no pure test can reach -----------------------------------
// This is the assertion that matters most here: update_field() has to store a nested
// repeater the way the writer assembled it, and get_field() has to read it back the same
// way. The logic being right is not the same as SCF agreeing with it.
pllx_acf_write( $target, 'sections.0.cta.label', 'Anidado', $source );
$rows = get_field( 'sections', $target );
t( 'nested write lands in the row', isset( $rows[0]['cta']['label'] ) ? $rows[0]['cta']['label'] : null, 'Anidado' );

// The old dot-count writer read "inner" as a row index -- (int) 'inner' is 0 -- and wrote
// into row 0 of a field that has no rows. Against a real SCF that produced a group
// silently holding nothing.
pllx_acf_write( $target, 'box.inner.text', 'Profundo', $source );
$box = get_field( 'box', $target );
t( 'group>group nests rather than indexing', isset( $box['inner']['text'] ) ? $box['inner']['text'] : null, 'Profundo' );
t( 'group>group did not create a row 0', isset( $box[0] ), false );

// A path that does not match the structure must leave the field untouched.
$before = get_field( 'box', $target );
pllx_acf_write( $target, 'box.nope.text', 'X', $source );
t( 'unmatched path writes nothing', get_field( 'box', $target ), $before );

$failed = $GLOBALS['pllx_fixture_failed'];
echo $failed ? "INTEGRATION FAILED\n" : "INTEGRATION OK\n";
exit( $failed );
