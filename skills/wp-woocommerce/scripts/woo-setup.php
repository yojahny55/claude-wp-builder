<?php
/**
 * woo-setup.php -- bring a WooCommerce store in line with the `store` block in .wp-create.json.
 *
 * Usage: wp eval-file woo-setup.php <project-path> [dry-run] [force]
 *   The flags are bare words: `wp eval-file` refuses a --flag it does not know.
 *   dry-run  print what would change, write nothing
 *   force    also take back values this script did not write (a client's edit, an adopted store),
 *            except launch state on a store with orders, which force never changes
 *
 * Every line is `<status> <setting>[: detail]`:
 *   set / would-set  changed (or would be, in a dry or report-only run)
 *   ok               already what the block says
 *   client           differs, and this script did not write it: left alone (force takes it back,
 *                    except launch state on a store with orders)
 *   degraded         could not be done here, or a row setup created that the block no longer
 *                    names (setup never deletes); the line says why and what to do
 *   note             information, counted nowhere
 * and the last line is the summary: `setup: 12 set, 31 already right, 1 client's, 1 degraded`.
 *
 * Exit 0: the store matches the block (degraded lines allowed). Exit 1: refused, with a
 * `refused:` line, before anything is written.
 *
 * Stripe keys are read here -- the environment first, then .wp-create.local.json, the order
 * bin/lib/manifest.mjs resolveSecret() uses -- so they never pass through a command line or a
 * transcript, and they are never printed. PHP 7.4 floor.
 */

require_once __DIR__ . '/woo-lib.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

function wooset_refuse( $message ) {
	WP_CLI::line( 'refused: ' . $message );
	WP_CLI::halt( 1 );
}

function wooset_report( $status, $id, $detail = '' ) {
	$c = &$GLOBALS['wooset_ctx'];
	if ( 'set' === $status && ! $c['write'] ) {
		$status = 'would-set';
	}
	$bucket = array( 'set' => 'set', 'would-set' => 'set', 'ok' => 'ok', 'client' => 'client', 'degraded' => 'degraded' );
	if ( isset( $bucket[ $status ] ) ) {
		$c['n'][ $bucket[ $status ] ]++;
	}
	WP_CLI::line( $status . ' ' . $id . ( '' === $detail ? '' : ': ' . $detail ) );
}

/**
 * One owned value: read it, decide whose it is, write it if it is ours, record what we wrote.
 * $kind: 'secret' -- a credential, shown only as a fingerprint in any note; 'launch' -- decides
 * whether a store takes real money, and is never written on a store that has orders.
 */
function wooset_converge( $id, $desired, $get, $set, $note = '', $kind = '' ) {
	$c        = &$GLOBALS['wooset_ctx'];
	$current  = call_user_func( $get );
	$recorded = isset( $c['state'][ $id ] ) ? $c['state'][ $id ] : null;
	$held     = 'launch' === $kind && $c['orders'];
	// On a store with orders launch state is never written, absent or not, forced or not:
	// WooCommerce reads an absent coming-soon row as a live shop, so writing one takes it offline.
	$decision = $held
		? ( wooset_same( $current, $desired ) ? 'ok' : 'client' )
		: wooset_decide( $current, $desired, $recorded, $c['fresh'], $c['force'] );
	if ( 'set' === $decision && $c['write'] ) {
		call_user_func( $set, $desired );
	}
	if ( 'client' !== $decision && $c['write'] ) {
		$c['state'][ $id ] = wooset_hash( $desired );
	}
	if ( 'client' === $decision ) {
		$show = 'secret' === $kind ? 'wooset_fingerprint' : 'wooset_show';
		$note = 'kept ' . ( $held && null === $current ? 'absent' : $show( $current ) ) . ', the block says ' . $show( $desired )
			. ( $held ? ' (launch state on a store with orders: change it in WooCommerce, force does not)' : ' (force takes it back)' );
	}
	wooset_report( $decision, $id, $note );
	return $decision;
}

function wooset_option( $option, $value, $note = '', $kind = '' ) {
	return wooset_converge(
		$option,
		$value,
		function () use ( $option ) {
			return get_option( $option, null );
		},
		function ( $v ) use ( $option ) {
			update_option( $option, $v );
		},
		$note,
		$kind
	);
}

function wooset_suboption( $option, $key, $value, $note = '', $kind = '' ) {
	return wooset_converge(
		$option . '.' . $key,
		$value,
		function () use ( $option, $key ) {
			$o = get_option( $option, array() );
			return is_array( $o ) && array_key_exists( $key, $o ) ? $o[ $key ] : null;
		},
		function ( $v ) use ( $option, $key ) {
			$o         = get_option( $option, array() );
			$o         = is_array( $o ) ? $o : array();
			$o[ $key ] = $v;
			update_option( $option, $o );
		},
		$note,
		$kind
	);
}

