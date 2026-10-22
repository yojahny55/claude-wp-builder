# Security procedure — payment-gateway credentials at rest (SEC-040)

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-security.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before SEC-040 on a site with WooCommerce.

## Contents

- Procedure — SEC-040 (payment-gateway credentials stored at rest)

### Procedure — SEC-040 (payment-gateway credentials stored at rest)

SEC-005 greps theme PHP for hardcoded secrets, but a payment gateway does not keep its live
API key in a file at all — most gateways keep their settings, credentials included, as a
serialized array in the `wp_options` row `woocommerce_<gateway_id>_settings` (a few use their
own option names instead; WooCommerce PayPal Payments keeps its secrets in `woocommerce-ppcp-*`
rows, and Mollie keeps each API key in an option of its own). Nothing that scans source code
can see those rows, and they are exactly what a database dump, a staging
snapshot or a cloned copy carries verbatim. A key sitting there is a live secret the same way a
key in a `.env` file is: whoever gets a copy of the database gets the gateway's production
credentials.

**Enumerate the rows from the database, not from WooCommerce's gateway registry, and classify
key names by their parts, not against a fixed list.** `WC_Payment_Gateways::instance()->payment_gateways()`
only returns gateways whose plugin is active and whose class is loaded — on a clone, where the
gateway plugins are deactivated, it returns the core offline methods only and every stored key
escapes the check. The `woocommerce_<gateway_id>_settings` rows are still there, so read those.
Likewise each gateway names its secrets its own way (`secret_key`, `app_secret`,
`live_secret_key`, `api_password`, `api_signature`, `webhook_secret`, `shared_secret_eu`,
`secret_key_v3`…), so an exact-name list, or a pattern anchored to a fixed set of suffixes,
misses real secrets.

**Read the stored row, not the option.** `get_option()` runs every `option_{$name}` filter, so a
plugin that supplies a key when the option is read — `store-kit` merges the `STORE_KIT_STRIPE_*`
constants from `wp-config.php` into `woocommerce_stripe_settings` this way — would be reported as
a key at rest while the database holds none. Both snippets read `option_value` directly and
unserialize it. This is revision 2 (`SEC-040@2`): on a site with such a filter, revision 1
reported a CRITICAL that revision 2 does not, which is a change in what the check reports on an
unchanged site.

Three sets of rows are read:

- every `woocommerce_*_settings` row, gateway or not (email settings and the like are swept
  too; a credential there is just as much a secret at rest);
- every `woocommerce-ppcp-*` row (WooCommerce PayPal Payments);
- every option whose name starts with one of the `$prefixes` below — gateways that keep a
  credential in an option of its own instead of inside a settings array: Mollie
  (`mollie-payments-for-woocommerce_live_api_key`, `…_test_api_key`), Square
  (`wc_square_access_tokens`, `wc_square_refresh_tokens`, `wc_square_settings`), Amazon Pay
  (`woocommerce_amazon_payments_advanced_private_key`), Mercado Pago (`_mp_access_token_prod`,
  `_mp_public_key_prod`, `…_test`), the JWT WooCommerce PayPal Payments keeps in
  `ppcp_agentic_registration_token`, and the Jetpack connection tokens
  WooPayments authenticates with (`jetpack_private_options`). For these the option name minus
  the prefix is part of the name being classified, so `live_api_key` and
  `access_tokens.production` are judged like a settings key.

