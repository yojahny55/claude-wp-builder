<?php
/**
 * Runs the two SEC-040 snippets from agents/wp-audit-security.md against a stubbed options
 * table and checks what they do, not what they say.
 *
 * Usage: php sec040-gateway-credentials-behavior.php <detect-snippet> <scrub-snippet>
 * Each snippet file holds the PHP between `$WP eval '` and the closing `'`, as extracted by
 * tests/checks/audit-gateway-credentials.sh. Exits non-zero with one line per failure.
 */

$failures = array();
function sec040_fail( $msg ) {
	global $failures;
	$failures[] = $msg;
}

// --- minimal WordPress stubs ---------------------------------------------------------------

class wpdb {
	public $options = 'wp_options';
	private $likes  = array();

	public function esc_like( $text ) {
		return addcslashes( $text, '_%\\' );
	}

	public function prepare( $query, ...$args ) {
		if ( 1 === count( $args ) && is_array( $args[0] ) ) {
			$args = $args[0];
		}
		if ( substr_count( $query, '%s' ) !== count( $args ) ) {
			sec040_fail( 'prepare(): ' . substr_count( $query, '%s' ) . ' placeholders for ' . count( $args ) . ' arguments' );
		}
		$this->likes = $args;
		return $query;
	}

	public function get_col( $query ) {
		$out = array();
		foreach ( array_keys( $GLOBALS['sec040_options'] ) as $name ) {
			foreach ( $this->likes as $like ) {
				if ( sec040_like( $name, $like ) ) {
					$out[] = $name;
					break;
				}
			}
		}
		return $out;
	}
}

/** SQL LIKE with backslash escapes: `_` is one character, `%` any run, `\_` and `\%` literal. */
function sec040_like( $subject, $pattern ) {
	$re = '';
	for ( $i = 0, $n = strlen( $pattern ); $i < $n; $i++ ) {
		$c = $pattern[ $i ];
		if ( '\\' === $c && $i + 1 < $n ) {
			$re .= preg_quote( $pattern[ ++$i ], '/' );
		} elseif ( '%' === $c ) {
			$re .= '.*';
		} elseif ( '_' === $c ) {
			$re .= '.';
		} else {
			$re .= preg_quote( $c, '/' );
		}
	}
	return 1 === preg_match( '/^' . $re . '$/s', $subject );
}

function get_option( $name, $default = false ) {
	return array_key_exists( $name, $GLOBALS['sec040_options'] ) ? $GLOBALS['sec040_options'][ $name ] : $default;
}

// Like WordPress, update_option() compares against the stored value and saves nothing when they
// match — so a scrub that edits the object get_option() handed back, instead of a copy, saves
// nothing, here as on a real site.
function update_option( $name, $value ) {
	if ( array_key_exists( $name, $GLOBALS['sec040_options'] )
		&& serialize( $GLOBALS['sec040_options'][ $name ] ) === serialize( $value ) ) {
		return false;
	}
	$GLOBALS['sec040_updates'][] = $name;
	$GLOBALS['sec040_options'][ $name ] = $value;
	return true;
}

$wpdb = new wpdb();

// --- fixture ---------------------------------------------------------------------------------
// Every secret value holds a unique sentinel, so any of them reaching the output is caught.