function wooset_has_orders() {
	return (bool) wc_get_orders( array( 'limit' => 1, 'return' => 'ids', 'status' => 'any' ) );
}

function wooset_page_ok( $id ) {
	return $id && 'publish' === get_post_status( (int) $id );
}

/** The status of an assigned page that exists unpublished and is not in the trash (the client's draft), or ''. */
function wooset_page_held( $id ) {
	$status = $id ? get_post_status( (int) $id ) : false;
	return $status && ! in_array( $status, array( 'publish', 'trash' ), true ) ? $status : '';
}

/** A page's content for a checkout type, or null when WooCommerce's block markup cannot be read. */
function wooset_page_content( $page, $mode ) {
	if ( 'shortcode' === $mode ) {
		return '<!-- wp:shortcode -->[woocommerce_' . $page . ']<!-- /wp:shortcode -->';
	}
	$method = 'get_' . $page . '_block_content';
	if ( ! method_exists( 'WC_Install', $method ) ) {
		return null;
	}
	// ponytail: WooCommerce's default block markup lives in a protected helper; reflection reads
	// it rather than a copy that would go stale. If the helper is renamed, switching back to the
	// block checkout reports degraded instead of guessing markup.
	$m = new ReflectionMethod( 'WC_Install', $method );
	if ( PHP_VERSION_ID < 80100 ) {
		$m->setAccessible( true );
	}
	return (string) $m->invoke( null );
}

/** Stripe test keys: environment first, then <project>/.wp-create.local.json. Never printed. */
function wooset_read_keys( $root ) {
	$local = array();
	$file  = $root . '/.wp-create.local.json';
	if ( is_readable( $file ) ) {
		$decoded = json_decode( (string) file_get_contents( $file ), true );
		if ( ! is_array( $decoded ) ) {
			wooset_refuse( '.wp-create.local.json is not valid JSON' );
		}
		$local = isset( $decoded['store']['payments'] ) && is_array( $decoded['store']['payments'] ) ? $decoded['store']['payments'] : array();
	}
	$keys = array();
	$envs = array(
		'test_secret_key'      => 'WP_CREATE_STRIPE_TEST_SECRET_KEY',
		'test_publishable_key' => 'WP_CREATE_STRIPE_TEST_PUBLISHABLE_KEY',
		'test_webhook_secret'  => 'WP_CREATE_STRIPE_TEST_WEBHOOK_SECRET',
	);
	foreach ( $envs as $field => $env ) {
		$from_env       = getenv( $env );
		$keys[ $field ] = ( false !== $from_env && '' !== $from_env )
			? (string) $from_env
			: ( isset( $local[ $field ] ) && is_string( $local[ $field ] ) ? $local[ $field ] : '' );
	}
	return $keys;
}

function wooset_config_path() {
	foreach ( array( ABSPATH . 'wp-config.php', dirname( ABSPATH ) . '/wp-config.php' ) as $file ) {
		if ( is_file( $file ) ) {
			return is_writable( $file ) ? $file : null;
		}
	}
	return null;
}

function wooset_step_environment() {
	$type = wp_get_environment_type();
	if ( 'local' !== $type ) {
		wooset_report( 'note', 'environment', "reads as $type: cash on delivery stays off and the store stays coming soon (a dev site sets WP_ENVIRONMENT_TYPE=local)" );
	}
}

function wooset_step_admin() {
	wooset_option( 'woocommerce_onboarding_profile', array( 'skipped' => true ) );
	wooset_option( 'woocommerce_task_list_hidden_lists', array( 'setup', 'extended' ) );
	wooset_option( 'woocommerce_allow_tracking', 'no' );
	wooset_option( 'woocommerce_show_marketplace_suggestions', 'no' );
	wooset_option( 'woocommerce_admin_created_default_shipping_zones', 'yes', 'WooCommerce Home adds no zone of its own' );
	if ( $GLOBALS['wooset_ctx']['write'] ) {
		delete_transient( '_wc_activation_redirect' );
	}
}