```bash
$WP eval '
global $wpdb;
// --- SEC-040 classifier: keep this block byte-identical in both snippets ---
$prefixes = array( "mollie-payments-for-woocommerce_", "wc_square_", "woocommerce_amazon_payments_advanced_", "_mp_", "ppcp_agentic_", "jetpack_private_options" );
$classify = function ( $name, $path, $value ) use ( $prefixes ) {
    if ( ! is_scalar( $value ) || "" === trim( (string) $value )
        || in_array( strtolower( trim( (string) $value ) ), array( "yes", "no", "on", "off", "true", "false", "0", "1" ), true ) ) {
        return "";
    }
    $subject = (string) $path;
    foreach ( $prefixes as $prefix ) {
        if ( 0 === strpos( (string) $name, $prefix ) ) {
            $subject = substr( (string) $name, strlen( $prefix ) ) . "." . $subject;
            break;
        }
    }
    $subject = strtolower( preg_replace( "/([a-z0-9])([A-Z])/", "\\1_\\2", $subject ) );
    $subject = preg_replace( "/pass[^a-z0-9]*(phrase|word)/", "pass\\1", $subject );
    $parts   = preg_split( "/[^a-z0-9]+/", $subject, -1, PREG_SPLIT_NO_EMPTY );
    while ( count( $parts ) > 1 && preg_match( "/^(live|test|sandbox|production|prod|staging|dev|v[0-9]+|[0-9]+|eu|us|uk|gb|ca|au|nz|de|fr|es|it|nl|se|dk|fi|no|at|ch|be|pl|pt|ie|in|br|mx|jp|sg|hk|za|na|apac|emea|latam)$/", end( $parts ) ) ) {
        array_pop( $parts );
    }
    $last = $parts ? (string) end( $parts ) : "";
    $prev = count( $parts ) > 1 ? $parts[ count( $parts ) - 2 ] : "";
    if ( "" === $last || preg_match( "/^(method|type|mode|algorithm|algo|enabled|enable|length|format|version|url|uri|endpoint|name|label|title|description|status|date|time|expiry|expires|expiration|page|field|placeholder|text|message|path|file|prefix|count|size|limit|required|protected|header|lock)$/", $last ) ) {
        return "";
    }
    if ( preg_match( "/^(id|user|username|login|email|account)$/", $last )
        || preg_match( "/^(publishable|public|client|site)key$/", $prev . $last ) ) {
        return "INFO";
    }
    if ( preg_match( "/^(signature|pass|pw|pwd|pin|seed|salt|hash|private|[a-z0-9]*sha(256|512))$/", $last ) ) {
        return "CRITICAL";
    }
    foreach ( $parts as $part ) {
        if ( preg_match( "/^(secret[a-z0-9]*|[a-z0-9]*secrets?|[a-z0-9]*keys?|[a-z0-9]*tokens?|[a-z0-9]*passwords?|passwd|passphrase|credentials?|hmac|clave[0-9]*)$/", $part ) ) {
            return "CRITICAL";
        }
    }
    return "";
};
// --- end SEC-040 classifier ---
$likes = array(
    $wpdb->esc_like( "woocommerce_" ) . "%" . $wpdb->esc_like( "_settings" ),
    $wpdb->esc_like( "woocommerce-ppcp-" ) . "%",
);
foreach ( $prefixes as $prefix ) {
    $likes[] = $wpdb->esc_like( $prefix ) . "%";
}
$names = $wpdb->get_col( $wpdb->prepare(
    "SELECT option_name FROM {$wpdb->options} WHERE " . implode( " OR ", array_fill( 0, count( $likes ), "option_name LIKE %s" ) ),
    $likes
) );
if ( class_exists( "WC_Payment_Gateways" ) ) {
    foreach ( WC_Payment_Gateways::instance()->payment_gateways() as $gateway ) {
        $names[] = "woocommerce_" . $gateway->id . "_settings";
    }
}
$walk = function ( $name, $enabled, $data, $path ) use ( &$walk, $classify ) {
    if ( is_array( $data ) || $data instanceof stdClass ) {
        foreach ( (array) $data as $key => $value ) {
            $walk( $name, $enabled, $value, "" === $path ? (string) $key : $path . "." . $key );
        }
        return;
    }
    if ( is_object( $data ) ) {
        printf( "UNREAD %s: enabled=%s key=%s class=%s\n", $name, $enabled, "" === $path ? "-" : $path, get_class( $data ) );
        return;
    }
    $level = $classify( $name, $path, $data );
    if ( "" !== $level ) {
        printf( "%s %s: enabled=%s key=%s len=%d\n", $level, $name, $enabled, "" === $path ? "-" : $path, strlen( (string) $data ) );
    }
};
foreach ( array_unique( $names ) as $name ) {
    // The stored row, not get_option(): a plugin that supplies a key when the option is read
    // (store-kit merges wp-config.php constants into woocommerce_stripe_settings) has not put
    // it at rest, and get_option() would report it as if it had.
    $raw      = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $name ) );
    $settings = null === $raw ? false : maybe_unserialize( $raw );
    $enabled  = is_array( $settings ) && isset( $settings["enabled"] ) && is_scalar( $settings["enabled"] ) ? $settings["enabled"] : "-";
    $walk( $name, $enabled, $settings, "" );
}
'
```

How `$classify` reads a key (for a nested key, its dotted path; for a prefixed option, the
name after the prefix, then the path):

1. **Switch values are skipped** whatever the key is called: empty, `yes`, `no`, `on`, `off`,
   `true`, `false`, `0`, `1`. That is what keeps switches named after a secret, such as
   `require_signature=yes` or `use_hmac=1`, out.
2. The name is **split into segments** at camelCase boundaries and on anything that is not a
   letter or a digit, then lower-cased, so `clientSecretLive` reads like `client_secret_live`
   (`pass_phrase` and `pass_word` are joined back into one word).
3. **Qualifier segments are dropped from the end**, one at a time, while more than one segment
   is left: environments (`live`, `test`, `sandbox`, `production`, `prod`, `staging`, `dev`),
   versions (`v2`, `v3`), bare numbers, and region codes (`eu`, `us`, `uk`, …). So
   `secret_key_v3`, `shared_secret_eu`, `client_secret_production` and `secretsha256_2` are read
   as `secret_key`, `shared_secret`, `client_secret` and `secretsha256`. `id` is never a
   qualifier, so `merchant_id_eu` still ends in `id`.
