<?php
/**
 * Report nav-menu items that do not navigate anywhere useful.
 *
 * Usage: wp eval-file audit-menu-links.php
 *
 * Read-only. Exits 1 when any item is reported, 0 otherwise.
 *
 * WHY THIS EXISTS. A `custom` menu item stores its target in
 * postmeta._menu_item_url, verbatim. Nothing in header.php or footer.php shows
 * it, so a broken menu link is invisible to any check that reads the theme. On
 * an audited site two footer items had url = "#" while the pages they were meant
 * to open existed and were published, and a third held the absolute URL of the
 * development host — a link that leaves the live site after a migration. None of
 * the three was in the theme: the menu was assigned through a nav-menu widget, so
 * even the registered menu locations did not list it.
 *
 * WHY THE CHILD EXCLUSION IS NOT OPTIONAL. A `custom` item with url = "#" that
 * has children is a submenu header. It is not supposed to navigate; the theme
 * opens its submenu on hover or tap. Without this exclusion the check fires on
 * almost every menu that has a submenu at all, and the genuinely broken links are
 * lost among the false positives.
 *
 * Prefer converting a finding to a `post_type` item over editing its URL. A
 * `post_type` item derives its URL from siteurl at render time, so it survives a
 * migration to another host; a `custom` item carries whatever host was typed into
 * it, which is how a development host ends up in the database in the first place
 * (see check-dev-host.php).
 */

$dev_host = preg_replace( '#^https?://#', '', rtrim( home_url(), '/' ) );
$findings = 0;

/*
 * Every menu, not only the ones assigned to a registered location. A menu
 * assigned through a widget has no location, and that is exactly the case that
 * went unnoticed.
 */
$menus = wp_get_nav_menus();

if ( ! $menus ) {
	echo "No nav menus exist.\n";
	exit( 0 );
}

$locations = array_flip( (array) get_nav_menu_locations() );

foreach ( $menus as $menu ) {
	$items = wp_get_nav_menu_items( $menu->term_id );

	if ( ! $items ) {
		continue;
	}

	// An item is a submenu header when something else declares it as its parent.
	$has_children = array();
	foreach ( $items as $item ) {
		if ( $item->menu_item_parent ) {
			$has_children[ (int) $item->menu_item_parent ] = true;
		}
	}

	$where = isset( $locations[ $menu->term_id ] )
		? "location '{$locations[ $menu->term_id ]}'"
		: 'no location — assigned by widget, or unassigned';

	foreach ( $items as $item ) {
		if ( 'custom' !== $item->type ) {
			continue;
		}

		if ( isset( $has_children[ (int) $item->ID ] ) ) {
			continue;
		}

		$url    = trim( (string) $item->url );
		$reason = '';

		if ( '' === $url || '#' === $url ) {
			$reason = 'goes nowhere';
		} elseif ( '' !== $dev_host && false !== strpos( $url, $dev_host ) ) {
			$reason = 'absolute URL on the development host';
		}

		if ( '' === $reason ) {
			continue;
		}

		printf(
			"%s — item %d '%s' (%s): %s [url: %s]\n",
			$menu->name,
			$item->ID,
			$item->title,
			$where,
			$reason,
			'' === $url ? '(empty)' : $url
		);

		$findings++;
	}
}

printf( "\n%d menu items do not navigate\n", $findings );

exit( $findings > 0 ? 1 : 0 );