function wooset_step_hpos() {
	$c = $GLOBALS['wooset_ctx'];
	if ( 'yes' === get_option( 'woocommerce_custom_orders_table_enabled' ) ) {
		wooset_report( 'ok', 'hpos', 'order tables authoritative' );
	} elseif ( wooset_has_orders() ) {
		wooset_report( 'degraded', 'hpos', 'off, and this store has orders: migrating is your decision (wp wc hpos sync, then wp wc hpos enable)' );
		return;
	} elseif ( ! $c['write'] ) {
		wooset_report( 'set', 'hpos', 'enable before any order exists' );
		return;
	} else {
		$r  = WP_CLI::runcommand( 'wc hpos enable', array( 'return' => 'all', 'launch' => false, 'exit_error' => false ) );
		$ok = 'yes' === get_option( 'woocommerce_custom_orders_table_enabled' );
		wooset_report( $ok ? 'set' : 'degraded', 'hpos', $ok ? 'enabled before any order exists' : 'wc hpos enable failed: ' . trim( (string) $r->stderr ) );
		if ( ! $ok ) {
			return;
		}
	}
	wooset_option( 'woocommerce_custom_orders_table_data_sync_enabled', 'no', 'no second copy of every order in the posts tables' );
}

function wooset_step_identity( $store ) {
	$a = $store['address'];
	wooset_option( 'woocommerce_store_address', $a['street'] );
	wooset_option( 'woocommerce_store_city', $a['city'] );
	wooset_option( 'woocommerce_store_postcode', $a['postcode'] );
	wooset_option( 'woocommerce_default_country', $a['country'] );
	wooset_option( 'woocommerce_currency', $store['currency'] );
	wooset_option( 'woocommerce_weight_unit', $store['units']['weight'] );
	wooset_option( 'woocommerce_dimension_unit', $store['units']['dimension'] );
}

function wooset_step_pages( $store ) {
	$c       = $GLOBALS['wooset_ctx'];
	$missing = array();
	foreach ( array( 'shop', 'cart', 'checkout', 'myaccount' ) as $page ) {
		if ( ! wooset_page_ok( get_option( "woocommerce_{$page}_page_id" ) ) ) {
			$missing[] = $page;
		}
	}
	if ( $missing && $c['write'] ) {
		WC_Install::create_pages();
	}
	foreach ( array( 'shop', 'cart', 'checkout', 'myaccount' ) as $page ) {
		$id = get_option( "woocommerce_{$page}_page_id" );
		if ( ! in_array( $page, $missing, true ) ) {
			wooset_report( 'ok', "page:$page" );
		} elseif ( $c['write'] && wooset_page_ok( $id ) ) {
			wooset_report( 'set', "page:$page", 'created and assigned' );
		} elseif ( wooset_page_held( $id ) ) {
			// WooCommerce keeps an assigned page it finds unpublished rather than make another.
			wooset_report( 'client', "page:$page", 'kept as ' . wooset_page_held( $id ) . ': publish it in WooCommerce' );
		} elseif ( ! $c['write'] ) {
			wooset_report( 'set', "page:$page", 'created and assigned' );
		} else {
			wooset_report( 'degraded', "page:$page", 'WooCommerce did not create it: WooCommerce > Status > Tools > Create default WooCommerce pages' );
		}
	}
	$terms = get_option( 'woocommerce_terms_page_id' );
	if ( wooset_page_ok( $terms ) ) {
		wooset_report( 'ok', 'page:terms' );
	} elseif ( wooset_page_held( $terms ) ) {
		wooset_report( 'client', 'page:terms', 'kept as ' . wooset_page_held( $terms ) . ': the client publishes the terms before launch' );
	} else {
		if ( $c['write'] ) {
			$id = wp_insert_post( array( 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'Terms and conditions', 'post_name' => 'terms' ) );
			update_option( 'woocommerce_terms_page_id', (int) $id );
		}
		wooset_report( 'set', 'page:terms', 'created empty: the client supplies the terms before launch' );
	}
	if ( 'catalog' !== $store['tier'] ) {
		$mode = isset( $store['checkout'] ) ? $store['checkout'] : 'block';
		foreach ( array( 'cart', 'checkout' ) as $page ) {
			$id = (int) get_option( "woocommerce_{$page}_page_id" );
			if ( ! $id ) {
				continue; // a dry run on a store whose pages do not exist yet
			}
			$content = wooset_page_content( $page, $mode );
			if ( null === $content ) {
				wooset_report( 'degraded', "page:$page:type", "cannot read WooCommerce's block markup to switch back to $mode" );
				continue;
			}
			wooset_converge(
				"page:$page:type",
				$mode,
				function () use ( $id, $page ) {
					return wooset_page_mode( (string) get_post_field( 'post_content', $id ), $page );
				},
				function () use ( $id, $content ) {
					wp_update_post( array( 'ID' => $id, 'post_content' => $content ) );
				},
				'shortcode' === $mode ? 'shortcode: ' . $store['checkout_reason'] : 'block'
			);
		}
	}
	wooset_page_languages();
}

