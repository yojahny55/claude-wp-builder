#!/usr/bin/env bash
# Almost every check in this suite is a contract grep, because almost everything this
# plugin ships is prose that instructs Claude at runtime. This one is different, and the
# difference is worth stating: pll-lib.php is real PHP, its top-level code is all
# `if (!defined(...))` guards that touch no WordPress function, and the ACF path walker
# and resolver inside it are pure array manipulation. So they can be RUN here, against
# fixture structures, and asserted on their output.
#
# What that buys: the translation payload walker used to stop at one level of nesting, so
# a group inside a repeater was dropped -- no error, and a counterpart that read as
# translated because its top-level fields were. A grep cannot catch that coming back. This
# can, by walking a structure and counting what comes out.
#
# The write half is only half testable. pllx_acf_set() is pure and is exercised below;
# pllx_acf_write(), which wraps it, calls get_field()/update_field() and stays covered by
# tests/checks/wp-polylang-live.sh against a real site with PLL_TEST_SITE set.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

lib=skills/wp-polylang/scripts/pll-lib.php
[ -f "$lib" ] || fail "$lib is missing"
[ -r "$lib" ] || fail "$lib exists but cannot be read"
command -v php >/dev/null 2>&1 || fail "php is not on PATH; this check executes the walker rather than grepping it"

php -l "$lib" >/dev/null 2>&1 || fail "$lib does not parse; every assertion below would report a contract failure instead"