$fixture = array(
	'woocommerce_demo_settings'                     => array(
		'enabled'               => 'no',
		'title'                 => 'Card',
		'description'           => 'Pay with your card',
		'tokenization'          => 'yes',
		'password_protected'    => 'yes',
		'require_signature'     => 'yes',
		'use_hmac'              => '1',
		'send_token'            => 'off',
		'signature_method'      => 'HMAC-SHA256',
		'token_type'            => 'Bearer',
		'api_key_status'        => 'valid',
		'debug'                 => 'no',
		'api_key'               => 'SENTINEL-01',
		'secret_key'            => '',
		'secret_key_v3'         => 'SENTINEL-02',
		'shared_secret_eu'      => 'SENTINEL-03',
		'test_shared_secret_us' => 'SENTINEL-04',
		'api_password'          => 'SENTINEL-05',
		'api_signature'         => 'SENTINEL-06',
		'pass_phrase'           => 'SENTINEL-07',
		'webhook_secret'        => 'SENTINEL-08',
		'key_secret'            => 'SENTINEL-09',
		'identity_token'        => 'SENTINEL-10',
		'secretsha256_2'        => 'SENTINEL-11',
		'customtestsha256'      => 'SENTINEL-12',
		'transaction_key'       => 'SENTINEL-13',
		'refresh_token'         => 'SENTINEL-14',
		'clave256'              => 'SENTINEL-29',
		'merchant_id_eu'        => 'MID-EU',
		'site_key_v3'           => 'site-public',
		'client_key'            => 'client-public',
		'publishable_key'       => 'pk_public',
		'test_publishable_key'  => 'pk_test_public',
		'merchant_key'          => 'merchant-public',
		'key_id'                => 'rzp_key_id',
		'api_username'          => 'api-user',
		'receiver_email'        => 'shop@example.com',
		'merchant_account'      => 'ACCOUNT',
		'credentials'           => array(
			'production' => array(
				'client_secret' => 'SENTINEL-15',
				'merchant_id'   => 'MID-PROD',
				'mode'          => 'live',
			),
			'sandbox'    => array(
				'client_secret' => 'SENTINEL-16',
			),
		),
	),
	'woocommerce_ppcp-recaptcha_settings'           => array(
		'enabled'            => 'yes',
		'secret_key_v2'      => 'SENTINEL-17',
		'site_key_v2'        => 'site-public-v2',
		'recaptcha_site_key' => 'site-public-rc',
	),
	'woocommerce-ppcp-settings'                     => array(
		'client_id_production'     => 'CID',
		'client_secret_production' => 'SENTINEL-18',
		'merchant_email_production' => 'seller@example.com',
	),
	'mollie-payments-for-woocommerce_live_api_key'  => 'SENTINEL-19',
	'mollie-payments-for-woocommerce_test_api_key'  => 'SENTINEL-20',
	'mollie-payments-for-woocommerce_test_mode_enabled' => 'yes',
	'wc_square_access_tokens'                       => array( 'production' => 'SENTINEL-21' ),
	'_mp_access_token_prod'                         => 'SENTINEL-30',
	'_mp_public_key_prod'                           => 'APP_USR-public',
	'jetpack_private_options'                       => array(
		'blog_token'  => 'SENTINEL-22',
		'user_tokens' => array( 1 => 'SENTINEL-23' ),
	),
	'woocommerce_camel_settings'                    => array(
		'clientSecretLive' => 'SENTINEL-24',
		'merchantIdEU'     => 'MID-CAMEL',
		'publishableKey'   => 'pk_camel',
		'APIKey'           => 'SENTINEL-25',
		'account'          => (object) array(
			'accessToken' => 'SENTINEL-26',
			'mode'        => 'live',
		),
		'opaque'           => new ArrayObject( array( 'secret' => 'SENTINEL-27' ) ),
	),
	'woocommerce_object_settings'                   => (object) array(
		'api_key' => 'SENTINEL-28',
		'title'   => 'Stored as an object',
	),
	// Outside every enumerated pattern: never read, never touched.
	'unrelated_plugin_api_key'                      => 'SENTINEL-99',
	'woocommerce_currency'                          => 'EUR',
);