function wooset_page_languages() {
	if ( ! function_exists( 'pll_default_language' ) || ! pll_default_language() ) {
		return;
	}
	$lang = pll_default_language();
	foreach ( array( 'shop', 'cart', 'checkout', 'myaccount', 'terms' ) as $page ) {
		$id = (int) get_option( "woocommerce_{$page}_page_id" );
		if ( ! $id ) {
			continue;
		}
		$have = pll_get_post_language( $id );
		if ( $have ) {
			wooset_report( 'ok', "page:$page:language", $have );
			continue;
		}
		if ( $GLOBALS['wooset_ctx']['write'] ) {
			pll_set_post_language( $id, $lang );
		}
		wooset_report( 'set', "page:$page:language", "$lang -- created before Polylang had a language, so it had none" );
	}
}

function wooset_step_rules( $store ) {
	wooset_option( 'woocommerce_manage_stock', 'yes' );
	wooset_option( 'woocommerce_enable_reviews', 'yes' );
	wooset_option( 'woocommerce_file_download_method', 'force', 'SEC-039: paid files stream through PHP; the server template closes the folder' );
	if ( 'catalog' === $store['tier'] ) {
		return;
	}
	wooset_option( 'woocommerce_enable_guest_checkout', 'yes' );
	wooset_option( 'woocommerce_enable_delayed_account_creation', 'yes', 'an account is offered after purchase, never forced' );
	wooset_option( 'woocommerce_enable_coupons', 'yes' );
}

function wooset_find_zone( $name ) {
	foreach ( WC_Shipping_Zones::get_zones() as $z ) {
		if ( $z['zone_name'] === $name ) {
			return WC_Shipping_Zones::get_zone( $z['zone_id'] );
		}
	}
	return null;
}

function wooset_find_method( $zone, $type ) {
	foreach ( $zone->get_shipping_methods() as $m ) {
		if ( $m->id === $type ) {
			return $m;
		}
	}
	return null;
}

function wooset_step_shipping( $store ) {
	if ( empty( $store['shipping'] ) ) {
		wooset_report( 'note', 'shipping', 'no zones in the block: only virtual and downloadable products can be bought' );
		return;
	}
	$c = &$GLOBALS['wooset_ctx'];
	foreach ( $store['shipping'] as $z ) {
		$name = $z['zone'];
		$zone = wooset_find_zone( $name );
		if ( ! $zone ) {
			wooset_report( 'set', "zone:$name", 'created' );
			if ( ! $c['write'] ) {
				continue;
			}
			$zone = new WC_Shipping_Zone();
			$zone->set_zone_name( $name );
			$zone->save();
		}
		$want = array();
		foreach ( $z['locations'] as $code ) {
			$want[] = wooset_location( $code );
		}
		wooset_converge(
			"zone:$name:locations",
			wooset_locations_canon( $want ),
			function () use ( $zone ) {
				$have = wooset_locations_canon( $zone->get_zone_locations() );
				return $have ? $have : null; // a zone with no locations is nobody's choice yet
			},
			function () use ( $zone, $want ) {
				$zone->set_locations( $want );
				$zone->save();
			}
		);
		foreach ( $z['methods'] as $m ) {
			$id    = "zone:$name:{$m['type']}";
			$owned = wooset_method_settings( $m );
			$found = wooset_find_method( $zone, $m['type'] );
			if ( ! $found ) {
				// A method this run adds is this run's, whatever the store's history.
				wooset_report( 'set', $id, 'added' );
				if ( $c['write'] ) {
					$iid = $zone->add_shipping_method( $m['type'] );
					update_option( "woocommerce_{$m['type']}_{$iid}_settings", $owned );
					$c['state'][ $id ] = wooset_hash( $owned );
				}
				continue;
			}
			$key = "woocommerce_{$m['type']}_{$found->instance_id}_settings";
			wooset_converge(
				$id,
				$owned,
				function () use ( $key, $owned ) {
					// woo-lib's contract: an absent key reads as null, and a method with none of
					// the owned keys stored is absent altogether.
					$stored = get_option( $key, null );
					$stored = is_array( $stored ) ? $stored : array();
					$have   = array();
					foreach ( $owned as $k => $unused ) {
						$have[ $k ] = array_key_exists( $k, $stored ) ? $stored[ $k ] : null;
					}
					return array_intersect_key( $stored, $owned ) ? $have : null;
				},
				function ( $v ) use ( $key ) {
					$stored = get_option( $key, array() );
					update_option( $key, array_merge( is_array( $stored ) ? $stored : array(), $v ) );
				}
			);
		}
	}
	if ( $c['write'] ) {
		WC_Cache_Helper::get_transient_version( 'shipping', true );
	}
}