4. If the last segment **describes** a credential rather than holding one — `method`, `type`,
   `mode`, `algorithm`, `enabled`, `length`, `format`, `version`, `url`, `endpoint`, `name`,
   `title`, `status`, `date`, `expiry`, `page`, `path`, `file`, `protected`, `lock`… — nothing
   is reported, even when an earlier segment is a secret word. So
   `signature_method=HMAC-SHA256`, `token_type`, `api_key_status` and Jetpack's `token_lock`
   (an expiry and a site URL) are silent.
5. If the last segment is an **identifier** (`id`, `user`, `username`, `login`, `email`,
   `account`), or the name ends in a key that is public by design (`publishable_key`,
   `public_key`, `client_key`, `site_key`), it is **INFO**. So `merchant_id_eu`, `site_key_v3`,
   `recaptcha_site_key`, `client_key` (Authorize.Net, Adyen) and `key_id` are INFO, not
   CRITICAL. `merchant_key` is deliberately **not** on that list: PayFast posts it in the
   checkout form, but Paytm's `merchant_key` is its secret signing key, so it is CRITICAL and a
   PayFast row costs one manual look.
6. It is **CRITICAL** if the last segment is signing material (`signature`, `pass`, `pw`,
   `pwd`, `pin`, `seed`, `salt`, `hash`, `private`, `…sha256`), or if **any** segment is a
   secret word: `secret` and its run-ons (`secretsha256`, `clientsecret`), anything ending in
   `key`, `token`, `password` or `secret` (`apikey`, `accesstoken`), their plurals, `passwd`,
   `passphrase`, `credential(s)`, `hmac`, or `clave` (Spanish for key, as Redsys names its
   signing key: `clave256`). Anything else is not reported.

Nested arrays and plain (`stdClass`) objects are walked, and a nested key is reported with its
dotted path. Any other object is printed as `UNREAD` with its class and not inspected: its
private properties cannot be read from outside, so read that one by hand before calling the
check a pass.

The order is the rule: switches, then descriptors, then identifiers, then secrets. A key the
classifier does not report is left alone by the scrub too, because the scrub runs the same
function.

- **Pass:** no row read above holds a non-empty value that `$classify` rates CRITICAL, and no
  `UNREAD` line is left unexplained — whatever the gateway's `enabled` flag and whether its
  plugin is active. Identifiers and
  public keys are listed as INFO and pass: a publishable key is public by design and an id is
  not a credential on its own. Coverage is limited to the three sets of rows listed above: a
  gateway that keeps its credential in an option with another name, a custom table or a file
  is not seen by this check, and a pass says nothing about it.
- **Fail:** any row read above holds a non-empty value that `$classify` rates CRITICAL
  (`secret_key`, `api_key`, `access_token`, `app_secret`, `api_password`, `shared_secret_eu`…).
  Report the option name, its `enabled` value (`-` when the row has none) and which key(s)
  matched (`-` when the option holds a single value), but never print the value itself — the
  length is enough to prove it is non-empty.
- Message: `Option "<option_name>" (enabled=<yes|no|->) stores a credential ("<key>") in
  wp_options — a database copy carries the working key`

**This is `N/A`, not a finding, on a non-commerce site.** Read `site.commerce` from `/wp-audit`
Step 2.3 rather than re-detecting WooCommerce here; when it is `none` this check is
`N/A ("no WooCommerce")`, out of the denominator, same as every other commerce-only check.

**Do not confuse this with the local-clone suppression in `/wp-audit` Step 2.3.** That step
lists "known-local plugins deactivated (payment gateways, …)" as a clone artifact to suppress
— a gateway turned off so the local copy cannot reach a live payment endpoint is expected and
is not a finding. SEC-040 is a different fact about the same gateway: the credential value
still sitting in `wp_options` is true of production too — deactivating the gateway on the
clone does not clear it — and it is exactly what makes a shared or cloned database a leak
risk. So a deactivated-but-still-configured gateway is reported by SEC-040 (a live key at
rest) even while its deactivation is not reported by Step 2.3 (a clone artifact). Neither the
`enabled` flag nor the plugin being inactive silences it: only a row with no CRITICAL key
holding a value is silent here.

**Fix is manual, never automatic.** There is no safe automatic fix — the theme does not own
`wp_options`, and clearing the key would break the live gateway on production. The remediation
is procedural: rotate the key at the payment processor if this database was ever shared, backed
up off the original server, or handed to a third party; and on a clone or shared copy meant to
be handed around, scrub the value from `wp_options` before the copy leaves the machine that has
production access. Scrub in place, never by dumping the option — `wp option get … --format=json`
prints every secret into the terminal and the session transcript. Run the scrub once per option
name the detection reported CRITICAL; it handles a settings array (nested keys included) and an
option that holds a single value alike:

```bash
$WP eval '
global $wpdb;
$name = "woocommerce_<gateway_id>_settings";
// --- SEC-040 classifier: keep this block byte-identical in both snippets ---
$prefixes = array( "mollie-payments-for-woocommerce_", "wc_square_", "woocommerce_amazon_payments_advanced_", "_mp_", "ppcp_agentic_", "jetpack_private_options" );
$classify = function ( $name, $path, $value ) use ( $prefixes ) {
    if ( ! is_scalar( $value ) || "" === trim( (string) $value )
        || in_array( strtolower( trim( (string) $value ) ), array( "yes", "no", "on", "off", "true", "false", "0", "1" ), true ) ) {
        return "";
    }
    $subject = (string) $path;
    foreach ( $prefixes as $prefix ) {
        if ( 0 === strpos( (string) $name, $prefix ) ) {
            $subject = substr( (string) $name, strlen( $prefix ) ) . "." . $subject;
            break;
        }
    }
    $subject = strtolower( preg_replace( "/([a-z0-9])([A-Z])/", "\\1_\\2", $subject ) );
    $subject = preg_replace( "/pass[^a-z0-9]*(phrase|word)/", "pass\\1", $subject );
    $parts   = preg_split( "/[^a-z0-9]+/", $subject, -1, PREG_SPLIT_NO_EMPTY );
    while ( count( $parts ) > 1 && preg_match( "/^(live|test|sandbox|production|prod|staging|dev|v[0-9]+|[0-9]+|eu|us|uk|gb|ca|au|nz|de|fr|es|it|nl|se|dk|fi|no|at|ch|be|pl|pt|ie|in|br|mx|jp|sg|hk|za|na|apac|emea|latam)$/", end( $parts ) ) ) {
        array_pop( $parts );
    }
    $last = $parts ? (string) end( $parts ) : "";
    $prev = count( $parts ) > 1 ? $parts[ count( $parts ) - 2 ] : "";
    if ( "" === $last || preg_match( "/^(method|type|mode|algorithm|algo|enabled|enable|length|format|version|url|uri|endpoint|name|label|title|description|status|date|time|expiry|expires|expiration|page|field|placeholder|text|message|path|file|prefix|count|size|limit|required|protected|header|lock)$/", $last ) ) {
        return "";
    }
    if ( preg_match( "/^(id|user|username|login|email|account)$/", $last )
        || preg_match( "/^(publishable|public|client|site)key$/", $prev . $last ) ) {
        return "INFO";
    }
    if ( preg_match( "/^(signature|pass|pw|pwd|pin|seed|salt|hash|private|[a-z0-9]*sha(256|512))$/", $last ) ) {
        return "CRITICAL";
    }
    foreach ( $parts as $part ) {
        if ( preg_match( "/^(secret[a-z0-9]*|[a-z0-9]*secrets?|[a-z0-9]*keys?|[a-z0-9]*tokens?|[a-z0-9]*passwords?|passwd|passphrase|credentials?|hmac|clave[0-9]*)$/", $part ) ) {
            return "CRITICAL";
        }
    }
    return "";
};
// --- end SEC-040 classifier ---
$count = 0;
$scrub = function ( $data, $path ) use ( &$scrub, &$count, $classify, $name ) {
    if ( is_array( $data ) || $data instanceof stdClass ) {
        $copy = is_object( $data ) ? clone $data : $data;
        foreach ( (array) $data as $key => $value ) {
            $new = $scrub( $value, "" === $path ? (string) $key : $path . "." . $key );
            if ( is_object( $copy ) ) {
                $copy->$key = $new;
            } else {
                $copy[ $key ] = $new;
            }
        }
        return $copy;
    }
    if ( "CRITICAL" === $classify( $name, $path, $data ) ) {
        $count++;
        return "";
    }
    return $data;
};
$raw = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $name ) );
$o   = null === $raw ? null : maybe_unserialize( $raw );
if ( null === $o ) {
    printf( "%s: option not found, nothing changed\n", $name );
} else {
    $clean = $scrub( $o, "" );
    if ( $count > 0 && ! update_option( $name, $clean ) ) {
        printf( "%s: update_option failed, nothing saved\n", $name );
    } else {
        printf( "%s: %d secret value(s) blanked\n", $name, $count );
    }
}
'
```

The scrub runs the same `$classify` as the detection snippet — the block between the two
`SEC-040 classifier` comments is identical in both — so it blanks exactly the keys reported
CRITICAL and leaves identifiers, public keys, descriptors and switches alone.
