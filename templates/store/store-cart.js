/* Store cart: keeps the header's cart count (template-parts/header/store-cart.php) current.
 * Copied by /wp-woo-setup to assets/js/store-cart.js and enqueued by that template part.
 *
 * The server renders the count. This re-reads it from WooCommerce's Store API only when
 * WooCommerce says the cart changed, and when the browser restores the page from its
 * back-forward cache. Classic add-to-cart buttons announce a change with jQuery events, which
 * a native listener never hears; blocks announce it with native events.
 */
( () => {
	'use strict';

	const links = document.querySelectorAll( '[data-store-cart]' );
	if ( ! links.length || ! window.fetch ) {
		return;
	}
	const endpoint = links[ 0 ].getAttribute( 'data-store-cart' );

	const render = ( count ) => {
		links.forEach( ( link ) => {
			const label = link.getAttribute( count === 1 ? 'data-label-one' : 'data-label-many' );
			if ( label ) {
				link.setAttribute( 'aria-label', label.replace( '%d', String( count ) ) );
			}
			const badge = link.querySelector( '[data-store-cart-count]' );
			if ( badge ) {
				badge.textContent = String( count );
				badge.hidden = count === 0;
			}
		} );
	};

	// One request at a time; a change announced while one is in flight reads again after it.
	let inFlight = false;
	let again = false;
	const refresh = () => {
		if ( inFlight ) {
			again = true;
			return;
		}
		inFlight = true;
		fetch( endpoint, { credentials: 'same-origin', headers: { Accept: 'application/json' } } )
			.then( ( response ) => ( response.ok ? response.json() : null ) )
			.then( ( cart ) => {
				if ( cart && typeof cart.items_count === 'number' ) {
					render( cart.items_count );
				}
			} )
			.catch( () => {} ) // The server's count stays; the next change tries again.
			.then( () => {
				inFlight = false;
				if ( again ) {
					again = false;
					refresh();
				}
			} );
	};

	if ( window.jQuery ) {
		window.jQuery( document.body ).on( 'added_to_cart removed_from_cart', refresh );
	}
	document.body.addEventListener( 'wc-blocks_added_to_cart', refresh );
	document.body.addEventListener( 'wc-blocks_removed_from_cart', refresh );
	window.addEventListener( 'pageshow', ( event ) => {
		if ( event.persisted ) {
			refresh();
		}
	} );
} )();