function wooset_existing_rates() {
	$out = array();
	foreach ( array( '', 'reduced-rate', 'zero-rate' ) as $class ) {
		foreach ( WC_Tax::get_rates_for_tax_class( $class ) as $r ) {
			$out[] = wooset_tax_row(
				array(
					'id'       => (int) $r->tax_rate_id,
					'country'  => $r->tax_rate_country,
					'state'    => $r->tax_rate_state,
					'postcode' => isset( $r->postcode ) ? implode( ';', (array) $r->postcode ) : '',
					'city'     => isset( $r->city ) ? implode( ';', (array) $r->city ) : '',
					'name'     => $r->tax_rate_name,
					'class'    => $r->tax_rate_class,
					'rate'     => $r->tax_rate,
					'shipping' => $r->tax_rate_shipping,
				)
			);
		}
	}
	return $out;
}

function wooset_step_tax( $store ) {
	if ( empty( $store['tax'] ) ) {
		return;
	}
	$tax = $store['tax'];
	$c   = &$GLOBALS['wooset_ctx'];
	wooset_option( 'woocommerce_calc_taxes', $tax['enabled'] ? 'yes' : 'no' );
	wooset_option( 'woocommerce_prices_include_tax', $tax['prices_include_tax'] ? 'yes' : 'no' );
	$existing = wooset_existing_rates();
	foreach ( isset( $tax['rates'] ) ? $tax['rates'] : array() as $r ) {
		$want  = wooset_tax_row( $r );
		$key   = wooset_tax_key( $want );
		$id    = 'tax:' . $key;
		$owned = array( 'rate' => $want['rate'], 'shipping' => $want['shipping'] );
		$have  = null;
		foreach ( $existing as $e ) {
			if ( wooset_tax_key( $e ) === $key ) {
				$have = $e;
				break;
			}
		}
		if ( ! $have ) {
			wooset_report( 'set', $id, 'added at ' . $want['rate'] . '%' );
			if ( $c['write'] ) {
				$rid = WC_Tax::_insert_tax_rate(
					array(
						'tax_rate_country'  => $want['country'],
						'tax_rate_state'    => $want['state'],
						'tax_rate'          => $want['rate'],
						'tax_rate_name'     => $want['name'],
						'tax_rate_priority' => 1,
						'tax_rate_compound' => 0,
						'tax_rate_shipping' => $want['shipping'] ? 1 : 0,
						'tax_rate_order'    => 0,
						'tax_rate_class'    => 'standard' === $want['class'] ? '' : $want['class'],
					)
				);
				if ( '' !== $want['postcode'] ) {
					WC_Tax::_update_tax_rate_postcodes( $rid, $want['postcode'] );
				}
				if ( '' !== $want['city'] ) {
					WC_Tax::_update_tax_rate_cities( $rid, $want['city'] );
				}
				$c['state'][ $id ] = wooset_hash( $owned );
			}
			continue;
		}
		wooset_converge(
			$id,
			$owned,
			function () use ( $have ) {
				return array( 'rate' => $have['rate'], 'shipping' => $have['shipping'] );
			},
			function ( $v ) use ( $have ) {
				WC_Tax::_update_tax_rate( $have['id'], array( 'tax_rate' => $v['rate'], 'tax_rate_shipping' => $v['shipping'] ? 1 : 0 ) );
			}
		);
	}
}

/**
 * Zones, methods and rates setup recorded that the block no longer names but WooCommerce still
 * has. Setup never deletes -- a stale rate or method would otherwise keep charging while the run
 * read as a match -- so each is reported degraded, and a renamed zone or rate is a new one plus
 * a stale one.
 */
function wooset_step_stale( $store ) {
	$named = array();
	foreach ( empty( $store['shipping'] ) ? array() : $store['shipping'] as $z ) {
		$named[ "zone:{$z['zone']}:locations" ] = true;
		foreach ( $z['methods'] as $m ) {
			$named[ "zone:{$z['zone']}:{$m['type']}" ] = true;
		}
	}
	foreach ( empty( $store['tax']['rates'] ) ? array() : $store['tax']['rates'] as $r ) {
		$named[ 'tax:' . wooset_tax_key( wooset_tax_row( $r ) ) ] = true;
	}
	$rates = null;
	$gone  = array(); // zones already reported, so their methods are not reported again
	foreach ( array_keys( $GLOBALS['wooset_ctx']['state'] ) as $id ) {
		$id = (string) $id;
		if ( isset( $named[ $id ] ) ) {
			continue;
		}
		$exists = false;
		if ( 0 === strpos( $id, 'zone:' ) ) {
			$cut  = strrpos( $id, ':' );
			$name = substr( $id, 5, $cut - 5 );
			$zone = wooset_find_zone( $name );
			if ( ! $zone || isset( $gone[ $name ] ) ) {
				continue;
			}
			if ( ! isset( $named[ "zone:$name:locations" ] ) ) {
				$gone[ $name ] = true;
				$id            = "zone:$name";
				$exists        = true;
			} else {
				$exists = (bool) wooset_find_method( $zone, substr( $id, $cut + 1 ) );
			}
		} elseif ( 0 === strpos( $id, 'tax:' ) ) {
			$rates = null === $rates ? wooset_existing_rates() : $rates;
			foreach ( $rates as $e ) {
				$exists = $exists || 'tax:' . wooset_tax_key( $e ) === $id;
			}
		}
		if ( $exists ) {
			wooset_report( 'degraded', $id, 'setup created this and it is no longer in the block — remove it in WooCommerce' );
		}
	}
}