out=$(php -d error_reporting=E_ALL -d display_errors=1 -r '
require_once "'"$PWD/$lib"'";

$fail = 0;
function check( $label, $got, $want ) {
    global $fail;
    if ( $got !== $want ) {
        echo "MISMATCH [$label] got: " . var_export( $got, true ) . " want: " . var_export( $want, true ) . "\n";
        $fail = 1;
    }
}

// A repeater whose rows carry a group, which carries text. The group is the level the
// walker used to stop before.
$nested = array(
    "sections" => array(
        "type"  => "repeater",
        "value" => array(
            0 => array( "heading" => "H", "cta" => array( "label" => "L" ) ),
        ),
        "sub_fields" => array(
            array( "name" => "heading", "type" => "text" ),
            array( "name" => "cta", "type" => "group", "sub_fields" => array(
                array( "name" => "label", "type" => "text" ),
            ) ),
        ),
    ),
);
$out = array();
pllx_acf_walk( $nested, $out );
check( "repeater>group>text", array_keys( $out ), array( "sections.0.heading", "sections.0.cta.label" ) );
check( "nested value carried", isset( $out["sections.0.cta.label"] ) ? $out["sections.0.cta.label"] : null, "L" );

// A link nested inside a group: only its title is translatable, and the url must never
// be emitted -- it is re-pointed by the reference pass instead.
$link = array(
    "box" => array(
        "type"  => "group",
        "value" => array( "more" => array( "title" => "Read", "url" => "/x", "target" => "" ) ),
        "sub_fields" => array( array( "name" => "more", "type" => "link" ) ),
    ),
);
$out = array();
pllx_acf_walk( $link, $out );
check( "group>link emits title only", array_keys( $out ), array( "box.more.title" ) );

// Flexible content: the layout is matched by NAME, and acf_fc_layout is never emitted as
// translatable text even though it is a string sitting in the row.
$flex = array(
    "blocks" => array(
        "type"  => "flexible_content",
        "value" => array(
            0 => array( "acf_fc_layout" => "quote", "body" => "B" ),
        ),
        "layouts" => array(
            array( "name" => "quote", "sub_fields" => array(
                array( "name" => "body", "type" => "text" ),
            ) ),
        ),
    ),
);
$out = array();
pllx_acf_walk( $flex, $out );
check( "flex layout matched by name", array_keys( $out ), array( "blocks.0.body" ) );

// A layout that defines a sub_field literally called acf_fc_layout must still not have it
// emitted: it is the row identifier, and translating it would rename the layout.
$flex["blocks"]["layouts"][0]["sub_fields"][] = array( "name" => "acf_fc_layout", "type" => "text" );
$out = array();
pllx_acf_walk( $flex, $out );
check( "acf_fc_layout never emitted", array_keys( $out ), array( "blocks.0.body" ) );

// Three containers deep, which no previous version reached at all.
$deep = array(
    "page" => array(
        "type"  => "group",
        "value" => array( "rows" => array( 0 => array( "cta" => array( "label" => "D" ) ) ) ),
        "sub_fields" => array(
            array( "name" => "rows", "type" => "repeater", "sub_fields" => array(
                array( "name" => "cta", "type" => "group", "sub_fields" => array(
                    array( "name" => "label", "type" => "text" ),
                ) ),
            ) ),
        ),
    ),
);
$out = array();
pllx_acf_walk( $deep, $out );
check( "group>repeater>group>text", array_keys( $out ), array( "page.rows.0.cta.label" ) );

// ---- the write half: resolution by structure, not by counting dots ----------------
// "a.b.c" against a GROUP of a GROUP must nest. The old dot-count writer read part 2 as a
// row index here -- (int) "cta" is 0 -- and wrote into row 0 of a field with no rows.
$def = array( "type" => "group", "sub_fields" => array(
    array( "name" => "cta", "type" => "group", "sub_fields" => array(
        array( "name" => "label", "type" => "text" ),
    ) ),
) );
$node = array();
$okw  = pllx_acf_set( $node, $def, array( "cta", "label" ), "V", array(), "box.cta.label" );
check( "group>group resolves as keys", $okw, true );
check( "group>group placement", $node, array( "cta" => array( "label" => "V" ) ) );

// The same shape of path against a REPEATER must index instead.
$rdef = array( "type" => "repeater", "sub_fields" => array(
    array( "name" => "label", "type" => "text" ),
) );
$node = array();
pllx_acf_set( $node, $rdef, array( "0", "label" ), "V", array(), "rows.0.label" );
check( "repeater resolves as index", $node, array( 0 => array( "label" => "V" ) ) );

// A brand-new flexible-content row must inherit acf_fc_layout from the source row: SCF
// drops a row that has none, and the walker never emits it as translatable.
$fdef = array( "type" => "flexible_content", "layouts" => array(
    array( "name" => "quote", "sub_fields" => array( array( "name" => "body", "type" => "text" ) ) ),
) );
$node = array();
$src  = array( 0 => array( "acf_fc_layout" => "quote", "body" => "source" ) );
pllx_acf_set( $node, $fdef, array( "0", "body" ), "V", $src, "blocks.0.body" );
check( "flex row backfills layout", $node, array( 0 => array( "acf_fc_layout" => "quote", "body" => "V" ) ) );

// A path that does not match the structure must refuse rather than write somewhere
// plausible. Silently writing to a guessed location is the defect this replaced.
$node = array();
$bad  = pllx_acf_set( $node, $def, array( "nope", "label" ), "V", array(), "box.nope.label" );
check( "unknown sub-field refuses", $bad, false );
check( "unknown sub-field writes nothing", $node, array() );

echo $fail ? "PHPFAIL\n" : "PHPOK\n";
' 2>&1)

case "$out" in
  *PHPOK*) : ;;
  *) echo "$out" | sed 's/^/  /'; fail "the ACF path walker or resolver behaved differently from the contract above" ;;
esac

# The ceiling sentence the walker used to carry must not come back by accident: someone
# reverting the recursion would leave the code and the docblock agreeing on the wrong thing.
grep -Fq -- 'Nesting is walked to any depth' "$lib" \
  || fail "$lib no longer documents that nesting is walked to any depth"

echo "PASS: ACF nesting walked to any depth, layout matched by name, paths resolved by structure ($(echo "$out" | grep -c PHPOK) run)"