// The explicit expected CRITICAL set, as "<option> <dotted path or ->".
$expected_critical = array(
	'woocommerce_demo_settings api_key',
	'woocommerce_demo_settings secret_key_v3',
	'woocommerce_demo_settings shared_secret_eu',
	'woocommerce_demo_settings test_shared_secret_us',
	'woocommerce_demo_settings api_password',
	'woocommerce_demo_settings api_signature',
	'woocommerce_demo_settings pass_phrase',
	'woocommerce_demo_settings webhook_secret',
	'woocommerce_demo_settings key_secret',
	'woocommerce_demo_settings identity_token',
	'woocommerce_demo_settings secretsha256_2',
	'woocommerce_demo_settings customtestsha256',
	'woocommerce_demo_settings transaction_key',
	'woocommerce_demo_settings refresh_token',
	'woocommerce_demo_settings credentials.production.client_secret',
	'woocommerce_demo_settings credentials.sandbox.client_secret',
	'woocommerce_ppcp-recaptcha_settings secret_key_v2',
	'woocommerce-ppcp-settings client_secret_production',
	'mollie-payments-for-woocommerce_live_api_key -',
	'mollie-payments-for-woocommerce_test_api_key -',
	'wc_square_access_tokens production',
	'jetpack_private_options blog_token',
	'jetpack_private_options user_tokens.1',
	'woocommerce_camel_settings clientSecretLive',
	'woocommerce_camel_settings APIKey',
	'woocommerce_camel_settings account.accessToken',
	'woocommerce_object_settings api_key',
	'woocommerce_demo_settings clave256',
	'_mp_access_token_prod -',
);
// Objects other than stdClass are not walked: detection names them, the scrub leaves them.
$expected_unread = array(
	'woocommerce_camel_settings opaque',
);
$expected_info = array(
	'woocommerce_demo_settings merchant_id_eu',
	'woocommerce_demo_settings site_key_v3',
	'woocommerce_demo_settings client_key',
	'woocommerce_demo_settings publishable_key',
	'woocommerce_demo_settings test_publishable_key',
	'woocommerce_demo_settings merchant_key',
	'woocommerce_demo_settings key_id',
	'woocommerce_demo_settings api_username',
	'woocommerce_demo_settings receiver_email',
	'woocommerce_demo_settings merchant_account',
	'woocommerce_demo_settings credentials.production.merchant_id',
	'woocommerce_ppcp-recaptcha_settings site_key_v2',
	'woocommerce_ppcp-recaptcha_settings recaptcha_site_key',
	'woocommerce-ppcp-settings client_id_production',
	'woocommerce-ppcp-settings merchant_email_production',
	'woocommerce_camel_settings merchantIdEU',
	'woocommerce_camel_settings publishableKey',
	'_mp_public_key_prod -',
);

function sec040_run( $code ) {
	// The snippet runs in its own function scope, like `wp eval` gives it a fresh one.
	ob_start();
	try {
		eval( $code );
	} catch ( Throwable $e ) {
		ob_end_clean();
		sec040_fail( 'snippet threw: ' . $e->getMessage() );
		return '';
	}
	return (string) ob_get_clean();
}

function sec040_sentinels( $out, $label ) {
	if ( preg_match_all( '/SENTINEL-\d+/', $out, $m ) ) {
		sec040_fail( "$label printed secret value(s): " . implode( ', ', array_unique( $m[0] ) ) );
	}
}

/** Sets the value at a dotted path ("-" is the option itself). */
function sec040_blank( $value, $path ) {
	if ( '-' === $path ) {
		return '';
	}
	$segs = explode( '.', $path );
	$head = array_shift( $segs );
	$tail = implode( '.', $segs );
	if ( is_object( $value ) ) {
		$value = clone $value;
		$value->$head = '' === $tail ? '' : sec040_blank( $value->$head, $tail );
	} else {
		$value[ $head ] = '' === $tail ? '' : sec040_blank( $value[ $head ], $tail );
	}
	return $value;
}

/** A fresh deep copy, so a snippet that edits an object in place cannot corrupt the fixture. */
function sec040_copy( $value ) {
	return unserialize( serialize( $value ) );
}

/** Deep equality that sees inside objects (=== on objects compares identity). */
function sec040_same( $a, $b ) {
	return serialize( $a ) === serialize( $b );
}

$detect = file_get_contents( $argv[1] );
$scrub  = file_get_contents( $argv[2] );
if ( false === $detect || false === $scrub ) {
	fwrite( STDERR, "cannot read the extracted snippets\n" );
	exit( 2 );
}

// --- detection -------------------------------------------------------------------------------

$GLOBALS['sec040_options'] = sec040_copy( $fixture );
$GLOBALS['sec040_updates'] = array();
$out = sec040_run( $detect );
sec040_sentinels( $out, 'detection' );
if ( $GLOBALS['sec040_updates'] ) {
	sec040_fail( 'detection wrote to the options table' );
}