function wooset_step_payments( $keys, $root ) {
	// Only Stripe's own sub-steps depend on the keys; cash on delivery is converged either way.
	if ( wooset_stripe_keys( $keys, $root ) ) {
		wooset_stripe_resave();
		wooset_suboption( 'woocommerce_stripe_settings', 'enabled', 'yes', '', 'launch' );
		wooset_suboption( 'woocommerce_stripe_settings', 'testmode', 'yes', '', 'launch' );
	}
	$local = $GLOBALS['wooset_ctx']['local'];
	wooset_suboption(
		'woocommerce_cod_settings',
		'enabled',
		$local ? 'yes' : 'no',
		$local ? 'local only: pays the automated test order' : 'off outside a local environment',
		'launch'
	);
}

/** Puts the test keys in wp-config.php. True when Stripe can read them from there. */
function wooset_stripe_keys( $keys, $root ) {
	$map = array(
		'test_secret_key'      => 'STORE_KIT_STRIPE_TEST_SECRET_KEY',
		'test_publishable_key' => 'STORE_KIT_STRIPE_TEST_PUBLISHABLE_KEY',
		'test_webhook_secret'  => 'STORE_KIT_STRIPE_TEST_WEBHOOK_SECRET',
	);
	if ( '' === $keys['test_secret_key'] || '' === $keys['test_publishable_key'] ) {
		$supplied = store_kit_stripe_supplied();
		if ( isset( $supplied['test_secret_key'], $supplied['test_publishable_key'] ) ) {
			wooset_report( 'ok', 'stripe:keys', 'in wp-config.php' );
			return true;
		}
		wooset_report( 'degraded', 'stripe', 'no test keys in WP_CREATE_STRIPE_TEST_SECRET_KEY and _PUBLISHABLE_KEY, or in ' . $root . '/.wp-create.local.json (store.payments.test_secret_key, test_publishable_key): payments stay off until they are there' );
		return false;
	}
	$changed = array();
	foreach ( $map as $field => $constant ) {
		if ( '' !== $keys[ $field ] && ! ( defined( $constant ) && constant( $constant ) === $keys[ $field ] ) ) {
			$changed[ $field ] = $constant;
		}
	}
	if ( ! $changed ) {
		wooset_report( 'ok', 'stripe:keys', 'in wp-config.php, not the database (SEC-040)' );
		return true;
	}
	$config = wooset_config_path();
	if ( ! $config || ! class_exists( 'WPConfigTransformer' ) ) {
		wooset_report( 'degraded', 'stripe:keys', 'wp-config.php is not writable here: the keys were not written' );
		return false;
	}
	if ( $GLOBALS['wooset_ctx']['write'] ) {
		try {
			$t = new WPConfigTransformer( $config );
			foreach ( $changed as $field => $constant ) {
				$t->update( 'constant', $constant, $keys[ $field ], array( 'raw' => false, 'normalize' => true ) );
				// This process read wp-config.php before the write. Defining the constant here
				// is what lets store-kit's save filter strip the field in the re-save below.
				if ( ! defined( $constant ) ) {
					define( $constant, $keys[ $field ] );
				}
			}
		} catch ( Exception $e ) {
			// The class only: a transformer message can quote the line it choked on.
			wooset_report( 'degraded', 'stripe:keys', 'wp-config.php could not be written (' . get_class( $e ) . ')' );
			return false;
		}
	}
	wooset_report( 'set', 'stripe:keys', implode( ', ', array_keys( $changed ) ) . ' written to wp-config.php, values not shown (SEC-040: no key at rest)' );
	return true;
}

/**
 * A key typed into the Stripe screen before its constant existed is still in the row: store-kit
 * strips a supplied field only when the option is saved. Save it once, through store-kit's own
 * filter, whenever the stored row holds something that filter would take out.
 */
