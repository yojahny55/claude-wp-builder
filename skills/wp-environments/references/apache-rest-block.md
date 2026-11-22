# Blocking the WordPress REST API in Apache

A site that exposes nothing through the REST API to anonymous visitors (no headless front end,
no public app) can refuse `/wp-json/` at the web server. This page is the recipe for Apache
2.4, and the PHP half that has to go with it. Read the last section before you treat either
half as a boundary.

## Contents

- Why an `<If>` in server context
- The rule — what each part answers, measured
- What it breaks, and how to open a namespace
- Apache is the outer layer, not the boundary — the mu-plugin
- Applying it

## Why an `<If>` in server context

A rule inside the site's `<VirtualHost>` is the obvious place, and it fails on a host whose
vhost files are included twice (a `conf.d/*.conf` glob plus an explicit `Include` of the same
file, or a control panel that writes its own copy): the request is answered by whichever copy
Apache matched first, and that may be the one without the rule.

`<If>` sections are merged last, after `<Directory>`, `<Location>` and `.htaccess`. An `<If>`
written in server context, outside every `<VirtualHost>`, applies to every request whichever
vhost answers it, and a later `Require all granted` in a `<Directory>` cannot undo it. The
condition names the site's document root, so the other sites on the server are untouched.

Put it in its own file under `conf.d/` (`/etc/httpd/conf.d/` or `/etc/apache2/conf-enabled/`),
never in `.htaccess`: `.htaccess` is per directory, a plugin can rewrite it, and `<If>` there
only covers requests that reach that directory.

## The rule

Replace the document root (`/var/www/example`) and nothing else: write it exactly as the
site's `DocumentRoot` reads, with any `.` in it as `[.]`. Every character class is written as
`[.]` or `[+]` instead of a backslash escape on purpose: Apache's config parser and the
expression parser both consume backslashes, and a class reads the same to both.

<!-- apache-rest-block:rule -->
```apache
# REST API blocked for the site in /var/www/example, CF7 left open. Server context: outside every <VirtualHost>.
<If "%{DOCUMENT_ROOT} =~ m#^/var/www/example/?$# && ((%{REQUEST_URI} =~ m#^/+([^/]+[.]php/+)?wp-json(/|$)#i && ! (%{REQUEST_URI} =~ m#^/+wp-json/+contact-form-7/+v1/#i)) || %{QUERY_STRING} =~ /(^|&)([+]|%20)*(r|%72)(e|%65)(s|%73)(t|%74)(_|[.]|[+]|[[]|%5f|%2e|%20|%5b)(r|%72)(o|%6f)(u|%75)(t|%74)(e|%65)($|=|&|[[]|%5b|%00)/i)">
    Require all denied
</If>
```
<!-- /apache-rest-block:rule -->

What each part answers:

- **Which site.** The condition names the site by `%{DOCUMENT_ROOT}`, the `DocumentRoot` of
  the vhost that actually answered, never by the `Host` header. A host test is a test of what
  the client typed: every `ServerAlias`, the server's IP, a trailing dot, a port, and no `Host`
  at all when the site is the default vhost all reach the same site under a name the test does
  not list. The document root is the same whichever name got the request there, and a site on
  another vhost has its own. Two vhosts serving one directory (a `:80` and a `:443` copy) are
  one site and are both covered. Under `mod_vhost_alias` the document root is computed per
  request and this variable does not reflect it; that layout needs one condition per name.
- **Path.** `%{REQUEST_URI}` is the decoded path with dot segments already removed, so
  `%77p-json`, `/x/../wp-json` and `//wp-json` all arrive as `/wp-json`. `[^/]+[.]php/+`
  covers WordPress reading the route from `PATH_INFO`: `/index.php/wp-json/…` and
  `/wp-blog-header.php/wp-json/…` both reach the API. The match ignores case.
- **Query.** WordPress also serves the API from any URL carrying `rest_route`. PHP decodes and
  rewrites a key before `$_GET` sees it, and the expression has to match what PHP reads, not
  what the client typed:

  | Client sends | PHP reads | Why |
  |---|---|---|
  | `%72est_route=` | `rest_route` | keys are percent-decoded |
  | `rest.route=`, `rest+route=`, `rest%20route=`, `rest[route=` | `rest_route` | `.`, space and an unmatched `[` become `_` |
  | `+rest_route=` | `rest_route` | leading spaces are dropped |
  | `rest_route%00x=` | `rest_route` | the key ends at a NUL byte |
  | `rest_route[]=` | `rest_route` (array) | still the key |
  | `rest_route` (no `=`) | `rest_route` = `""` | blocked anyway |
  | `x=1%26rest_route=` | `x` only | `&` splits before decoding: not a key, not blocked |
  | `s=rest_route`, `payment_method=` | not the key | the match is anchored to a key start |

  The expression never calls `unescape()`: it fails on `%zz` or `%00` and returns an empty
  string, which would let any such query through. Each letter is matched as itself or its
  `%XX` form instead. `REST_ROUTE` is blocked although PHP keys are case sensitive; nothing
  legitimate sends it.