$got = array( 'CRITICAL' => array(), 'INFO' => array(), 'UNREAD' => array() );
foreach ( preg_split( '/\n/', trim( $out ) ) as $line ) {
	if ( '' === $line ) {
		continue;
	}
	if ( preg_match( '/^UNREAD (\S+): enabled=\S+ key=(\S+) class=\S+$/', $line, $m ) ) {
		$got['UNREAD'][] = $m[1] . ' ' . $m[2];
		continue;
	}
	if ( ! preg_match( '/^(CRITICAL|INFO) (\S+): enabled=(\S+) key=(\S+) len=(\d+)$/', $line, $m ) ) {
		sec040_fail( "detection printed an unexpected line: $line" );
		continue;
	}
	$got[ $m[1] ][] = $m[2] . ' ' . $m[4];
	if ( 'woocommerce_demo_settings' === $m[2] && 'no' !== $m[3] ) {
		sec040_fail( "detection reported enabled=$m[3] for a row whose enabled is no" );
	}
	if ( 0 === strpos( $m[2], 'mollie-' ) && '-' !== $m[3] ) {
		sec040_fail( "detection reported enabled=$m[3] for a single-value option" );
	}
}
foreach ( array( 'CRITICAL' => $expected_critical, 'INFO' => $expected_info, 'UNREAD' => $expected_unread ) as $level => $want ) {
	$have    = array_unique( $got[ $level ] );
	$missing = array_diff( $want, $have );
	$extra   = array_diff( $have, $want );
	if ( $missing ) {
		sec040_fail( "detection missed $level: " . implode( ', ', $missing ) );
	}
	if ( $extra ) {
		sec040_fail( "detection reported unexpected $level: " . implode( ', ', $extra ) );
	}
	if ( count( $have ) !== count( $got[ $level ] ) ) {
		sec040_fail( "detection printed a $level key more than once" );
	}
}

// --- scrub, once per option ------------------------------------------------------------------

$placeholder = '$name = "woocommerce_<gateway_id>_settings";';
if ( 1 !== substr_count( $scrub, $placeholder ) ) {
	sec040_fail( 'scrub snippet does not set $name from the woocommerce_<gateway_id>_settings placeholder exactly once' );
}
foreach ( $fixture as $option => $original ) {
	$paths = array();
	foreach ( $expected_critical as $entry ) {
		list( $opt, $path ) = explode( ' ', $entry, 2 );
		if ( $opt === $option ) {
			$paths[] = $path;
		}
	}
	$want = $original;
	foreach ( $paths as $path ) {
		$want = sec040_blank( $want, $path );
	}

	$GLOBALS['sec040_options'] = sec040_copy( $fixture );
	$GLOBALS['sec040_updates'] = array();
	$out = sec040_run( str_replace( $placeholder, '$name = ' . var_export( $option, true ) . ';', $scrub ) );
	sec040_sentinels( $out, "scrub of $option" );

	if ( ! sec040_same( $GLOBALS['sec040_options'][ $option ], $want ) ) {
		sec040_fail( "scrub of $option did not blank exactly the CRITICAL keys and keep the rest" );
	}
	$want_line = sprintf( "%s: %d secret value(s) blanked\n", $option, count( $paths ) );
	if ( $out !== $want_line ) {
		sec040_fail( "scrub of $option printed " . var_export( $out, true ) . ', expected ' . var_export( $want_line, true ) );
	}
	$want_updates = $paths ? array( $option ) : array();
	if ( $GLOBALS['sec040_updates'] !== $want_updates ) {
		sec040_fail( "scrub of $option called update_option for [" . implode( ', ', $GLOBALS['sec040_updates'] ) . '], expected [' . implode( ', ', $want_updates ) . ']' );
	}
	foreach ( $fixture as $other => $value ) {
		if ( $other !== $option && ! sec040_same( $GLOBALS['sec040_options'][ $other ], $value ) ) {
			sec040_fail( "scrub of $option changed $other" );
		}
	}
}

$GLOBALS['sec040_options'] = sec040_copy( $fixture );
$GLOBALS['sec040_updates'] = array();
$out = sec040_run( str_replace( $placeholder, '$name = "woocommerce_missing_settings";', $scrub ) );
if ( false === strpos( $out, 'nothing changed' ) ) {
	sec040_fail( 'scrub of a missing option does not say nothing changed: ' . var_export( $out, true ) );
}
if ( $GLOBALS['sec040_updates'] ) {
	sec040_fail( 'scrub of a missing option called update_option' );
}

if ( $failures ) {
	echo implode( "\n", $failures ), "\n";
	exit( 1 );
}
echo "ok\n";