function wooset_stripe_resave() {
	global $wpdb;
	$raw = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", 'woocommerce_stripe_settings' ) );
	$row = null === $raw ? null : maybe_unserialize( $raw );
	if ( ! is_array( $row ) || store_kit_stripe_strip( $row ) === $row ) {
		wooset_report( 'ok', 'stripe:row', 'no supplied key stored in woocommerce_stripe_settings' );
		return;
	}
	if ( $GLOBALS['wooset_ctx']['write'] ) {
		update_option( 'woocommerce_stripe_settings', $row );
	}
	wooset_report( 'set', 'stripe:row', 'a key stored before its wp-config.php constant was taken out of the database' );
}

function wooset_step_protection() {
	wooset_option( 'woocommerce_feature_rate_limit_checkout_enabled', 'yes', 'checkout: 3 attempts a minute per IP against card testing' );
	// The general Store API limiter stays off on purpose: in WooCommerce 11.1.2 it shares the
	// checkout limit's per-IP row, so ordinary traffic dilutes 3 a minute to 25 every 10 seconds.
	if ( ! is_plugin_active( 'simple-cloudflare-turnstile/simple-cloudflare-turnstile.php' ) ) {
		wooset_report( 'degraded', 'turnstile', 'plugin not active: the checkout has no bot check' );
		return;
	}
	if ( ! $GLOBALS['wooset_ctx']['local'] ) {
		wooset_report( 'degraded', 'turnstile', 'real keys are set at launch; the checkout has no bot check until then' );
		return;
	}
	wooset_option( 'cfturnstile_key', '1x00000000000000000000AA', 'Cloudflare test site key: always passes' );
	wooset_option( 'cfturnstile_secret', '1x0000000000000000000000000000000AA', 'Cloudflare test secret: always passes', 'secret' );
	wooset_option( 'cfturnstile_woo_checkout', '1' );
	wooset_option( 'cfturnstile_tested', 'yes', 'the plugin loads its WooCommerce checks only once tested is yes' );
}

function wooset_step_visibility() {
	$local = $GLOBALS['wooset_ctx']['local'];
	wooset_option( 'woocommerce_coming_soon', $local ? 'no' : 'yes', $local ? 'visible on a local site' : 'coming soon until launch', 'launch' );
	wooset_option( 'woocommerce_store_pages_only', 'no' );
}

function wooset_step_jobs() {
	if ( defined( 'DISABLE_WP_CRON' ) && DISABLE_WP_CRON ) {
		wooset_report( 'degraded', 'cron', 'DISABLE_WP_CRON is set: without a real cron job the Action Scheduler backlog and expired sessions pile up (PERF-061, PERF-062)' );
	}
	if ( ! $GLOBALS['wooset_ctx']['write'] ) {
		return;
	}
	$r = WP_CLI::runcommand( 'action-scheduler run', array( 'return' => 'all', 'launch' => false, 'exit_error' => false ) );
	wooset_report( 0 === (int) $r->return_code ? 'ok' : 'degraded', 'jobs', 0 === (int) $r->return_code ? 'queued actions run' : 'action-scheduler run failed: ' . trim( (string) $r->stderr ) );
}

// ---------------------------------------------------------------------------------------------
// The run. Top-level variables in an eval-file script are not globals (see pll-lib.php), so the
// state the functions above share is put in $GLOBALS explicitly.
// ---------------------------------------------------------------------------------------------
$wooset_argv  = isset( $args ) ? array_values( (array) $args ) : array();
$wooset_root  = isset( $wooset_argv[0] ) ? rtrim( (string) $wooset_argv[0], '/' ) : '';
$wooset_dry   = in_array( 'dry-run', $wooset_argv, true );
$wooset_force = in_array( 'force', $wooset_argv, true );