- **No query exception.** Contact Form 7 is exempt only in its pretty-permalink form,
  `/wp-json/contact-form-7/v1/`. Every `rest_route` query is refused, including one naming CF7,
  because PHP keeps the last of duplicated keys and WordPress lets a query `rest_route`
  override the route in the path: `?rest_route=/contact-form-7/…&rest_route=/wp/v2/users` or
  `/wp-json/contact-form-7/v1/x?rest_route=/wp/v2/users` would otherwise pass. The site must
  use pretty permalinks, which every site this plugin builds does.

### Measured

Replayed against a throwaway Apache 2.4 with the rule above by
`tests/checks/apache-rest-block.sh`. `403` is the rule firing; anything else means it let the
request through.

| Request | Result |
|---|---|
| `/wp-json/`, `/wp-json/wp/v2/users`, `/WP-JSON/wp/v2/users`, `//wp-json/` | 403 |
| `/%77p-json/wp/v2/users`, `/wp-json/contact-form-7/../wp/v2/users` | 403 |
| `/index.php/wp-json/wp/v2/users`, `/wp-blog-header.php/wp-json/` | 403 |
| `/?rest_route=/wp/v2/users` and every key form in the table above | 403 |
| `/wp-json/contact-form-7/v1/x?rest_route=/wp/v2/users` | 403 |
| `Host: example.com.`, `Host: WWW.EXAMPLE.COM:443`, an alias, the IP, no `Host` (default vhost) | 403 |
| `/wp-json/contact-form-7/v1/contact-forms/1/feedback` | passes |
| `/wp-admin/admin-ajax.php`, `/`, `/?s=rest_route`, `/?payment_method=x`, `/?x=1%26rest_route=/a` | passes |
| `/wp-json/wp/v2/users` on another vhost with its own document root | passes |

## What it breaks, and how to open a namespace

- **The block editor** calls `/wp/v2/` with a nonce from wp-admin. A site edited with Gutenberg
  needs the PHP half below instead of the Apache rule, or the rule plus an exception for
  `wp/v2`, which hands that namespace back to anonymous visitors too.
- **WooCommerce** cart and checkout blocks call the Store API, `wc/store`. A store must exempt
  it.
- **Site Health** reports the REST API as unavailable. That is the block working.
- `admin-ajax.php` is untouched.

To exempt a namespace, add it to the path exception, never as a query exception:

```apache
! (%{REQUEST_URI} =~ m#^/+wp-json/+(contact-form-7/+v1|wc/+store)/#i)
```

**Do not exempt by cookie.** "Let logged-in users through" written as a `wordpress_logged_in_`
cookie test is a test for a header any client can send. Authentication is WordPress's job,
which is the next section.

**`rest_url_prefix`.** The rule assumes the prefix is `wp-json`. If a plugin or the theme
filters `rest_url_prefix`, the path half guards the wrong name and the API answers at the new
one; read the prefix with `wp eval 'echo rest_get_url_prefix();'` and write that instead.
WordPress installed in a subdirectory needs the directory in front of `wp-json` too.

## Apache is the outer layer, not the boundary

WordPress also reads `rest_route` from a POST body, on any URL, and `X-HTTP-Method-Override:
GET` or `?_method=GET` turns that POST into a read. Apache never sees the body, so a form post
to `/` with `rest_route=/wp/v2/users` goes straight through the rule above. The rule cuts the
noise; the refusal that holds lives in PHP. Ship both.

<!-- apache-rest-block:mu-plugin -->
```php
<?php
/**
 * Plugin Name: REST API restricted
 * Description: Refuses REST requests from anonymous visitors, except the listed namespaces.
 */

defined( 'ABSPATH' ) || exit;

add_filter(
	'rest_pre_dispatch',
	function ( $result, $server, $request ) {
		if ( null !== $result || is_user_logged_in() ) {
			return $result;
		}
		$open  = array( '/contact-form-7/v1/' );
		$route = '/' . ltrim( (string) $request->get_route(), '/' ) . '/';
		foreach ( $open as $prefix ) {
			if ( 0 === strpos( $route, $prefix ) ) {
				return $result;
			}
		}
		return new WP_Error( 'rest_forbidden', 'REST API restricted.', array( 'status' => 401 ) );
	},
	10,
	3
);
```
<!-- /apache-rest-block:mu-plugin -->

Save it as `wp-content/mu-plugins/rest-restricted.php`. `rest_pre_dispatch` runs on every
dispatch, whichever way the route arrived (path, query, POST body, method override) and also
for internal `rest_do_request()` calls. A cookie without a valid `X-WP-Nonce` leaves the user
logged out for the REST request, so `is_user_logged_in()` is not fooled by a copied cookie
either. Add `/wc/store/` to `$open` on a store.

## Applying it

1. Write the file under `conf.d/`, run `apachectl configtest`, then reload (`graceful`), not
   restart.
2. Verify by result, with curl, from outside the server: one blocked request from each row of
   the table, the CF7 endpoint, `admin-ajax.php` and the home page. `configtest` passing says
   the syntax parses, not that the rule matches.
3. On production, only through the audit's production runbook (`audit-runbook.mjs`), never by
   hand from an audit session, and with the PHP half deployed first.