if ( '' === $wooset_root || ! is_readable( $wooset_root . '/.wp-create.json' ) ) {
	wooset_refuse( 'usage: wp eval-file woo-setup.php <project-path> [dry-run] [force] -- no readable .wp-create.json at "' . $wooset_root . '"' );
}
$wooset_manifest = json_decode( (string) file_get_contents( $wooset_root . '/.wp-create.json' ), true );
if ( ! is_array( $wooset_manifest ) ) {
	wooset_refuse( '.wp-create.json is not valid JSON' );
}
$wooset_store = isset( $wooset_manifest['store'] ) && is_array( $wooset_manifest['store'] ) ? $wooset_manifest['store'] : null;
if ( null === $wooset_store ) {
	wooset_refuse( 'the manifest has no store block -- /wp-woo-setup records one' );
}
if ( ! isset( $wooset_store['tier'] ) || ! in_array( $wooset_store['tier'], array( 'catalog', 'store', 'full' ), true ) ) {
	wooset_refuse( 'store.tier must be catalog, store or full -- run wp-config.mjs validate' );
}
// The keys this script reads, checked here too: a block edited after validate would otherwise
// write an empty address or currency before anything noticed. Every tier sets its identity.
$wooset_required = array( 'address.street', 'address.city', 'address.postcode', 'address.country', 'currency', 'units.weight', 'units.dimension' );
if ( 'catalog' !== $wooset_store['tier'] ) {
	array_push( $wooset_required, 'payments.gateway', 'payments.mode' );
}
foreach ( $wooset_required as $wooset_path ) {
	$wooset_value = $wooset_store;
	foreach ( explode( '.', $wooset_path ) as $wooset_key ) {
		$wooset_value = is_array( $wooset_value ) && isset( $wooset_value[ $wooset_key ] ) ? $wooset_value[ $wooset_key ] : null;
	}
	if ( ! is_string( $wooset_value ) || '' === trim( $wooset_value ) ) {
		wooset_refuse( 'store block incomplete: store.' . $wooset_path . ' -- run wp-config.mjs validate' );
	}
}
if ( ! class_exists( 'WooCommerce' ) ) {
	wooset_refuse( 'WooCommerce is not active' );
}
if ( ! defined( 'STORE_KIT_VERSION' ) ) {
	wooset_refuse( 'store-kit is not active -- /wp-woo-setup copies and activates it first' );
}
$wooset_keys = wooset_read_keys( $wooset_root );
$wooset_live = wooset_live_key_in_test( $wooset_keys );
if ( $wooset_live ) {
	wooset_refuse( 'a live Stripe key sits in ' . implode( ', ', $wooset_live ) . ' -- test mode needs test keys; going live is a launch step' );
}
// store-kit supplies nothing from a constant whose prefix does not match its field, silently.
// Writing one would report keys configured while Stripe reads none.
$wooset_malformed = array();
foreach ( $wooset_keys as $wooset_field => $wooset_key ) {
	if ( '' !== $wooset_key && ! store_kit_stripe_prefix_ok( $wooset_field, $wooset_key ) ) {
		$wooset_malformed[] = $wooset_field;
	}
}
if ( $wooset_malformed ) {
	wooset_refuse( implode( ', ', $wooset_malformed ) . ' does not look like a Stripe test key (sk_test_/rk_test_, pk_test_, whsec_) -- store-kit would ignore it' );
}

$wooset_state = get_option( 'store_kit_setup_state', array() );
$wooset_state = is_array( $wooset_state ) ? $wooset_state : array();
$wooset_orders = wooset_has_orders();
$wooset_fresh  = wooset_is_fresh( $wooset_orders, isset( $wooset_manifest['origin'] ) ? (string) $wooset_manifest['origin'] : 'created' );
// A store with orders (or an adopted one) that setup has never recorded is a real merchant's:
// report what would change and write nothing until the operator passes force.
$wooset_report_only = ! $wooset_fresh && ! $wooset_state && ! $wooset_force;

$GLOBALS['wooset_ctx'] = array(
	'write'  => ! $wooset_dry && ! $wooset_report_only,
	'fresh'  => $wooset_fresh,
	'orders' => $wooset_orders,
	'force'  => $wooset_force,
	'local'  => 'local' === wp_get_environment_type(),
	'state'  => $wooset_state,
	'n'      => array( 'set' => 0, 'ok' => 0, 'client' => 0, 'degraded' => 0 ),
);
if ( $wooset_report_only && ! $wooset_dry ) {
	WP_CLI::line( 'report-only: this store has orders or was adopted, and setup has never run here -- re-run with force to apply; force never changes launch state (coming soon, Stripe enabled and test mode, cash on delivery) on a store with orders' );
}

$wooset_sells = 'catalog' !== $wooset_store['tier'];
wooset_step_environment();
wooset_step_admin();
wooset_step_hpos();
wooset_step_identity( $wooset_store );
wooset_step_pages( $wooset_store );
wooset_step_rules( $wooset_store );
if ( $wooset_sells ) {
	wooset_step_shipping( $wooset_store );
	wooset_step_tax( $wooset_store );
	wooset_step_stale( $wooset_store );
	wooset_step_payments( $wooset_keys, $wooset_root );
	wooset_step_protection();
}
wooset_step_visibility();
wooset_option( 'store_kit_catalog_mode', $wooset_sells ? 'no' : 'yes', $wooset_sells ? '' : 'prices shown, nothing purchasable' );
wooset_step_jobs();

if ( $GLOBALS['wooset_ctx']['write'] ) {
	update_option( 'store_kit_setup_state', $GLOBALS['wooset_ctx']['state'], false );
}
WP_CLI::line( wooset_summary( $GLOBALS['wooset_ctx']['n'], ! $GLOBALS['wooset_ctx']['write'] ) );
